# -*- coding: utf-8 -*-
"""准备「方案 C 形态落地」对照页所需的图片资源。

源稿 scheme_c_sprout.png 是 1440×900，画面里并排两部手机。这里用暗色像素
的列/行投影自动框出两部手机，避免手写坐标在换图后失效。
"""
import io
import os
import shutil

from PIL import Image

ROOT = r"D:\Project\个人工作台"
SPEC = os.path.join(ROOT, r"design_preview\green_schemes\scheme_c_sprout.png")
OUT = os.path.join(ROOT, r"design_preview\green_schemes\before_after")
os.makedirs(OUT, exist_ok=True)

img = Image.open(SPEC).convert("RGB")
w, h = img.size
px = img.load()


def is_dark(x, y):
    r, g, b = px[x, y]
    return r < 90 and g < 90 and b < 90


# 列投影 → 手机的深色边框是「整列几乎全暗」，屏幕内部几乎全亮。
# 取整列命中数很高的列，按间隔聚类；每部手机贡献左右两条边。
col_hits = [sum(1 for y in range(h) if is_dark(x, y)) for x in range(w)]
threshold = h * 0.55
edge_cols = [x for x, hits in enumerate(col_hits) if hits >= threshold]

clusters = []
for x in edge_cols:
    if clusters and x - clusters[-1][-1] <= 24:
        clusters[-1].append(x)
    else:
        clusters.append([x])

if len(clusters) < 4:
    raise SystemExit("未能自动框出两部手机，边框列簇 = %r" % (clusters,))

phones = [
    (clusters[0][0], clusters[1][-1]),
    (clusters[2][0], clusters[3][-1]),
]
print("column clusters:", clusters)
print("phones:", phones)

for index, (x0, x1) in enumerate(phones):
    row_hits = [
        sum(1 for x in range(x0, x1) if is_dark(x, y)) for y in range(h)
    ]
    ys = [y for y, hits in enumerate(row_hits) if hits >= 20]
    y0, y1 = ys[0], ys[-1]
    pad = 6
    box = (max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad))
    crop = img.crop(box)
    name = "spec_phone1_capture.png" if index == 0 else "spec_phone2_today.png"
    crop.save(os.path.join(OUT, name))
    print(name, box, crop.size)


def copy_golden(src, dst):
    shutil.copyfile(os.path.join(ROOT, src), os.path.join(OUT, dst))
    print("copied", dst, Image.open(os.path.join(OUT, dst)).size)


GOLDENS = [
    (r"test\goldens\android_today.png", "real_today.png"),
    (r"test\goldens\android_capture_sheet.png", "real_capture.png"),
    # 桌面端「改后」= 当前 golden。
    (r"test\goldens\wide_today_light.png", "after_desktop_today_light.png"),
    (r"test\goldens\wide_today_dark.png", "after_desktop_today_dark.png"),
    (r"test\goldens\ui_audit\plan_desktop.png", "after_desktop_plan.png"),
    (r"test\goldens\wide_shell_today_light.png", "after_desktop_sidebar.png"),
]

for src, dst in GOLDENS:
    copy_golden(src, dst)


# ── 桌面端派生对照图 ──────────────────────────────────────────────
# 「改前」三张（before_desktop_today_light / _dark / plan、before_desktop_sidebar）
# 是**冻结资产**：它们拍的是改造前的代码，无法再由当前仓库重现，
# 不要删除也不要覆盖。下面只从「改前冻图 + 改后 golden」派生出放大图。
def build_desktop_derivatives():
    before_light = os.path.join(OUT, "before_desktop_today_light.png")
    after_light = os.path.join(OUT, "after_desktop_today_light.png")
    if not (os.path.exists(before_light) and os.path.exists(after_light)):
        print("跳过派生图：改前冻图或改后 golden 缺失")
        return

    bef = Image.open(before_light).convert("RGB")
    aft = Image.open(after_light).convert("RGB")

    # 页头对照：同一区域各裁一次，放大 3 倍才看得清那条 3px 竖条。
    box = (14, 2, 430, 74)
    size = ((box[2] - box[0]) * 3, (box[3] - box[1]) * 3)
    for img, name in ((bef, "zoom_head_before.png"), (aft, "zoom_head_after.png")):
        img.crop(box).resize(size, Image.LANCZOS).save(os.path.join(OUT, name))
        print(name, size)

    # 概览卡只存在于「改后」，没有对照侧。
    ov = aft.crop((140, 95, 660, 196))
    ov.resize((ov.width * 2, ov.height * 2), Image.LANCZOS).save(
        os.path.join(OUT, "zoom_overview_after.png")
    )
    print("zoom_overview_after.png", (ov.width * 2, ov.height * 2))

    # 侧栏：只取「品牌块」与「页脚」两段，中间 630px 与本次改动无关。
    o = os.path.join(OUT, "before_desktop_sidebar.png")
    r = os.path.join(OUT, "after_desktop_sidebar.png")
    if not (os.path.exists(o) and os.path.exists(r)):
        print("跳过侧栏条带图：缺少 before_desktop_sidebar.png")
        return
    oi, ri = Image.open(o).convert("RGB"), Image.open(r).convert("RGB")
    bands, gap = [(0, 112), (746, 864)], 16
    canvas = Image.new(
        "RGB",
        (240 * 2 + gap, sum(b - a for a, b in bands) + gap * len(bands)),
        (223, 235, 225),  # panelBorder，用作分隔底色
    )
    y = 0
    for a, b in bands:
        canvas.paste(oi.crop((0, a, 240, b)), (0, y))
        canvas.paste(ri.crop((0, a, 240, b)), (240 + gap, y))
        y += b - a + gap
    canvas = canvas.resize((int(canvas.width * 1.7), int(canvas.height * 1.7)), Image.LANCZOS)
    canvas.save(os.path.join(OUT, "zoom_sidebar_bands.png"))
    print("zoom_sidebar_bands.png", canvas.size)


build_desktop_derivatives()
print("done")
