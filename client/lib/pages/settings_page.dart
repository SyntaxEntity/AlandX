import 'package:flutter/material.dart';

import '../api.dart';
import '../cache.dart';
import '../state.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppState _state = AppState.instance;

  static const List<Color> _seeds = <Color>[
    Color(0xFF3D5BFE),
    Color(0xFF0E9F8A),
    Color(0xFFC2410C),
    Color(0xFF7C3AED),
    Color(0xFF0F766E),
    Color(0xFFBE123C),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 980;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 26, wide ? 32 : 16, 90),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('设置',
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: kInk)),
                    const SizedBox(height: 5),
                    const Text('接口、外观与缓存',
                        style: TextStyle(fontSize: 12.5, color: kInk2)),
                    const SizedBox(height: 18),
                    _apiCard(),
                    const SizedBox(height: 14),
                    _themeCard(),
                    const SizedBox(height: 14),
                    _cacheCard(),
                    const SizedBox(height: 14),
                    _aboutCard(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _apiCard() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Expanded(
                child: Text('接口',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text('直连',
                  style: TextStyle(fontSize: 11, color: kInk3)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const SizedBox(
                width: 88,
                child: Text('API 基址',
                    style: TextStyle(fontSize: 12.5, color: kInk2)),
              ),
              Expanded(
                child: SelectableText(
                  Api.apiBase,
                  style: const TextStyle(
                      fontSize: 12, fontFamily: 'monospace', color: kInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const SizedBox(
                width: 88,
                child: Text('主站',
                    style: TextStyle(fontSize: 12.5, color: kInk2)),
              ),
              Expanded(
                child: SelectableText(
                  Api.webBase,
                  style: const TextStyle(
                      fontSize: 12, fontFamily: 'monospace', color: kInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '主站域名会漂移（nmbxd.com 已 301 到 www.nmbxd1.com）。'
            '若某天接口整体失效，优先检查这里，再改 lib/api.dart 的 apiBase。',
            style: TextStyle(fontSize: 12, height: 1.7, color: kInk2),
          ),
        ],
      ),
    );
  }

  Widget _themeCard() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Expanded(
                child: Text('主题',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text('Material 3 · 种子色',
                  style: TextStyle(fontSize: 11, color: kInk3)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '一个种子色生成整套配色，和 FlClash 的做法一致。',
            style: TextStyle(fontSize: 12.5, height: 1.7, color: kInk2),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _seeds.map((c) {
              final active = _state.seed.value == c.value;
              return GestureDetector(
                onTap: () => _state.setSeed(c),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: active ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: c.withOpacity(active ? 0.45 : 0.18),
                        blurRadius: active ? 16 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: active
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 22)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _cacheCard() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Expanded(
                child: Text('缓存',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text('持久化',
                  style: TextStyle(fontSize: 11, color: kInk3)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const SizedBox(
                width: 88,
                child: Text('最近耗时',
                    style: TextStyle(fontSize: 12.5, color: kInk2)),
              ),
              Text(
                _state.upstreamMs == 0 ? '—' : '${_state.upstreamMs} ms',
                style: const TextStyle(fontSize: 12.5, color: kInk),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              const SizedBox(
                width: 88,
                child: Text('缓存条目',
                    style: TextStyle(fontSize: 12.5, color: kInk2)),
              ),
              Text('${CacheStore.instance.count} 条',
                  style: const TextStyle(fontSize: 12.5, color: kInk)),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _state.clearCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清空')),
              );
            },
            child: const Text('清空接口缓存'),
          ),
          const SizedBox(height: 8),
          const Text(
            '列表缓存 90 秒、串 10 分钟、版面 12 小时；网络失败时会用过期缓存兜底，并在列表上方标注。',
            style: TextStyle(fontSize: 12, height: 1.7, color: kInk2),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          Text('关于',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text('X岛客户端 0.1.0 · 非官方',
              style: TextStyle(fontSize: 12.5, color: kInk2)),
          SizedBox(height: 10),
          Text(
            '• 接口非官方、无文档承诺，随时可能失效\n'
            '• 饼干只存本机，不上传任何服务器\n'
            '• 不提供登录自动化，不抓取未授权内容\n'
            '• 内容来自 X岛 用户，客户端不承担审核义务',
            style: TextStyle(fontSize: 12, height: 2, color: kInk2),
          ),
        ],
      ),
    );
  }
}
