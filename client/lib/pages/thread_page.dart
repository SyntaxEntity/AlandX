import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../models.dart';
import '../picker.dart';
import '../state.dart';
import '../widgets.dart';

class ThreadPage extends StatefulWidget {
  const ThreadPage({super.key, required this.threadId});

  final int threadId;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  final AppState _state = AppState.instance;

  Post? _op;
  List<Post> _replies = <Post>[];
  bool _loading = true;
  bool _more = false;
  bool _hasMore = true;
  bool _onlyPo = false;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load(1, reset: true);
  }

  Future<void> _load(int page, {bool reset = false}) async {
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _more = true;
      }
    });

    try {
      final data = await Api.instance.fetchThread(
        widget.threadId,
        page: page,
        onlyPo: _onlyPo,
        cookie: _state.cookie,
      );
      if (!mounted) return;
      setState(() {
        _op = data;
        if (page == 1) {
          _replies = List<Post>.of(data.replies);
        } else {
          _replies = <Post>[..._replies, ...data.replies];
        }
        _page = page;
        _hasMore = _replies.length < data.replyCount;
        _loading = false;
        _more = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _more = false;
      });
    }
  }

  Future<void> _toggleOnlyPo() async {
    setState(() => _onlyPo = !_onlyPo);
    await _load(1, reset: true);
  }

  Future<void> _share() async {
    final url = 'https://www.nmbxd1.com/t/${widget.threadId}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _toast('链接已复制：$url');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _subscribe() async {
    final txt = await Api.instance.addFeed(_state.uuid, widget.threadId);
    if (!mounted) return;
    _toast(txt.isEmpty ? '已订阅' : txt);
  }

  Future<void> _reply() async {
    final cookie = _state.cookie;
    if (cookie == null || cookie.isEmpty) {
      _toast('先在「订阅」页导入饼干，才能回复');
      return;
    }

    final ctrl = TextEditingController(text: '>>No.${widget.threadId} ');
    PickedImage? image;

    final payload = await showModalBottomSheet<_ReplyPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DDEC),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('回复 No.${widget.threadId}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                maxLines: 6,
                minLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8F9FF),
                  hintText: '回复内容…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E8F1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E8F1)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  if (image == null)
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final img = await pickImageBytes();
                          if (img != null) setSheet(() => image = img);
                        } on ApiException catch (e) {
                          _toast(e.message);
                        }
                      },
                      icon: const Icon(Icons.image_outlined, size: 17),
                      label: const Text('图片'),
                    )
                  else ...<Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(image!.bytes,
                          width: 46, height: 46, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${image!.name} · ${image!.sizeKb}KB',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: kInk3)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () => setSheet(() => image = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final text = ctrl.text.trim();
                    if (text.isEmpty && image == null) {
                      _toast('内容和图片不能同时为空');
                      return;
                    }
                    Navigator.of(ctx).pop(_ReplyPayload(text, image));
                  },
                  child: const Text('发送'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (payload == null) return;

    final r = await Api.instance.postReply(
      cookie: cookie,
      resto: widget.threadId,
      content: payload.content,
      image: payload.image?.bytes,
      filename: payload.image?.name,
    );
    if (!mounted) return;
    _toast(r.ok ? '回复成功' : '发送失败：${r.message}');
    if (r.ok) await _load(1, reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final scheme = Theme.of(context).colorScheme;
    final op = _op;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5FB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(op == null ? '串' : _state.forumName(op.fid),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text('No.${widget.threadId}',
                style: const TextStyle(fontSize: 11, color: kInk3)),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '复制链接',
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            onPressed: _share,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _toggleOnlyPo,
              style: TextButton.styleFrom(
                backgroundColor:
                    _onlyPo ? scheme.primary : Colors.white,
                foregroundColor: _onlyPo ? Colors.white : kInk2,
                minimumSize: const Size(44, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: _onlyPo ? scheme.primary : kOutline),
                ),
              ),
              child: const Text('PO', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(child: _body(wide, op)),
            _replyBar(),
          ],
        ),
      ),
    );
  }

  Widget _body(bool wide, Post? op) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16, vertical: 12),
        child: const Skeleton(count: 3, height: 120),
      );
    }
    if (_error != null && op == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off_rounded, color: kInk3, size: 30),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: kInk2)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _load(1, reset: true),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (op == null) return const SizedBox.shrink();

    final items = <Widget>[
      if (op.displayTitle.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(op.displayTitle,
              style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  height: 1.4)),
        ),
      PostCard(
        post: op,
        isOp: true,
        onThreadTap: (id) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ThreadPage(threadId: id)),
        ),
        onImageTap: (url) => _previewImage(url),
      ),
      const SizedBox(height: 6),
      ..._replies.map((p) => PostCard(
            post: p,
            onThreadTap: (id) => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ThreadPage(threadId: id)),
            ),
            onImageTap: (url) => _previewImage(url),
          )),
      if (_hasMore)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: OutlinedButton(
            onPressed: _more ? null : () => _load(_page + 1),
            child: Text(_more ? '加载中…' : '加载更多回复（$_page/${(op.replyCount / 20).ceil()}）'),
          ),
        )
      else
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: Text('— 到底了 —',
                style: TextStyle(fontSize: 12, color: kInk3)),
          ),
        ),
    ];

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(wide ? 32 : 14, 6, wide ? 32 : 14, 20),
      itemCount: items.length,
      itemBuilder: (context, i) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: items[i],
        ),
      ),
    );
  }

  Widget _replyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: kOutline)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: _subscribe,
              child: const Text('订阅'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _reply,
              child: const Text('回复'),
            ),
          ),
        ],
      ),
    );
  }

  void _previewImage(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyPayload {
  final String content;
  final PickedImage? image;
  const _ReplyPayload(this.content, this.image);
}
