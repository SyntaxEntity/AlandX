import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../state.dart';
import '../widgets.dart';
import 'cookie_claim.dart';
import 'search_page.dart';
import 'thread_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppState state = AppState.instance;

  Future<void> _refresh() => state.loadHome(reset: true);

  void _openThread(Post p) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadPage(threadId: p.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 980;
        // 首页没套顶部 SafeArea（banner 要铺到状态栏下面），所以自己把状态栏高度补回来。
        final topInset = MediaQuery.paddingOf(context).top;
        return RefreshIndicator(
          onRefresh: _refresh,
          color: Theme.of(context).colorScheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          wide ? 32 : 16, 26 + topInset, wide ? 32 : 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _header(context),
                          if (state.cookie == null &&
                              !state.anonHintDismissed) ...<Widget>[
                            const SizedBox(height: 12),
                            _anonHint(context),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // banner 单独一个 pinned header：往上滑时收成胶囊，钉在信息流上方。
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeroHeaderDelegate(
                  title: state.source.name,
                  loading: state.loading,
                  count: state.threads.length,
                  page: state.page,
                  horizontalBase: wide ? 32 : 16,
                  topInset: topInset,
                  onRefresh: _refresh,
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          wide ? 32 : 16, 16, wide ? 32 : 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _chips(context),
                          if (state.fromCache) ...<Widget>[
                            const SizedBox(height: 10),
                            _CacheBanner(
                              ageMs: state.cacheAgeMs,
                              onRefresh: _refresh,
                            ),
                          ],
                          SectionTitle('最新串',
                              trailing: state.loading
                                  ? '加载中…'
                                  : '${state.threads.length} 条'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _listSliver(wide),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 4,
                          wide ? 32 : 16, NavigationDock.insetOf(context)),
                      child: _footer(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 未登录时的一条轻提示：不弹窗、不挡内容，可关掉且记住选择。
  Widget _anonHint(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.person_outline_rounded,
              size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '当前是匿名浏览，受限版面看不到，也不能发串',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () =>
                Navigator.of(context).push(CookieClaimPage.route()),
            child: const Text('去领取', style: TextStyle(fontSize: 12.5)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '关闭',
            iconSize: 16,
            onPressed: () => state.dismissAnonHint(),
            icon: Icon(Icons.close_rounded, color: kInk3),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('时间线',
                  style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: kInk)),
              SizedBox(height: 5),
              Text(
                '下拉刷新 · 点按查看',
                style: TextStyle(fontSize: 12.5, color: kInk2),
              ),
            ],
          ),
        ),
        _IconBtn(
          icon: Icons.search_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SearchPage()),
          ),
        ),
        const SizedBox(width: 8),
        _IconBtn(icon: Icons.refresh_rounded, onTap: _refresh),
      ],
    );
  }

  Widget _chips(BuildContext context) {
    final items = <Widget>[];

    if (state.source.isForum) {
      items.add(_Pill(
        label: '版面：${state.source.name}',
        active: true,
        trailing: Icons.close_rounded,
        onTap: () => state.setSource(const Source.timeline(1, '综合线')),
      ));
    } else {
      for (final line in AppState.lines) {
        final active = !state.source.isForum && state.source.id == line.id;
        items.add(_Pill(
          label: line.name,
          active: active,
          locked: line.needsCookie,
          onTap: () {
            if (line.needsCookie) {
              _toast('「${line.name}」需要饼干才能看');
              return;
            }
            state.setSource(Source.timeline(line.id, line.name));
          },
        ));
      }
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }

  Widget _listSliver(bool wide) {
    if (state.threads.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16),
              child: state.loading
                  ? const Skeleton(count: 4)
                  : _errorOrEmpty(context),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16),
      sliver: SliverList.separated(
        itemCount: state.threads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final p = state.threads[i];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 916),
              child: ThreadCard(post: p, onTap: () => _openThread(p)),
            ),
          );
        },
      ),
    );
  }

  Widget _errorOrEmpty(BuildContext context) {
    if (state.error != null) {
      return SurfaceCard(
        padding: EdgeInsets.all(22),
        child: Column(
          children: <Widget>[
            Icon(Icons.cloud_off_rounded, color: kInk3, size: 30),
            SizedBox(height: 10),
            Text(state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kInk2)),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: _refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return SurfaceCard(
      padding: EdgeInsets.all(30),
      child: Center(
        child: Text('这里还没有内容',
            style: TextStyle(fontSize: 13, color: kInk3)),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    if (state.threads.isEmpty) return const SizedBox.shrink();
    if (state.loading) {
      return const Skeleton(count: 2, height: 84);
    }
    if (state.error != null) {
      return Column(
        children: <Widget>[
          Text(state.error!,
              style: TextStyle(fontSize: 12, color: kInk3)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _refresh, child: const Text('重试')),
        ],
      );
    }
    if (!state.hasMore) {
      return Center(
        child: Text('— 到底了 —',
            style: TextStyle(fontSize: 12, color: kInk3)),
      );
    }
    return Center(
      child: OutlinedButton(
        onPressed: state.loadMore,
        child: const Text('加载下一页'),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 首页 banner：既是展开的渐变卡片，也会收成胶囊钉在信息流上方。
///
/// [t] 是收拢进度，0 = 完全展开，1 = 完全收成胶囊，由 [SliverPersistentHeader]
/// 的 shrinkOffset 驱动。几何量线性插值（保证和 header 的高度严格对齐），
/// 两套内容之间做交叉淡入淡出，看起来就是「被压扁成一颗胶囊」。
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.t,
    required this.title,
    required this.loading,
    required this.count,
    required this.page,
    required this.onRefresh,
    required this.horizontalBase,
    required this.topInset,
  });

  /// 0 = 展开，1 = 收成胶囊。
  final double t;
  final String title;
  final bool loading;
  final int count;
  final int page;
  final Future<void> Function() onRefresh;

  /// 页面统一的左右留白（宽屏 32、窄屏 16）。
  final double horizontalBase;

  /// 状态栏高度。收成顶栏后要连状态栏一起染上，才算真正「融入」。
  final double topInset;

  /// 展开态/收起态的内容高度。
  static const double expandedContent = 84;
  static const double collapsedContent = 46;

  /// 上方留白：展开时贴近上文，收起时顶到屏幕最上面。
  static const double expandedGap = 18;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g1 = scheme.primary;
    final g2 = Color.lerp(scheme.primary, scheme.tertiary, 0.55)!;
    final g3 = Color.lerp(scheme.primary, const Color(0xFF8B5CF6), 0.85)!;

    // 几何量必须线性：header 的高度按 shrinkOffset 线性收，
    // 这里对不上就会出现「顶栏没贴住顶部」的错位。
    final h = lerpDouble(expandedContent, topInset + collapsedContent, t)!;
    final gap = lerpDouble(expandedGap, 0, t)!;
    // 收起时两侧留白收到 0：贴着屏幕边缘的顶栏，不再悬浮。
    final side = lerpDouble(horizontalBase, 0, t)!;
    // 顶边收成直角（上面是状态栏，圆角会被裁掉），底边保留圆角，
    // 和页面里 20 圆角的卡片是同一套语言。
    final radiusTop = lerpDouble(24, 0, t)!;
    final radiusBottom = lerpDouble(24, 22, t)!;
    final showExpanded = (1 - t * 2.4).clamp(0.0, 1.0);
    final showCollapsed = ((t - 0.42) * 2.2).clamp(0.0, 1.0);

    final bar = Padding(
      padding: EdgeInsets.fromLTRB(side, gap, side, 0),
      child: Container(
        height: h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[g1, g2, g3],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusTop),
            bottom: Radius.circular(radiusBottom),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: g1.withOpacity(lerpDouble(0.26, 0.32, t)!),
              blurRadius: lerpDouble(28, 18, t)!,
              offset: Offset(0, lerpDouble(10, 6, t)!),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Opacity(
                opacity: showExpanded,
                child: IgnorePointer(
                  ignoring: showExpanded < 0.5,
                  child: _expanded(),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: showCollapsed,
                child: IgnorePointer(
                  ignoring: showCollapsed < 0.5,
                  child: _collapsed(),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (t < 0.5) return bar;
    // 状态栏保持透明：顶栏的渐变已经铺到屏幕最上面了。
    // 之前给状态栏填纯色（statusBarColor: primary），等于在渐变上压了一条
    // 色差明显的横带，怎么调都对不齐——纯色和渐变色本来就不可能一致。
    // 这里只负责把状态栏图标转成白色。
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: bar,
    );
  }

  Widget _expanded() {
    final meta = loading ? '正在加载…' : '第 $page 页 · 共 $count 条';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 12, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('X 岛 · 匿名揭示板',
                    style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 1.1,
                        color: Colors.white70)),
                const SizedBox(height: 3),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: Colors.white)),
                const SizedBox(height: 3),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11.5, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _refreshDot(),
        ],
      ),
    );
  }

  Widget _collapsed() {
    // 顶栏高度里含状态栏，所以内容只占最下面那 46。
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: collapsedContent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.dynamic_feed_rounded,
                  size: 15, color: Colors.white70),
              const SizedBox(width: 7),
              Flexible(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
              const SizedBox(width: 7),
              Text('$count 条',
                  style:
                      const TextStyle(fontSize: 11.5, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _refreshDot() {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.white.withOpacity(0.16),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onRefresh(),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

/// 让 banner 钉在信息流上方：滑动时收缩成胶囊，停在顶部后继续悬浮。
class _HeroHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeroHeaderDelegate({
    required this.title,
    required this.loading,
    required this.count,
    required this.page,
    required this.horizontalBase,
    required this.topInset,
    required this.onRefresh,
  });

  final String title;
  final bool loading;
  final int count;
  final int page;
  final double horizontalBase;
  final double topInset;
  final Future<void> Function() onRefresh;

  /// 收起后要给状态栏让出高度，顶栏底色才能一直铺到屏幕最上面。
  @override
  double get minExtent => topInset + _HeroCard.collapsedContent;

  @override
  double get maxExtent {
    final expanded = _HeroCard.expandedGap + _HeroCard.expandedContent;
    // 状态栏特别高时（横屏/平板）别让 min 超过 max。
    return expanded > minExtent ? expanded : minExtent + 8;
  }

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final span = maxExtent - minExtent;
    final t = span <= 0 ? 0.0 : (shrinkOffset / span).clamp(0.0, 1.0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: _HeroCard(
          t: t,
          title: title,
          loading: loading,
          count: count,
          page: page,
          horizontalBase: horizontalBase,
          topInset: topInset,
          onRefresh: onRefresh,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeroHeaderDelegate old) =>
      old.title != title ||
      old.loading != loading ||
      old.count != count ||
      old.page != page ||
      old.horizontalBase != horizontalBase ||
      old.topInset != topInset;
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
    this.locked = false,
    this.trailing,
  });

  final String label;
  final bool active;
  final bool locked;
  final IconData? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: active ? scheme.primary : kOutline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? Colors.white : kInk2)),
              if (locked) ...<Widget>[
                SizedBox(width: 4),
                Icon(Icons.lock_outline_rounded,
                    size: 12,
                    color: active ? Colors.white70 : kInk3),
              ],
              if (trailing != null) ...<Widget>[
                SizedBox(width: 4),
                Icon(trailing,
                    size: 14, color: active ? Colors.white : kInk3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: kOutline),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                  color: Color(0x0A16203C),
                  blurRadius: 16,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Icon(icon, size: 20, color: scheme.primary),
        ),
      ),
    );
  }
}

/// 站点不可用时会回落到过期缓存，必须明说，别让用户以为是最新数据。
class _CacheBanner extends StatelessWidget {
  const _CacheBanner({required this.ageMs, required this.onRefresh});

  final int ageMs;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final mins = (ageMs / 60000).ceil();
    final label = mins <= 0
        ? '刚刚'
        : (mins < 60 ? '$mins 分钟前' : '${(mins / 60).ceil()} 小时前');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3E0C4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded,
              size: 17, color: Color(0xFF8A5A12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '离线缓存 · 数据来自 $label，站点可能维护中',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A5A12)),
            ),
          ),
          TextButton(
            onPressed: () => onRefresh(),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 30),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('重试', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
