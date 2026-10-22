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
}
