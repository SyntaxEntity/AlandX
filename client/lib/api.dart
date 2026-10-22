import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cache.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class CookieCheck {
  final bool ok;
  final String message;
  const CookieCheck(this.ok, this.message);
}

class PostResult {
  final bool ok;
  final String message;
  const PostResult(this.ok, this.message);
}

class SearchHit {
  final int id;
  final String title;
  const SearchHit(this.id, this.title);
}

class SearchResult {
  final List<SearchHit> hits;
  final String message;
  const SearchResult(this.hits, this.message);
}

/// X岛接口封装（原生直连）。
///
/// 注意：api.nmb.best 不返回任何 CORS 头，所以 Flutter Web 不能直连；
/// 本项目只面向 Android / iOS / Desktop。
class Api {
  Api._();
  static final Api instance = Api._();

  static const String apiBase = 'https://api.nmb.best/api/';
  static const String cdnBase = 'https://image.nmb.best/';
  static const String webBase = 'https://www.nmbxd1.com';

  /// 最近一次请求耗时（毫秒）。
  int lastUpstreamMs = 0;

  /// 最近一次返回是否来自过期缓存（网络失败兜底）。
  bool lastFromCache = false;
  int lastCacheAgeMs = 0;

  void clearCache() => CacheStore.instance.clear();

  Map<String, String> _headers(String? cookie) {
    final h = <String, String>{
      'Accept': '*/*',
      'User-Agent': 'HavfunClient-Flutter',
    };
    if (cookie != null && cookie.isNotEmpty) {
      h['Cookie'] = 'userhash=$cookie';
    }
    return h;
  }

  static Duration _ttlFor(String path) {
    if (path.startsWith('getForumList')) return const Duration(hours: 12);
    if (path.startsWith('thread?') || path.startsWith('po?')) {
      return const Duration(minutes: 10);
    }
    if (path.startsWith('feed?')) return const Duration(minutes: 2);
    return const Duration(seconds: 90);
  }

  dynamic _staleOrNull(String key) {
    final stale = CacheStore.instance.getStale(key);
    if (stale == null) return null;
    lastFromCache = true;
    lastCacheAgeMs = stale.ageMs;
    return stale.data;
  }

  Future<dynamic> getJson(String path, {String? cookie, bool force = false}) async {
    final key = CacheStore.keyOf(path, cookie);

    if (!force) {
      final fresh = CacheStore.instance.getFresh(key, _ttlFor(path));
      if (fresh != null) {
        lastFromCache = false;
        lastCacheAgeMs = 0;
        return fresh;
      }
    }

    final sw = Stopwatch()..start();
    http.Response res;
    try {
      res = await http
          .get(Uri.parse(apiBase + path), headers: _headers(cookie))
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      final stale = _staleOrNull(key);
      if (stale != null) return stale;
      throw ApiException('上游 25s 未响应');
    } catch (e) {
      final stale = _staleOrNull(key);
      if (stale != null) return stale;
      throw ApiException('网络错误：$e');
    }
    lastUpstreamMs = sw.elapsedMilliseconds;

    // 5xx 多半是站点维护（实测整站 502 过），用旧缓存兜底比直接报错友好。
    if (res.statusCode >= 500) {
      final stale = _staleOrNull(key);
      if (stale != null) return stale;
      throw ApiException('HTTP ${res.statusCode}（站点可能维护中）');
    }
    if (res.statusCode != 200) {
      throw ApiException('HTTP ${res.statusCode}');
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ApiException('返回不是合法 JSON');
    }

    if (data is Map && data['success'] == false) {
      throw ApiException(
          asStr(data['error']).isEmpty ? '接口返回失败' : asStr(data['error']));
    }

    lastFromCache = false;
    lastCacheAgeMs = 0;
    await CacheStore.instance.put(key, data);
    return data;
  }

  Future<List<Post>> fetchList(Source s, int page,
      {String? cookie, bool force = false}) async {
    final data = await getJson('${s.path}$page', cookie: cookie, force: force);
    if (data is! List) throw ApiException('返回格式异常');
    return data
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Post> fetchThread(int id,
      {int page = 1, bool onlyPo = false, String? cookie}) async {
    final key = onlyPo ? 'po?id=$id&page=$page' : 'thread?id=$id&page=$page';
    final data = await getJson(key, cookie: cookie);
    if (data is! Map) throw ApiException('该串不存在');
    return Post.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<ForumCategory>> fetchForums({bool force = false}) async {
    final data = await getJson('getForumList', force: force);
    if (data is! List) throw ApiException('返回格式异常');
    return data
        .whereType<Map>()
        .map((e) => ForumCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Post>> fetchFeed(String uuid, {bool force = false}) async {
    final data = await getJson('feed?uuid=$uuid&page=1', force: force);
    if (data is! List) return const <Post>[];
    return data
        .whereType<Map>()
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> addFeed(String uuid, int tid) async =>
      _plain('addFeed?uuid=$uuid&tid=$tid');

  Future<String> delFeed(String uuid, int tid) async =>
      _plain('delFeed?uuid=$uuid&tid=$tid');

  Future<String> _plain(String path) async {
    final res = await http
        .get(Uri.parse(apiBase + path), headers: _headers(null))
        .timeout(const Duration(seconds: 20));
    var text = utf8.decode(res.bodyBytes).trim();
    if (text.startsWith('"') && text.endsWith('"') && text.length > 1) {
      text = text.substring(1, text.length - 1);
    }
    return text;
  }

  /// 用受限版面（速报2）探测饼干是否有效。
  Future<CookieCheck> verifyCookie(String cookie) async {
    if (cookie.isEmpty) return const CookieCheck(false, '饼干为空');
    try {
      final data = await getJson('showf?id=121&page=1',
          cookie: cookie, force: true);
      if (data is List) return const CookieCheck(true, '饼干有效');
      return const CookieCheck(false, '饼干无效');
    } on ApiException catch (e) {
      return CookieCheck(false, e.message);
    }
  }

  // ---------------- 发串 / 回复 ----------------

  Future<PostResult> postThread({
    required String cookie,
    required int fid,
    required String title,
    required String content,
    Uint8List? image,
    String? filename,
  }) {
    return _write(
      '/home/forum/doPostThread.html',
      cookie: cookie,
      fields: <String, String>{
        'fid': '$fid',
        'title': title.isEmpty ? '无标题' : title,
        'content': content,
        'name': '无名氏',
      },
      image: image,
      filename: filename,
    );
  }

  Future<PostResult> postReply({
    required String cookie,
    required int resto,
    required String content,
    Uint8List? image,
    String? filename,
  }) {
    return _write(
      '/home/forum/doReplyThread.html',
      cookie: cookie,
      fields: <String, String>{
        'resto': '$resto',
        'title': '无标题',
        'content': content,
        'name': '无名氏',
      },
      image: image,
      filename: filename,
    );
  }

  Future<PostResult> _write(
    String path, {
    required String cookie,
    required Map<String, String> fields,
    Uint8List? image,
    String? filename,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse(webBase + path));
    req.headers.addAll(<String, String>{
      'Cookie': 'userhash=$cookie',
      'Referer': '$webBase/',
      'User-Agent': 'HavfunClient-Flutter',
    });
    req.fields.addAll(fields);
    if (image != null && image.isNotEmpty) {
      req.files.add(http.MultipartFile.fromBytes(
        'image',
        image,
        filename: (filename == null || filename.isEmpty) ? 'image.jpg' : filename,
      ));
    }

    http.Response res;
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 45));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      return const PostResult(false, '发送超时，请稍后重试');
    } catch (e) {
      return PostResult(false, '发送失败：$e');
    }

    return parseJumpHtml(utf8.decode(res.bodyBytes));
  }

  /// 发串接口返回「跳转提示」HTML，没有结构化错误码，只能靠文案判断。
  ///
  /// 这段逻辑是「猜」，最容易随站点改文案而失效，所以对外开放以便单测。
  @visibleForTesting
  PostResult parseJumpHtml(String html) {
    final text = _stripHtml(html);

    for (final ok in const <String>['发串成功', '回复成功', '发送成功']) {
      if (text.contains(ok)) return PostResult(true, ok);
    }
    for (final bad in const <String>[
      '未应用饼干', '内容不能为空', '间隔', '过快', '禁止', '失败', '不存在',
    ]) {
      if (text.contains(bad)) {
        final i = text.indexOf(bad);
        final start = i - 30 < 0 ? 0 : i - 30;
        final end = i + 50 > text.length ? text.length : i + 50;
        return PostResult(false, text.substring(start, end).trim());
      }
    }
    return PostResult(
        false,
        text.isEmpty
            ? '未知返回'
            : text.substring(0, text.length > 100 ? 100 : text.length));
  }

  // ---------------- 搜索（网页表单） ----------------

  /// 搜索没有 JSON 接口：先取 `__hash__` 与 PHPSESSID，再 POST 网页表单，最后解析 HTML。
  Future<SearchResult> search(String keyword, {String? cookie}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return const SearchResult(<SearchHit>[], '请输入关键词');

    final client = http.Client();
    try {
      final indexUri = Uri.parse('$webBase/Forum/searchIndex.html');
      final idx = await client
          .get(indexUri, headers: _headers(cookie))
          .timeout(const Duration(seconds: 20));
      final indexHtml = utf8.decode(idx.bodyBytes);
      final token = RegExp(r'name="__hash__"[^>]*value="([^"]+)"')
              .firstMatch(indexHtml)
              ?.group(1) ??
          RegExp(r'value="([^"]+)"[^>]*name="__hash__"')
              .firstMatch(indexHtml)
              ?.group(1) ??
          '';

      final sess = _sessionCookie(idx.headers['set-cookie']);
      final cookieHeader = <String>[
        if (sess != null) sess,
        if (cookie != null && cookie.isNotEmpty) 'userhash=$cookie',
      ].join('; ');

      final res = await client.post(
        Uri.parse('$webBase/Forum/search.html'),
        headers: <String, String>{
          ..._headers(cookie),
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': indexUri.toString(),
          'Origin': webBase,
          if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
        },
        body: <String, String>{
          '__hash__': token,
          'q': kw,
          'keyword': kw,
        },
      ).timeout(const Duration(seconds: 30));

      return parseSearchHtml(utf8.decode(res.bodyBytes));
    } on TimeoutException {
      return const SearchResult(<SearchHit>[], '搜索超时');
    } catch (e) {
      return SearchResult(<SearchHit>[], '搜索失败：$e');
    } finally {
      client.close();
    }
  }

  static String? _sessionCookie(String? setCookie) {
    if (setCookie == null) return null;
    final m = RegExp(r'PHPSESSID=([^;,\s]+)').firstMatch(setCookie);
    return m == null ? null : 'PHPSESSID=${m.group(1)}';
  }

  @visibleForTesting
  SearchResult parseSearchHtml(String html) {
    final hits = <int, SearchHit>{};
    final re = RegExp(
      r'''<a[^>]+href=["']([^"']*?/t/(\d+))["'][^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final m in re.allMatches(html)) {
      final id = int.tryParse(m.group(2) ?? '');
      if (id == null) continue;
      final title = _stripHtml(m.group(3) ?? '');
      if (title.isEmpty || title.length > 100) continue;
      hits.putIfAbsent(id, () => SearchHit(id, title));
    }

    if (hits.isNotEmpty) {
      return SearchResult(hits.values.take(40).toList(), '');
    }

    final text = _stripHtml(html);
    String msg;
    if (text.contains('没有找到') || text.contains('无结果') || text.contains('没有相关')) {
      msg = '没有找到相关串';
    } else if (text.contains('请登录') || text.contains('必须登入')) {
      msg = '搜索需要登录：先导入饼干再试';
    } else if (text.contains('秒') && text.contains('再')) {
      msg = '搜索太频繁，稍后再试';
    } else {
      msg = '没有解析到结果（页面结构可能已变化）';
    }
    return SearchResult(const <SearchHit>[], msg);
  }

  static String _stripHtml(String html) {
    final text = html
        .replaceAll(
            RegExp(r'<(script|style)[^>]*>.*?</\1>',
                caseSensitive: false, multiLine: true, dotAll: true),
            ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String imageUrl(Post p, {bool thumb = true}) {
    if (!p.hasImage) return '';
    final kind = thumb ? 'thumb' : 'image';
    return '$cdnBase$kind/${p.img}${p.ext.isEmpty ? '.jpg' : p.ext}';
  }
}
