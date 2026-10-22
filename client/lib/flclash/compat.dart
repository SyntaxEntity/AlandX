// 移植自 FlClash（https://github.com/chen08209/FlClash）
// Copyright (C) FlClash contributors
// 原项目以 GNU General Public License v3.0 分发；本项目据此同样以 GPL-3.0 分发。
// 本文件保留原实现，仅替换图标类型与 Liquid Glass 依赖，差异集中在 compat.dart。
import 'package:flutter/material.dart';

/// FlClash 的 `NavigationDock` 移植时需要的兼容层。
///
/// 原实现依赖 `material_ui`（FlClash 自己 fork 的 Flutter material）与一个
/// 自定义图标字体。为了让那份 2000 行的交互代码原样跑起来，这里补齐它用到的
/// 少量符号，把差异收敛在这一个文件里：
///
/// * `Glyph` / `GlyphIcon`  → 用 Material Icons 代替自定义字形；
/// * `AppShape.full`        → 原实现是超椭圆 `RoundedSuperellipseBorder`，
///                            Material 没有，用 `StadiumBorder` 代替（胶囊段曲线
///                            肉眼几乎无差）；
/// * `SurfaceLevel`         → 直接照抄，只依赖官方 ColorScheme；
/// * `LiquidGlass*`         → iOS 26 液态玻璃。非 iOS 平台本来就不启用，
///                            这里全部退化成「无玻璃」，保留同名 API 不报错。
///
/// 来源：chen08209/FlClash（GPL-3.0）。本项目据此同样以 GPL-3.0 分发。

// ---------------------------------------------------------------------------
// 图标
// ---------------------------------------------------------------------------

/// 图标字形的轻量包装，对应 FlClash 的 `Glyph`。
class Glyph {
  const Glyph(this.icon);

  final IconData icon;
}

/// 对应 FlClash 的 `GlyphIcon(glyph, size:, color:, fill:)`。
class GlyphIcon extends StatelessWidget {
  const GlyphIcon(
    this.glyph, {
    super.key,
    this.size,
    this.color,
    this.fill = 0,
  });

  final Glyph glyph;
  final double? size;
  final Color? color;

  /// 原实现是可变字体的填充轴（0–1）。Material Icons 不是可变字体，
  /// 这里只在 1 时保留参数语义，不影响布局。
  final double fill;

  @override
  Widget build(BuildContext context) {
    return Icon(glyph.icon, size: size, color: color);
  }
}

// ---------------------------------------------------------------------------
// 形状
// ---------------------------------------------------------------------------

abstract final class AppShape {
  static const ShapeBorder none = StadiumBorder();
  static const ShapeBorder full = StadiumBorder();
}

// ---------------------------------------------------------------------------
// 表面层级
// ---------------------------------------------------------------------------

/// 与 FlClash `lib/ui/surface.dart` 同名同义：四级表面，深色不往回降级。
enum SurfaceLevel {
  page,
  card,
  block,
  inset;

  static SurfaceLevel floatingOf(ColorScheme colorScheme) =>
      colorScheme.brightness == Brightness.dark ? block : card;

  SurfaceLevel get next => switch (this) {
        page => card,
        card => block,
        block || inset => inset,
      };

  Color colorOf(ColorScheme colorScheme) {
    final dark = colorScheme.brightness == Brightness.dark;
    return switch (this) {
      page => dark ? colorScheme.surface : colorScheme.surfaceContainer,
      card => dark ? colorScheme.surfaceContainer : colorScheme.surfaceBright,
      block =>
        dark ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainer,
      inset => colorScheme.surfaceContainerHighest,
    };
  }
}

extension BuildContextExt on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}

// ---------------------------------------------------------------------------
// 字体
// ---------------------------------------------------------------------------

/// 只保留 dock 用到的 `AppTextStyle.custom`。
abstract final class AppTextStyle {
  static TextStyle custom(
    BuildContext context, {
    required double size,
    required double leading,
    FontWeight weight = FontWeight.w400,
  }) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return base.copyWith(
      fontSize: size,
      height: leading / size,
      fontWeight: weight,
      letterSpacing: 0,
    );
  }
}

// ---------------------------------------------------------------------------
// 液态玻璃（降级）
// ---------------------------------------------------------------------------

enum LiquidGlassQuality { standard, high, ultra }

/// 原实现用它描述「手指按下去时照亮底栏」的位置与强度。
class LiquidGlassGlow {
  const LiquidGlassGlow({
    required this.center,
    required this.reach,
    required this.strength,
    required this.wash,
  });

  static const LiquidGlassGlow none = LiquidGlassGlow(
    center: null,
    reach: 0,
    strength: 0,
    wash: 0,
  );

  final Offset? center;
  final double reach;
  final double strength;
  final double wash;
}

class LiquidGlassStyle {
  const LiquidGlassStyle({required this.brightness});

  final Brightness brightness;

  factory LiquidGlassStyle.pill(ColorScheme scheme) =>
      LiquidGlassStyle(brightness: scheme.brightness);

  factory LiquidGlassStyle.lens(ColorScheme scheme) =>
      LiquidGlassStyle(brightness: scheme.brightness);

  factory LiquidGlassStyle.lensContent(ColorScheme scheme) =>
      LiquidGlassStyle(brightness: scheme.brightness);

  LiquidGlassStyle scale(double factor) => this;
}

/// 非 iOS 平台恒为 false，dock 会走普通 surface 分支。
class LiquidGlassScope {
  const LiquidGlassScope._();

  static bool of(BuildContext context) => false;

  static LiquidGlassQuality qualityOf(BuildContext context) =>
      LiquidGlassQuality.standard;
}

/// 空实现：直接透传 child（可能为 null）。
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    this.style,
    this.shadows = const <BoxShadow>[],
    this.glow,
    this.child,
  });

  final LiquidGlassStyle? style;
  final List<BoxShadow> shadows;
  final LiquidGlassGlow? glow;
  final Widget? child;

  @override
  Widget build(BuildContext context) => child ?? const SizedBox.shrink();
}
