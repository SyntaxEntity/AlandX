import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'cache.dart';
import 'cookies.dart';
import 'models.dart';

/// 全局状态：只保留跨页面共享的部分（主题、当前来源、时间线数据）。
/// 详情页有自己的局部状态，避免刷新列表时把详情也重建。
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  static const List<TimelineLine> lines = <TimelineLine>[
    TimelineLine(1, '综合线', ''),
    TimelineLine(2, '创作线', ''),
    TimelineLine(3, '非创作线', ''),
    TimelineLine(4, '亚文化线', ''),
    TimelineLine(5, '游戏线', ''),
    TimelineLine(6, '生活线', ''),
  ];

  final Api _api = Api.instance;

  Color seed = const Color(0xFF3D5BFE);
  String uuid = '';

  /// 底部/侧边导航的当前页，放在全局是为了让「版面 → 串列表」能自动切页。
  int tabIndex = 0;

  void setTab(int i) {
    if (tabIndex == i) return;
    tabIndex = i;
    notifyListeners();
  }

  Source source = const Source.timeline(1, '综合线');
  List<Post> threads = <Post>[];
  bool loading = false;
  String? error;
  int page = 1;
  bool hasMore = true;

  List<ForumCategory> categories = <ForumCategory>[];
  bool forumsLoading = false;

  /// 当前列表是否来自过期缓存（站点不可用时的兜底），供界面提示。
  bool fromCache = false;
  int cacheAgeMs = 0;

  int _seq = 0;
  SharedPreferences? _prefs;

  int get upstreamMs => _api.lastUpstreamMs;

  /// 当前生效的饼干；为空表示以匿名身份浏览。
  String? get cookie => CookieStore.instance.active?.cookie;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await CacheStore.instance.init(_prefs!);
    await CookieStore.instance.init(_prefs!);
    CookieStore.instance.addListener(_onCookieChanged);
    final savedSeed = _prefs!.getInt('seed');
    if (savedSeed != null) seed = Color(savedSeed);
    uuid = _prefs!.getString('uuid') ?? '';
    if (uuid.isEmpty) {
      uuid = _newUuid();
      await _prefs!.setString('uuid', uuid);
    }
    notifyListeners();
    await loadHome();
  }

  static String _newUuid() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// 切换/导入饼干后，受限版面应当立刻可用，所以清缓存并重拉。
  void _onCookieChanged() {
    _api.clearCache();
    loadHome(reset: true);
  }

  Future<void> setSeed(Color c) async {
    seed = c;
    notifyListeners();
    await _prefs?.setInt('seed', c.value);
  }

  void clearCache() {
    _api.clearCache();
    fromCache = false;
    cacheAgeMs = 0;
    notifyListeners();
  }

  Future<void> setSource(Source s) async {
    if (s.id == source.id && s.isForum == source.isForum) return;
    source = s;
    await loadHome(reset: true);
  }

  Future<void> loadHome({bool reset = false}) async {
    final int seq = ++_seq;
    if (reset) {
      page = 1;
      hasMore = true;
      threads = <Post>[];
    }
    loading = true;
    error = null;
    notifyListeners();

    try {
      final list =
          await _api.fetchList(source, page, cookie: cookie, force: reset);
      if (seq != _seq) return; // 已有更新的请求，丢弃这次结果
      threads = reset ? list : <Post>[...threads, ...list];
      hasMore = list.length >= 20;
      fromCache = _api.lastFromCache;
      cacheAgeMs = _api.lastCacheAgeMs;
      loading = false;
      notifyListeners();
    } on ApiException catch (e) {
      if (seq != _seq) return;
      // 刷新失败时保留旧数据，只提示；首次加载才清空
      error = e.message;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    page += 1;
    await loadHome();
  }

  Future<void> loadForums({bool force = false}) async {
    if (forumsLoading) return;
    if (categories.isNotEmpty && !force) return;
    forumsLoading = true;
    notifyListeners();
    try {
      categories = await _api.fetchForums(force: force);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      forumsLoading = false;
      notifyListeners();
    }
  }

  String forumName(int fid) {
    for (final c in categories) {
      for (final f in c.forums) {
        if (f.id == fid) return f.name;
      }
    }
    return '版面 $fid';
  }
}
