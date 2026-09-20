# -*- coding: utf-8 -*-
r"""字形覆盖门禁：代码里用到的字符，交付字体必须画得出来。

动机（2026-09-19 实测）：
方案 C 概览卡的标题后缀是一枚 U+2726（四角星）。四款内置字体的 cmap
**都没有**这个码位，于是它一直渲染成豆腐块——`android_today` 与
`wide_shell_today_*` 两份 golden 都在拍一张**错误的照片**，而且拍了两轮
没人发现，因为没人放大看。

判据不是「有没有配字体」，而是「这个码位在 cmap 里存不存在」。
字体子集脚本（`tool/subset_fonts.py`）只是把码位**请求**进来，
源字体本身没有的话，subsetter 什么也拿不到——本脚本检测的正是这一层。

用法：`python tool/verify_glyph_coverage.py`
退出码 0 = 全部覆盖；1 = 有缺字（逐条打印 file:line）。

依赖 fontTools（与 `tool/subset_fonts.py` 同一份）。本机可用的是
**系统 Python 3.11**：`C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe`；
WorkBuddy 托管版 3.13 未装 fontTools。故本模块的文档字符串用 r-string。
"""
import glob
import io
import os
import sys


def configure_console_encoding():
    """Keep diagnostics printable on Windows consoles using legacy code pages."""
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, 'reconfigure', None)
        if reconfigure is not None:
            reconfigure(errors='backslashreplace')


configure_console_encoding()

try:
    from fontTools.ttLib import TTFont
except ImportError:  # pragma: no cover - 环境问题，不是逻辑分支
    sys.stderr.write(
        '需要 fontTools：请用系统 Python 3.11 运行\n'
        '  C:\\Users\\Administrator\\AppData\\Local\\Programs\\Python'
        '\\Python311\\python.exe tool/verify_glyph_coverage.py\n'
    )
    sys.exit(2)

TEXT_FONTS = [
    'assets/fonts/LXGWWenKaiGB-Medium.ttf',
    'assets/fonts/IBMPlexSansSC-Regular.otf',
    'assets/fonts/IBMPlexSansSC-Medium.otf',
    'assets/fonts/IBMPlexSansSC-SemiBold.otf',
    'assets/fonts/IBMPlexMono-Medium.ttf',
]

# 这些区段由字体以外的机制保证，不需要查 cmap：
#   CJK 表意文字 / CJK 标点 / 全角形式 —— 由中文字体覆盖，且属预期内容
#   0x2000–0x206F —— 通用标点（–—…''""），字体已覆盖，且量大
# ASCII 与拉丁扩展同理（< 0x2000 全部跳过）
SKIP_RANGES = [
    (0x3000, 0x303F),   # CJK 标点
    (0xFF00, 0xFFEF),   # 全角形式
    (0x4E00, 0x9FFF),   # CJK 基本区
    (0x3400, 0x4DBF),   # CJK 扩展 A
    (0x2000, 0x206F),   # 通用标点
]

SCAN_DIR = 'lib'


def cmap_of(path, font_number=0):
    font = TTFont(path, fontNumber=font_number)
    codes = set()
    for table in font['cmap'].tables:
        codes |= set(table.cmap.keys())
    font.close()
    return codes


def in_skip_range(code):
    return any(a <= code <= b for a, b in SKIP_RANGES)


def icon_font_path():
    """取 golden 环境实际使用的那份图标字体。

    `flutter test` 通过 rootBundle 的 `fonts/MaterialIcons-Regular.otf`
    解析到 `build/unit_test_assets/fonts/`，与真机打包用的是同一份。
    """
    for pattern in (
        os.path.join('build', 'unit_test_assets', 'fonts',
                     'MaterialIcons-Regular.otf'),
        os.path.join('assets', 'fonts', 'MaterialIcons-Regular.otf'),
    ):
        if os.path.exists(pattern):
            return pattern
    found = glob.glob('**/MaterialIcons-Regular.otf', recursive=True)
    return found[0] if found else None


def main():
    missing = [p for p in TEXT_FONTS if not os.path.exists(p)]
    if missing:
        print('缺少字体文件：%s' % ', '.join(missing))
        return 1

    text_codes = set()
    for path in TEXT_FONTS:
        text_codes |= cmap_of(path)
    print('文本字体合并 cmap 码位数 = %d' % len(text_codes))

    print('\n── 关键字形探测 ──')
    for code, name in [
        (0x2726, 'FOUR POINTED STAR (deprecated; use Icons.auto_awesome)'),
        (0x2605, 'BLACK STAR'),
        (0x2606, 'WHITE STAR'),
        (0x2713, 'CHECK MARK'),
        (0x2022, 'BULLET'),
    ]:
        print('  U+%04X %-40s %s' % (code, name, '有' if code in text_codes else '无'))

    icons = icon_font_path()
    if icons:
        icon_codes = cmap_of(icons)
        print('\n── 图标字体 %s（cmap %d 项）──' % (icons, len(icon_codes)))
        for code, name in [(0xE0B7, 'auto_awesome'), (0xE838, 'add')]:
            print('  U+%04X %-16s %s' % (code, name, '有' if code in icon_codes else '无'))

    # ── 扫描源码里实际出现的字符 ──
    offenders = {}
    scanned = 0
    for root, _dirs, files in os.walk(SCAN_DIR):
        for name in files:
            if not name.endswith('.dart'):
                continue
            path = os.path.join(root, name)
            scanned += 1
            for line_no, line in enumerate(
                io.open(path, encoding='utf-8'), start=1
            ):
                for ch in line:
                    code = ord(ch)
                    if code < 0x2000 or in_skip_range(code):
                        continue
                    if code in text_codes:
                        continue
                    offenders.setdefault(ch, []).append(
                        '%s:%d' % (path.replace(os.sep, '/'), line_no)
                    )

    print('\n── 源码字形扫描（%d 个 dart 文件）──' % scanned)
    if not offenders:
        print('  无缺字')
        return 0

    print('  发现 %d 个字体画不出的字符：' % len(offenders))
    for ch, locations in sorted(offenders.items(), key=lambda kv: ord(kv[0])):
        print('    U+%04X %s  ×%d' % (ord(ch), ch, len(locations)))
        for loc in locations[:5]:
            print('        %s' % loc)
    return 1


sys.exit(main())
