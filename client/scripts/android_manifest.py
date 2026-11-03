#!/usr/bin/env python3
"""给 Flutter 生成的 Android 清单补上 INTERNET 权限。

背景
----
Flutter 3.24 的工程模板把 `android.permission.INTERNET` 只写在
`android/app/src/debug/AndroidManifest.xml` 里（模板注释写得很清楚：给 hot reload
和断点调试用），主清单 `src/main/AndroidManifest.xml` 里没有这一条。

后果是：debug 包联网正常，**release 包完全不能联网**。所有请求在建立连接阶段就抛
SocketException，界面上表现为「网络错误」，看起来和「服务器挂了」一模一样。
本项目此前一直是靠 CI 生成平台目录再打 release 包，所以这个问题被站点 502 掩盖了
很久——站点恢复后才发现「APP 没法用」。

因为 android/ 目录不入库（由 `flutter create` 现场生成），修复只能落在 CI 上：

    python3 scripts/android_manifest.py patch                 # 注入权限
    python3 scripts/android_manifest.py verify <apk 路径>      # 校验产物里真有

verify 直接读 APK 里编译后的二进制 `AndroidManifest.xml`，字符串常量以 UTF-8 或
UTF-16LE 存在字符串池里，两种都查，避免误判。
"""

from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path

MANIFEST = Path("android/app/src/main/AndroidManifest.xml")
PERMISSION = "android.permission.INTERNET"
PERMISSION_TAG = f'    <uses-permission android:name="{PERMISSION}"/>\n'


def patch() -> int:
    if not MANIFEST.exists():
        print(f"找不到 {MANIFEST}，先跑 flutter create", file=sys.stderr)
        return 1

    src = MANIFEST.read_text(encoding="utf-8")
    if PERMISSION in src:
        print(f"{PERMISSION} 已存在，跳过")
        return 0

    m = re.search(r"<manifest\b[^>]*>", src)
    if not m:
        print("清单里没有 <manifest> 标签，结构异常", file=sys.stderr)
        return 1

    fixed = src[: m.end()] + "\n" + PERMISSION_TAG + src[m.end():]
    MANIFEST.write_text(fixed, encoding="utf-8")

    if PERMISSION not in MANIFEST.read_text(encoding="utf-8"):
        print("写入后仍然找不到权限，失败", file=sys.stderr)
        return 1
    print(f"已注入 {PERMISSION}")
    return 0


def verify(apk: str) -> int:
    path = Path(apk)
    if not path.exists():
        print(f"找不到 APK：{apk}", file=sys.stderr)
        return 1

    with zipfile.ZipFile(path) as z:
        try:
            blob = z.read("AndroidManifest.xml")
        except KeyError:
            print("APK 里没有 AndroidManifest.xml", file=sys.stderr)
            return 1

    hit = (
        PERMISSION.encode("utf-8") in blob
        or PERMISSION.encode("utf-16-le") in blob
    )
    if not hit:
        print(
            f"✗ {path.name} 缺少 {PERMISSION}：这个包装到手机上会完全无法联网",
            file=sys.stderr,
        )
        return 1

    print(f"✓ {path.name} 含 {PERMISSION}")
    return 0


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in ("patch", "verify"):
        print(__doc__)
        return 2
    if sys.argv[1] == "patch":
        return patch()
    if len(sys.argv) < 3:
        print("用法：android_manifest.py verify <apk>", file=sys.stderr)
        return 2
    return verify(sys.argv[2])


if __name__ == "__main__":
    sys.exit(main())
