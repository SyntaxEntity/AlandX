import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../widgets.dart';
import 'thread_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _ctrl = TextEditingController();
  final AppState _state = AppState.instance;

  bool _loading = false;
  SearchResult? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final kw = _ctrl.text.trim();
    if (kw.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _result = null;
    });
    final r = await Api.instance.search(kw, cookie: _state.cookie);
    if (!mounted) return;
    setState(() {
      _result = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.only(right: 12),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _run(),
            decoration: InputDecoration(
              hintText: '搜索串标题或内容',
              isDense: true,
              filled: true,
              fillColor: kCard,
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kOutline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: kOutline),
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: _run, child: const Text('搜索')),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Skeleton(count: 4, height: 64),
      );
    }

    final r = _result;
    if (r == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            '搜索用的是网页表单，不是 JSON 接口。\n'
            '未登录可能拿不到结果，建议先导入饼干。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.9, color: kInk3),
          ),
        ),
      );
    }

    if (r.hits.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(r.message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kInk2)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: r.hits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final h = r.hits[i];
        return SurfaceCard(
          padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ThreadPage(threadId: h.id),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color(0xFFF1F4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.chat_bubble_outline_rounded,
                    size: 17, color: Color(0xFF6D82F5)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(h.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4)),
                    SizedBox(height: 3),
                    Text('No.${h.id}',
                        style: TextStyle(fontSize: 11, color: kInk3)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: kInk3),
            ],
          ),
        );
      },
    );
  }
}
