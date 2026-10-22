# X岛客户端

X岛匿名揭示板的第三方 Flutter 客户端，视觉语言参考 [FlClash](https://github.com/chen08209/FlClash)：Material 3、动态种子色、大圆角卡片、悬浮导航。

> 非官方项目。接口无文档承诺，随时可能变更；仅供个人使用与学习。

## 功能

- 时间线 / 版面 / 串详情：引用跳转、只看 PO、图片查看、触底加载
- 饼干（身份）管理：导入、切换、删除、有效性校验，只存本机
- 发串 / 回复：支持图片（自动压到 1600px / 88%，上限 4MB）
- 搜索：走网页表单（`__hash__` + POST + HTML 解析），未登录可能拿不到结果
- 持久缓存：列表 90s / 串 10min / 版面 12h；站点 5xx 时回退旧缓存并提示
- 订阅：UUID 机制，与服务端账号无关

## 下载

[**Releases**](https://github.com/SyntaxEntity/AlandX/releases) 提供预编译包，无需登录即可下载：

| 平台 | 文件 |
|---|---|
| Android arm64-v8a | `app-arm64-v8a-release.apk` |
| Linux x86_64 | `xd-client-linux-x64.zip` |

推送 `v*` 标签会自动构建并发布：

```bash
git tag v0.1.0
git push origin v0.1.0
```

日常提交只跑 CI 校验，产物在对应 run 的 Artifacts 里（需登录，保留 90 天）。

## 仓库结构

```
client/            Flutter 工程（仓库里只有源码，平台目录由 flutter create 生成）
preview.html       单文件静态设计预览，双击即看
docs/              开发状态与路线图
.github/workflows  build：analyze + Android arm64 + Linux x64
                   release：推送 v* 标签时出包并发布
```

## 构建

```bash
cd client
bash scripts/bootstrap.sh          # 补平台目录 + pub get
flutter run -d linux
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

也可以直接推到 GitHub 让 CI 出包，见上方「[下载](#下载)」。

### 目标支持

| 目标 | 状态 |
|---|---|
| Android arm64-v8a | ✅ |
| Linux x86_64 | ✅ |
| Linux arm64 | ❌ Flutter 官方不提供 arm64 的 Linux SDK |

## 许可

本项目以 **GNU General Public License v3.0** 分发，全文见 [LICENSE](LICENSE)。

原因：悬浮底栏（`client/lib/flclash/`）移植自 [FlClash](https://github.com/chen08209/FlClash)，
该项目以 GPL-3.0 发布。GPL 具有传染性，因此整个项目一并以 GPL-3.0 开源。
`client/lib/flclash/` 下文件保留原版权声明，改动集中在 `compat.dart`（图标类型与
Liquid Glass 依赖的兼容层）。

## 声明

内容版权归 X岛及其用户所有。本项目不提供登录自动化、不抓取未授权内容、不做公开镜像。
