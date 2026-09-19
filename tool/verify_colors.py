# -*- coding: utf-8 -*-
"""复算「柔壤 · 年轮」色板的对比度与分类色色差，供文档引用。

输出：
  1. 正文级/图形级配对对比度（WCAG 2.1）
  2. 8 类节点分类色两两最小 ΔE（CIEDE2000）
"""
import math
import sys


def rgb(hex_str):
    value = hex_str.lstrip("#")
    return tuple(int(value[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def _lin(channel):
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def luminance(hex_str):
    r, g, b = rgb(hex_str)
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)


def contrast(fg, bg):
    a, b = luminance(fg), luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def to_lab(hex_str):
    r, g, b = (_lin(c) for c in rgb(hex_str))
    x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
    y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b) / 1.00000
    z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 216 / 24389 else (841 / 108) * t + 4 / 29

    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def delta_e00(hex_a, hex_b):
    l1, a1, b1 = to_lab(hex_a)
    l2, a2, b2 = to_lab(hex_b)
    c1, c2 = math.hypot(a1, b1), math.hypot(a2, b2)
    c_bar = (c1 + c2) / 2
    g = 0.5 * (1 - math.sqrt(c_bar**7 / (c_bar**7 + 25**7))) if c_bar else 0.5
    a1p, a2p = (1 + g) * a1, (1 + g) * a2
    c1p, c2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360 if (a1p or b1) else 0
    h2p = math.degrees(math.atan2(b2, a2p)) % 360 if (a2p or b2) else 0

    dl = l2 - l1
    dc = c2p - c1p
    if c1p * c2p == 0:
        dh_term = 0
        dh = 0
    else:
        dh = h2p - h1p
        if dh > 180:
            dh -= 360
        elif dh < -180:
            dh += 360
        dh_term = 2 * math.sqrt(c1p * c2p) * math.sin(math.radians(dh) / 2)

    l_bar = (l1 + l2) / 2
    c_bar_p = (c1p + c2p) / 2
    if c1p * c2p == 0:
        h_bar = h1p + h2p
    else:
        diff = abs(h1p - h2p)
        if diff <= 180:
            h_bar = (h1p + h2p) / 2
        elif h1p + h2p < 360:
            h_bar = (h1p + h2p + 360) / 2
        else:
            h_bar = (h1p + h2p - 360) / 2

    t = (
        1
        - 0.17 * math.cos(math.radians(h_bar - 30))
        + 0.24 * math.cos(math.radians(2 * h_bar))
        + 0.32 * math.cos(math.radians(3 * h_bar + 6))
        - 0.20 * math.cos(math.radians(4 * h_bar - 63))
    )
    sl = 1 + (0.015 * (l_bar - 50) ** 2) / math.sqrt(20 + (l_bar - 50) ** 2)
    sc = 1 + 0.045 * c_bar_p
    sh = 1 + 0.015 * c_bar_p * t
    rt = (
        -2
        * math.sqrt(c_bar_p**7 / (c_bar_p**7 + 25**7))
        * math.sin(math.radians(60 * math.exp(-(((h_bar - 275) / 25) ** 2))))
        if c_bar_p
        else 0
    )
    return math.sqrt(
        (dl / sl) ** 2
        + (dc / sc) ** 2
        + (dh_term / sh) ** 2
        + rt * (dc / sc) * (dh_term / sh)
    )


LIGHT = {
    "canvas": "#F7F4EC",
    "surface": "#FFFDF9",
    "raised": "#FFFFFF",
    "subtle": "#EFEAE0",
    "ink": "#232A22",
    "inkMuted": "#636B5E",
    "inkFaint": "#8A9083",
    "divider": "#E3DCCF",
    "borderStrong": "#D2CFC5",
    "primary": "#4A6E4C",
    "primaryContainer": "#DCE7D8",
    "primaryOnContainer": "#1E3320",
    "signal": "#9E3A32",
    "signalContainer": "#F7DEDA",
    "signalOnContainer": "#5A1F19",
    "reward": "#9B5227",
    "rewardContainer": "#F5E3D6",
    "rewardOnContainer": "#4A2410",
    "info": "#3E6883",
    "infoContainer": "#DCE8F0",
    "infoOnContainer": "#1C3947",
    "teal": "#0F6668",
    "olive": "#8F931A",
    "violet": "#6B4A8C",
    "amber": "#BB811B",
    "outline": "#918783",
}

DARK = {
    "canvas": "#171612",
    "surface": "#1E1D18",
    "raised": "#26251E",
    "subtle": "#2C2A22",
    "ink": "#EFEDE4",
    "inkMuted": "#A9A797",
    "inkFaint": "#7C7A6C",
    "divider": "#3A382E",
    "borderStrong": "#4F4D45",
    "primary": "#93C08D",
    "primaryContainer": "#2C3A2B",
    "primaryOnContainer": "#CFE8CB",
    "signal": "#E88C7E",
    "signalContainer": "#4C2A26",
    "signalOnContainer": "#F9D9D3",
    "reward": "#E2A176",
    "rewardContainer": "#4A3629",
    "rewardOnContainer": "#F7DCC6",
    "info": "#93B7CF",
    "infoContainer": "#27333D",
    "infoOnContainer": "#C7DCE8",
    "teal": "#5FC0BD",
    "olive": "#D4D864",
    "violet": "#C2A6E4",
    "amber": "#DBA657",
    "outline": "#938B85",
}

# content=(前景, 背景, 要求下限, 说明)
PAIRS = [
    ("ink", "canvas", 4.5, "正文压画布"),
    ("ink", "surface", 4.5, "正文压工作面"),
    ("inkMuted", "surface", 4.5, "辅助文字压实面"),
    ("inkMuted", "canvas", 4.5, "辅助文字压画布"),
    ("inkFaint", "surface", 3.0, "装饰级（禁承载信息）"),
    ("primary", "surface", 4.5, "苔绿实面"),
    ("primary", "canvas", 4.5, "苔绿压画布"),
    ("primaryOnContainer", "primaryContainer", 4.5, "苔绿容器槽"),
    ("signal", "surface", 4.5, "砖红实面"),
    ("signalOnContainer", "signalContainer", 4.5, "砖红容器槽"),
    ("reward", "surface", 4.5, "陶土实面"),
    ("rewardOnContainer", "rewardContainer", 4.5, "陶土容器槽"),
    ("info", "surface", 4.5, "靛蓝实面"),
    ("infoOnContainer", "infoContainer", 4.5, "靛蓝容器槽"),
    ("divider", "surface", 1.0, "分组线（非文本）"),
    ("borderStrong", "surface", 1.0, "控件边界（非文本）"),
    ("primary", "canvas", 3.0, "焦点环压画布（图形级）"),
]

CATEGORY = [
    ("policy", "primary"),
    ("habit", "teal"),
    ("ritual", "info"),
    ("goal", "olive"),
    ("reward", "amber"),
    ("penalty", "signal"),
    ("trigger", "violet"),
    ("reminder", "outline"),
]


def report(title, palette, panel_key):
    sys.stdout.write("\n═══ %s ═══\n" % title)
    fails = 0
    for fg, bg, floor, label in PAIRS:
        ratio = contrast(palette[fg], palette[bg])
        ok = ratio >= floor
        if not ok:
            fails += 1
        sys.stdout.write(
            "  %-22s %-22s %6.2f:1  下限 %.1f  %s\n"
            % (label, "%s on %s" % (fg, bg), ratio, floor, "OK" if ok else "FAIL")
        )
    sys.stdout.write("  未达标：%d\n" % fails)

    colors = [(name, palette[key]) for name, key in CATEGORY]
    worst = None
    for i in range(len(colors)):
        for j in range(i + 1, len(colors)):
            de = delta_e00(colors[i][1], colors[j][1])
            if worst is None or de < worst[0]:
                worst = (de, colors[i][0], colors[j][0], colors[i][1], colors[j][1])
    sys.stdout.write(
        "  8 色最小 ΔE00 = %.1f（%s %s vs %s %s）\n"
        % (worst[0], worst[1], worst[3], worst[2], worst[4])
    )
    sys.stdout.write("  分类色贴面板底最低对比度：\n")
    lowest = None
    for name, hex_val in colors:
        ratio = contrast(hex_val, palette[panel_key])
        if lowest is None or ratio < lowest[0]:
            lowest = (ratio, name, hex_val)
    sys.stdout.write("    %.2f:1（%s %s）\n" % (lowest[0], lowest[1], lowest[2]))
    return fails


total = report("浅色 · 晨间陶土", LIGHT, "surface")
total += report("深色 · 夜间炭壤", DARK, "surface")
sys.stdout.write("\n合计未达标配对：%d\n" % total)
