import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 持久化 JSON 缓存。
///
/// 接口实测 1–8 秒，且响应头是 `no-store`，所以缓存必须自己做。
/// 这里用 SharedPreferences 存整段 JSON：实现简单、跨平台、无需额外插件；
/// 串内容较大时可能占用几 MB，属于可接受范围。
class CacheStore {
  CacheStore._();
  static final CacheStore instance = CacheStore._();

  static const String _prefix = 'cache:';
  SharedPreferences? _prefs;

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  /// 用 FNV-1a 把 path+cookie 压成短 key，避免把整条 URL 当键。
  static String keyOf(String path, String? cookie) {
    final raw = path + (cookie == null || cookie.isEmpty ? '' : '#${cookie.hashCode}');
    var h = 2166136261;
    for (final c in raw.codeUnits) {
      h = (h ^ c) * 16777619;
      h &= 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  Future<void> put(String key, dynamic data) async {
    final payload = jsonEncode(<String, dynamic>{
      't': DateTime.now().millisecondsSinceEpoch,
      'v': data,
    });
    await _prefs?.setString(_prefix + key, payload);
  }

  ({dynamic data, int ageMs})? _read(String key) {
    final raw = _prefs?.getString(_prefix + key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      return (
        data: m['v'],
        ageMs: DateTime.now().millisecondsSinceEpoch - (m['t'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  /// 命中且未过期才返回，否则 null。
  dynamic getFresh(String key, Duration ttl) {
    final e = _read(key);
    if (e == null || e.ageMs > ttl.inMilliseconds) return null;
    return e.data;
  }

  /// 不管过期与否都返回，用于网络失败时的兜底。
  ({dynamic data, int ageMs})? getStale(String key) => _read(key);

  int get count {
    final p = _prefs;
    if (p == null) return 0;
    return p.getKeys().where((k) => k.startsWith(_prefix)).length;
  }

  Future<void> clear() async {
    final p = _prefs;
    if (p == null) return;
    final keys = p.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await p.remove(k);
    }
  }
}
