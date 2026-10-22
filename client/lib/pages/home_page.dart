import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../widgets.dart';
import 'cookie_help.dart';
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
                      padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 26, wide ? 32 : 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _header(context),
                          if (state.cookie == null &&
                              !state.anonHintDismissed) ...<Widget>[
                            const SizedBox(height: 12),
                            _anonHint(context),
                          ],
                          const SizedBox(height: 18),
                          _HeroCard(
                            title: state.source.name,
                            loading: state.loading,
                            latencyMs: state.upstreamMs,
                            count: state.threads.length,
                            page: state.page,
                            onRefresh: _refresh,
                            onSearch: () => _toast(
                                '搜索只有网页表单（需 __hash__ 与登录），没有 JSON 接口'),
                          ),
                          const SizedBox(height: 16),
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
            onPressed: () => Navigator.of(context).push(CookieHelpPage.route()),
            child: const Text('怎么弄', style: TextStyle(fontSize: 12.5)),
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
                '来源 ${state.source.isForum ? '/showf' : '/timeline'} · 20 条一页',
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
              _toast('「${line.name}」需要饼干：匿名访问会返回“必须登入领取饼干后才可以访问”');
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.loading,
    required this.latencyMs,
    required this.count,
    required this.page,
    required this.onRefresh,
    required this.onSearch,
  });

  final String title;
  final bool loading;
  final int latencyMs;
  final int count;
  final int page;
  final Future<void> Function() onRefresh;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g1 = scheme.primary;
    final g2 = Color.lerp(scheme.primary, scheme.tertiary, 0.55)!;
    final g3 = Color.lerp(scheme.primary, const Color(0xFF8B5CF6), 0.85)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[g1, g2, g3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: g1.withOpacity(0.28),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('X 岛 · 匿名揭示板',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: Colors.white70)),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  loading ? '正在拉取第 $page 页…' : '第 $page 页 · 已加载 $count 条',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    _Stat(
                        value: latencyMs == 0 ? '—' : '${latencyMs}ms',
                        label: '上游延迟'),
                    const SizedBox(width: 26),
                    _Stat(value: '$count', label: '本轮串数'),
                    const SizedBox(width: 26),
                    const _Stat(value: '直连', label: '通道'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 108,
                  height: 108,
                  child: CircularProgressIndicator(
                    value: loading ? null : 0.78,
                    strokeWidth: 3,
                    color: Colors.white.withOpacity(0.9),
                    backgroundColor: Colors.white24,
                  ),
                ),
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRefresh(),
                    child: SizedBox(
                      width: 78,
                      height: 78,
                      child: Icon(Icons.refresh_rounded,
                          color: scheme.primary, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
      ],
    );
  }
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
