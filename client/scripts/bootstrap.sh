#!/usr/bin/env bash
# 补齐平台目录并拉依赖。
# 仓库里只有 lib/ 与 pubspec.yaml，platform 目录由 `flutter create` 生成。
set -euo pipefail
cd "$(dirname "$0")/.."

flutter --version
flutter create --platforms=android,linux,macos,windows,ios .
flutter pub get

cat <<'TIP'

完成。常用命令：
  flutter run -d linux
  flutter build linux --release
  flutter build apk --release --target-platform android-arm64 --split-per-abi

注意：Flutter 官方没有 arm64 的 Linux SDK，Linux arm64 桌面端无法用官方工具链构建。
TIP
