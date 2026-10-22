import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'image_cache.dart';
import 'models.dart';
import 'theme.dart';

// 颜色语义已迁到 theme.dart：kInk / kInk2 / kInk3 / kOutline 现在是跟着
// ColorScheme 走的 getter，明暗模式都能用。
// 这里 re-export，让原本 `import '../widgets.dart'` 的文件不用逐个改 import。
export 'image_cache.dart';
export 'theme.dart'
    show kInk, kInk2, kInk3, kOutline, kCanvas, kCard, kChip, palette;

/// 由饼干 hash 派生稳定颜色，和网页端「每个人一个色块」的观感对齐。
Color hashColor(String s, {double shift = 0, double sat = 0.52, double val = 0.66}) {
  int h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) % 360;
  }
  return HSVColor.fromAHSV(1, ((h + shift) % 360).toDouble(), sat, val).toColor();
}

class XAvatar extends StatelessWidget {
  const XAvatar({super.key, required this.hash, this.size = 36});

  final String hash;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = hash.isEmpty ? '?' : hash.substring(0, hash.length >= 2 ? 2 : 1);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[hashColor(hash), hashColor(hash, shift: 26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.3,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(title,
              style: TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600, color: kInk)),
          Spacer(),
          if (trailing != null)
            Text(trailing!,
                style: TextStyle(fontSize: 11.5, color: kInk3)),
        ],
      ),
    );
  }
}

/// 圆角卡片：和 FlClash 的卡片一致——纯白、24 圆角、极轻阴影。
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    final content = Padding(padding: padding, child: child);
    // MD3 靠 surfaceContainer 色阶表达层级，不再用「白底 + 1px 描边 + 投影」，
    // 那套是网页卡片的语言，也是之前「看起来像网页」的主要原因之一。
    return Material(
      color: kCard,
      borderRadius: radius,
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: radius, child: content),
    );
  }
}

class ThreadCard extends StatelessWidget {
  const ThreadCard({
    super.key,
    required this.post,
    required this.onTap,
    this.forum,
  });

  final Post post;
  final VoidCallback onTap;
  final String? forum;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImg = post.hasImage;
    final text = _plain(post.content);
    final title = post.displayTitle;

    return SurfaceCard(
      onTap: onTap,
      padding: EdgeInsets.fromLTRB(16, 15, 14, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              XAvatar(hash: post.userHash),
              if (forum != null) ...<Widget>[
                SizedBox(height: 6),
                Text(forum!,
                    style: TextStyle(fontSize: 9.5, color: kInk3)),
              ],
            ],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(post.displayName,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: kInk)),
                    if (post.admin) ...<Widget>[
                      SizedBox(width: 6),
                      _Badge('ADMIN', bg: Color(0xFFFFF0E8), fg: Color(0xFFC25A12)),
                    ],
                    SizedBox(width: 6),
                    Text('·', style: TextStyle(color: kInk3, fontSize: 11)),
                    SizedBox(width: 6),
                    Text('No.${post.id}',
                        style: TextStyle(fontSize: 11, color: kInk3)),
                  ],
                ),
                SizedBox(height: 7),
                Text(
                  title.isEmpty ? text : title,
                  maxLines: title.isEmpty ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: title.isEmpty ? 14 : 15.5,
                    height: 1.45,
                    letterSpacing: -0.2,
                    fontWeight: title.isEmpty ? FontWeight.w400 : FontWeight.w600,
                    color: title.isEmpty ? Color(0xFF4A5162) : kInk,
                  ),
                ),
                if (title.isNotEmpty && text.isNotEmpty) ...<Widget>[
                  SizedBox(height: 5),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, height: 1.65, color: kInk2),
                  ),
                ],
                SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    Icon(Icons.mode_comment_outlined,
                        size: 14, color: scheme.primary.withOpacity(0.75)),
                    SizedBox(width: 4),
                    Text('${post.replyCount}',
                        style: TextStyle(fontSize: 11.5, color: kInk3)),
                    SizedBox(width: 12),
                    Text(prettyTime(post.now),
                        style: TextStyle(fontSize: 11.5, color: kInk3)),
                  ],
                ),
              ],
            ),
          ),
          if (hasImg) ...<Widget>[
            SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedImage(
                Api.instance.imageUrl(post),
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 76,
                  height: 76,
                  color: kChip,
                  child: Icon(Icons.image_not_supported_outlined,
                      size: 18, color: kInk3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// 串详情里的一条内容（OP 或回复）。
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.isOp = false,
    this.onQuote,
    this.onThreadTap,
    this.onImageTap,
  });

  final Post post;
  final bool isOp;
  final void Function(int id)? onQuote;
  final void Function(int id)? onThreadTap;
  final void Function(String url)? onImageTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imgUrl = post.hasImage ? Api.instance.imageUrl(post, thumb: false) : '';

    return Container(
      margin: EdgeInsets.only(bottom: isOp ? 12 : 10),
      padding: EdgeInsets.fromLTRB(isOp ? 18 : 16, 15, isOp ? 18 : 16, 16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(isOp ? 24 : 20),
        border: Border.all(color: kOutline),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Color(0x0A16203C), blurRadius: 18, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              XAvatar(hash: post.userHash, size: 32),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(post.displayName,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: kInk)),
                        SizedBox(width: 6),
                        if (post.isTips)
                          _Badge('TIPS',
                              bg: Color(0xFFFFF0E8),
                              fg: Color(0xFFC25A12))
                        else if (isOp)
                          _Badge('PO',
                              bg: scheme.primary.withOpacity(0.10),
                              fg: scheme.primary)
                        else if (post.admin)
                          _Badge('ADMIN',
                              bg: Color(0xFFFFF0E8),
                              fg: Color(0xFFC25A12)),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text('No.${post.id}  ·  ${prettyTime(post.now)}',
                        style: TextStyle(fontSize: 11, color: kInk3)),
                  ],
                ),
              ),
            ],
          ),
          if (imgUrl.isNotEmpty) ...<Widget>[
            SizedBox(height: 12),
            GestureDetector(
              onTap: () => onImageTap?.call(imgUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedImage(
                  imgUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    alignment: Alignment.center,
                    color: kCanvas,
                    child: Icon(Icons.broken_image_outlined, color: kInk3),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          RichContent(
            html: post.content,
            onQuote: onQuote,
            onThreadTap: onThreadTap,
            onImageTap: onImageTap,
          ),
        ],
      ),
    );
  }
}

/// 极简 HTML → TextSpan 渲染器。
///
/// X岛的正文是 HTML 片段（br / a / ul / li / img），而且引用是纯文本 `>>No.123`。
/// 这里只支持用到的那几个标签，避免为了一个正文引入整套 WebView。
class RichContent extends StatelessWidget {
  const RichContent({
    super.key,
    required this.html,
    this.onQuote,
    this.onThreadTap,
    this.onImageTap,
    this.fontSize = 14.5,
  });

  final String html;
  final void Function(int id)? onQuote;
  final void Function(int id)? onThreadTap;
  final void Function(String url)? onImageTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocks = _splitBlocks(html);
    final children = <Widget>[];

    for (final block in blocks) {
      final t = block.trim();
      if (t.isEmpty) {
        children.add(const SizedBox(height: 7));
        continue;
      }
      final img = RegExp(r'^<img[^>]*>$', caseSensitive: false).firstMatch(t);
      if (img != null) {
        final src = _attr(t, 'src');
        if (src.isEmpty) continue;
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: GestureDetector(
            onTap: () => onImageTap?.call(_absolute(src)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedImage(
                _absolute(src),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ));
        continue;
      }

      children.add(Text.rich(
        TextSpan(
          children: _parseInline(t, _Sty(fontSize: fontSize, scheme: scheme)),
        ),
        style: TextStyle(
          fontSize: fontSize,
          height: 1.8,
          color: const Color(0xFF22252E),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<String> _splitBlocks(String html) {
    var s = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '· ')
        .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</?(ul|ol|div|blockquote|table|tbody|tr)[^>]*>',
            caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n———\n');

    return s.split('\n');
  }

  List<InlineSpan> _parseInline(String s, _Sty st) {
    final spans = <InlineSpan>[];
    int i = 0;

    while (i < s.length) {
      final lt = s.indexOf('<', i);
      if (lt < 0) {
        _addText(spans, s.substring(i), st);
        break;
      }
      if (lt > i) _addText(spans, s.substring(i, lt), st);
      final gt = s.indexOf('>', lt);
      if (gt < 0) {
        _addText(spans, s.substring(lt), st);
        break;
      }
      final tag = s.substring(lt + 1, gt).trim();
      if (tag.startsWith('/')) {
        i = gt + 1;
        continue;
      }
      final name = tag.split(RegExp(r'[\s/]')).first.toLowerCase();

      if (name == 'img') {
        final src = _attr(tag, 'src');
        if (src.isNotEmpty) {
          final w = int.tryParse(_attr(tag, 'width')) ?? 0;
          final emoji = w > 0 && w < 120;
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: CachedImage(
                _absolute(src),
                height: emoji ? 22 : 90,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ));
        }
        i = gt + 1;
        continue;
      }

      final close = s.indexOf('</$name>', gt);
      if (close < 0) {
        i = gt + 1;
        continue;
      }
      final inner = s.substring(gt + 1, close);
      final next = st.apply(name, tag, this);
      spans.addAll(_parseInline(inner, next));
      i = close + name.length + 3;
    }
    return spans;
  }

  void _addText(List<InlineSpan> out, String raw, _Sty st) {
    final text = _decode(raw);
    if (text.isEmpty) return;
    final re = RegExp(r'>>No\.(\d+)');
    int i = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > i) {
        out.add(TextSpan(text: text.substring(i, m.start), style: st.style));
      }
      final id = int.tryParse(m.group(1) ?? '');
      final primary = st.scheme.primary;
      out.add(TextSpan(
        text: m.group(0),
        style: st.style.copyWith(
          color: primary,
          backgroundColor: primary.withOpacity(0.10),
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            if (id != null) onQuote?.call(id);
          },
      ));
      i = m.end;
    }
    if (i < text.length) {
      out.add(TextSpan(text: text.substring(i), style: st.style));
    }
  }

  static String _attr(String tag, String name) {
    final m = RegExp('$name\\s*=\\s*["\']([^"\']*)["\']', caseSensitive: false)
        .firstMatch(tag);
    return m?.group(1) ?? '';
  }

  static const Map<String, String> _entities = <String, String>{
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&bull;': '·',
    '&middot;': '·',
    '&hellip;': '…',
    '&mdash;': '—',
    '&ndash;': '–',
    '&laquo;': '«',
    '&raquo;': '»',
    '&times;': '×',
  };

  static String _decode(String s) {
    var out = s;
    _entities.forEach((k, v) => out = out.replaceAll(k, v));
    out = out.replaceAllMapped(RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.tryParse(m.group(1)!) ?? 32));
    // 去掉控制字符与零宽字符
    return out.replaceAll(RegExp(r'[\u200b-\u200d\ufeff]'), '');
  }

  static String _absolute(String src) {
    if (src.startsWith('http')) return src;
    if (src.startsWith('//')) return 'https:$src';
    if (src.startsWith('/')) return '${Api.webBase}$src';
    return src;
  }
}

class _Sty {
  _Sty({
    required this.fontSize,
    required this.scheme,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color,
    this.href,
  });

  final double fontSize;
  final ColorScheme scheme;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final Color? color;
  final String? href;

  TextStyle get style => TextStyle(
        fontSize: fontSize,
        height: 1.8,
        color: color ?? const Color(0xFF22252E),
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        fontStyle: italic ? FontStyle.italic : null,
        decoration: (underline || strike)
            ? TextDecoration.combine(<TextDecoration>[
                if (underline) TextDecoration.underline,
                if (strike) TextDecoration.lineThrough,
              ])
            : null,
        decorationColor: href != null ? scheme.primary : null,
      );

  _Sty apply(String name, String tag, RichContent host) {
    switch (name) {
      case 'b':
      case 'strong':
        return _copy(bold: true);
      case 'i':
      case 'em':
        return _copy(italic: true);
      case 'u':
        return _copy(underline: true);
      case 'del':
      case 's':
        return _copy(strike: true);
      case 'h1':
      case 'h2':
      case 'h3':
        return _copy(bold: true);
      case 'a':
        return _copy(
          underline: true,
          color: scheme.primary,
          href: RichContent._attr(tag, 'href'),
        );
      case 'font':
        final c = RichContent._attr(tag, 'color');
        if (c.startsWith('#') && (c.length == 7 || c.length == 4)) {
          return _copy(color: _parseHex(c));
        }
        return this;
      default:
        return this;
    }
  }

  _Sty _copy({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    Color? color,
    String? href,
  }) {
    return _Sty(
      fontSize: fontSize,
      scheme: scheme,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
      color: color ?? this.color,
      href: href ?? this.href,
    );
  }

  static Color _parseHex(String hex) {
    var h = hex.substring(1);
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    final v = int.tryParse(h, radix: 16) ?? 0x22252E;
    return Color(0xFF000000 | v);
  }
}

/// 加载骨架，带轻微呼吸感。
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 96, this.count = 3});

  final double height;
  final int count;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        widget.count,
        (i) => FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 0.9).animate(_c),
          child: Container(
            height: widget.height,
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kOutline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                    width: 120, height: 10, color: kChip),
                const SizedBox(height: 12),
                Container(
                    width: double.infinity,
                    height: 12,
                    color: kChip),
                const SizedBox(height: 8),
                Container(
                    width: 200, height: 12, color: kChip),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String prettyTime(String now) {
  final m = RegExp(r'\d{4}-(\d{2})-(\d{2})\(.+?\)(\d{2}):(\d{2})').firstMatch(now);
  if (m == null) return now;
  return '${m.group(1)}-${m.group(2)} ${m.group(3)}:${m.group(4)}';
}

String _plain(String html) {
  var s = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
