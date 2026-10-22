// X岛客户端 · 应用入口
// 注意：本仓库未包含平台目录，首次运行前执行 `flutter create --platforms=... .`
import 'package:flutter/material.dart';

import 'state.dart';
import 'pages/compose_page.dart';
import 'pages/home_page.dart';
import 'pages/forums_page.dart';
import 'pages/feeds_page.dart';
import 'pages/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const XdApp());
}

ThemeData buildTheme(Color seed) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  ).copyWith(surface: Colors.white);

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF3F5FB),
    visualDensity: VisualDensity.standard,
    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF181C28),
      contentTextStyle: const TextStyle(fontSize: 13, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
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
        theme: buildTheme(state.seed),
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

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    ForumsPage(),
    FeedsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final state = AppState.instance;

    final body = Row(
      children: <Widget>[
        if (wide)
          _Rail(
            index: index,
            onTap: (i) => AppState.instance.setTab(i),
          ),
        Expanded(
          child: IndexedStack(index: index, children: _pages),
        ),
      ],
    );

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Scaffold(
        body: SafeArea(child: body),
        floatingActionButton: index == 0
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final ok = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                        builder: (_) => const ComposePage()),
                  );
                  if (ok == true) AppState.instance.loadHome(reset: true);
                },
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('发串'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              )
            : null,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => AppState.instance.setTab(i),
                height: 72,
                backgroundColor: Colors.white,
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: <Widget>[
                  _dest(Icons.dynamic_feed_rounded, '时间线'),
                  _dest(Icons.grid_view_rounded, '版面'),
                  _dest(Icons.bookmark_rounded, '订阅'),
                  _dest(Icons.tune_rounded, '设置'),
                ],
              ),
      ),
    );
  }

  NavigationDestination _dest(IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationDestination(
      icon: Icon(icon, color: scheme.onSurfaceVariant),
      selectedIcon: Icon(icon, color: scheme.onPrimary),
      label: label,
    );
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
        color: Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(39),
        border: Border.all(color: const Color(0xFFE9ECF4)),
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
                  color: active ? Colors.white : const Color(0xFF8B93A7)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  color: active ? Colors.white : const Color(0xFF8B93A7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
