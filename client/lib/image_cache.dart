import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 图片磁盘缓存。
///
/// 之前图片走 `Image.network`，只有 Flutter 的内存缓存，退出页面再进来就重下。
/// X岛的图床在境外，每张图几百 KB，重复下载代价明显，所以这里加一层磁盘缓存。
///
/// 没有引入 `cached_network_image`：它依赖 `flutter_cache_manager` → `sqflite`，
/// 而 sqflite 没有 Linux/Windows 实现，会把这个项目的桌面构建拖下水。
/// 这里用 `Directory.systemTemp` 落地，三端都可用，零新依赖。
class ImageDiskCache {
  ImageDiskCache._();
  static final ImageDiskCache instance = ImageDiskCache._();

  static const int _memEntries = 40;
  static const int _maxFiles = 400;
  static const int _maxBytes = 8 * 1024 * 1024;

  final Map<String, Uint8List> _mem = <String, Uint8List>{};
  Directory? _dir;
  bool _swept = false;

  Future<Directory> _ensureDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final d = Directory('${Directory.systemTemp.path}/xd_img_cache');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    if (!_swept) {
      _swept = true;
      // 目录里的文件太多时按修改时间清一批，避免长期使用无限膨胀。
      unawaited(_sweep(d));
    }
    return d;
  }

  Future<void> _sweep(Directory d) async {
    try {
      final files = await d
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      if (files.length <= _maxFiles) return;
      final stats = <MapEntry<File, DateTime>>[];
      for (final f in files) {
        stats.add(MapEntry(f, (await f.stat()).modified));
      }
      stats.sort((a, b) => a.value.compareTo(b.value));
      final drop = stats.length - _maxFiles;
      for (var i = 0; i < drop; i++) {
        try {
          await stats[i].key.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  static String _keyOf(String url) {
    var h = 2166136261;
    for (final c in url.codeUnits) {
      h = (h ^ c) * 16777619;
      h &= 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  void _remember(String url, Uint8List bytes) {
    if (_mem.length >= _memEntries) {
      _mem.remove(_mem.keys.first);
    }
    _mem[url] = bytes;
  }

  /// 取图片字节：内存 → 磁盘 → 网络，逐级回退。
  Future<Uint8List?> bytes(String url) async {
    if (url.isEmpty) return null;

    final cached = _mem[url];
    if (cached != null) return cached;

    File? file;
    try {
      final d = await _ensureDir();
      file = File('${d.path}/${_keyOf(url)}');
      if (await file.exists()) {
        final b = await file.readAsBytes();
        if (b.isNotEmpty) {
          _remember(url, b);
          return b;
        }
      }
    } catch (_) {
      file = null;
    }

    try {
      final res = await http
          .get(Uri.parse(url), headers: <String, String>{
            'User-Agent': 'HavfunClient-Flutter',
            'Referer': 'https://www.nmbxd1.com/',
          })
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return null;
      final body = res.bodyBytes;
      if (body.isEmpty || body.length > _maxBytes) return null;
      _remember(url, body);
      try {
        await file?.writeAsBytes(body, flush: false);
      } catch (_) {}
      return body;
    } catch (_) {
      return null;
    }
  }
}

/// 带磁盘缓存的图片。参数刻意与 `Image.network` 常用子集对齐，方便替换。
class CachedImage extends StatefulWidget {
  const CachedImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.filterQuality = FilterQuality.low,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final FilterQuality filterQuality;

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  late Future<Uint8List?> _future = ImageDiskCache.instance.bytes(widget.url);

  @override
  void didUpdateWidget(covariant CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = ImageDiskCache.instance.bytes(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        if (data != null) {
          return Image.memory(
            data,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            filterQuality: widget.filterQuality,
            gaplessPlayback: true,
          );
        }
        if (snap.connectionState == ConnectionState.done) {
          return widget.errorBuilder?.call(
                context,
                'image',
                null,
              ) ??
              const SizedBox.shrink();
        }
        // 占位保持与原图同尺寸，避免加载完成时列表跳动。
        return SizedBox(width: widget.width, height: widget.height);
      },
    );
  }
}
