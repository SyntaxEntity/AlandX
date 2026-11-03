#!/usr/bin/env python3
"""把「读取屏幕圆角半径」的原生代码注入 flutter create 生成出来的 MainActivity。

背景
----
Flutter 没有暴露设备屏幕圆角半径，Android 12（API 31）以上才有
`WindowInsets.getRoundedCorner()`。而本仓库的 android/ 目录不入库，由 CI 里
`flutter create` 现场生成，所以只能在这里改写。

策略：整份重写 MainActivity.kt（模板里它只有一行 FlutterActivity 继承），
再挂一个 `xd/screen` 的 MethodChannel。Dart 侧拿不到会回退默认值，
所以**这个脚本失败也不该让构建失败**——所有异常都只打印警告并返回 0。

`getRoundedCorner(1)` 里的 1 是 `RoundedCornerPosition.TOP_LEFT`。四个角的半径
本来就是同一个值，所以写常量数字既不用赌 Kotlin 对嵌套类的解析，也不会取错。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

CHANNEL = "xd/screen"

TEMPLATE = """package {package}

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {{
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "{channel}")
            .setMethodCallHandler {{ call, result ->
                if (call.method == "cornerRadius") {{
                    result.success(cornerRadiusDp())
                }} else {{
                    result.notImplemented()
                }}
            }}
    }}

    /** 设备屏幕圆角半径，单位 dp；取不到返回 0，由 Dart 侧回退估算值。 */
    private fun cornerRadiusDp(): Double {{
        if (Build.VERSION.SDK_INT < 31) return 0.0
        try {{
            val density = resources.displayMetrics.density
            if (density <= 0f) return 0.0
            // 首选 decorView 的 insets，取不到再问 WindowManager（有些 ROM
            // 在 Activity 刚起来时不回填 rootWindowInsets）。
            var insets = window?.decorView?.rootWindowInsets
            if (insets == null) {{
                val wm = getSystemService(android.content.Context.WINDOW_SERVICE)
                    as? android.view.WindowManager
                insets = wm?.currentWindowMetrics?.windowInsets
            }}
            // 1 == WindowInsets.RoundedCornerPosition.TOP_LEFT，四角同值
            val corner = insets?.getRoundedCorner(1) ?: return 0.0
            return (corner.radius / density).toDouble()
        }} catch (e: Throwable) {{
            return 0.0
        }}
    }}
}}
"""


def main() -> int:
    root = Path("android/app/src/main")
    if not root.exists():
        print("没有 android/app/src/main，先跑 flutter create，跳过。")
        return 0

    candidates = sorted(root.glob("**/MainActivity.kt"))
    if not candidates:
        print("没找到 MainActivity.kt，跳过（桌面端不需要）。")
        return 0

    target = candidates[0]
    text = target.read_text(encoding="utf-8")

    if CHANNEL in text:
        print("已经注入过屏幕圆角通道，跳过。")
        return 0

    m = re.search(r"^package\s+([\w.]+)", text, re.MULTILINE)
    if not m:
        print("MainActivity.kt 里没有 package 声明，结构异常，跳过。")
        return 0

    if "FlutterActivity" not in text:
        print("MainActivity 不是 FlutterActivity 模板，跳过。")
        return 0

    target.write_text(
        TEMPLATE.format(package=m.group(1), channel=CHANNEL),
        encoding="utf-8",
    )
    print(f"已注入屏幕圆角通道：{target}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # 注入失败不能影响出包
        print("注入屏幕圆角通道失败（忽略）：", e)
        sys.exit(0)
