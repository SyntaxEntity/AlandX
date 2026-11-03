import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api.dart';
import '../cookies.dart';
import '../theme.dart';
import '../widgets.dart';

/// 一键领取饼干。
///
/// 饼干（userhash）没有 JSON 接口可领，只能走网页用户中心，而用户中心要登录。
/// 这里把「取验证码 → 提交登录 → 拿 Set-Cookie 里的 userhash」整条流程收进 App，
/// 用户只要填一次账号密码加验证码，不用再去浏览器开 F12 抄 cookie。
///
/// 密码只在内存里用来提交这一次登录，**不落盘、不上传**。
class CookieClaimPage extends StatefulWidget {
  const CookieClaimPage({super.key});

  static Route<bool> route() =>
      MaterialPageRoute<bool>(builder: (_) => const CookieClaimPage());

  @override
  State<CookieClaimPage> createState() => _CookieClaimPageState();
}

class _CookieClaimPageState extends State<CookieClaimPage> {
  final Api _api = Api.instance;
  final CookieStore _cookies = CookieStore.instance;

  final TextEditingController _email = TextEditingController();
  final TextEditingController _pwd = TextEditingController();
  final TextEditingController _code = TextEditingController();

  CookieClaim? _claim;
  Uint8List? _captcha;
  bool _busy = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final claim = await _api.beginCookieClaim();
      final img = await _api.fetchCaptcha(claim);
      if (!mounted) return;
      setState(() {
        _claim = claim;
        _captcha = img;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 换一张验证码：会话和 __hash__ 都不用换，只重新拉图。
  Future<void> _reloadCaptcha() async {
    final claim = _claim;
    if (claim == null) return _boot();
    try {
      final img = await _api.fetchCaptcha(claim);
      if (!mounted) return;
      setState(() {
        _captcha = img;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    final claim = _claim;
    if (claim == null || _submitting) return;
    final email = _email.text.trim();
    final pwd = _pwd.text;
    final code = _code.text.trim();
    if (email.isEmpty || pwd.isEmpty || code.isEmpty) {
      setState(() => _error = '邮箱、密码、验证码都要填');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final hash = await _api.loginForCookie(
        claim,
        email: email,
        password: pwd,
        verify: code,
      );
      // 名字用邮箱前缀，日后在饼干列表里一眼认得出是哪个账号。
      final label = email.split('@').first;
      final b = await _cookies.add('userhash=$hash', _newId(), name: label);
      final r = await _cookies.verify(b.id);
      if (!mounted) return;
      Navigator.of(context).pop<bool>(r.ok);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
      // 多半是验证码错了，直接给一张新的，省得用户自己点。
      await _reloadCaptcha();
      _code.clear();
    }
  }

  String _newId() =>
      'c${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('一键领取饼干',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '用你的 X岛账号登录，App 会自动把服务端发下来的饼干存好，'
                  '不需要再去浏览器复制。密码只用于这一次登录，不保存。',
                  style: TextStyle(fontSize: 12.5, height: 1.7, color: kInk2),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '邮箱',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pwd,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _code,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: '验证码',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _captchaBox(),
                  ],
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(fontSize: 12.5, color: kInk3)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? '正在领取…' : '领取并保存'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionTitle('说明'),
          const SizedBox(height: 8),
          Text(
            '· 领取后饼干只保存在本机（SharedPreferences），不会上传任何地方。\n'
            '· 没有账号的话，仍可回到「导入饼干」用网页端复制的内容。\n'
            '· 若站点校验严格到必须人工确认，这里会给出失败原因。',
            style: TextStyle(fontSize: 12.5, height: 1.9, color: kInk2),
          ),
        ],
      ),
    );
  }

  Widget _captchaBox() {
    final img = _captcha;
    return Semantics(
      label: '验证码，点按换一张',
      child: GestureDetector(
        onTap: _busy ? null : _reloadCaptcha,
        child: Container(
          width: 122,
          height: 56,
          decoration: BoxDecoration(
            color: kChip,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kOutline),
          ),
          clipBehavior: Clip.antiAlias,
          child: _busy
              ? const Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : img == null
                  ? const Center(
                      child: Text('换一张',
                          style: TextStyle(fontSize: 12, color: Colors.grey)))
                  : Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      ),
    );
  }
}
