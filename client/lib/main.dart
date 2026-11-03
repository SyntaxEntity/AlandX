// X岛客户端 · 应用入口
// 注意：本仓库未包含平台目录，首次运行前执行 `flutter create --platforms=... .`
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state.dart';
import 'theme.dart';
import 'flclash/navigation_dock.dart';
import 'pages/compose_page.dart';
import 'pages/home_page.dart';
import 'pages/forums_page.dart';
import 'pages/feeds_page.dart';
import 'pages/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 边到边：状态栏与导航栏都透明，内容铺到系统栏下面（沉浸式）。
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const XdApp());
}

class XdApp extends StatefulWidget {
  const XdApp({super.key});

  @override
  State<XdApp> createState() => _XdAppState();
}

class _XdAppState extends State<XdApp> {
  final AppState state = AppState.instance;

  @override
  void initState() {
    super.initState();
    state.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        title: 'X岛',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(state.seed, Brightness.light),
        darkTheme: buildAppTheme(state.seed, Brightness.dark),
        themeMode: ThemeMode.system,
        // 主题切换必须即时生效。
        // MaterialApp 默认用 AnimatedTheme 做 200ms 插值，换成新种子色的那一帧
        // `Theme.of` 拿到的还是旧色；而页面大多只读全局 `palette`、不依赖 Theme.of，
        // 它们只会在「状态通知」那一帧重建一次，正好取到插值初值，于是永远停在旧配色。
        // 把时长压到 0，palette 和 Theme 在同一帧就都到终值。
        themeAnimationDuration: Duration.zero,
        // MaterialApp.builder 在主题解析之后、子树构建之前执行，
        // 正好用来把当前 ColorScheme 同步进全局色板，明暗切换时它会自动重跑。
        builder: (context, child) {
          final scheme = Theme.of(context).colorScheme;
          palette = AppPalette.of(scheme);
          // 状态栏/导航栏透明 + 图标亮度跟随明暗，才是真正的沉浸式。
          final dark = scheme.brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
              statusBarBrightness: dark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int get index => AppState.instance.tabIndex;

  /// 页面随底栏位置横向移动。
  late final PageController _pc =
      PageController(initialPage: AppState.instance.tabIndex);

  /// 已经同步到 PageView 的分栏。tabIndex 可能被别的页面直接改
  /// （版面页点板块就是先 setSource 再 setTab(0)），底栏高亮会跟着变，
  /// 但 PageView 不会自己动，所以这里统一兜住。
  int _syncedTab = AppState.instance.tabIndex;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_syncPageToTab);
  }

  void _syncPageToTab() {
    final tab = AppState.instance.tabIndex;
    if (tab == _syncedTab || !_pc.hasClients) return;
    _syncedTab = tab;
    final current = _pc.page?.round();
    if (current == tab) return;
    _pc.animateToPage(
      tab,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 页面实例不能长期复用同一个 const 对象。
  ///
  /// `updateChild` 判断到新旧 widget 是**同一个实例**时会直接跳过整棵子树，
  /// 于是主题种子色换了、全局 palette 也刷新了，页面却一次都不重建，
  /// 表现就是「点了主题没反应」。这里按种子色缓存一份新实例：
  /// 只有种子变了才换，别的状态通知不去打扰页面。
  Color _pageSeed = AppState.instance.seed;
  late List<Widget> _pages = _buildPages();

  List<Widget> _buildPages() {
    // ignore: prefer_const_constructors, prefer_const_literals_to_create_immutables
    return <Widget>[HomePage(), ForumsPage(), FeedsPage(), SettingsPage()];
  }

  List<Widget> get pages {
    final seed = AppState.instance.seed;
    if (seed != _pageSeed) {
      _pageSeed = seed;
      _pages = _buildPages();
    }
    return _pages;
  }

  static const List<NavigationDockDestination> _destinations =
      <NavigationDockDestination>[
    NavigationDockDestination(glyph: Glyph(Icons.dynamic_feed_rounded), label: '时间线'),
    NavigationDockDestination(glyph: Glyph(Icons.grid_view_rounded), label: '版面'),
    NavigationDockDestination(glyph: Glyph(Icons.bookmark_rounded), label: '订阅'),
    NavigationDockDestination(glyph: Glyph(Icons.tune_rounded), label: '设置'),
  ];

  Future<void> _compose() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ComposePage()),
    );
    if (ok == true) AppState.instance.loadHome(reset: true);
  }

  /// 右下角「发串」圆形按钮，尺寸与底栏高度一致，和 Deck 并排。
  Widget _composeButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = NavigationDock.heightOf(context);
    return Material(
      key: const ValueKey('compose_btn'),
      color: scheme.primary,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _compose,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.edit_outlined, size: 24, color: scheme.onPrimary),
        ),
      ),
    );
  }

  /// 切栏：只改状态，真正推 PageView 的动作交给 [_syncPageToTab]。
  /// 这样无论入口是底栏还是别的页面，都只有一条同步路径。
  void _goTo(int i) => AppState.instance.setTab(i);

  @override
  void dispose() {
    AppState.instance.removeListener(_syncPageToTab);
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final state = AppState.instance;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        if (wide) return _buildWide(context);

        final showCompose = index == 0;

        return Scaffold(
          backgroundColor: kCanvas,
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  // 不给整页加底部内边距：内容滚到 Deck 下方才是「悬浮」，
                  // 末端留白交给各页面自己的 NavigationDock.insetOf。
                  child: PageView.builder(
                    controller: _pc,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pages.length,
                    itemBuilder: (_, i) => _KeepAlivePage(child: pages[i]),
                  ),
                ),
              ),

              // 底栏 + 右下角圆形按钮，对应 FlClash 仪表盘的「启动」按钮：
              // 两者并排在同一水平线；按钮在时底栏缩短让位，按钮消失后底栏恢复全长。
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Stack(
                  children: <Widget>[
                    // 底栏宽度必须渐变：NavigationDock 内部用 context.size 算 pitch/lens，
                    // 宽度一变就立刻按新宽度重排，所以让位空间本身要做补间，
                    // 否则切换分栏时底栏会「啪」地变宽/变窄。
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: showCompose ? 86 : 0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      builder: (context, space, _) => NavigationDock(
                        destinations: _destinations,
                        selectedIndex: index,
                        trailingSpace: space,
                        onSelected: (i) {
                          if (i != index) _goTo(i);
                        },
                      ),
                    ),
                    Positioned(
                      right: 21,
                      bottom: NavigationDock.bottomMarginOf(context),
                      // 与底栏补间同一时长/曲线，两边同步收放，才不会一边先跳。
                      child: AnimatedOpacity(
                        opacity: showCompose ? 1 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: AnimatedScale(
                          scale: showCompose ? 1 : 0.4,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: IgnorePointer(
                            ignoring: !showCompose,
                            child: _composeButton(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 宽屏保留侧栏：桌面端横向空间足够，悬浮底栏反而浪费高度。
  Widget _buildWide(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      backgroundColor: kCanvas,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Row(
              children: <Widget>[
                _Rail(index: index, onTap: (i) => state.setTab(i)),
                Expanded(child: IndexedStack(index: index, children: pages)),
              ],
            ),
            Positioned(
              right: 28,
              bottom: 28,
              child: FloatingActionButton.extended(
                heroTag: 'compose_wide',
                onPressed: _compose,
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('发串'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PageView 会销毁远离视口的页面，切回来时列表回到顶部、图片重新解码。
/// 这里保活，行为和原来的 IndexedStack 一致。
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = AppState.instance;
    final ok = state.error == null && state.threads.isNotEmpty;

    return Container(
      width: 78,
      margin: const EdgeInsets.fromLTRB(18, 20, 0, 20),
      decoration: BoxDecoration(
        color: kCard.withOpacity(0.86),
        borderRadius: BorderRadius.circular(39),
        border: Border.all(color: kOutline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14202B45),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 12),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[scheme.primary, scheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: scheme.primary.withOpacity(0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.explore_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 10),
          _railBtn(context, 0, Icons.dynamic_feed_rounded, '时间线'),
          _railBtn(context, 1, Icons.grid_view_rounded, '版面'),
          _railBtn(context, 2, Icons.bookmark_rounded, '订阅'),
          _railBtn(context, 3, Icons.tune_rounded, '设置'),
          const Spacer(),
          Tooltip(
            message: ok ? '接口正常' : '接口异常',
            child: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: ok ? const Color(0xFF1F9D6B) : const Color(0xFFD84C4C),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (ok
                            ? const Color(0xFF1F9D6B)
                            : const Color(0xFFD84C4C))
                        .withOpacity(0.24),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _railBtn(BuildContext context, int i, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final active = index == i;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => onTap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 58,
          height: 56,
          decoration: BoxDecoration(
            color: active ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon,
                  size: 21,
                  color: active ? scheme.onPrimary : kInk3),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  color: active ? scheme.onPrimary : kInk3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
