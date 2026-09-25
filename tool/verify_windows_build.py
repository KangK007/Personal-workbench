"""Windows 发行包内容探针 —— 与 verify_apk.py 同规格。

用途：确认 %LOCALAPPDATA%\\Programs\\PersonalWorkbench 下的已安装产物
确实来自当前源码树（而非某次陈旧构建），并核验三个快捷方式的指向。

判据：新增符号命中 > 0 且已删除符号命中 == 0（负对照必须为 0，否则方法失效）。
"""
from __future__ import annotations

import datetime
import os
import re
import subprocess
import sys

INSTALL_DIR = os.path.join(
    os.environ["LOCALAPPDATA"], "Programs", "PersonalWorkbench"
)

# (字节模式, 期望, 说明)
PROBES: list[tuple[bytes, str, str]] = [
    (b"VineRail", ">0", "VineRail（昨日重命名，新代码标志）"),
    (b"VineRailState", ">0", "VineRailState"),
    (b"rsipNodeTypeColor", ">0", "8 类节点配色纯函数"),
    (b"personal_workbench", ">0", "可执行文件名（正对照）"),
    (b"LogRail", "==0", "LogRail（已删除，负对照）"),
    (b"LogRailState", "==0", "LogRailState（已删除，负对照）"),
]

# Dart AOT 里 CJK 字面量存为 TwoByteString（UTF-16LE），不能按 UTF-8 搜。
CJK_PROBES: list[tuple[str, str, str]] = [
    ("全部任务", ">0", "导航节点：全部任务"),
    ("任务群", ">0", "导航节点：任务群"),
    ("个人工作台", ">0", "应用名（正对照）"),
]

# 说明：`bottomNavClearance` 这类被内联的 static const 取值不会保留符号名，
# 用它作探针会得到假阴性（实测 0 命中），故不作为判据。


def stamp(path: str) -> str:
    return datetime.datetime.fromtimestamp(os.stat(path).st_mtime).strftime(
        "%Y-%m-%d %H:%M:%S"
    )


def check_shortcut(path: str) -> list[str]:
    """解析 .lnk 原始字节，提取其中的可执行路径。

    注意：.lnk 里目标路径与工作目录是两条相邻字符串，若字符集允许 `:` 会被
    粘成一条假路径，故显式排除 `:`（路径段中本就不会出现）。
    """
    lines = [f"FILE   {os.path.basename(path)}"]
    if not os.path.exists(path):
        lines.append("   MISSING")
        return lines
    lines.append(f"   mtime  = {stamp(path)}")
    raw = open(path, "rb").read()
    text = raw.decode("utf-16-le", "ignore")
    found: list[str] = []
    pattern = r"([A-Za-z]:\\[A-Za-z0-9\\ ._\-\u4e00-\u9fff]{4,220}?\.exe)"
    for m in re.finditer(pattern, text):
        p = m.group(1).rstrip()
        if p not in found:
            found.append(p)
    for p in found:
        exists = "OK" if os.path.exists(p) else "NOT-FOUND"
        lines.append(f"   -> {p}   [{exists}]")
    if not found:
        lines.append("   (未解析出目标路径)")
    return lines


def known_folder(name: str, fallback: str) -> str:
    """Resolve the same Windows Known Folder used by PowerShell installers."""
    try:
        value = subprocess.check_output(
            [
                "powershell.exe",
                "-NoProfile",
                "-Command",
                f"[Environment]::GetFolderPath('{name}')",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        if value:
            return value
    except (OSError, subprocess.SubprocessError):
        pass
    return fallback


def main() -> int:
    out: list[str] = []
    out.append("=" * 68)
    out.append("Windows 发行包核验")
    out.append("=" * 68)

    # ---- 1) 安装目录时间戳 ----
    out.append("")
    out.append("[1] 已安装产物时间戳")
    targets = [
        "personal_workbench.exe",
        os.path.join("data", "app.so"),
        "app_links_plugin.dll",
        "hotkey_manager_windows_plugin.dll",
        "flutter_timezone_plugin.dll",
        "url_launcher_windows_plugin.dll",
    ]
    for rel in targets:
        p = os.path.join(INSTALL_DIR, rel)
        if os.path.exists(p):
            out.append(f"   {stamp(p)}   {os.path.getsize(p):>12,}   {rel}")
        else:
            out.append(f"   MISSING                  {rel}")

    # ---- 2) app.so 内容探针 ----
    out.append("")
    out.append("[2] app.so 内容探针（AOT 快照字符串表）")
    so_path = os.path.join(INSTALL_DIR, "data", "app.so")
    if not os.path.exists(so_path):
        out.append("   app.so 不存在，跳过")
        hard_fail = True
    else:
        blob = open(so_path, "rb").read()
        out.append(f"   文件大小 {len(blob):,} 字节")
        hard_fail = False
        for needle, expect, note in PROBES:
            n = blob.count(needle)
            ok = (n > 0) if expect == ">0" else (n == 0)
            hard_fail |= not ok
            out.append(
                f"   [{'PASS' if ok else 'FAIL'}] {needle.decode():<22}"
                f"{n:>6} 次   {note}"
            )
        for s, expect, note in CJK_PROBES:
            needle = s.encode("utf-16-le")
            n = blob.count(needle)
            ok = (n > 0) if expect == ">0" else (n == 0)
            hard_fail |= not ok
            out.append(
                f"   [{'PASS' if ok else 'FAIL'}] {s:<22}{n:>6} 次   {note}"
            )

    # ---- 3) 快捷方式 ----
    out.append("")
    out.append("[3] 快捷方式指向")
    desktop = known_folder(
        "Desktop", os.path.join(os.environ["USERPROFILE"], "Desktop")
    )
    programs = known_folder(
        "Programs",
        os.path.join(
            os.environ["APPDATA"], "Microsoft", "Windows", "Start Menu", "Programs"
        ),
    )
    for p in [
        os.path.join(desktop, "Personal Workbench.lnk"),
        os.path.join(programs, "Personal Workbench.lnk"),
        os.path.join(programs, "个人工作台.lnk"),
    ]:
        out.extend(check_shortcut(p))

    out.append("")
    out.append("=" * 68)
    out.append("结论：" + ("全部通过" if not hard_fail else "存在 FAIL，见上"))
    out.append("=" * 68)

    text = "\n".join(out)
    print(text)
    report = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "build",
        "_verify_windows.txt",
    )
    os.makedirs(os.path.dirname(report), exist_ok=True)
    with open(report, "w", encoding="utf-8") as fh:
        fh.write(text)
    return 1 if hard_fail else 0


if __name__ == "__main__":
    sys.exit(main())
