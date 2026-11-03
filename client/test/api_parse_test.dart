import 'package:flutter_test/flutter_test.dart';
import 'package:xd_client/api.dart';
import 'package:xd_client/cache.dart';
import 'package:xd_client/models.dart';

/// 这里只测「纯函数」——不碰网络、不碰存储。
///
/// 重点覆盖 `parseJumpHtml`：发串接口没有结构化返回，成功失败全靠文案匹配，
/// 站点改一个字这套逻辑就会失效，所以必须有回归测试兜着。
void main() {
  final api = Api.instance;

  group('parseJumpHtml 发串结果判定', () {
    test('文案含「发串成功」判成功', () {
      final r = api.parseJumpHtml(
        '<html><body><div class="msg">发串成功，正在跳转…</div></body></html>',
      );
      expect(r.ok, isTrue);
      expect(r.message, contains('发串成功'));
    });

    test('文案含「回复成功」判成功', () {
      final r = api.parseJumpHtml('<p>回复成功</p>');
      expect(r.ok, isTrue);
    });

    test('「间隔」类文案判失败并回传上下文', () {
      final r = api.parseJumpHtml('<p>发帖间隔小于 30 秒，请稍后再试</p>');
      expect(r.ok, isFalse);
      expect(r.message, contains('间隔'));
    });

    test('「未应用饼干」判失败', () {
      final r = api.parseJumpHtml('<p>未应用饼干，请先领取饼干</p>');
      expect(r.ok, isFalse);
      expect(r.message, contains('未应用饼干'));
    });

    test('命中多个关键词时不崩，只取首个', () {
      final r = api.parseJumpHtml('<p>禁止发布，发送失败</p>');
      expect(r.ok, isFalse);
      expect(r.message.isNotEmpty, isTrue);
    });

    test('完全没匹配上时，返回原文前 100 字且不超长', () {
      final r = api.parseJumpHtml('<p>${'占位' * 200}</p>');
      expect(r.ok, isFalse);
      expect(r.message.length, lessThanOrEqualTo(100));
    });

    test('空响应不抛异常', () {
      final r = api.parseJumpHtml('');
      expect(r.ok, isFalse);
      expect(r.message, '未知返回');
    });
  });

  group('parseSearchHtml 搜索结果解析', () {
    test('解析 /t/{id} 链接并按 id 去重', () {
      const html = '<a href="/t/123456">第一个串</a>'
          '<a href="/t/123456">同一个串的重复链接</a>'
          '<a href="/t/789">第二个串</a>';
      final r = api.parseSearchHtml(html);
      expect(r.hits.length, 2);
      expect(r.hits.first.id, 123456);
      expect(r.hits.first.title, '第一个串');
    });

    test('没有结果时给出对应文案', () {
      final r = api.parseSearchHtml('<div>没有找到相关串</div>');
      expect(r.hits, isEmpty);
      expect(r.message, contains('没有找到'));
    });

    test('需要登录时提示导入饼干', () {
      final r = api.parseSearchHtml('<div>必须登入后才能搜索</div>');
      expect(r.hits, isEmpty);
      expect(r.message, contains('导入饼干'));
    });
  });

  group('asInt 数字容错', () {
    test('字符串数字、整数、空值、脏数据', () {
      expect(asInt('123'), 123);
      expect(asInt(45), 45);
      expect(asInt(7.8), 7);
      expect(asInt(null), 0);
      expect(asInt('abc'), 0);
    });
  });

  group('写接口路径', () {
    test('默认使用网页端的大驼峰写法', () {
      expect(Api.postThreadPath, '/Home/Forum/doPostThread.html');
      expect(Api.replyThreadPath, '/Home/Forum/doReplyThread.html');
    });

    test('404 回退可以互换大小写，且对无关路径原样返回', () {
      expect(
        Api.flipPathCasing('/Home/Forum/doPostThread.html'),
        '/home/forum/doPostThread.html',
      );
      expect(
        Api.flipPathCasing('/home/forum/doReplyThread.html'),
        '/Home/Forum/doReplyThread.html',
      );
      expect(Api.flipPathCasing('/Forum/search.html'), '/Forum/search.html');
    });

    test('互换两次回到原值，保证回退不会来回抖动', () {
      const p = '/Home/Forum/doPostThread.html';
      expect(Api.flipPathCasing(Api.flipPathCasing(p)), p);
    });
  });

  group('CacheStore.keyOf 缓存键', () {
    test('同 path + 同饼干得到同一个键', () {
      expect(
        CacheStore.keyOf('thread?id=1&page=1', 'abc'),
        CacheStore.keyOf('thread?id=1&page=1', 'abc'),
      );
    });

    test('饼干不同则键不同，避免串号串味', () {
      expect(
        CacheStore.keyOf('thread?id=1&page=1', 'abc'),
        isNot(CacheStore.keyOf('thread?id=1&page=1', 'def')),
      );
    });

    test('path 不同则键不同', () {
      expect(
        CacheStore.keyOf('thread?id=1&page=1', 'abc'),
        isNot(CacheStore.keyOf('thread?id=2&page=1', 'abc')),
      );
    });
  });

  // 领取饼干走的是网页登录，没有结构化返回，全靠解析 HTML。
  // 站点改一个属性这套逻辑就可能失效，所以必须有回归测试兜着。
  group('parseClaimHash 登录页令牌', () {
    const page =
        '<form><input type="hidden" name="__hash__" value="a1b2_c3d4" /></form>';

    test('取 name 在前的 __hash__', () {
      expect(api.parseClaimHash(page), 'a1b2_c3d4');
    });

    test('value 在 name 之前也能取到', () {
      expect(
        api.parseClaimHash('<input type="hidden" value="xy_z" name="__hash__">'),
        'xy_z',
      );
    });

    test('大小写不敏感', () {
      expect(
        api.parseClaimHash('<INPUT NAME="__HASH__" VALUE="Up_Case">'),
        'Up_Case',
      );
    });

    test('页面里没有 __hash__ 时抛 ApiException', () {
      expect(() => api.parseClaimHash('<form></form>'),
          throwsA(isA<ApiException>()));
    });
  });

  group('parseLoginError 登录失败原因', () {
    test('取 <p class="error"> 的文案', () {
      expect(
        api.parseLoginError('<div><p class="error">验证码错误</p></div>'),
        '验证码错误',
      );
    });

    test('class 里混了别的名字也认得 error', () {
      expect(
        api.parseLoginError('<p class="am-error text">密码错误</p>'),
        '密码错误',
      );
    });

    test('没有 error 标签时按关键词兜底', () {
      expect(api.parseLoginError('<div>验证码不正确</div>'), '验证码错误');
      expect(api.parseLoginError('<div>密码不对</div>'), '账号或密码不对');
    });

    test('完全认不出时给通用文案', () {
      expect(api.parseLoginError('<html></html>'), contains('登录没成功'));
    });

    test('标签里的样式内容不会混进文案', () {
      expect(
        api.parseLoginError(
            '<p class="error"><style>p{color:red}</style>验证码错误</p>'),
        '验证码错误',
      );
    });
  });
}
