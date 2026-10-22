// X岛客户端 · 应用入口
// 注意：本仓库未包含平台目录，首次运行前执行 `flutter create --platforms=... .`
import 'package:flutter/material.dart';

import 'state.dart';
import 'theme.dart';
import 'widgets/navigation_dock.dart';
import 'pages/compose_page.dart';
import 'pages/home_page.dart';
import 'pages/forums_page.dart';
import 'pages/feeds_page.dart';
import 'pages/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
          palette = AppPalette.of(Theme.of(context).colorScheme);
          return child ?? const SizedBox.shrink();
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
    NavigationDockDestination(icon: Icons.dynamic_feed_rounded, label: '时间线'),
    NavigationDockDestination(icon: Icons.grid_view_rounded, label: '版面'),
    NavigationDockDestination(icon: Icons.bookmark_rounded, label: '订阅'),
    NavigationDockDestination(icon: Icons.tune_rounded, label: '设置'),
  ];

  Future<void> _compose() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ComposePage()),
    );
    if (ok == true) AppState.instance.loadHome(reset: true);
  }

  /// Deck 的位置变化 → 页面同步位移。
  void _syncPageTo(double pos) {
    if (!_pc.hasClients) return;
    final width = _pc.position.viewportDimension;
    if (width <= 0) return;
    final target = pos * width;
    if ((_pc.offset - target).abs() < 0.5) return;
    _pc.jumpTo(target);
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

        final scheme = Theme.of(context).colorScheme;
        final vp = MediaQuery.viewPaddingOf(context).bottom;
        final showFab = index == 0;
        final dockBottom = NavigationDock.margin + vp;

        return Scaffold(
          backgroundColor: kCanvas,
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  // 关键：不给整页加底部内边距。
                  // 内容可以一直滚到 Deck 下方（这才是「悬浮」），
                  // 末端留白交给各页面自己的 NavigationDock.insetOf。
                  child: PageView.builder(
                    controller: _pc,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _KeepAlivePage(child: _pages[i]),
                  ),
                ),
              ),

              // 发串按钮：在第 0 栏浮在 Deck 之上；切到别的栏时下沉、缩小并淡出，
              // 视觉上是「收进 Deck 里」，因为 Deck 在 Stack 中排在它后面，会盖住它。
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                right: showFab ? 20 : 40,
                bottom: showFab ? dockBottom + NavigationDock.height + 14 : dockBottom + 12,
                child: IgnorePointer(
                  ignoring: !showFab,
                  child: AnimatedOpacity(
                    opacity: showFab ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: AnimatedScale(
                      scale: showFab ? 1 : 0.32,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: FloatingActionButton.extended(
                        heroTag: 'compose',
                        onPressed: _compose,
                        elevation: 2,
                        highlightElevation: 6,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: const Text('发串'),
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: NavigationDock.margin,
                right: NavigationDock.margin,
                bottom: dockBottom,
                child: NavigationDock(
                  destinations: _destinations,
                  selectedIndex: index,
                  onProgress: _syncPageTo,
                  onSelected: (i) {
                    if (i != index) AppState.instance.setTab(i);
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
