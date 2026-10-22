#!/usr/bin/env python3
"""把 release 签名接进 flutter create 生成的 android/app/build.gradle。

flutter create 每个版本产出的模板可能不同，所以这里不整份替换，
只做三处增量修改，且幂等（已改过就直接退出）：

  1. 在 android { 之前插入 key.properties 的读取逻辑；
  2. 在 android { 之后插入 signingConfigs.release；
  3. 把 release 构建里的 signingConfig signingConfigs.debug 换成 release。

在 CI 里只有配置了 KEYSTORE_BASE64 才会执行。
"""
from __future__ import annotations

import pathlib
import sys

LOADER = """
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
"""

SIGNING = """
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
"""


def main() -> int:
    gradle = pathlib.Path("android/app/build.gradle")
    if not gradle.exists():
        gradle = pathlib.Path("android/app/build.gradle.kts")
        if gradle.exists():
            print("检测到 Kotlin DSL（build.gradle.kts），本脚本只处理 Groovy 模板。")
            print("请手动把 signingConfigs 配进 android/app/build.gradle.kts。")
            return 0
        print("找不到 android/app/build.gradle，先跑一次 flutter create。")
        return 1

    text = gradle.read_text(encoding="utf-8")

    if "keystoreProperties" in text:
        print("已经配置过签名，跳过。")
        return 0

    if "\nandroid {" not in text:
        print("没找到 android { 块，模板结构与预期不符，放弃修改。")
        return 1

    text = text.replace("\nandroid {", LOADER + "\nandroid {", 1)
    text = text.replace("\nandroid {", "\nandroid {" + SIGNING, 1)

    if "signingConfig signingConfigs.debug" in text:
        text = text.replace(
            "signingConfig signingConfigs.debug",
            "signingConfig signingConfigs.release",
        )
    else:
        print("警告：没找到 debug 签名占位，可能模板已变，release 仍会用调试签名。")

    gradle.write_text(text, encoding="utf-8")
    print("已写入 release 签名配置：", gradle)
    return 0


if __name__ == "__main__":
    sys.exit(main())
