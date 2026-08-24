from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
OUT = ROOT
SCALE = 2
WIDTH, HEIGHT = 1536, 864


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        r"C:\Windows\Fonts\msyhbd.ttc" if bold else r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\simhei.ttf",
        r"C:\Windows\Fonts\segoeui.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size * SCALE)
    return ImageFont.load_default()


def sc(value: float) -> int:
    return int(round(value * SCALE))


def box(values: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    return tuple(sc(value) for value in values)  # type: ignore[return-value]


def draw_text(draw: ImageDraw.ImageDraw, xy: tuple[float, float], value: str,
              size: int, fill: tuple[int, int, int, int], bold: bool = False,
              anchor: str | None = None) -> None:
    draw.text((sc(xy[0]), sc(xy[1])), value, font=font(size, bold), fill=fill,
              anchor=anchor)


def rounded(draw: ImageDraw.ImageDraw, values: tuple[float, float, float, float],
            radius: float, fill: tuple[int, int, int, int],
            outline: tuple[int, int, int, int] | None = None, width: int = 1) -> None:
    draw.rounded_rectangle(box(values), radius=sc(radius), fill=fill,
                           outline=outline, width=sc(width) if outline else 1)


def line(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]],
         fill: tuple[int, int, int, int], width: int = 1) -> None:
    draw.line([(sc(x), sc(y)) for x, y in points], fill=fill, width=sc(width), joint="curve")


def render(theme: str, output: Path) -> None:
    dark = theme == "dark"
    if dark:
        colors = {
            "canvas": (7, 27, 20, 255), "canvas_alt": (11, 36, 27, 255),
            "ink": (229, 243, 234, 255), "muted": (154, 183, 170, 255),
            "faint": (113, 148, 133, 255), "line": (95, 163, 132, 75),
            "line_strong": (98, 220, 163, 255), "glass": (18, 53, 41, 255),
            "glass_strong": (26, 62, 48, 255), "glass_soft": (18, 58, 43, 255),
            "primary": (94, 224, 168, 255), "primary_strong": (152, 240, 200, 255),
            "primary_soft": (30, 82, 61, 255), "success": (99, 221, 176, 255),
            "warn": (231, 182, 106, 255), "white": (238, 250, 243, 255),
        }
    else:
        colors = {
            "canvas": (234, 245, 239, 255), "canvas_alt": (244, 251, 247, 255),
            "ink": (23, 53, 42, 255), "muted": (105, 128, 119, 255),
            "faint": (145, 167, 158, 255), "line": (34, 110, 78, 42),
            "line_strong": (22, 142, 91, 255), "glass": (249, 253, 250, 255),
            "glass_strong": (255, 255, 255, 255), "glass_soft": (226, 244, 235, 255),
            "primary": (21, 151, 101, 255), "primary_strong": (8, 119, 73, 255),
            "primary_soft": (216, 241, 226, 255), "success": (26, 157, 114, 255),
            "warn": (198, 132, 47, 255), "white": (255, 255, 255, 255),
        }

    image = Image.new("RGBA", (sc(WIDTH), sc(HEIGHT)), colors["canvas"])
    draw = ImageDraw.Draw(image, "RGBA")

    # Quiet full-canvas tint: no decorative orbs, only low-contrast tonal shifts.
    rounded(draw, (0, 0, WIDTH, HEIGHT * 0.42), 0, colors["canvas_alt"])
    line(draw, [(0, 80), (WIDTH, 80)], colors["line"], 1)
    line(draw, [(0, HEIGHT - 18), (WIDTH, HEIGHT - 18)], colors["line"], 1)

    sidebar_w = 236
    rounded(draw, (0, 0, sidebar_w, HEIGHT), 0, colors["glass"], colors["line"], 1)
    line(draw, [(sidebar_w, 0), (sidebar_w, HEIGHT)], colors["line"], 1)

    def nav_item(y: float, label: str, glyph: str, active: bool = False) -> None:
        if active:
            rounded(draw, (14, y, 222, y + 42), 6, colors["primary_soft"], colors["line_strong"], 1)
        draw_text(draw, (32, y + 21), glyph, 17, colors["primary_strong"] if active else colors["muted"], anchor="mm")
        draw_text(draw, (52, y + 21), label, 13, colors["primary_strong"] if active else colors["muted"], active, "lm")

    rounded(draw, (24, 22, 58, 56), 10, colors["primary_soft"], colors["line_strong"], 1)
    draw_text(draw, (41, 39), "PW", 12, colors["primary_strong"], True, "mm")
    draw_text(draw, (72, 25), "个人工作台", 15, colors["ink"], True)
    draw_text(draw, (72, 47), "本地优先 · 演示工作区", 11, colors["muted"])

    draw_text(draw, (26, 92), "工作台", 10, colors["faint"], True)
    nav_item(106, "今日", "⌂", True)
    nav_item(150, "任务", "□")
    nav_item(194, "计划", "◷")
    nav_item(238, "项目", "▦")
    nav_item(282, "专注", "◉")
    draw_text(draw, (26, 348), "记录与回顾", 10, colors["faint"], True)
    nav_item(362, "笔记", "▤")
    nav_item(406, "日记", "◫")
    nav_item(450, "回顾", "⌁")
    draw_text(draw, (26, 516), "成长", 10, colors["faint"], True)
    nav_item(530, "目标", "◇")
    nav_item(574, "习惯", "○")
    nav_item(618, "成长", "↗")
    line(draw, [(24, 776), (212, 776)], colors["line"], 1)
    rounded(draw, (28, 799, 36, 807), 4, colors["success"])
    draw_text(draw, (48, 796), "已同步 · 本地可用", 12, colors["muted"])
    nav_item(816, "设置", "⚙")

    content_x = sidebar_w + 24
    content_right = WIDTH - 24
    rounded(draw, (content_x, 18, content_right, 76), 8, colors["glass"], colors["line"], 1)
    draw_text(draw, (content_x + 18, 47), "今日", 14, colors["ink"], True, "lm")
    draw_text(draw, (content_x + 63, 47), "/", 12, colors["faint"], anchor="lm")
    draw_text(draw, (content_x + 79, 47), "执行工作台", 12, colors["muted"], anchor="lm")
    rounded(draw, (content_right - 260, 31, content_right - 166, 63), 16, colors["glass_soft"], colors["line"], 1)
    rounded(draw, (content_right - 248, 43, content_right - 240, 51), 4, colors["success"])
    draw_text(draw, (content_right - 230, 47), "刚刚同步", 11, colors["muted"], anchor="lm")
    for x, glyph in [(content_right - 142, "⌕"), (content_right - 101, "◐")]:
        rounded(draw, (x, 28, x + 36, 66), 6, colors["glass_soft"], colors["line"], 1)
        draw_text(draw, (x + 18, 47), glyph, 18, colors["muted"], anchor="mm")
    rounded(draw, (content_right - 57, 28, content_right, 66), 6, colors["primary"], None)
    draw_text(draw, (content_right - 28, 47), "+  快速新增", 12, colors["white"], True, "mm")

    draw_text(draw, (content_x + 2, 111), "MONDAY · 08/23", 11, colors["primary"], True)
    draw_text(draw, (content_x + 2, 136), "今天，先完成最重要的三件事", 28, colors["ink"], True)
    draw_text(draw, (content_x + 2, 172), "把注意力留给当前这一项，其他安排会在时间线上等你。", 13, colors["muted"])
    rounded(draw, (content_right - 300, 125, content_right - 145, 157), 6, colors["glass_soft"], colors["line"], 1)
    draw_text(draw, (content_right - 222, 141), "2026年8月23日 · 星期日", 11, colors["muted"], anchor="mm")
    rounded(draw, (content_right - 136, 125, content_right, 157), 6, colors["glass_soft"], colors["line"], 1)
    draw_text(draw, (content_right - 68, 141), "完成度 2 / 6", 11, colors["muted"], anchor="mm")

    main_x, main_w, rail_w, gap = content_x, 820, 306, 16
    rail_x = main_x + main_w + gap

    def panel(x: float, y: float, w: float, h: float, strong: bool = False, accent: bool = False) -> None:
        fill = colors["primary_soft"] if accent else (colors["glass_strong"] if strong else colors["glass"])
        outline = colors["line_strong"] if accent else colors["line"]
        rounded(draw, (x, y, x + w, y + h), 8, fill, outline, 1)

    def panel_title(x: float, y: float, title: str, right: str, panel_width: float) -> None:
        rounded(draw, (x, y + 1, x + 3, y + 18), 2, colors["primary"])
        draw_text(draw, (x + 12, y), title, 15, colors["ink"], True)
        draw_text(draw, (x + panel_width - 16, y + 1), right, 11, colors["muted"], anchor="ra")

    panel(main_x, 196, main_w, 156)
    panel_title(main_x + 16, 214, "今日重点", "已锁定 3 项", main_w)
    card_y, card_w = 244, 246
    commitment_data = [
        ("01 · 进行中", "整理本周实验笔记", "专注 45 分钟 · 光学仿真", True, False),
        ("02 · 待开始", "完成论文图表的误差分析", "预计 60 分钟 · 下午时间块", False, False),
        ("03 · 已完成", "清理收集箱中的待处理记录", "完成于 09:20 · 执行记录", False, True),
    ]
    for index, (meta, title, sub, active, done) in enumerate(commitment_data):
        x = main_x + 16 + index * (card_w + 10)
        fill = colors["primary_soft"] if active else (colors["glass_soft"] if not done else colors["glass"])
        outline = colors["line_strong"] if active else colors["line"]
        rounded(draw, (x, card_y, x + card_w, 336), 6, fill, outline, 1)
        draw_text(draw, (x + 12, card_y + 12), meta, 11, colors["muted"])
        draw_text(draw, (x + card_w - 14, card_y + 11), "◉" if active else ("✓" if done else "○"), 17, colors["primary" if active or done else "muted"], anchor="ra")
        draw_text(draw, (x + 12, card_y + 44), title, 13, colors["ink"], True)
        draw_text(draw, (x + 12, card_y + 76), sub, 11, colors["muted"])

    panel(main_x, 368, main_w, 108, accent=True)
    panel_title(main_x + 16, 387, "下一时间块", "距离开始 18 分钟", main_w)
    draw_text(draw, (main_x + 18, 429), "14:00", 15, colors["primary_strong"], True)
    draw_text(draw, (main_x + 98, 420), "论文图表的误差分析", 13, colors["ink"], True)
    draw_text(draw, (main_x + 98, 443), "60 分钟 · 安静工作 · 与当前重点关联", 11, colors["muted"])
    rounded(draw, (main_x + main_w - 122, 421, main_x + main_w - 16, 455), 5, colors["glass_strong"], colors["line"], 1)
    draw_text(draw, (main_x + main_w - 69, 438), "安排专注", 11, colors["primary_strong"], True, "mm")

    panel(main_x, 492, main_w, 328, strong=True)
    panel_title(main_x + 16, 511, "今日时间线", "进行中   已完成   待开始", main_w)
    timeline = [("09:00", "整理本周实验笔记", "45 分钟 · 当前专注任务", "进行中", colors["primary"]),
                ("11:00", "回顾今日计划并清理收集箱", "30 分钟 · 已留下执行记录", "已完成", colors["success"]),
                ("14:00", "论文图表的误差分析", "60 分钟 · 下午时间块", "待开始", colors["faint"]),
                ("16:30", "记录今天的实验观察", "20 分钟 · 日记与回顾", "待开始", colors["faint"])]
    y = 554
    for time_value, title, sub, status, dot_color in timeline:
        draw_text(draw, (main_x + 18, y), time_value, 11, colors["muted"])
        line(draw, [(main_x + 78, y - 2), (main_x + 78, y + 58)], colors["line"], 1)
        rounded(draw, (main_x + 74, y + 1, main_x + 82, y + 9), 4, dot_color)
        draw_text(draw, (main_x + 100, y - 2), title, 13, colors["ink"], True)
        draw_text(draw, (main_x + 100, y + 21), sub, 11, colors["muted"])
        rounded(draw, (main_x + 100, y + 43, main_x + 154, y + 64), 4, colors["primary_soft"], colors["line"], 1)
        draw_text(draw, (main_x + 127, y + 53), status, 10, colors["primary_strong" if status == "进行中" else "muted"], anchor="mm")
        y += 68

    panel(rail_x, 196, rail_w, 204)
    panel_title(rail_x + 16, 214, "习惯摘要", "今天 4 / 5", rail_w)
    rounded(draw, (rail_x + 16, 246, rail_x + rail_w - 50, 253), 4, colors["primary_soft"])
    rounded(draw, (rail_x + 16, 246, rail_x + rail_w - 90, 253), 4, colors["primary"])
    draw_text(draw, (rail_x + rail_w - 16, 240), "80%", 12, colors["primary_strong"], True, "ra")
    habits = [("晨间拉伸", "4d", 4), ("阅读 20 分钟", "2d", 2), ("记录实验观察", "4d", 4)]
    y = 283
    for name, days, count in habits:
        draw_text(draw, (rail_x + 16, y), name, 12, colors["ink"])
        for index in range(4):
            fill = colors["primary"] if index < count else colors["primary_soft"]
            rounded(draw, (rail_x + 150 + index * 21, y - 1, rail_x + 166 + index * 21, y + 15), 4, fill, colors["line"], 1)
        draw_text(draw, (rail_x + rail_w - 16, y), days, 11, colors["muted"], anchor="ra")
        y += 34

    panel(rail_x, 416, rail_w, 164)
    panel_title(rail_x + 16, 434, "每日收尾", "未完成 2 项", rail_w)
    draw_text(draw, (rail_x + 16, 474), "已完成重点", 12, colors["muted"])
    draw_text(draw, (rail_x + rail_w - 16, 474), "2 / 3", 13, colors["ink"], True, "ra")
    draw_text(draw, (rail_x + 16, 503), "待处理承诺", 12, colors["muted"])
    draw_text(draw, (rail_x + rail_w - 16, 503), "2 项", 13, colors["ink"], True, "ra")
    rounded(draw, (rail_x + 16, 535, rail_x + rail_w - 16, 570), 6, colors["primary_soft"], colors["line_strong"], 1)
    draw_text(draw, (rail_x + rail_w / 2, 552), "查看收尾清单", 12, colors["primary_strong"], True, "mm")

    panel(rail_x, 596, rail_w, 224, accent=True)
    panel_title(rail_x + 16, 614, "当前节奏", "稳定", rail_w)
    draw_text(draw, (rail_x + 16, 655), "专注正在进行。下一次切换前，", 13, colors["ink"])
    draw_text(draw, (rail_x + 16, 678), "还有足够时间把这一项收好。", 13, colors["ink"])
    rounded(draw, (rail_x + 16, 722, rail_x + rail_w - 16, 760), 6, colors["primary"], None)
    draw_text(draw, (rail_x + rail_w / 2, 741), "打开专注计时", 12, colors["white"], True, "mm")
    draw_text(draw, (rail_x + 16, 789), "状态反馈同时使用文字、图标和颜色。", 11, colors["muted"])

    image = image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS).convert("RGB")
    image.save(output, quality=95)


if __name__ == "__main__":
    render("light", OUT / "glass_today_light.png")
    render("dark", OUT / "glass_today_dark.png")
    print(f"generated: {OUT / 'glass_today_light.png'}")
    print(f"generated: {OUT / 'glass_today_dark.png'}")
