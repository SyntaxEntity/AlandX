import 'package:flutter/material.dart';

/// 语义色板。
///
/// 页面里原本散落着 `kInk` / `kInk2` / `kOutline` 这些硬编码颜色，
/// 它们绕过了 ColorScheme，导致换主题只生效一半、也没法做深色模式。
/// 这里把它们改成「从当前 ColorScheme 派生」的 getter，调用点不用动，
/// 但颜色会跟着明暗模式走。
class AppPalette {
  const AppPalette({
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.outline,
    required this.card,
    required this.canvas,
    required this.chip,
    required this.isDark,
  });

  /// 主文字
  final Color ink;

  /// 次级文字
  final Color ink2;

  /// 辅助/占位文字
  final Color ink3;

  /// 分隔线、描边
  final Color outline;

  /// 卡片底色
  final Color card;

  /// 页面底色
  final Color canvas;

  /// 弱强调块（标签、代码块）
  final Color chip;

  final bool isDark;

  factory AppPalette.of(ColorScheme s) {
    return AppPalette(
      ink: s.onSurface,
      ink2: s.onSurfaceVariant,
      ink3: s.onSurfaceVariant.withOpacity(0.62),
      outline: s.outlineVariant,
      card: s.surfaceContainerLow,
      canvas: s.surface,
      chip: s.surfaceContainerHighest,
      isDark: s.brightness == Brightness.dark,
    );
  }
}

/// 当前生效的色板。
///
/// 用全局变量而不是 InheritedWidget，是为了让 127 个调用点从
/// `kInk`（常量）平滑换成 `kInk`（getter）时不必每处都写 `context.`。
/// 它由 [XdApp] 在每次 build 时刷新，早于任何子组件构建。
AppPalette palette = AppPalette.of(
  ColorScheme.fromSeed(seedColor: const Color(0xFF3D5BFE)),
);

Color get kInk => palette.ink;
Color get kInk2 => palette.ink2;
Color get kInk3 => palette.ink3;
Color get kOutline => palette.outline;

/// 页面底色。
Color get kCanvas => palette.canvas;

/// 卡片/浮层底色。
Color get kCard => palette.card;

/// 弱强调块（标签、代码块、分段控件底座）。
Color get kChip => palette.chip;

/// Material 3 的组件主题。明暗两套只有 ColorScheme 不同，其余共用。
ThemeData buildAppTheme(Color seed, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,

    // 卡片：MD3 的层级靠色阶和高度表达，不用 1px 描边。
    cardTheme: CardTheme(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.5,
      space: 0.5,
    ),

    textTheme: base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.55),
      bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.5),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.6),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(fontSize: 13, color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: scheme.surfaceTint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),

    dialogTheme: DialogTheme(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: scheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),

    // 各平台走各自的系统转场，避免「一眼像网页」。
    pageTransitionsTheme: const PageTransitionsTheme(
      // 只保留 Android / 桌面：本项目不适配 iOS，不再挂 Cupertino 转场。
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}
