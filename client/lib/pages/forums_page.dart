import 'package:flutter/material.dart';

import '../models.dart';
import '../state.dart';
import '../widgets.dart';

class ForumsPage extends StatefulWidget {
  const ForumsPage({super.key});

  @override
  State<ForumsPage> createState() => _ForumsPageState();
}

class _ForumsPageState extends State<ForumsPage> {
  final AppState state = AppState.instance;
  int selected = -1; // -1 = 全部

  @override
  void initState() {
    super.initState();
    if (state.categories.isEmpty) {
      state.loadForums();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 980;
        final total = state.categories.fold<int>(0, (a, c) => a + c.forums.length);
        final shown = selected < 0
            ? state.categories
            : state.categories.where((c) => c.id == selected).toList();

        return CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 26, wide ? 32 : 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('版面',
                                      style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.5,
                                          color: kInk)),
                                  SizedBox(height: 5),
                                  Text(
                                    state.categories.isEmpty
                                        ? '正在获取 /getForumList…'
                                        : '${state.categories.length} 个分类 · $total 个版面',
                                    style: TextStyle(
                                        fontSize: 12.5, color: kInk2),
                                  ),
                                ],
                              ),
                            ),
                            _RefreshBtn(
                              onTap: () => state.loadForums(force: true),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _categoryChips(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (state.forumsLoading)
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Skeleton(count: 3, height: 100),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 16,
                    wide ? 32 : 16, NavigationDock.insetOf(context)),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 108,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final list = shown.expand((c) => c.forums).toList();
                      if (i >= list.length) return const SizedBox.shrink();
                      final f = list[i];
                      return _ForumTile(
                        forum: f,
                        category: state.categories
                            .firstWhere((c) => c.forums.contains(f))
                            .name,
                        onTap: () {
                          state.setSource(Source.forum(f.id, f.name));
                          state.setTab(0);
                        },
                      );
                    },
                    childCount:
                        shown.fold<int>(0, (a, c) => a + c.forums.length),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _categoryChips() {
    final items = <Widget>[
      _chip('全部', -1),
      ...state.categories.map((c) => _chip(c.name, c.id)),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }

  Widget _chip(String label, int id) {
    final scheme = Theme.of(context).colorScheme;
    final active = selected == id;
    return Material(
      color: active ? scheme.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => selected = id),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? scheme.primary : kOutline),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? Colors.white : kInk2)),
        ),
      ),
    );
  }
}

class _ForumTile extends StatelessWidget {
  const _ForumTile({
    required this.forum,
    required this.category,
    required this.onTap,
  });

  final Forum forum;
  final String category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = (forum.threadCount <= 0)
        ? 0.06
        : (0.12 + (forum.threadCount / 6000).clamp(0.0, 0.88));

    return SurfaceCard(
      onTap: onTap,
      padding: EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(forum.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: kInk)),
              ),
              if (forum.threadCount > 0)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${forum.threadCount}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary)),
                ),
            ],
          ),
          SizedBox(height: 5),
          Text('$category · 间隔 ${forum.interval}s',
              style: TextStyle(fontSize: 11.5, color: kInk3)),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: kChip,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshBtn extends StatelessWidget {
  const _RefreshBtn({required this.onTap});

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
          ),
          child: Icon(Icons.refresh_rounded, size: 20, color: scheme.primary),
        ),
      ),
    );
  }
}
