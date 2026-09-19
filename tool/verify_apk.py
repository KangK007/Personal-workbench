"""验证 APK 内是否真的打包了「柔壤 · 年轮」这一轮改动。

探针选择依据：Dart kernel（debug 产物）会保留标识符名称，因此
**上一轮重命名/新增的符号**可作为"该改动是否已进入本次构建"的可靠证据。
（不要用 `Color(0xFF...)` 字面量的字节搜索：Dart kernel 的整型常量
是变长编码，不是 4 字节大端，正负对照会一起失效而给出假结论。）
"""
from __future__ import annotations

import os
import zipfile

APK = r"D:\Project\个人工作台\dist\apk\PersonalWorkbench_0.1.0_4_debug-arm64-v8a.apk"

# 本轮（2026-09-18 界面优化）引入 / 移除的符号
SHOULD_EXIST = {
    "VineRail": "LogRail → VineRail 重命名（组件层）",
    "VineRailState": "VineRail 状态枚举",
    "VineBud": "芽点四态绘制件",
    "rsipNodeTypeColor": "8 类节点配色纯函数",
    "bottomNavClearance": "移动端底部导航净空令牌",
}
SHOULD_BE_GONE = {
    "LogRail": "上一轮已被重命名移除",
    "LogRailState": "上一轮已被重命名移除",
}

if not os.path.exists(APK):
    raise SystemExit(f"APK 不存在: {APK}")
print(f"APK: {os.path.basename(APK)}  ({os.path.getsize(APK):,} 字节)\n")

with zipfile.ZipFile(APK) as zf:
    targets = [n for n in zf.namelist() if n.endswith("kernel_blob.bin")]
    if not targets:
        raise SystemExit("APK 内未找到 kernel_blob.bin")
    blob = zf.read(targets[0])

print(f"kernel_blob.bin: {targets[0]}  ({len(blob):,} 字节)\n")

ok_present = 0
print("== 本轮新增/重命名的符号（应存在）==")
for sym, why in SHOULD_EXIST.items():
    hit = blob.count(sym.encode())
    print(f"  {'OK  ' if hit else 'MISS'} {sym:<20} 命中 {hit:<4} ({why})")
    ok_present += 1 if hit else 0

ok_gone = 0
print("\n== 已被移除的旧符号（应消失）==")
for sym, why in SHOULD_BE_GONE.items():
    hit = blob.count(sym.encode())
    print(f"  {'OK  ' if not hit else 'BLEED'} {sym:<20} 命中 {hit:<4} ({why})")
    ok_gone += 1 if not hit else 0

total = len(SHOULD_EXIST) + len(SHOULD_BE_GONE)
passed = ok_present + ok_gone
print(f"\n小结：{passed}/{total} 项符合预期")
print("结论：" + (
    "APK 确认包含 2026-09-18 的界面优化改动（新符号已入包，旧符号已清除）"
    if passed == total
    else "存在异常，需复查"
))
