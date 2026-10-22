import 'package:flutter/widgets.dart';

/// 与 FlClash `lib/ui/fade_box.dart` 中的 `FadeScaleBox` 一致：
/// `AnimatedSwitcher` + 淡入淡出 + 从 0.4 放大，出用 `easeOutBack`、入用 `easeInBack`。
///
/// FlClash 的仪表盘「启动」按钮就是用这个包起来的——状态切换时旧按钮缩小淡出、
/// 新按钮放大淡入，锚点固定在右侧。本项目的「发串」按钮沿用同一套。
///
/// 来源：chen08209/FlClash（GPL-3.0）。本项目据此同样以 GPL-3.0 分发。
class FadeScaleBox extends StatelessWidget {
  const FadeScaleBox({super.key, required this.child, this.alignment});

  final Widget child;
  final AlignmentGeometry? alignment;

  static const Duration _duration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final realAlignment = alignment ?? Alignment.center;
    return AnimatedSwitcher(
      duration: _duration,
      switchOutCurve: Curves.easeOutBack,
      switchInCurve: Curves.easeInBack,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation.drive(Tween(begin: 0.4, end: 1.0)),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) => Align(
        alignment: realAlignment,
        child: Stack(
          alignment: realAlignment,
          children: <Widget>[
            ...previousChildren,
            // 原码用 Dart 3.8 的 `?currentChild`，这里写成显式判空
            if (currentChild != null) currentChild,
          ],
        ),
      ),
      child: child,
    );
  }
}
