import 'package:flutter/material.dart';

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
          padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 26, wide ? 32 : 16,
              NavigationDock.insetOf(context)),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('设置',
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: kInk)),
                    SizedBox(height: 5),
                    Text('外观与缓存',
                        style: TextStyle(fontSize: 12.5, color: kInk2)),
                    const SizedBox(height: 18),
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

  Widget _themeCard() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('主题',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text('主题色',
                  style: TextStyle(fontSize: 11, color: kInk3)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '挑一个喜欢的颜色，界面会跟着变。',
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
          Row(
            children: <Widget>[
              Expanded(
                child: Text('缓存',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: <Widget>[
              SizedBox(
                width: 88,
                child: Text('已缓存',
                    style: TextStyle(fontSize: 12.5, color: kInk2)),
              ),
              Text('${CacheStore.instance.count} 条',
                  style: TextStyle(fontSize: 12.5, color: kInk)),
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
            child: Text('清空缓存'),
          ),
          SizedBox(height: 8),
          Text(
            '网络不好时会先显示上次的内容，并在列表上方标出来。',
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
        children: <Widget>[
          Text('关于',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text('X岛客户端 · 非官方',
              style: TextStyle(fontSize: 12.5, color: kInk2)),
          SizedBox(height: 10),
          Text(
            '• 非官方客户端，与 X岛 官方无关\n'
            '• 内容来自 X岛 用户，请遵守站点规则\n'
            '• 饼干只存在本机，不会上传到任何地方',
            style: TextStyle(fontSize: 12, height: 2, color: kInk2),
          ),
        ],
      ),
    );
  }
}
