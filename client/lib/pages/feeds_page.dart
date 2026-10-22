import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../cookies.dart';
import '../models.dart';
import '../state.dart';
import '../widgets.dart';
import 'cookie_help.dart';
import 'thread_page.dart';

class FeedsPage extends StatefulWidget {
  const FeedsPage({super.key});

  @override
  State<FeedsPage> createState() => _FeedsPageState();
}

class _FeedsPageState extends State<FeedsPage> {
  final AppState _state = AppState.instance;
  final CookieStore _cookies = CookieStore.instance;

  List<Post> _feed = <Post>[];
  bool _loading = false;
  String? _error;

  String _lastUuid = '';

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    _loadFeed();
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  /// 启动时 uuid 还没从本地读出来，等它到位后再拉一次订阅。
  void _onStateChanged() {
    if (_state.uuid.isNotEmpty && _state.uuid != _lastUuid) {
      _loadFeed();
    }
  }

  Future<void> _loadFeed() async {
    if (_state.uuid.isEmpty) return;
    _lastUuid = _state.uuid;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await Api.instance.fetchFeed(_state.uuid, force: true);
      if (!mounted) return;
      setState(() {
        _feed = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static String _newId() {
    final r = Random();
    return '${DateTime.now().microsecondsSinceEpoch}-${r.nextInt(9999)}';
  }

  Future<void> _importBiscuit() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('导入饼干'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '在用户中心领取饼干后，二维码内容是 {"cookie":"…","name":"…"}，'
              '整段粘贴或只贴 cookie 值都可以。只保存在本机。',
              style: TextStyle(fontSize: 12.5, height: 1.6, color: kInk2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              minLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '{"cookie":"…","name":"…"}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(CookieHelpPage.route());
            },
            child: const Text('怎么获取'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('保存并校验'),
          ),
        ],
      ),
    );

    if (text == null || text.isEmpty) return;
    try {
      final b = await _cookies.add(text, _newId());
      _toast('已保存，正在校验…');
      final r = await _cookies.verify(b.id);
      _toast(r.ok ? '饼干有效，受限版面已解锁' : '校验未通过：${r.message}');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_state, _cookies]),
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 980;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 26, wide ? 32 : 16,
              NavigationDock.insetOf(context)),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('订阅',
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: kInk)),
                    SizedBox(height: 5),
                    Text('饼干是身份，订阅是收藏，两者互不绑定',
                        style: TextStyle(fontSize: 12.5, color: kInk2)),
                    const SizedBox(height: 18),
                    _biscuitCard(),
                    const SizedBox(height: 14),
                    _uuidCard(),
                    const SectionTitle('收藏的串'),
                    _feedList(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _biscuitCard() {
    final active = _cookies.active;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('饼干（身份）',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: active == null
                      ? Color(0xFFFFF3E6)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  active == null
                      ? '未导入'
                      : '使用中：${active.name}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active == null
                        ? Color(0xFFB96A12)
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '一块饼干就是一个可发帖身份。第三方客户端无法代你登录，'
            '只能由你从用户中心复制/扫码导入；饼干只存在本机。',
            style: TextStyle(fontSize: 12.5, height: 1.7, color: kInk2),
          ),
          SizedBox(height: 12),
          if (_cookies.items.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kChip,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Color(0xFFD3D9EA)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.cookie_outlined,
                      color: Color(0xFF3D5BFE), size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('还没有导入饼干',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('导入后可看速报2 / DANGER_U，并可发串',
                            style:
                                TextStyle(fontSize: 11.5, color: kInk3)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ..._cookies.items.map(_biscuitTile),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              FilledButton.tonal(
                onPressed: _importBiscuit,
                child: const Text('导入饼干'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _showHelp,
                child: const Text('如何获取'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _biscuitTile(Biscuit b) {
    final isActive = _cookies.active?.id == b.id;
    final verified = _cookies.verified[b.id];
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: isActive ? Color(0xFFF5F7FF) : kChip,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isActive ? Color(0xFFC3CCFF) : kOutline),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.cookie_outlined,
              size: 20, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(b.name,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '${b.masked} · ${verified == true ? "已校验" : verified == false ? "校验未通过" : "未校验"}',
                  style: TextStyle(
                      fontSize: 11, color: kInk3, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          if (isActive)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('使用中',
                  style: TextStyle(fontSize: 11, color: kInk3)),
            )
          else
            TextButton(
              onPressed: () => _cookies.setActive(b.id),
              child: const Text('使用'),
            ),
          IconButton(
            tooltip: '校验',
            icon: const Icon(Icons.verified_outlined, size: 18),
            onPressed: () async {
              final r = await _cookies.verify(b.id);
              _toast(r.ok ? '饼干有效' : '校验未通过：${r.message}');
            },
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('删除饼干？'),
                  content: Text('「${b.name}」将从本机移除，对应的身份无法恢复。'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              );
              if (ok == true) await _cookies.remove(b.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _uuidCard() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('本地订阅',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text('UUID',
                  style: TextStyle(fontSize: 11, color: kInk3)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '订阅接口只认 UUID，不校验账号。换设备时导入同一个 UUID 就能同步收藏。',
            style: TextStyle(fontSize: 12.5, height: 1.7, color: kInk2),
          ),
          SizedBox(height: 10),
          SelectableText(
            _state.uuid,
            style: TextStyle(
                fontSize: 11.5, color: kInk3, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _state.uuid));
                  _toast('UUID 已复制');
                },
                child: const Text('复制 UUID'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => _toast('重新生成会丢失当前设备上的收藏关联，暂未开放'),
                child: const Text('重新生成'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feedList() {
    if (_loading) return const Skeleton(count: 2, height: 96);
    if (_error != null) {
      return SurfaceCard(
        child: Column(
          children: <Widget>[
            Text(_error!,
                style: TextStyle(fontSize: 12.5, color: kInk2)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _loadFeed, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_feed.isEmpty) {
      return SurfaceCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              '这个 UUID 下还没有订阅\n在串详情点「订阅」即可加入',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.8, color: kInk3),
            ),
          ),
        ),
      );
    }
    return Column(
      children: _feed.map((p) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            ThreadCard(
              post: p,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ThreadPage(threadId: p.id),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final txt = await Api.instance.delFeed(_state.uuid, p.id);
                _toast(txt.isEmpty ? '已取消订阅' : txt);
                _loadFeed();
              },
              child: Text('取消订阅',
                  style: TextStyle(fontSize: 12, color: kInk3)),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCanvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(22, 18, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('饼干怎么拿？',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            Text(
              '1. 浏览器登录 www.nmbxd1.com 用户中心（邮箱 + 密码 + 验证码，第三方无法代劳）\n'
              '2. 进入「饼干」页领取/装备一块，页面二维码内容是 {"cookie":"…","name":"…"}\n'
              '3. 在客户端粘贴导入，即可访问受限版面并以其身份发串',
              style: TextStyle(fontSize: 13, height: 1.9, color: kInk2),
            ),
            SizedBox(height: 8),
            Text(
              '接口约定：Cookie 键名固定为 userhash；缺失时返回「必须登入领取饼干后才可以访问」。',
              style: TextStyle(fontSize: 11.5, height: 1.7, color: kInk3),
            ),
          ],
        ),
      ),
    );
  }
}
