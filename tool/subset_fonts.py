#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""个人工作台字体子集化脚本。

把 assets/fonts/ 下的中文字体裁剪为目标字符集，去除韩文等本项目
用不到的字形，减小 APK / Windows 安装包体积。子集保留 CJK 基本区
与扩展 A 全量，用户输入的生僻中文字仍然可以显示。

用法:
    python tool\subset_fonts.py            # 就地生成子集并替换
    python tool\subset_fonts.py --restore  # 从 .bak 备份恢复原字体

依赖: pip install fonttools
"""
import os
import sys

from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_DIR = os.path.join(ROOT, 'assets', 'fonts')

# 需要子集化的字体
TARGET_FONTS = [
    'LXGWWenKaiGB-Medium.ttf',
    'IBMPlexSansSC-Regular.otf',
    'IBMPlexSansSC-Medium.otf',
    'IBMPlexSansSC-SemiBold.otf',
]

# 保留的 Unicode 范围:
#   ASCII / 拉丁扩展(含拼音声调) / 希腊(科研公式) / 常用标点符号 /
#   箭头 / 数学符号 / 几何框线 / 杂项符号 / CJK 标点 / 平假名片假名 /
#   带圈数字 / CJK 扩展 A / CJK 基本区全量 / 兼容表意文字 / 全角形式
UNICODE_RANGES = [
    (0x0020, 0x007E),  # ASCII
    (0x00A0, 0x024F),  # Latin-1 + Latin Ext-A/B(含拼音)
    (0x0370, 0x03FF),  # Greek
    (0x1E00, 0x1EFF),  # Latin Extended Additional(越南文等)
    (0x2000, 0x206F),  # 标点 –—…''""‰
    (0x20AC, 0x20AC),  # €
    (0x2100, 0x214F),  # 字母符号 ™℃℅
    (0x2190, 0x21FF),  # 箭头
    (0x2200, 0x22FF),  # 数学符号 ×÷≠≤≥±∑√∞
    (0x2300, 0x23FF),  # 技术符号
    (0x2500, 0x25FF),  # 几何 / 框线
    (0x2600, 0x26FF),  # 杂项符号 ★☆☑
    (0x2700, 0x27BF),  # Dingbats ✓✗
    (0x2E80, 0x2EFF),  # CJK 部首补充(部分字体有)
    (0x3000, 0x303F),  # CJK 标点
    (0x3040, 0x30FF),  # 平假名 / 片假名
    (0x3105, 0x312F),  # 注音符号
    (0x31F0, 0x31FF),  # 片假名语音扩展
    (0x3220, 0x32FF),  # 带圈 CJK 数字
    (0x3400, 0x4DBF),  # CJK 扩展 A
    (0x4E00, 0x9FFF),  # CJK 基本区(全量保留)
    (0xF900, 0xFAFF),  # CJK 兼容表意文字
    (0xFB00, 0xFB06),  # fi/fl 连字
    (0xFE10, 0xFE1F),  # 竖排形式
    (0xFE30, 0xFE4F),  # CJK 兼容形式
    (0xFF00, 0xFFEF),  # 全角形式
]

OPTIONS = subset.Options()
OPTIONS.layout_features = ['*']       # 保留全部 OpenType 布局特性
OPTIONS.name_IDs = ['*']              # 保留全部 name 表条目
OPTIONS.name_languages = ['*']
OPTIONS.notdef_outline = True
OPTIONS.recommended_glyphs = True
OPTIONS.recalc_bounds = True
OPTIONS.drop_tables = []              # 不激进删除任何表


def build_unicodes() -> list[int]:
    codes = []
    for a, b in UNICODE_RANGES:
        codes.extend(range(a, b + 1))
    return codes


def subset_font(path: str, unicodes: list[int], out_path: str) -> None:
    font = subset.load_font(path, OPTIONS)
    subsetter = subset.Subsetter(options=OPTIONS)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    font.save(out_path)
    font.close()


def main() -> int:
    if '--restore' in sys.argv:
        for name in TARGET_FONTS:
            path = os.path.join(FONT_DIR, name)
            backup = path + '.bak'
            if os.path.exists(backup):
                os.replace(backup, path)
                print(f'已恢复: {name}')
        return 0

    unicodes = build_unicodes()
    total_before = total_after = 0
    for name in TARGET_FONTS:
        path = os.path.join(FONT_DIR, name)
        backup = path + '.bak'
        if not os.path.exists(backup):
            os.replace(path, backup)
        before = os.path.getsize(backup)
        tmp = path + '.subset.tmp'
        subset_font(backup, unicodes, tmp)
        after = os.path.getsize(tmp)
        os.replace(tmp, path)
        total_before += before
        total_after += after
        saved = (before - after) / before * 100
        print(
            f'{name}: {before / 1e6:.2f} MB -> {after / 1e6:.2f} MB '
            f'(节省 {saved:.1f}%)'
        )
    print(
        f'合计: {total_before / 1e6:.2f} MB -> {total_after / 1e6:.2f} MB '
        f'(节省 {(total_before - total_after) / 1e6:.2f} MB)'
    )
    print('如需回滚: python tool/subset_fonts.py --restore')
    return 0


if __name__ == '__main__':
    sys.exit(main())
