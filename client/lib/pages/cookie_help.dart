import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets.dart';

/// 「如何获取饼干」教程。
///
/// 饼干（cookie 里的 `userhash`）是 X岛的身份凭证：没有它也能读大部分版面，
/// 但受限版面、发串、回复都不行。这里把获取步骤写清楚，省得用户到处找。
class CookieHelpPage extends StatelessWidget {
  const CookieHelpPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const CookieHelpPage());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('如何获取饼干',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          _lead(context),
          const SizedBox(height: 14),
          _step(
            context,
            index: 1,
            title: '用浏览器打开 X岛',
            body: '在手机或电脑的浏览器里访问 www.nmbxd1.com。'
                'X岛没有账号体系，进站就会自动给你发一块饼干。',
          ),
          _step(
            context,
            index: 2,
            title: '打开开发者工具',
            body: '电脑端按 F12，切到「应用 / Application」→「存储 / Storage」→「Cookie」。'
                '手机端可以用支持开发者工具的浏览器（如 Kiwi、Edge Canary）。',
          ),
          _step(
            context,
            index: 3,
            title: '找到 userhash',
            body: '在 Cookie 列表里找到名为 userhash 的一项，'
                '复制它的值——一串十六进制字符，通常 20～30 位。',
            code: true,
          ),
          _step(
            context,
            index: 4,
            title: '回到本应用粘贴',
            body: '打开「订阅」页 →「导入饼干」，把刚才那段值粘进去，点「保存并校验」。'
                '校验通过后会显示「饼干有效」。',
          ),
          _step(
            context,
            index: 5,
            title: '可以存多块',
            body: '每块饼干是一个独立身份。粘贴时还能顺便起个名字，'
                '方便在多个身份之间切换。',
          ),
          const SizedBox(height: 18),
          _warning(context, scheme),
          const SizedBox(height: 14),
          _faq(context, scheme),
        ],
      ),
    );
  }

  Widget _lead(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.cookie_outlined,
                  size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text('饼干是什么',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '饼干是 X岛发给你的一块身份凭证。没有它你也能浏览大部分版面，'
            '但受限版面打不开、也不能发串和回复。它只保存在这台设备上，不会上传到任何服务器。',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context, {
    required int index,
    required String title,
    required String body,
    bool code = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                if (code)
                  _codeLine(context, 'userhash=样例值…', scheme)
                else
                  const SizedBox.shrink(),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.62,
                    color: kInk2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeLine(BuildContext context, String text, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已复制示例')),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: kChip,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: kInk2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _warning(BuildContext context, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.shield_outlined, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '饼干等同于你的身份，拿到它的人就能以你的名义发言。'
              '不要发到群里、不要贴进截图、不要提交到代码仓库。'
              '怀疑泄露就去网页端重新领一块，旧的会失效。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faq(BuildContext context, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kChip,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('常见问题',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _qa('粘贴后提示「没能识别这段饼干」',
              '确认粘的是 userhash 的「值」，不带 userhash= 前缀也可以，但不能把整行 Cookie 全贴进来。'),
          _qa('提示「饼干无效」',
              '可能已经在网页端失效了，回浏览器重新取一次。'),
          _qa('换设备会同步吗',
              '不会。饼干只存在本机，换设备需要重新导入。'),
        ],
      ),
    );
  }

  Widget _qa(String q, String a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(q,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w500, color: kInk)),
          const SizedBox(height: 2),
          Text(a, style: TextStyle(fontSize: 12.5, height: 1.55, color: kInk2)),
        ],
      ),
    );
  }
}
