import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 发串草稿。
///
/// 只有一个草稿槽：写一半退出、或者被系统杀掉，回来还能接着写。
/// 存在 SharedPreferences 里，不上传，也不参与接口缓存清理。
class DraftStore {
  DraftStore._();
  static final DraftStore instance = DraftStore._();

  static const String _key = 'compose_draft';

  SharedPreferences? _prefs;

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  Map<String, dynamic>? read() {
    final raw = _prefs?.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      return j is Map ? Map<String, dynamic>.from(j) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String title,
    required String content,
    required int fid,
  }) async {
    final p = _prefs;
    if (p == null) return;
    if (title.trim().isEmpty && content.trim().isEmpty) {
      await p.remove(_key);
      return;
    }
    await p.setString(
      _key,
      jsonEncode(<String, dynamic>{
        'title': title,
        'content': content,
        'fid': fid,
        'at': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> clear() async {
    await _prefs?.remove(_key);
  }
}
