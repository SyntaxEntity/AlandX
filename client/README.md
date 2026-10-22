# X岛客户端（Flutter）

X岛匿名揭示板的第三方客户端，视觉语言参考 FlClash：Material 3 + 动态种子色 + 大圆角卡片 + 悬浮导航。

> **非官方**。接口无文档承诺，随时可能变更；本项目仅供个人使用与学习，不提供登录自动化、不抓取未授权内容。

## 当前状态

| 模块 | 状态 |
|---|---|
| 时间线 / 版面 / 串详情 | 已实现（20 条/页、引用跳转、只看 PO、图片查看） |
| 饼干管理 | 已实现（导入 / 切换 / 删除 / 校验，仅存本机） |
| 发串 / 回复 | 已实现（纯文本 + 图片，图片压到 1600px / 88%，上限 4MB） |
| 搜索 | 已实现（网页表单 + `__hash__`，解析 HTML；未登录可能拿不到结果） |
| 缓存 | 已实现（持久化 JSON：列表 90s、串 10min、版面 12h；5xx 时用旧缓存兜底并提示） |
| 订阅 | 已实现（UUID 机制，与服务端账号无关） |
| 外观 | 已实现（6 个种子色、深浅色跟随系统） |
| 平台 | Android / iOS / Desktop；**不支持 Web**（接口无 CORS） |

✅ **已在 CI 上真实构建通过**（2026-10-22，run `39744311614`，Flutter 3.24.5 / ubuntu-latest）：

| job | 结果 | 产物 |
|---|---|---|
| `analyze` | success | — |
| `android arm64-v8a` | success | `app-arm64-v8a-release.apk`（8.0 MB） |
| `linux x86_64` | success | `bundle/`（9.3 MB） |

产物在对应 run 的 Artifacts 里，GitHub 保留 90 天。

开发机是 aarch64，而官方只发 x64 的 Linux SDK，本地跑不起来——所以本地只能做静态检查，真实构建交给 CI。这也意味着**任何改动都要先推上去看 CI 结果**，不能只靠本机 `dart analyze`。

## 运行

```bash
# 1. 补齐平台目录（仓库里只有 lib/ 与 pubspec.yaml）
flutter create --platforms=android,ios,linux,macos,windows .

# 2. 拉依赖
flutter pub get

# 3. 跑起来
flutter run -d <device>
```

要求 Flutter **3.22 及以上**（用到 `surfaceContainer` 之前的稳定 API 与 M3 默认值），推荐 3.24 系列。

图片上传用 `image_picker`：Android 走系统相册选择器（13+ 无需权限），iOS 需要往 `ios/Runner/Info.plist` 加一条：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>选择图片用于发串或回复</string>
```

### 构建矩阵（重要）

| 目标 | 能否产出 | 怎么出 |
|---|---|---|
| Android arm64-v8a | ✅ | x64 机器或 CI：`flutter build apk --release --target-platform android-arm64 --split-per-abi` |
| Linux x86_64 | ✅ | Ubuntu：`flutter build linux --release` |
| Linux arm64 | ❌ | 官方只发 x64 的 Linux SDK，没有 arm64 版本；本机是 aarch64 也跑不了这个 SDK |

仓库根目录的 `.github/workflows/build.yml` 会并行跑 **analyze + Android arm64 + Linux x64**，
产物直接在 Actions 里下载。这是 ARM 设备上最省事的路径。

如果一定要 Linux arm64 桌面端，只剩两条非官方路：社区编译的 arm64 Flutter SDK，或 Sony 的 `flutter-elinux`（嵌入式 Linux，不是标准 desktop embedding）。两者都要自己维护工具链，不建议。

### 在 UOS / ARM 上怎么办

Flutter 官方 Linux 归档**只有 x64**（`flutter_linux_<version>-stable.tar.xz`），没有 arm64 版本；SDK 本身是免安装的压缩包，解压即用，但跑不了 ARM 主机。

所以 UOS ARM 有三条路：

1. **在 x64 机器或 CI 上构建 Android APK**（推荐）——Flutter 交叉打 APK 与主机架构无关，产物直接装到 ARM 设备。
2. 用社区维护的 arm64 Linux 构建（非官方，升级容易踩坑）。
3. 只做 Android 端，桌面端放弃。

另外 UOS 的 glibc 一般够用（Flutter 要求 2.23+），真正的门槛是架构，不是发行版。

如果 `flutter create` 生成了 `test/widget_test.dart` 并引用不存在的 `MyApp`，直接删掉该文件即可。

## 结构

```
lib/
├── main.dart              应用外壳、主题、侧栏/底栏导航
├── models.dart            Post / Forum / TimelineLine / Source
├── api.dart               接口封装：读、发串、回复、订阅、搜索、饼干校验
├── cache.dart             持久化 JSON 缓存（SharedPreferences）
├── cookies.dart           饼干仓库（SharedPreferences）
├── picker.dart            选图与压缩
├── state.dart             全局状态：主题、当前来源、时间线分页
├── widgets.dart           卡片、头像、正文 HTML 渲染、骨架屏
└── pages/
    ├── home_page.dart     时间线（Hero + 圆环刷新 + 列表）
    ├── forums_page.dart   版面（分类 + 网格）
    ├── thread_page.dart   串详情（PO / 引用 / 回复 / 图片）
    ├── compose_page.dart  发新串（含图片）
    ├── search_page.dart   搜索（网页表单解析）
    ├── feeds_page.dart    订阅 + 饼干管理
    └── settings_page.dart 接口、主题、缓存、关于
```

## 几个必须知道的实现细节

1. **正文是 HTML 片段**，不是纯文本。`widgets.dart` 里的 `RichContent` 只认 `br / a / img / ul / li / b / i / u / del` 这些标签，引用格式是纯文本 `>>No.123`，点它会跳到对应楼层。
2. **数字字段可能是字符串**。`getForumList` 与 `feed` 的数字全是 string，统一走 `asInt()` 解析，别直接 `as int`。
3. **分页语义**：串列表 20 条/页；串内回复 20 条/页，但首屏只返回前 5 条 + `RemainReplies`。
4. **写操作没有结构化返回**：发串/回复返回的是「跳转提示」HTML，只能靠文案判断成功与否，见 `api.dart` 的 `_parseJump`。
5. **饼干 = 身份**。Cookie 键名固定 `userhash`；缺失时受限版面返回 `{"success":false,"error":"必须登入领取饼干后才可以访问"}`。饼干存在 SharedPreferences 明文里，介意的话换成 `flutter_secure_storage`。
6. **域名会漂**。主站已从 `nmbxd.com` 迁到 `www.nmbxd1.com`；接口在 `api.nmb.best`。改地址只需要动 `lib/api.dart` 顶部三个常量。

## 未做

- 推送（接口没有，只能前台轮询 `/feed?uuid=`）
- 图片缓存（只缓存 JSON；图片走 Flutter 默认内存缓存，重进页面会重新下载）
- 楼层定位（点 `>>No.` 打开的是串，不会滚到对应楼层）

## 许可

仅供学习交流。内容版权归 X岛及其用户所有。
