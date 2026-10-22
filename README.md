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

## 仓库结构

```
client/            Flutter 工程（仓库里只有源码，平台目录由 flutter create 生成）
preview.html       单文件静态设计预览，双击即看
.github/workflows  CI：analyze + Android arm64 + Linux x64
```

## 构建

```bash
cd client
bash scripts/bootstrap.sh          # 补平台目录 + pub get
flutter run -d linux
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

也可以直接推到 GitHub 让 Actions 出包，产物在对应 workflow run 的 Artifacts 里。

### 目标支持

| 目标 | 状态 |
|---|---|
| Android arm64-v8a | ✅ |
| Linux x86_64 | ✅ |
| Linux arm64 | ❌ Flutter 官方不提供 arm64 的 Linux SDK |

## 声明

内容版权归 X岛及其用户所有。本项目不提供登录自动化、不抓取未授权内容、不做公开镜像。
