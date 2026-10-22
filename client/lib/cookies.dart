import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// 一块饼干 = 一个可发帖身份。
class Biscuit {
  final String id;
  final String name;
  final String cookie;

  const Biscuit({required this.id, required this.name, required this.cookie});

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'id': id, 'name': name, 'cookie': cookie};

  factory Biscuit.fromJson(Map<String, dynamic> j) => Biscuit(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '饼干',
        cookie: j['cookie']?.toString() ?? '',
      );

  String get masked =>
      cookie.length <= 8 ? cookie : '${cookie.substring(0, 8)}…';
}

/// 饼干仓库。只存在本机 SharedPreferences，不上传任何服务器。
class CookieStore extends ChangeNotifier {
  CookieStore._();
  static final CookieStore instance = CookieStore._();

  final List<Biscuit> items = <Biscuit>[];
  String? activeId;
  final Map<String, bool> verified = <String, bool>{};

  SharedPreferences? _prefs;

  Biscuit? get active {
    for (final b in items) {
      if (b.id == activeId) return b;
    }
    return items.isEmpty ? null : items.first;
  }

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    items.clear();
    final raw = prefs.getString('biscuits');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final e in list) {
            if (e is Map) {
              items.add(Biscuit.fromJson(Map<String, dynamic>.from(e)));
            }
          }
        }
      } catch (_) {}
    }
    activeId = prefs.getString('biscuitActive');
    if (activeId == null && items.isNotEmpty) activeId = items.first.id;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs?.setString(
        'biscuits', jsonEncode(items.map((e) => e.toJson()).toList()));
    if (activeId != null) {
      await _prefs?.setString('biscuitActive', activeId!);
    } else {
      await _prefs?.remove('biscuitActive');
    }
  }

  /// 支持三种粘贴格式：JSON、`userhash=...`、裸串。
  static Biscuit? parse(String raw, String id) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    var cookie = '';
    var name = '';
    if (text.startsWith('{')) {
      try {
        final j = jsonDecode(text);
        if (j is Map) {
          cookie = (j['cookie'] ?? j['userhash'] ?? '').toString().trim();
          name = (j['name'] ?? '').toString().trim();
        }
      } catch (_) {
        return null;
      }
    } else if (text.toLowerCase().contains('userhash=')) {
      final m = RegExp(r'userhash=([^;]+)', caseSensitive: false).firstMatch(text);
      cookie = m?.group(1)?.trim() ?? '';
    } else {
      cookie = text;
    }
    if (cookie.length < 8) return null;
    return Biscuit(
      id: id,
      name: name.isEmpty ? '饼干 ${cookie.substring(0, 4)}' : name,
      cookie: cookie,
    );
  }

  Future<Biscuit> add(String raw, String id) async {
    final b = parse(raw, id);
    if (b == null) throw ApiException('没能识别这段饼干');
    items.add(b);
    activeId ??= b.id;
    await _persist();
    notifyListeners();
    return b;
  }

  Future<void> remove(String id) async {
    items.removeWhere((e) => e.id == id);
    verified.remove(id);
    if (activeId == id) activeId = items.isEmpty ? null : items.first.id;
    await _persist();
    notifyListeners();
  }

  Future<void> setActive(String id) async {
    activeId = id;
    await _persist();
    notifyListeners();
  }

  Future<CookieCheck> verify(String id) async {
    final b = items.firstWhere((e) => e.id == id);
    final r = await Api.instance.verifyCookie(b.cookie);
    verified[id] = r.ok;
    notifyListeners();
    return r;
  }
}
