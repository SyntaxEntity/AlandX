// X岛客户端 · 应用入口
// 注意：本仓库未包含平台目录，首次运行前执行 `flutter create --platforms=... .`
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state.dart';
import 'theme.dart';
import 'flclash/fade_box.dart';
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

  /// 页面随底栏位置横向移动。用 `jumpTo` 而不是 `animateToPage`：
  /// 位置由 Deck 的 `_pos` 唯一驱动，拖动时跟手、吸附时一起滑，不会出现两套动画打架。
  late final PageController _pc =
      PageController(initialPage: AppState.instance.tabIndex);

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    ForumsPage(),
    FeedsPage(),
    SettingsPage(),
  ];

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

  /// 切栏：先更新选中态，再让页面横向滑过去。
  /// FlClash 就是这么分工的——deck 只管自己的弹性，页面切换走 `animateToPage`。
  void _goTo(int i) {
    AppState.instance.setTab(i);
    if (!_pc.hasClients) return;
    _pc.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
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
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _KeepAlivePage(child: _pages[i]),
                  ),
                ),
              ),

              // 发串按钮：位置与 FlClash 的「启动」按钮一致——挂在顶部栏右侧，
              // 和 Deck 分处屏幕两端，不贴合、不遮让、不联动位移。
              // 显隐走 FadeScaleBox（缩放 0.4↔1 + 淡入淡出，锚点 centerRight）。
              Positioned(
                right: 16,
                top: MediaQuery.paddingOf(context).top + 20,
                child: FadeScaleBox(
                  alignment: Alignment.centerRight,
                  child: index == 0
                      ? FilledButton.icon(
                          key: const ValueKey('compose_btn'),
                          onPressed: _compose,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('发串'),
                        )
                      : const SizedBox.shrink(key: ValueKey('compose_gone')),
                ),
              ),

              // Deck 自带左右与底部留白，这里贴边放即可。
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NavigationDock(
                  destinations: _destinations,
                  selectedIndex: index,
                  onSelected: (i) {
                    if (i != index) _goTo(i);
                  },
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
                Expanded(child: IndexedStack(index: index, children: _pages)),
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
