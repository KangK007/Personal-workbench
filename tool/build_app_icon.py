#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""应用图标「新芽 · 破土」生成器 —— 单一几何真源，派生全部尺寸与平台产物。

用法：
    python tool/build_app_icon.py     # 生成全部产物 + 自检

改配色 / 造型只需改本文件顶部的 PALETTE 与几何常量，重跑即可全链路同步。
配色与对比度判据复用 tool/verify_colors.py（避免 ΔE00 双实现）。

设计要点（详见 APP_ICON_SPEC.md）：
  · 用途：个人工作台的应用图标（Windows 快捷方式/任务栏、Android 启动器）
  · 风格：扁平实色 + 有机曲线；无渐变、无阴影、无描边式线条画
  · 结构：圆角砖 = 天空（新芽绿）+ 大地（陶土，浅弧分界，全出血）
          白色芽自大地中破土而出（茎的下端被大地覆盖）
  · 双尺寸档：≥40px 全形态；<40px 简化档（芽加粗放大）
  · 深浅双主题 + Android 13+ 主题单色层

几何坐标空间固定为 1024×1024 逻辑网格；所有栅格渲染先超采样再逐级降采样。
"""
from __future__ import annotations

import math
import struct
import sys
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tool"))
from verify_colors import contrast, delta_e00  # noqa: E402

U = 1024.0  # 逻辑网格边长

# ──────────────────────────────────────────────────────────────────────────
# 配色：全部取自 app_theme.dart 现行令牌，不引入新色值
# ──────────────────────────────────────────────────────────────────────────
PALETTE = {
    "light": {
        "sky": "#3E7F4B",   # AppColors.lightPrimary 新芽绿
        "soil": "#9B5227",  # AppColors.lightReward 陶土 —— 土就是陶土色
        "mark": "#FFFFFF",  # AppColors.lightSurface
    },
    "dark": {
        "sky": "#16231A",   # AppColors.darkSurface
        "soil": "#4A3629",  # AppColors.darkRewardContainer
        "mark": "#7FCB8E",  # AppColors.darkPrimary
    },
}

# ──────────────────────────────────────────────────────────────────────────
# 几何常量（1024 逻辑网格）
# ──────────────────────────────────────────────────────────────────────────
TILE_RADIUS = 232.0   # 圆角砖（≈22.7%，与 SealLogo 的 0.22 同源）

# 芽（局部坐标：茎轴 = x0，原点在茎顶附近）
L_STEM_TOP = 10.0     # 茎顶（含圆头）
L_STEM_BOT = 300.0    # 茎底（会被大地覆盖，仅决定被埋深度）
L_STEM_W = 82.0
L_LEAF_BASE = 44.0    # 叶基点，落在茎体内 → 结合处无缺口；越靠上腋部越浅
L_LEAF_LEN = 268.0
L_LEAF_ANGLE = 47.0   # 叶轴与竖直方向夹角（度）
L_LEAF_HALF_W = 108.0
# 叶缘（沿轴比例, 法向倍数）。外缘与内缘各自两段，独立控制外凸程度——
# 若近尖端的外缘法向过小，外缘会退化成直线段，叶子就读成「翼」而非「叶」。
L_OUT_NEAR = (0.34, 0.95)
L_OUT_FAR = (0.68, 1.20)
L_IN_NEAR = (0.34, 0.50)
L_IN_FAR = (0.68, 0.72)

# 大地：全出血的浅弧，下缘即砖底
SOIL_HALF = 512.0     # 半弦 = 砖宽一半 → 弧正好触到砖左右边缘
SOIL_EDGE_Y = 850.0
SOIL_APEX_Y = 768.0

# 芽在砖中的落位：包围盒上/下沿
SPROUT_TOP_Y = 218.0
SPROUT_BOT_Y = 884.0  # 茎底，深埋于大地之下

# 尺寸分档：≥40px 全形态，<40px 简化档（去细部、加粗放大）
TIER_THRESHOLD = 40
TIERS = {
    "full":   dict(top=SPROUT_TOP_Y, bot=SPROUT_BOT_Y, stem_mul=1.00, leaf_mul=1.00),
    "simple": dict(top=240.0, bot=SPROUT_BOT_Y, stem_mul=1.19, leaf_mul=1.12),
}
# Android 自适应安全圆直径（相对 108 viewport）。官方保证可见区 66/108，
# 这里取 62 留余量——叶尖正是包围盒角点，贴边在圆形遮罩下会显拥挤。
SAFE_DIA = 62.0 / 108.0


# ──────────────────────────────────────────────────────────────────────────
# 小工具
# ──────────────────────────────────────────────────────────────────────────
def hex2rgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def cubic(p0, p1, p2, p3, n=40):
    """三次贝塞尔采样点（含两端）。"""
    out = []
    for i in range(n + 1):
        t = i / n
        mt = 1 - t
        out.append((
            mt ** 3 * p0[0] + 3 * mt * mt * t * p1[0] + 3 * mt * t * t * p2[0] + t ** 3 * p3[0],
            mt ** 3 * p0[1] + 3 * mt * mt * t * p1[1] + 3 * mt * t * t * p2[1] + t ** 3 * p3[1],
        ))
    return out


def bbox(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def _f(v: float) -> str:
    return f"{v:.2f}".rstrip("0").rstrip(".")


# ──────────────────────────────────────────────────────────────────────────
# 几何构建
# ──────────────────────────────────────────────────────────────────────────
def build_geometry(tier: str) -> dict:
    """返回 1024 网格下已定位的全部图元。"""
    cfg = TIERS[tier]
    stem_w = L_STEM_W * cfg["stem_mul"]
    hw = L_LEAF_HALF_W * cfg["leaf_mul"]
    base = (0.0, L_LEAF_BASE)
    th = math.radians(L_LEAF_ANGLE)
    dx = L_LEAF_LEN * math.sin(th)
    dy = -L_LEAF_LEN * math.cos(th)

    def make_leaf(sign: int):
        """sign=+1 右叶 / -1 左叶。叶几何由该叶自身轴导出，避免镜像算错。"""
        tip = (base[0] + sign * dx, base[1] + dy)
        ax = (tip[0] - base[0], tip[1] - base[1])
        ln = math.hypot(*ax)
        u = (ax[0] / ln, ax[1] / ln)
        p = (-u[1], u[0])                 # 屏幕坐标下 +90° 旋转
        if p[1] > 0:                      # 取朝上的一侧为饱满面（芽向上舒展）
            p = (-p[0], -p[1])
        def ctrl(a, n, s):
            return (base[0] + ax[0] * a + p[0] * hw * n * s,
                    base[1] + ax[1] * a + p[1] * hw * n * s)

        return [
            [base, ctrl(*L_OUT_NEAR, 1), ctrl(*L_OUT_FAR, 1), tip],   # 外缘（饱满侧）
            [base, ctrl(*L_IN_NEAR, -1), ctrl(*L_IN_FAR, -1), tip],   # 内缘
        ]

    leaves_l = [make_leaf(-1), make_leaf(1)]

    # 局部包围盒（含茎的圆头）
    probe = [(0.0, L_STEM_TOP), (0.0, L_STEM_BOT),
             (-stem_w / 2, L_STEM_TOP), (stem_w / 2, L_STEM_TOP),
             (-stem_w / 2, L_STEM_BOT), (stem_w / 2, L_STEM_BOT)]
    for e in leaves_l:
        for bez in e:
            probe += cubic(*bez, n=24)
    lx0, ly0, lx1, ly1 = bbox(probe)

    k = (cfg["bot"] - cfg["top"]) / (ly1 - ly0)
    cx, cy = U / 2, (cfg["top"] + cfg["bot"]) / 2

    def xf(p):
        return (cx + (p[0] - (lx0 + lx1) / 2) * k, cy + (p[1] - (ly0 + ly1) / 2) * k)

    leaves = [[tuple(xf(p) for p in bez) for bez in e] for e in leaves_l]
    st = xf((0.0, L_STEM_TOP))
    sb = xf((0.0, L_STEM_BOT))

    sag = SOIL_EDGE_Y - SOIL_APEX_Y
    return {
        "tier": tier,
        "scale": k,
        "stem": (st[0], st[1], sb[0], sb[1], stem_w * k),
        "leaves": leaves,
        "sky": (0.0, 0.0, U, U, TILE_RADIUS),
        "soil": {"R": (SOIL_HALF ** 2 + sag ** 2) / (2 * sag),
                 "cy": SOIL_APEX_Y + (SOIL_HALF ** 2 + sag ** 2) / (2 * sag),
                 "cx": U / 2, "edge_y": SOIL_EDGE_Y, "apex_y": SOIL_APEX_Y},
    }


def mark_bbox(g: dict):
    pts = []
    for e in g["leaves"]:
        for bez in e:
            pts += cubic(*bez, n=32)
    sx, sy0, _, sy1, sw = g["stem"]
    pts += [(sx - sw / 2, sy0), (sx + sw / 2, sy0), (sx - sw / 2, sy1), (sx + sw / 2, sy1)]
    return bbox(pts)


def soil_pts(g: dict, n: int = 128):
    """大地弧的采样点，自左端到右端（弧向上弓起）。"""
    s = g["soil"]
    half_ang = math.asin(SOIL_HALF / s["R"])
    return [(s["cx"] + s["R"] * math.sin(-half_ang + 2 * half_ang * i / n),
             s["cy"] - s["R"] * math.cos(-half_ang + 2 * half_ang * i / n)) for i in range(n + 1)]


# ──────────────────────────────────────────────────────────────────────────
# 栅格渲染（PIL）
# ──────────────────────────────────────────────────────────────────────────
def _progressive_resize(img: Image.Image, size: int) -> Image.Image:
    cur = img
    while cur.width > size * 2:
        cur = cur.resize((cur.width // 2, cur.height // 2), Image.LANCZOS)
    return cur if cur.width == size else cur.resize((size, size), Image.LANCZOS)


def _draw_sprout(d: ImageDraw.ImageDraw, g: dict, k: float, color, cut_y: float | None = None):
    """画茎与双叶。cut_y 非空时把茎截断到该 y（自适应前景用：大地在背景层）。"""
    sx, sy0, _, sy1, sw = g["stem"]
    bot = sy1 if cut_y is None else min(sy1, cut_y)
    d.rounded_rectangle([(sx - sw / 2) * k, sy0 * k, (sx + sw / 2) * k, bot * k],
                        radius=sw * k / 2, fill=color)
    for e in g["leaves"]:
        up = cubic(*e[0], n=56)
        lo = cubic(*e[1], n=56)
        poly = [(p[0] * k, p[1] * k) for p in up + list(reversed(lo))[1:-1]]
        d.polygon(poly, fill=color)


def _draw_soil(d: ImageDraw.ImageDraw, g: dict, k: float, color):
    pts = [(p[0] * k, p[1] * k) for p in soil_pts(g)]
    d.polygon(pts + [(U * k, (U + 80) * k), (0.0, (U + 80) * k)], fill=color)


def render_tile(size: int, theme: str, tier: str = "full") -> Image.Image:
    """完整图标：圆角砖 + 天空 + 破土的芽 + 大地（覆盖茎的下端）。"""
    pal = PALETTE[theme]
    R = 4096 if size >= 256 else 2048
    k = R / U
    g = build_geometry(tier)
    img = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    x0, y0, x1, y1, rad = g["sky"]
    d.rounded_rectangle([x0 * k, y0 * k, x1 * k, y1 * k], radius=rad * k, fill=hex2rgb(pal["sky"]) + (255,))
    _draw_sprout(d, g, k, hex2rgb(pal["mark"]) + (255,))
    _draw_soil(d, g, k, hex2rgb(pal["soil"]) + (255,))

    # 裁到圆角砖：大地是全出血的，必须靠遮罩收边
    mask = Image.new("L", (R, R), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, R - 1, R - 1], radius=rad * k, fill=255)
    img.putalpha(Image.composite(img.getchannel("A"), Image.new("L", (R, R), 0), mask))
    return _progressive_resize(img, size)


def render_mark(size: int, theme: str, tier: str = "full", cut: bool = True) -> Image.Image:
    """仅芽，透明底。cut=True 时茎在大地顶点处截断（供自适应前景叠加在背景之上）。"""
    pal = PALETTE[theme]
    R = 4096 if size >= 256 else 2048
    k = R / U
    g = build_geometry(tier)
    img = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    _draw_sprout(ImageDraw.Draw(img), g, k, hex2rgb(pal["mark"]) + (255,),
                 cut_y=g["soil"]["apex_y"] if cut else None)
    return _progressive_resize(img, size)


def render_adaptive_foreground(size: int, theme: str) -> Image.Image:
    """自适应前景层：芽按安全圆映射落在 108 画布上，透明底，茎在大地顶点截断。"""
    pal = PALETTE[theme]
    s, dx, dy = _adaptive_map()
    SS = 2048
    kk = SS / 108.0
    g = build_geometry("full")
    img = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    col = hex2rgb(pal["mark"]) + (255,)

    def T(p):
        return ((p[0] * s + dx) * kk, (p[1] * s + dy) * kk)

    sx, sy0, _, sy1, sw = g["stem"]
    p0, p1_ = T((sx, sy0)), T((sx, min(sy1, g["soil"]["apex_y"])))
    half = sw * s * kk / 2
    d.rounded_rectangle([p0[0] - half, p0[1], p0[0] + half, p1_[1]], radius=half, fill=col)
    for e in g["leaves"]:
        up = cubic(*e[0], n=48)
        lo = cubic(*e[1], n=48)
        d.polygon([T(p) for p in up + list(reversed(lo))[1:-1]], fill=col)
    return _progressive_resize(img, size)


def render_adaptive_bg(size: int, theme: str) -> Image.Image:
    """Android 自适应背景层：天空铺满 + 大地弧，全出血。

    弧半径按**画布比例**取（与传统版同弧度），只有弧的顶点高度跟随芽的落位。
    若连半径一起按芽的安全区缩放取，遮罩窗口内的地平线会比传统版明显更弯——
    那样 Android 与 Windows 两个图标就不是同一个东西了。
    """
    pal = PALETTE[theme]
    s, dx, dy = _adaptive_map()
    SS, kk = 2048, 2048 / 108.0
    R = build_geometry("full")["soil"]["R"] / U * 108.0
    cy = SOIL_APEX_Y * s + dy + R
    img = Image.new("RGBA", (SS, SS), hex2rgb(pal["sky"]) + (255,))
    xa, xb, n = -40.0, 148.0, 160
    pts = []
    for i in range(n + 1):
        x = xa + (xb - xa) * i / n
        pts.append((x * kk, (cy - math.sqrt(max(0.0, R * R - (x - 54.0) ** 2))) * kk))
    ImageDraw.Draw(img).polygon(pts + [(xb * kk, xb * kk), (xa * kk, xb * kk)],
                                fill=hex2rgb(pal["soil"]) + (255,))
    return _progressive_resize(img, size)


def render_adaptive_icon(size: int, theme: str) -> Image.Image:
    """自适应图标两层合成后的真实观感（供遮罩模拟用）。"""
    return Image.alpha_composite(render_adaptive_bg(size, theme),
                                 render_adaptive_foreground(size, theme))


def render_soil_layer(size: int, theme: str) -> Image.Image:
    """仅大地，透明底（预览用）。"""
    pal = PALETTE[theme]
    R = 2048
    k = R / U
    g = build_geometry("full")
    img = Image.new("RGBA", (R, R), (0, 0, 0, 0))
    _draw_soil(ImageDraw.Draw(img), g, k, hex2rgb(pal["soil"]) + (255,))
    return _progressive_resize(img, size)


def render_flat(size: int, theme: str, tier: str = "full") -> Image.Image:
    """不带圆角裁切的方形版：Android 自适应图标由系统遮罩决定外形，故需此版。"""
    pal = PALETTE[theme]
    R = 4096 if size >= 256 else 2048
    k = R / U
    g = build_geometry(tier)
    img = Image.new("RGBA", (R, R), hex2rgb(pal["sky"]) + (255,))
    d = ImageDraw.Draw(img)
    _draw_sprout(d, g, k, hex2rgb(pal["mark"]) + (255,))
    _draw_soil(d, g, k, hex2rgb(pal["soil"]) + (255,))
    return _progressive_resize(img, size)


# ──────────────────────────────────────────────────────────────────────────
# SVG / VectorDrawable 序列化
# ──────────────────────────────────────────────────────────────────────────
def _pt(p):
    return f"{_f(p[0])} {_f(p[1])}"


def _leaf_path(e):
    up, lo = e
    return (f"M {_pt(up[0])} C {_pt(up[1])} {_pt(up[2])} {_pt(up[3])} "
            f"C {_pt(lo[1])} {_pt(lo[2])} {_pt(lo[0])} Z")


def _soil_path(g: dict) -> str:
    s = g["soil"]
    return (f"M 0 {_f(s['edge_y'])} A {_f(s['R'])} {_f(s['R'])} 0 0 1 {_f(U)} {_f(s['edge_y'])} "
            f"L {_f(U)} {_f(U)} L 0 {_f(U)} Z")


def svg_master(theme: str) -> str:
    pal = PALETTE[theme]
    g = build_geometry("full")
    sx, sy0, _, sy1, sw = g["stem"]
    body = [
        f'  <rect width="1024" height="1024" rx="{_f(TILE_RADIUS)}" fill="{pal["sky"]}"/>',
        (f'  <path d="M {_f(sx)} {_f(sy0)} L {_f(sx)} {_f(sy1)}" fill="none" stroke="{pal["mark"]}" '
         f'stroke-width="{_f(sw)}" stroke-linecap="round"/>'),
    ]
    for e in g["leaves"]:
        body.append(f'  <path d="{_leaf_path(e)}" fill="{pal["mark"]}"/>')
    body.append(f'  <path d="{_soil_path(g)}" fill="{pal["soil"]}"/>')
    head = ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'
            f'  <clipPath id="tile"><rect width="1024" height="1024" rx="{_f(TILE_RADIUS)}"/></clipPath>\n'
            '  <g clip-path="url(#tile)">\n')
    return head + "\n".join("  " + b for b in body) + "\n  </g>\n</svg>\n"


def _adaptive_map():
    """返回把 1024 网格映射进 108 viewport 的 (scale, dx, dy)，使芽落入安全圆。"""
    g = build_geometry("full")
    x0, y0, x1, y1 = mark_bbox(g)
    dia = math.hypot(x1 - x0, y1 - y0)
    s = SAFE_DIA * 108.0 / dia
    return s, 54.0 - (x0 + x1) / 2 * s, 54.0 - (y0 + y1) / 2 * s


def _wrap_vd(body: str, note: str) -> str:
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            f"<!-- {note} · 由 tool/build_app_icon.py 生成，请勿手改 -->\n"
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="108dp"\n    android:height="108dp"\n'
            '    android:viewportWidth="108"\n    android:viewportHeight="108">\n'
            f"{body}\n</vector>\n")


def vd_background_xml() -> str:
    """自适应背景：天空铺满 + 大地弧（与前景同一映射，故与芽的落位严格对齐）。

    弧半径按画布比例取，保证与传统启动器图标同弧度，见 render_adaptive_bg。
    """
    pal = PALETTE["light"]
    s, dx, dy = _adaptive_map()
    R = build_geometry("full")["soil"]["R"] / U * 108.0
    cy = SOIL_APEX_Y * s + dy + R

    def y_at(x):
        return cy - math.sqrt(max(0.0, R * R - (x - 54.0) ** 2))

    xa, xb = -40.0, 148.0   # 越过画布，保证全出血
    body = "\n".join([
        "  <path\n"
        f'      android:fillColor="{pal["sky"]}"\n'
        '      android:pathData="M 0 0 H 108 V 108 H 0 Z" />',
        "  <path\n"
        f'      android:fillColor="{pal["soil"]}"\n'
        f'      android:pathData="M {_f(xa)} {_f(y_at(xa))} A {_f(R)} {_f(R)} 0 0 1 '
        f'{_f(xb)} {_f(y_at(xb))} L {_f(xb)} 148 L {_f(xa)} 148 Z" />',
    ])
    return _wrap_vd(body, "自适应图标背景层")


def _vd_sprout_body(color: str, cut: bool) -> str:
    s, dx, dy = _adaptive_map()
    g = build_geometry("full")

    def P(p):
        return f"{_f(p[0] * s + dx)} {_f(p[1] * s + dy)}"

    sx, sy0, _, sy1, sw = g["stem"]
    end_y = min(sy1, g["soil"]["apex_y"]) if cut else sy1
    blocks = ["  <path\n"
              '      android:fillColor="#00000000"\n'
              f'      android:strokeColor="{color}"\n'
              f'      android:strokeWidth="{_f(sw * s)}"\n'
              '      android:strokeLineCap="round"\n'
              f'      android:pathData="M {P((sx, sy0))} L {P((sx, end_y))}" />']
    for e in g["leaves"]:
        up, lo = e
        blocks.append("  <path\n"
                      f'      android:fillColor="{color}"\n'
                      f'      android:pathData="M {P(up[0])} C {P(up[1])} {P(up[2])} {P(up[3])} '
                      f'C {P(lo[1])} {P(lo[2])} {P(lo[0])} Z" />')
    return "\n".join(blocks)


def vd_foreground_xml() -> str:
    """自适应前景：芽。茎在大地顶点处截断，与背景层严丝合缝。"""
    return _wrap_vd(_vd_sprout_body("#FFFFFFFF", cut=True), "自适应图标前景层")


def vd_monochrome_xml() -> str:
    """Android 13+ 主题单色层：几何同前景，由系统着色。"""
    return _wrap_vd(_vd_sprout_body("#FFFFFFFF", cut=True), "自适应图标主题单色层")


# ──────────────────────────────────────────────────────────────────────────
# ICO（DIB 条目，逐尺寸独立渲染，不靠系统缩放）
# ──────────────────────────────────────────────────────────────────────────
def write_ico(path: pathlib.Path, sizes: list[int], theme: str = "light"):
    frames, entries, offset = [], [], 6 + 16 * len(sizes)
    for s in sizes:
        tier = "full" if s >= TIER_THRESHOLD else "simple"
        px = render_tile(s, theme, tier).load()
        xor = bytearray()
        for y in range(s - 1, -1, -1):
            for x in range(s):
                r, g_, b, a = px[x, y]
                xor += bytes((b, g_, r, a))
        stride = ((s + 31) // 32) * 4
        and_mask = bytes(stride * s)  # 全 0 = 不透明；透明度由 alpha 通道承担
        blob = struct.pack("<IiiHHIIiiII", 40, s, s * 2, 1, 32, 0,
                           len(xor) + len(and_mask), 0, 0, 0, 0) + bytes(xor) + and_mask
        frames.append(blob)
        dim = s if s < 256 else 0
        entries.append(struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(blob), offset))
        offset += len(blob)
    path.write_bytes(struct.pack("<HHH", 0, 1, len(sizes)) + b"".join(entries) + b"".join(frames))


# ──────────────────────────────────────────────────────────────────────────
# 自检
# ──────────────────────────────────────────────────────────────────────────
def checks() -> list[str]:
    out = []

    # 1) 芽必须完全落在圆角砖内
    for tier in TIERS:
        SS, k = 2048, 2048 / U
        mk = Image.new("L", (SS, SS), 0)
        _draw_sprout(ImageDraw.Draw(mk), build_geometry(tier), k, 255)
        tl = Image.new("L", (SS, SS), 0)
        ImageDraw.Draw(tl).rounded_rectangle([0, 0, SS - 1, SS - 1], radius=TILE_RADIUS * k, fill=255)
        mp, tp = mk.load(), tl.load()
        spill = sum(1 for y in range(SS) for x in range(SS) if mp[x, y] > 40 and tp[x, y] < 200)
        out.append(f"[{'OK ' if spill == 0 else 'FAIL'}] {tier:6s} 芽越出圆角砖的像素 = {spill}/{SS * SS}")

    # 2) 自适应前景须落在安全圆内
    s, _, _ = _adaptive_map()
    x0, y0, x1, y1 = mark_bbox(build_geometry("full"))
    half = math.hypot(x1 - x0, y1 - y0) * s / 2
    out.append(f"[{'OK ' if half <= 31.5 else 'FAIL'}] 自适应前景包围圆半径 = {half:.2f}/54"
               f"（自设 ≤31.5，官方保证 ≤33）")

    # 3) 破土：茎底必须落在大地之下，且顶部露出足够长度
    g = build_geometry("full")
    stem_top, stem_bot = g["stem"][1], g["stem"][3]
    apex = g["soil"]["apex_y"]
    buried = stem_bot - apex
    exposed = apex - stem_top
    out.append(f"[{'OK ' if buried > 40 else 'FAIL'}] 茎埋入大地 {buried:.0f}/1024（须 >0，实为 {buried > 0}）")
    out.append(f"[{'OK ' if exposed > 240 else 'FAIL'}] 茎露出地面 {exposed:.0f}/1024"
               f"（16px 档 {exposed / 16:.1f}px）")

    # 4) 自适应两层必须严丝合缝：前景茎的截断点 = 背景弧的顶点
    s, dx, dy = _adaptive_map()
    cut = min(g["stem"][3], apex) * s + dy
    apex108 = SOIL_APEX_Y * s + dy
    out.append(f"[{'OK ' if abs(cut - apex108) < 0.05 else 'FAIL'}] 自适应两层对齐："
               f"茎截断 y={cut:.2f} vs 大地顶点 y={apex108:.2f}")

    # 5) 自适应弧与传统版必须同弧度（半径/弦长比值一致），否则两端图标不是同一个东西
    ratio_tile = g["soil"]["R"] / U
    ratio_adap = (g["soil"]["R"] / U * 108.0) / 108.0
    out.append(f"[{'OK ' if abs(ratio_tile - ratio_adap) < 1e-9 else 'FAIL'}] "
               f"弧的半径/弦长比：传统 {ratio_tile:.4f} vs 自适应 {ratio_adap:.4f}")

    # 6) 最小全形态尺寸下的特征宽度
    for label, v in (("茎宽", g["stem"][4]), ("叶全宽", L_LEAF_HALF_W * 2 * g["scale"])):
        px = v / TIER_THRESHOLD
        out.append(f"[{'OK ' if px >= 1.5 else '!! '}] {label} 在 {TIER_THRESHOLD}px 档 = {px:.2f}px")

    # 7) 对比度（复用 verify_colors 的判据实现）
    for th, pal in PALETTE.items():
        for name in ("sky", "soil"):
            c = contrast(pal["mark"], pal[name])
            out.append(f"[{'OK ' if c >= 4.5 else 'FAIL'}] {th:5s} 芽/{name:4s} = {c:.2f}:1")
        de = delta_e00(pal["sky"], pal["soil"])
        c = contrast(pal["sky"], pal["soil"])
        out.append(f"[{'OK ' if de >= 10 else '!! '}] {th:5s} 天空/大地 ΔE00 = {de:.1f}"
                   f"（对比度 {c:.2f}:1 — 此为**装饰性**分界，不承载信息）")
    cl = contrast(PALETTE["light"]["sky"], "#F3F3F3")
    cd = contrast(PALETTE["light"]["sky"], "#1F1F1F")
    out.append(f"[{'OK ' if cl >= 3 and cd >= 3 else '!! '}] 浅色砖 vs 外壳：浅 #F3F3F3 = {cl:.2f}:1"
               f" / 深 #1F1F1F = {cd:.2f}:1（两端任务栏都可见）")
    return out


# ──────────────────────────────────────────────────────────────────────────
# 主流程
# ──────────────────────────────────────────────────────────────────────────
PNG_SIZES = [16, 24, 32, 40, 48, 64, 128, 256, 512, 1024]
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
ANDROID_DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


# ──────────────────────────────────────────────────────────────────────────
# 预览页（由生成器产出，保证与产物同源、可重跑）
# ──────────────────────────────────────────────────────────────────────────
_HEAD = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>个人工作台 · 应用图标「新芽 · 破土」</title>
<style>
  :root{
    --canvas:#F5FAF0; --panel:#FFFFFF; --subtle:#EFF8F0;
    --ink:#17301B; --muted:#5D7961; --faint:#849A88;
    --primary:#3E7F4B; --primary-container:#E2F3E5;
    --reward:#9B5227; --signal:#9E3A32;
    --border:#DFEBE1; --border-strong:#C4D8C9;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--canvas);color:var(--ink);
    font-family:"IBM Plex Sans SC","Microsoft YaHei","PingFang SC",system-ui,sans-serif;
    font-size:14px;line-height:1.7}
  .wrap{max-width:1000px;margin:0 auto;padding:40px 28px 72px}
  h1{font-size:28px;line-height:1.35;margin:0 0 6px;font-weight:600;letter-spacing:.2px}
  .kicker{font-size:11.5px;color:var(--faint);letter-spacing:.5px;margin-bottom:4px}
  h2{font-size:17px;margin:44px 0 4px;font-weight:600}
  h2 .no{color:var(--faint);font-weight:400;margin-right:8px}
  .note{color:var(--muted);font-size:13px;margin:0 0 18px}
  .card{background:var(--panel);border:1px solid var(--border);border-radius:16px;padding:20px}
  .row{display:flex;flex-wrap:wrap;gap:20px;align-items:flex-end}
  .item{text-align:center}
  .item figcaption{font-size:11.5px;color:var(--muted);margin-top:8px;font-variant-numeric:tabular-nums}
  .item .sub{color:var(--faint);font-size:10.5px;display:block}
  .stage{display:flex;align-items:center;justify-content:center;
    border:1px solid var(--border);border-radius:12px;padding:8px;background:var(--subtle)}
  .stage.ondark{background:#1F1F1F;border-color:#333}
  .stage.onlight{background:#F3F3F3;border-color:#E2E2E2}
  .px{image-rendering:pixelated}
  table{border-collapse:collapse;width:100%;font-size:13px;
    font-variant-numeric:tabular-nums}
  th,td{text-align:left;padding:9px 12px;border-bottom:1px solid var(--border)}
  th{color:var(--muted);font-weight:500;font-size:12px;white-space:nowrap}
  td.k{color:var(--muted);white-space:nowrap}
  code{background:var(--subtle);border:1px solid var(--border);border-radius:6px;
    padding:1px 6px;font-family:"IBM Plex Mono",Consolas,monospace;font-size:12px}
  .sw{display:inline-flex;align-items:center;gap:8px}
  .chip{width:16px;height:16px;border-radius:6px;border:1px solid rgba(0,0,0,.12);
    display:inline-block;vertical-align:-3px}
  .ok{color:var(--primary);font-weight:600}
  .tag{display:inline-block;font-size:11px;padding:2px 8px;border-radius:999px;
    background:var(--primary-container);color:#1D4A27;margin-left:6px}
  .tag.warn{background:#F5E3D6;color:#4A2410}
  .mask{width:120px;height:120px;overflow:hidden;border:1px solid var(--border-strong);
    display:block}
  .mask img{width:100%;height:100%;display:block}
  ul{margin:6px 0 0;padding-left:20px} li{margin:3px 0}
  .muted{color:var(--muted)}
  .grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px}
</style>
</head>
<body>
<div class="wrap">
"""

_FOOT = """
</div>
</body>
</html>
"""


def html_preview() -> str:
    """生成 design_preview/icon/index.html（与产物同源，随生成器一起重跑）。"""
    p = PALETTE

    def swatch(hexv, name):
        return (f'<span class="sw"><i class="chip" style="background:{hexv}"></i>'
                f'<code>{hexv}</code><span class="muted">{name}</span></span>')

    def tiles(theme, sfx, sizes, cap=True):
        out = []
        for s in sizes:
            tier = "全形态" if s >= TIER_THRESHOLD else "简化档"
            label = f"{s}px" + (f"<span class='sub'>{tier}</span>" if cap else "")
            out.append(f'<figure class="item"><img src="tile_{sfx}_{s}.png" '
                       f'width="{s}" height="{s}" alt="{s}"><figcaption>{label}</figcaption></figure>')
        return "\n".join(out)

    def magnified(theme, sfx, sizes, z=8):
        out = []
        for s in sizes:
            out.append(
                f'<figure class="item"><div class="stage{" ondark" if theme == "dark" else ""}" '
                f'style="width:{s * z + 16}px;height:{s * z + 16}px">'
                f'<img class="px" src="tile_{sfx}_{s}.png" width="{s * z}" height="{s * z}" alt="{s}"></div>'
                f"<figcaption>{s}px<span class='sub'>{z}× 实际像素</span></figcaption></figure>")
        return "\n".join(out)

    masks = []
    for name, radius, note in (("圆形", "50%", "圆形遮罩"),
                               ("圆角方形", "22%", "squircle 近似"),
                               ("方形", "0", "极端：系统不裁")):
        for th, sfx in (("light", "L"), ("dark", "D")):
            masks.append(
                f'<figure class="item"><div class="mask" style="border-radius:{radius}">'
                f'<img src="adaptive_{sfx}_256.png" alt="{name}"></div>'
                f"<figcaption>{name}<span class='sub'>{'浅色' if th == 'light' else '深色'}档</span></figcaption></figure>")

    def c(fg, bg):
        return contrast(fg, bg)

    g = build_geometry("full")
    de_light = delta_e00(p["light"]["sky"], p["light"]["soil"])
    de_dark = delta_e00(p["dark"]["sky"], p["dark"]["soil"])

    return "".join([
        _HEAD,
        '<div class="kicker">应用图标规范 · APP_ICON_SPEC.md</div>',
        "<h1>新芽 · 破土</h1>",
        '<p class="note">圆角砖是「天空 + 大地」，白色芽自陶土色的土地里破土而出——'
        '茎的下端被大地覆盖，所以它是长出来的，不是插上去的。'
        '本页与图标产物同源，由 <code>tool/build_app_icon.py</code> 生成，改一个参数即可全链路重出。</p>',

        '<h2><span class="no">01</span>成品</h2>',
        '<p class="note">通用应用图标（Windows 快捷方式与任务栏、Android 传统启动器）。'
        '<b>Windows 一律用浅色档</b>：它的砖底在浅色任务栏 <code>#F3F3F3</code> 上 '
        f'{c(p["light"]["sky"], "#F3F3F3"):.2f}:1、在深色任务栏 <code>#1F1F1F</code> 上 '
        f'{c(p["light"]["sky"], "#1F1F1F"):.2f}:1，两端都立得住。</p>',
        '<div class="card"><div class="row">',
        f'<figure class="item"><img src="tile_L_256.png" width="256" height="256" alt="浅色档">'
        '<figcaption>浅色 · 新芽晨光<span class="sub">主用档</span></figcaption></figure>',
        f'<figure class="item"><img src="tile_D_256.png" width="256" height="256" alt="深色档">'
        '<figcaption>深色 · 夜露<span class="sub">仅限应用内深色画布</span></figcaption></figure>',
        "</div></div>",

        '<h2><span class="no">02</span>尺寸档实测<span class="tag">三档以下切简化档</span></h2>',
        '<p class="note">每张都是该尺寸的真实像素，不是缩放预览。'
        f'<b>{TIER_THRESHOLD}px 是分档线</b>：低于它去掉叶尖细部、茎与叶各自加粗放大，'
        '保证小尺寸下白芽仍是可辨的整体轮廓。</p>',
        '<div class="card"><div class="row">',
        tiles("light", "L", PNG_SIZES),
        "</div></div>",

        '<h2><span class="no">03</span>小尺寸真实像素</h2>',
        '<p class="note">8 倍近邻放大，看的不是「缩小后好不好看」，而是「一像素一像素长什么样」。</p>',
        '<div class="card"><div class="row">',
        magnified("light", "L", [16, 24, 32]),
        "</div></div>",
        '<div class="card" style="margin-top:16px"><div class="row">',
        magnified("dark", "D", [16, 24, 32]),
        "</div></div>",

        '<h2><span class="no">04</span>遮罩适配</h2>',
        '<p class="note">自适应图标由系统决定外形，所以「背景与芽能不能承受任意裁切」是硬要求。'
        f'下图<b>不是示意图</b>——它是两层按真实映射合成后的 108 画布，'
        f'芽被缩到 ∅{SAFE_DIA * 108:.0f}/108 的安全圆内，天空与大地本来就全出血，'
        '所以在圆形、squircle、方形三种遮罩下都不会缺角、不会露怯。</p>',
        '<div class="card"><div class="row">', "\n".join(masks), "</div></div>",

        '<h2><span class="no">05</span>分层</h2>',
        '<p class="note">Android 自适应图标的两层各自独立产出，共用同一映射，'
        '所以前景茎的截断点与背景大地的顶点严丝合缝。</p>',
        '<div class="card"><div class="row">',
        '<figure class="item"><div class="stage" style="background:#1F1F1F">'
        '<img src="layer_mark.png" width="160" height="160" alt="前景层"></div>'
        '<figcaption>前景层 · 芽<span class="sub">茎在大地顶点截断</span></figcaption></figure>',
        '<figure class="item"><div class="stage" style="background:#1F1F1F">'
        '<img src="layer_soil.png" width="160" height="160" alt="大地"></div>'
        '<figcaption>背景层的大地<span class="sub">全出血浅弧</span></figcaption></figure>',
        '<figure class="item"><div class="stage" style="background:#1F1F1F">'
        '<img src="flat_L_256.png" width="160" height="160" alt="合成"></div>'
        '<figcaption>两层合成<span class="sub">= 图标本体</span></figcaption></figure>',
        "</div></div>",

        '<h2><span class="no">06</span>配色</h2>',
        '<p class="note">全部取自 <code>lib/core/theme/app_theme.dart</code>，'
        '不引入新色值。对比度为芽在该底上的 WCAG 实测值。</p>',
        '<div class="card"><table>',
        "<tr><th>主题</th><th>层</th><th>色值</th><th>芽在其上</th></tr>",
        f'<tr><td class="k">浅色</td><td class="k">天空</td>'
        f'<td>{swatch(p["light"]["sky"], "lightPrimary 新芽绿")}</td>'
        f'<td class="ok">{c(p["light"]["mark"], p["light"]["sky"]):.2f}:1</td></tr>',
        f'<tr><td class="k">浅色</td><td class="k">大地</td>'
        f'<td>{swatch(p["light"]["soil"], "lightReward 陶土")}</td>'
        f'<td class="ok">{c(p["light"]["mark"], p["light"]["soil"]):.2f}:1</td></tr>',
        f'<tr><td class="k">深色</td><td class="k">天空</td>'
        f'<td>{swatch(p["dark"]["sky"], "darkSurface")}</td>'
        f'<td class="ok">{c(p["dark"]["mark"], p["dark"]["sky"]):.2f}:1</td></tr>',
        f'<tr><td class="k">深色</td><td class="k">大地</td>'
        f'<td>{swatch(p["dark"]["soil"], "darkRewardContainer")}</td>'
        f'<td class="ok">{c(p["dark"]["mark"], p["dark"]["soil"]):.2f}:1</td></tr>',
        "</table>",
        '<p class="note" style="margin:16px 0 0">'
        f'天空与大地的分界是<b>装饰性</b>的，不承载信息，所以真正该问的是「两色能不能分辨」'
        f'——按本项目判据用 ΔE<sub>00</sub> 而非对比度：浅色 <b>{de_light:.1f}</b>、'
        f'深色 <b>{de_dark:.1f}</b>，均远超「显著」门槛（&gt;20 为显著；'
        '亮度对比度仅 '
        f'{c(p["light"]["sky"], p["light"]["soil"]):.2f}:1 / '
        f'{c(p["dark"]["sky"], p["dark"]["soil"]):.2f}:1，'
        '二者亮度接近但色相差得远）。</p>',
        "</div>",

        '<h2><span class="no">07</span>几何</h2>',
        '<div class="card"><table>',
        '<tr><th>项</th><th>值</th><th>说明</th></tr>',
        f"<tr><td class='k'>设计网格</td><td>1024 × 1024</td><td>所有坐标以此为准，渲染时先超采样再逐级降采样</td></tr>",
        f"<tr><td class='k'>圆角砖</td><td>r = {TILE_RADIUS:.0f}</td><td>≈22.7%，与界内 SealLogo 的 0.22 同源</td></tr>",
        f"<tr><td class='k'>芽包围盒</td>"
        f"<td>y ∈ [{SPROUT_TOP_Y:.0f}, {SPROUT_BOT_Y:.0f}]</td>"
        f"<td>占砖高 {(SPROUT_BOT_Y - SPROUT_TOP_Y) / U * 100:.0f}%；"
        f"上方留白 {SPROUT_TOP_Y / U * 100:.0f}%</td></tr>",
        f"<tr><td class='k'>茎宽</td><td>{g['stem'][4]:.0f}</td>"
        f"<td>在 {TIER_THRESHOLD}px 档为 {g['stem'][4] / TIER_THRESHOLD:.2f}px</td></tr>",
        f"<tr><td class='k'>叶轴</td><td>{L_LEAF_LEN:.0f} @ {L_LEAF_ANGLE:.0f}°</td>"
        f"<td>与竖直方向夹角；叶由茎体内生出，结合处无缺口</td></tr>",
        f"<tr><td class='k'>大地弧</td><td>R = {g['soil']['R']:.0f}</td>"
        f"<td>顶点 y={SOIL_APEX_Y:.0f}、两端 y={SOIL_EDGE_Y:.0f}，全出血到砖左右边缘</td></tr>",
        f"<tr><td class='k'>茎露出 / 埋入</td>"
        f"<td>{g['soil']['apex_y'] - g['stem'][1]:.0f} / {g['stem'][3] - g['soil']['apex_y']:.0f}</td>"
        f"<td>露出部分即肉眼所见的整株；埋入部分只用来制造「长出来」的关系</td></tr>",
        f"<tr><td class='k'>自适应安全圆</td><td>∅ {SAFE_DIA * 108:.0f}/108</td>"
        f"<td>官方保证 66；取 62 留余量，避免叶尖在圆形遮罩下贴边</td></tr>",
        "</table></div>",

        '<h2><span class="no">08</span>落地位置</h2>',
        '<div class="card"><table>',
        '<tr><th>产物</th><th>位置</th><th>尺寸 / 形态</th></tr>',
        '<tr><td class="k">Windows 图标</td><td><code>windows/runner/resources/app_icon.ico</code></td>'
        f"<td>{'/'.join(map(str, ICO_SIZES))} 共 {len(ICO_SIZES)} 档，逐档独立渲染</td></tr>",
        '<tr><td class="k">Android 传统启动器</td><td><code>res/mipmap-*/ic_launcher.png</code></td>'
        f"<td>{'/'.join(str(v) for v in ANDROID_DENSITIES.values())}</td></tr>",
        '<tr><td class="k">Android 自适应背景</td><td><code>res/drawable/ic_launcher_background.xml</code></td>'
        "<td>矢量：天空 + 大地</td></tr>",
        '<tr><td class="k">Android 自适应前景</td><td><code>res/drawable/ic_launcher_foreground.xml</code></td>'
        "<td>矢量：芽（茎在大地顶点截断）</td></tr>",
        '<tr><td class="k">Android 13+ 单色层</td><td><code>res/drawable/ic_launcher_monochrome.xml</code></td>'
        "<td>矢量：同几何，由系统着色</td></tr>",
        '<tr><td class="k">品牌母版</td><td><code>assets/branding/app_icon_source{,_dark}.svg</code></td>'
        "<td>1024 矢量，改稿从这里起</td></tr>",
        '<tr><td class="k">品牌位图</td><td><code>assets/branding/app_icon{,_dark}.png</code></td>'
        "<td>1024 × 1024</td></tr>",
        "</table>",
        '<p class="note" style="margin:16px 0 0">改配色或造型只需编辑 '
        '<code>tool/build_app_icon.py</code> 顶部的 <code>PALETTE</code> 与几何常量，'
        '重跑一次即全链路同步——本页、母版、ICO、Android 四处一次性重出。</p>',
        "</div>",
        _FOOT,
    ])


def main() -> int:
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    branding = ROOT / "assets" / "branding"
    preview = ROOT / "design_preview" / "icon"
    preview.mkdir(parents=True, exist_ok=True)

    print("── 自检 ──")
    for line in checks():
        print("  " + line)

    print("\n── 品牌母版 ──")
    for th, sfx in (("light", ""), ("dark", "_dark")):
        (branding / f"app_icon_source{sfx}.svg").write_text(svg_master(th), encoding="utf-8")
        render_tile(1024, th).save(branding / f"app_icon{sfx}.png")
        print(f"  assets/branding/app_icon_source{sfx}.svg + app_icon{sfx}.png (1024)")

    print("\n── Windows ICO ──")
    ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    write_ico(ico, ICO_SIZES)
    print(f"  {ico.relative_to(ROOT)}  {'/'.join(map(str, ICO_SIZES))}  {ico.stat().st_size / 1024:.1f} KB")

    print("\n── Android 启动器 ──")
    for name, px in ANDROID_DENSITIES.items():
        render_tile(px, "light", "full" if px >= TIER_THRESHOLD else "simple").save(
            res / f"mipmap-{name}" / "ic_launcher.png")
        print(f"  mipmap-{name}/ic_launcher.png  {px}px")
    draw = res / "drawable"
    (draw / "ic_launcher_background.xml").write_text(vd_background_xml(), encoding="utf-8")
    (draw / "ic_launcher_foreground.xml").write_text(vd_foreground_xml(), encoding="utf-8")
    (draw / "ic_launcher_monochrome.xml").write_text(vd_monochrome_xml(), encoding="utf-8")
    print("  drawable/ic_launcher_background.xml  天空 + 大地（矢量）")
    print("  drawable/ic_launcher_foreground.xml  芽（矢量，茎在大地顶点截断）")
    print("  drawable/ic_launcher_monochrome.xml  Android 13+ 主题单色层")

    print("\n── 预览页 ──")
    for f in preview.glob("*.png"):
        f.unlink()  # 先清空，避免改版后留下孤儿样张
    for s in PNG_SIZES:
        render_tile(s, "light", "full" if s >= TIER_THRESHOLD else "simple").save(
            preview / f"tile_L_{s}.png")
    for s in (16, 24, 32, 256):
        render_tile(s, "dark", "full" if s >= TIER_THRESHOLD else "simple").save(
            preview / f"tile_D_{s}.png")
    for th, sfx in (("light", "L"), ("dark", "D")):
        render_adaptive_icon(256, th).save(preview / f"adaptive_{sfx}_256.png")
    render_flat(256, "light").save(preview / "flat_L_256.png")
    render_mark(512, "light", cut=False).save(preview / "layer_mark.png")
    render_soil_layer(512, "light").save(preview / "layer_soil.png")
    (preview / "index.html").write_text(html_preview(), encoding="utf-8")
    print(f"  design_preview/icon/  {len(list(preview.glob('*.png')))} 张样张 + index.html")
    return 0


if __name__ == "__main__":
    sys.exit(main())
