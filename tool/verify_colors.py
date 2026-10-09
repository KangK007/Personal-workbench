# -*- coding: utf-8 -*-
"""复算「柔壤图鉴 / 夜航工作室」语义色板的对比度与分类色色差。

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
    "canvas": "#F4F8F0",
    "navigation": "#FBFDF9",
    "surface": "#FFFFFF",
    "raised": "#FFFFFF",
    "subtle": "#EDF5EA",
    "emphasisSurface": "#E2EFDF",
    "heroStart": "#E8F2E7",
    "heroEnd": "#F7F5EB",
    "orbitTrack": "#CBE5D1",
    "ink": "#203A29",
    "inkMuted": "#4F6959",
    "inkFaint": "#586F60",
    "divider": "#E1EAE0",
    "borderStrong": "#789B83",
    "primary": "#347340",
    "onPrimary": "#FFFFFF",
    "primaryContainer": "#E6F2E4",
    "primaryOnContainer": "#1D4A27",
    "signal": "#9E3A32",
    "signalContainer": "#F7DEDA",
    "signalOnContainer": "#5A1F19",
    "reward": "#A95D37",
    "rewardContainer": "#F8E7D8",
    "rewardOnContainer": "#4A2410",
    "info": "#3E6883",
    "infoContainer": "#DCE8F0",
    "infoOnContainer": "#1C3947",
    "teal": "#0F6668",
    "olive": "#8F931A",
    "oliveContainer": "#F1F6DA",
    "oliveOnContainer": "#5F6C15",
    "violet": "#6B4A8C",
    "amber": "#BB811B",
    "outline": "#7E9284",
}

DARK = {
    "canvas": "#10192B",
    "navigation": "#0B1525",
    "surface": "#19263C",
    "raised": "#23334B",
    "subtle": "#23334B",
    "emphasisSurface": "#2C4058",
    "heroStart": "#1A3450",
    "heroEnd": "#14233B",
    "orbitTrack": "#355465",
    "ink": "#EAF3F3",
    "inkMuted": "#AABCC9",
    "inkFaint": "#99AEBF",
    "divider": "#2A3B52",
    "borderStrong": "#55728D",
    "primary": "#83D0D1",
    "onPrimary": "#102333",
    "primaryContainer": "#20444C",
    "primaryOnContainer": "#D7F6F4",
    "signal": "#E88C7E",
    "signalContainer": "#4C2A26",
    "signalOnContainer": "#F9D9D3",
    "reward": "#F1C17F",
    "rewardContainer": "#493D39",
    "rewardOnContainer": "#FAE9CC",
    "info": "#93B7CF",
    "infoContainer": "#273B54",
    "infoOnContainer": "#C7DCE8",
    "teal": "#68C8A1",
    "olive": "#D4D864",
    "oliveContainer": "#2B3312",
    "oliveOnContainer": "#D4D864",
    "violet": "#C2A6E4",
    "amber": "#DBA657",
    "outline": "#A9A9A7",
}

# content=(前景, 背景, 要求下限, 说明)
PAIRS = [
    ("ink", "canvas", 4.5, "正文压画布"),
    ("ink", "navigation", 4.5, "导航正文"),
    ("ink", "surface", 4.5, "正文压工作面"),
    ("inkMuted", "surface", 4.5, "辅助文字压实面"),
    ("inkMuted", "canvas", 4.5, "辅助文字压画布"),
    ("inkFaint", "surface", 4.5, "辅助小字压工作面"),
    *[(fg, bg, 4.5, "辅助文字与操作压分组/选中面")
      for fg in ("inkMuted", "inkFaint", "primary")
      for bg in ("subtle", "emphasisSurface")],
    ("primary", "surface", 4.5, "主操作色压工作面"),
    ("primary", "canvas", 4.5, "主操作色压画布"),
    ("onPrimary", "primary", 4.5, "主按钮文字"),
    ("primaryOnContainer", "primaryContainer", 4.5, "主操作容器槽"),
    ("signal", "surface", 4.5, "砖红实面"),
    ("signalOnContainer", "signalContainer", 4.5, "砖红容器槽"),
    ("reward", "surface", 4.5, "陶土实面"),
    ("rewardOnContainer", "rewardContainer", 4.5, "陶土容器槽"),
    ("oliveOnContainer", "oliveContainer", 4.5, "嫩黄绿容器槽"),
    ("info", "surface", 4.5, "靛蓝实面"),
    ("infoOnContainer", "infoContainer", 4.5, "靛蓝容器槽"),
    ("ink", "heroStart", 4.5, "引导面正文起点"),
    ("ink", "heroEnd", 4.5, "引导面正文终点"),
    ("divider", "surface", 1.0, "分组线（非文本）"),
    ("borderStrong", "surface", 3.0, "控件边界（非文本）"),
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


if __name__ == "__main__":
    total = report("浅色 · 柔壤图鉴", LIGHT, "surface")
    total += report("深色 · 夜航工作室", DARK, "surface")
    sys.stdout.write("\n合计未达标配对：%d\n" % total)
    sys.exit(1 if total else 0)
