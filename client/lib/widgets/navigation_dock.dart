import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 悬浮底栏（Deck）。
///
/// 交互契约参考 FlClash 的 NavigationDock：
///   · 胶囊悬浮在内容之上，不占布局高度；
///   · 选中项横向展开、露出文字标签，其余项只留图标；
///   · 可以直接在底栏上左右滑动切换分栏，松手吸附到最近的一项。
///
/// FlClash 以 GPL-3.0 分发，直接复制其源码会让本项目也被传染成 GPL-3.0，
/// 所以这里没有抄代码，而是按同样的交互重新实现。做法差异见
/// `docs/功能清单与开发计划.md` 的「与 FlClash 的对应关系」一节。
class NavigationDock extends StatefulWidget {
  const NavigationDock({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.onProgress,
    this.accent,
  });

  final List<NavigationDockDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 位置变化回调，单位是「第几项」，1.4 表示在一二项之间。
  ///
  /// 拖动、点击、吸附全过程都会回调，用来驱动外层 `PageView` 同步横向位移，
  /// 这样手指在底栏上滑动时页面是跟着走的，而不是松手后才跳过去。
  final ValueChanged<double>? onProgress;

  /// 选中态配色，缺省跟随主题 primary。
  final Color? accent;

  /// 胶囊本体高度（不含外边距）。
  static const double height = 64;

  /// 胶囊到屏幕左右边缘的留白。
  static const double margin = 16;

  /// 内容区需要预留的底部高度，避免最后一条被 Deck 盖住。
  static double insetOf(BuildContext context) =>
      height + margin * 2 + MediaQuery.viewPaddingOf(context).bottom;

  @override
  State<NavigationDock> createState() => _NavigationDockState();
}

class NavigationDockDestination {
  const NavigationDockDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _NavigationDockState extends State<NavigationDock>
    with SingleTickerProviderStateMixin {
  /// 当前位置，单位是「第几项」，允许 1.4 这种中间值。
  double _pos = 0;
  double _animFrom = 0;
  double _animTo = 0;

  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  int get _count => widget.destinations.length;

  @override
  void initState() {
    super.initState();
    _pos = widget.selectedIndex.toDouble();
    _snap.addListener(_onTick);
  }

  void _onTick() {
    // FlClash 切栏用 300ms + easeOut 系曲线，这里对齐，避免「弹一下」的廉价感。
    final t = Curves.easeOutCubic.transform(_snap.value);
    setState(() => _pos = _animFrom + (_animTo - _animFrom) * t);
    widget.onProgress?.call(_pos);
  }

  @override
  void didUpdateWidget(covariant NavigationDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _snapTo(widget.selectedIndex.toDouble(), notify: false);
    }
  }

  @override
  void dispose() {
    _snap.removeListener(_onTick);
    _snap.dispose();
    super.dispose();
  }

  void _snapTo(double target, {bool notify = true}) {
    final clamped = target.clamp(0.0, (_count - 1).toDouble()).toDouble();
    if ((clamped - _pos).abs() < 0.01) {
      if (notify && clamped.round() != widget.selectedIndex) {
        widget.onSelected(clamped.round());
      }
      return;
    }
    _animFrom = _pos;
    _animTo = clamped;
    _snap.forward(from: 0);
    if (notify) {
      final idx = clamped.round();
      if (idx != widget.selectedIndex) widget.onSelected(idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.accent ?? scheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Container(
        height: NavigationDock.height,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(NavigationDock.height / 2),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.7)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.shadow.withOpacity(0.10),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: scheme.shadow.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        // LayoutBuilder 放在 Container 内部，拿到的才是「扣掉内边距之后」的宽度，
        // 否则每一项的宽加起来会超出容器导致溢出。
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final n = _count;
            final slot = width / n;
            final labelWidth = math.min(slot * 0.8, 62.0);
            final base = (width - labelWidth) / n;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < n; i++)
                  SizedBox(
                    width: base + labelWidth * _influence(i),
                    child: _DockItem(
                      destination: widget.destinations[i],
                      influence: _influence(i),
                      accent: accent,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _snapTo(i.toDouble());
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final box = context.size;
    if (box == null) return;
    final slot = (box.width - 12) / _count;
    if (slot <= 0) return;
    final before = _pos;
    setState(() {
      _pos = (_pos + d.delta.dx / slot)
          .clamp(0.0, (_count - 1).toDouble())
          .toDouble();
    });
    widget.onProgress?.call(_pos);
    // 跨过一整格给一次轻震动，跟系统 tab 切换手感一致。
    if (before.floor() != _pos.floor() || before.ceil() != _pos.ceil()) {
      HapticFeedback.selectionClick();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx;
    final double target;
    if (v.abs() > 320) {
      // 甩动：按速度方向再送一格
      target = v > 0 ? _pos.ceilToDouble() : _pos.floorToDouble();
    } else {
      target = _pos.roundToDouble();
    }
    _snapTo(target);
  }

  /// 第 i 项被「选中」的程度：0 = 完全收起，1 = 完全展开。
  /// 相邻两项的权重之和恒为 1，所以整条底栏总宽不变。
  double _influence(int i) =>
      (1 - (_pos - i).abs()).clamp(0.0, 1.0).toDouble();
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.destination,
    required this.influence,
    required this.accent,
    required this.onTap,
  });

  final NavigationDockDestination destination;
  final double influence;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = influence > 0.5;
    // 选中态底色是 accent 的浅色蒙版，文字必须往 accent 靠；用 onPrimary（白）会看不见。
    final fg = Color.lerp(scheme.onSurfaceVariant, accent, influence)!;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          // 不能用 AnimatedContainer：拖动要跟手，任何隐式动画都会让指示器慢半拍。
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.13 * influence),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Transform.scale(
                  scale: 1 + 0.05 * influence,
                  child: Icon(destination.icon, size: 21, color: fg),
                ),
                // 文字用 ClipRect + Align 横向「拉」出来，不引起布局跳变；
                // 同时叠一层透明度，避免展开瞬间像被刀切出来。
                ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: influence,
                    child: Opacity(
                      opacity: influence,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
