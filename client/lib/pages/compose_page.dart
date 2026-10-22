import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../draft.dart';
import '../picker.dart';
import '../state.dart';
import '../widgets.dart';

class ComposePage extends StatefulWidget {
  const ComposePage({super.key, this.fid});

  final int? fid;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final AppState _state = AppState.instance;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();

  late int _fid = widget.fid ?? 4;
  PickedImage? _image;
  bool _sending = false;

  /// 草稿防抖：输入停下 700ms 才落盘，避免每个字符都写一次 SharedPreferences。
  Timer? _saveTimer;
  bool _restored = false;
  bool _posted = false;

  @override
  void initState() {
    super.initState();
    if (_state.categories.isEmpty) _state.loadForums();
    _restoreDraft();
    _title.addListener(_scheduleSave);
    _content.addListener(_scheduleSave);
  }

  void _restoreDraft() {
    final d = DraftStore.instance.read();
    if (d == null) return;
    final title = (d['title'] ?? '').toString();
    final content = (d['content'] ?? '').toString();
    if (title.isEmpty && content.isEmpty) return;
    _title.text = title;
    _content.text = content;
    final fid = d['fid'];
    if (fid is int) _fid = fid;
    _restored = true;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _saveDraft);
  }

  void _saveDraft() {
    DraftStore.instance.save(
      title: _title.text,
      content: _content.text,
      fid: _fid,
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // 退出时立刻落盘，不等防抖窗口；发送成功则不再回写。
    if (!_posted) _saveDraft();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pick() async {
    try {
      final img = await pickImageBytes();
      if (img == null || !mounted) return;
      setState(() => _image = img);
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _submit() async {
    final cookie = _state.cookie;
    if (cookie == null || cookie.isEmpty) {
      _toast('先在「订阅」页导入饼干，才能发串');
      return;
    }
    final content = _content.text.trim();
    if (content.isEmpty && _image == null) {
      _toast('内容和图片不能同时为空');
      return;
    }

    setState(() => _sending = true);
    final r = await Api.instance.postThread(
      cookie: cookie,
      fid: _fid,
      title: _title.text.trim(),
      content: content,
      image: _image?.bytes,
      filename: _image?.name,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    if (r.ok) {
      _posted = true;
      _saveTimer?.cancel();
      await DraftStore.instance.clear();
      if (!mounted) return;
      _toast('发串成功');
      Navigator.of(context).pop(true);
    } else {
      _toast('发送失败：${r.message}');
    }
  }

  /// 恢复草稿时给一条不打断输入的行内提示，而不是弹窗。
  Widget _draftBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.restore_rounded,
              size: 17, color: scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已恢复上次未发送的草稿',
              style: TextStyle(fontSize: 12.5, color: scheme.onPrimaryContainer),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: scheme.onPrimaryContainer,
              minimumSize: const Size(52, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () {
              _saveTimer?.cancel();
              _title.clear();
              _content.clear();
              DraftStore.instance.clear();
              setState(() => _restored = false);
            },
            child: const Text('清空', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        final boards = <({int id, String name})>[
          for (final c in _state.categories)
            for (final f in c.forums) (id: f.id, name: '${f.name} · ${c.name}'),
        ];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: kCanvas,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text('发新串',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  onPressed: _sending ? null : _submit,
                  child: Text(_sending ? '发送中…' : '发送'),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: <Widget>[
              if (_restored) _draftBanner(),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DropdownButtonFormField<int>(
                      value: boards.any((b) => b.id == _fid) ? _fid : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '版面',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<int>>[
                        for (final b in boards)
                          DropdownMenuItem<int>(
                            value: b.id,
                            child: Text(b.name,
                                style: const TextStyle(fontSize: 13)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _fid = v);
                      },
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: _title,
                      maxLength: 60,
                      decoration: InputDecoration(
                        labelText: '标题（可留空）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _content,
                      minLines: 8,
                      maxLines: 20,
                      decoration: InputDecoration(
                        hintText: '说点什么…（支持 >>No. 引用）',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              SurfaceCard(
                child: Row(
                  children: <Widget>[
                    if (_image == null)
                      OutlinedButton.icon(
                        onPressed: _pick,
                        icon: Icon(Icons.image_outlined, size: 18),
                        label: Text('添加图片'),
                      )
                    else ...<Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _image!.bytes,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_image!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5)),
                            Text('${_image!.sizeKb} KB',
                                style: TextStyle(
                                    fontSize: 11, color: kInk3)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '移除',
                        icon: Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _image = null),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                '发串走网页表单（multipart + userhash），成功与否靠返回文案判断。\n'
                '图片会先压到 1600px / 88%，超过 4MB 会拒绝。',
                style: TextStyle(fontSize: 11.5, height: 1.8, color: kInk3),
              ),
            ],
          ),
        );
      },
    );
  }
}
