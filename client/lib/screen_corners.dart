import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 设备屏幕圆角半径（dp）。
///
/// Flutter 没有公开这个值，Android 12+ 得走原生
/// `WindowInsets.getRoundedCorner()`。CI 里会往生成出来的 MainActivity 注入一段
/// Kotlin（见 `scripts/android_screen_corner.py`），通过 `xd/screen` 通道回传。
///
/// 取不到（桌面端、旧系统、注入失败）就用 [fallback]，界面不会因此坏掉。
class ScreenCorners {
  ScreenCorners._();

  static const MethodChannel _channel = MethodChannel('xd/screen');

  /// 从设备读到的原始值；0 表示没读到。
  static double deviceRadius = 0;

  /// 实际用于绘制的半径。
  ///
  /// 原生取不到时不能死守一个常数——不同机型屏幕圆角差得远，
  /// 按短边比例估算比写死 28 更接近真机（大屏手机 R 角明显更大）。
  static double resolve(BuildContext context) {
    if (deviceRadius > 0) return deviceRadius;
    final side = MediaQuery.sizeOf(context).shortestSide;
    return (side * 0.09).clamp(26.0, 42.0);
  }

  static bool _loaded = false;

  static Future<void> ensure() async {
    if (_loaded) return;
    _loaded = true;
    try {
      // 必须等第一帧画完再去问：Activity 还没布局时 rootWindowInsets 是 null，
      // 拿到的永远是 0，之前就是这样一直回退成默认值的。
      await WidgetsBinding.instance.endOfFrame;
      for (var attempt = 0; attempt < 3; attempt++) {
        final v = await _channel
            .invokeMethod<double>('cornerRadius')
            .timeout(const Duration(milliseconds: 800));
        if (v != null && v > 0) {
          deviceRadius = v;
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    } catch (_) {
      // 桌面端没有这个通道，旧系统也没有圆角信息，保持估算值即可。
    }
  }
}

/// 上下边圆角半径不同、且底部用**超椭圆**（squircle）收边的矩形。
///
/// 手机屏幕的四角不是圆弧而是「连续圆角」，用 `BorderRadius` 画出来半径一大会
/// 显得发尖。这里底部按 |x|^n + |y|^n = 1（n = 4）采样，形状和屏幕 R 角更接近；
/// 顶部保持直角，因为它贴着屏幕顶端，圆角会被裁掉。
class SquircleBottomBorder extends ShapeBorder {
  const SquircleBottomBorder({
    required this.topRadius,
    required this.bottomRadius,
    this.exponent = 4,
  });

  final double topRadius;
  final double bottomRadius;

  /// 底角「方」的程度：2 = 正圆弧（纯圆角），4 左右接近手机屏的连续圆角。
  /// 展开态用 2、收成顶栏时插值到 4，这样卡片阶段它就是普通圆角。
  final double exponent;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(math.min(topRadius, bottomRadius) / 2),
          textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final limit = math.min(rect.width, rect.height) / 2;
    final rt = topRadius.clamp(0.0, limit);
    final rb = bottomRadius.clamp(0.0, limit);
    final path = Path();

    // 顶边 + 两个上圆角（普通圆弧：上面贴着屏幕边缘，做成方角更利落）
    path.moveTo(rect.left + rt, rect.top);
    path.lineTo(rect.right - rt, rect.top);
    if (rt > 0) {
      path.arcToPoint(Offset(rect.right, rect.top + rt),
          radius: Radius.circular(rt));
    }
    path.lineTo(rect.right, rect.bottom - rb);

    // 右下 + 左下：超椭圆
    if (rb > 0) {
      // 右下：从 (right, bottom-rb) 扫到 (right-rb, bottom)
      _squircle(path, Offset(rect.right - rb, rect.bottom - rb), rb, 0, 90,
          exponent);
      path.lineTo(rect.left + rb, rect.bottom);
      // 左下：从 (left+rb, bottom) 扫到 (left, bottom-rb)，方向必须顺着路径走
      _squircle(path, Offset(rect.left + rb, rect.bottom - rb), rb, 90, 180,
          exponent);
    } else {
      path.lineTo(rect.right, rect.bottom);
      path.lineTo(rect.left, rect.bottom);
    }

    path.lineTo(rect.left, rect.top + rt);
    if (rt > 0) {
      path.arcToPoint(Offset(rect.left + rt, rect.top),
          radius: Radius.circular(rt));
    }
    path.close();
    return path;
  }

  /// 沿 |cos|^(2/n)、|sin|^(2/n) 采样，[fromDeg] → [toDeg] 画到 path 上。
  /// n = 2 时就是正圆弧，n 越大越接近方形。
  static void _squircle(Path path, Offset center, double r, double fromDeg,
      double toDeg, double n) {
    const steps = 14;
    final p = 2 / n;
    for (var i = 1; i <= steps; i++) {
      final deg = fromDeg + (toDeg - fromDeg) * i / steps;
      final a = deg * math.pi / 180;
      final c = math.cos(a);
      final s = math.sin(a);
      final x = center.dx + r * c.sign * math.pow(c.abs(), p);
      final y = center.dy + r * s.sign * math.pow(s.abs(), p);
      path.lineTo(x, y);
    }
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => SquircleBottomBorder(
        topRadius: topRadius * t,
        bottomRadius: bottomRadius * t,
        exponent: exponent,
      );

  @override
  bool operator ==(Object other) =>
      other is SquircleBottomBorder &&
      other.topRadius == topRadius &&
      other.bottomRadius == bottomRadius &&
      other.exponent == exponent;

  @override
  int get hashCode => Object.hash(topRadius, bottomRadius, exponent);
}
