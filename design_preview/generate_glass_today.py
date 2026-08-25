from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent
SCALE = 2
WIDTH, HEIGHT = 1536, 864
FONT_DIR = PROJECT / "assets" / "fonts"


def sc(value: float) -> int:
    return round(value * SCALE)


def font(size: int, role: str = "body") -> ImageFont.FreeTypeFont:
    filename = {
        "display": "LXGWWenKaiGB-Medium.ttf",
        "body": "IBMPlexSansSC-Regular.otf",
        "medium": "IBMPlexSansSC-Medium.otf",
        "mono": "IBMPlexMono-Medium.ttf",
    }[role]
    return ImageFont.truetype(FONT_DIR / filename, sc(size))


def rect(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float, float, float],
    fill: str,
    *,
    radius: float = 0,
    outline: str | None = None,
    width: int = 1,
) -> None:
    box = tuple(sc(value) for value in xy)
    draw.rounded_rectangle(
        box,
        radius=sc(radius),
        fill=fill,
        outline=outline,
        width=sc(width) if outline else 1,
    )


def text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    value: str,
    size: int,
    fill: str,
    *,
    role: str = "body",
    anchor: str | None = None,
) -> None:
    draw.text(
        (sc(xy[0]), sc(xy[1])),
        value,
        font=font(size, role),
        fill=fill,
        anchor=anchor,
    )


def render(theme: str, output: Path) -> None:
    dark = theme == "dark"
    colors = {
        "canvas": "#101614" if dark else "#F1F4F2",
        "surface": "#18211E" if dark else "#FAFBF9",
        "raised": "#202B27" if dark else "#FFFFFF",
        "subtle": "#253431" if dark else "#E8EFED",
        "ink": "#E9EFEB" if dark else "#1B2521",
        "muted": "#A5B4AE" if dark else "#687772",
        "divider": "#34433E" if dark else "#D5DEDA",
        "route": "#64B3BC" if dark else "#256B73",
        "route_soft": "#203F43" if dark else "#DCECEF",
        "signal": "#F07A6F" if dark else "#C84F45",
        "marker": "#DDB65B" if dark else "#B8862D",
    }
    image = Image.new("RGB", (sc(WIDTH), sc(HEIGHT)), colors["canvas"])
    draw = ImageDraw.Draw(image)

    sidebar_w = 236
    rect(draw, (0, 0, sidebar_w, HEIGHT), colors["surface"])
    draw.line((sc(sidebar_w), 0, sc(sidebar_w), sc(HEIGHT)), fill=colors["divider"], width=sc(1))

    icon_path = PROJECT / "assets" / "branding" / "app_icon.png"
    icon = Image.open(icon_path).convert("RGB").resize((sc(34), sc(34)))
    image.paste(icon, (sc(18), sc(16)))
    text(draw, (64, 22), "个人工作台", 15, colors["ink"], role="display")
    text(draw, (64, 43), "纯本地模式", 11, colors["muted"])
    draw.line((sc(0), sc(66), sc(sidebar_w), sc(66)), fill=colors["divider"], width=sc(1))

    rect(draw, (14, 82, 222, 118), colors["route"], radius=4)
    text(draw, (118, 100), "＋  快速新增", 12, "#FFFFFF", role="medium", anchor="mm")
    text(draw, (24, 144), "工作索引", 10, colors["muted"], role="medium")
    nav = ["今日", "任务", "项目", "专注", "笔记", "回顾", "行为", "成长", "自律", "设置"]
    for index, label in enumerate(nav):
        y = 162 + index * 42
        if index == 0:
            rect(draw, (12, y, 224, y + 36), colors["route_soft"], radius=4)
            rect(draw, (12, y + 8, 15, y + 28), colors["route"], radius=1)
        text(draw, (30, y + 18), label, 13, colors["route"] if index == 0 else colors["muted"], role="medium" if index == 0 else "body", anchor="lm")
    draw.line((sc(14), sc(806), sc(222), sc(806)), fill=colors["divider"], width=sc(1))
    text(draw, (24, 828), "本地数据可用", 11, colors["muted"])

    content_x = sidebar_w
    rect(draw, (content_x, 0, WIDTH, 74), colors["surface"])
    draw.line((sc(content_x), sc(74), sc(WIDTH), sc(74)), fill=colors["divider"], width=sc(1))
    rect(draw, (260, 20, 263, 54), colors["route"], radius=1)
    text(draw, (278, 25), "今日", 23, colors["ink"], role="display")
    text(draw, (278, 53), "2026年8月7日 · 星期五", 11, colors["muted"])
    rect(draw, (1350, 20, 1440, 55), colors["canvas"], radius=4, outline=colors["divider"])
    text(draw, (1395, 38), "搜索", 12, colors["muted"], anchor="mm")
    rect(draw, (1448, 20, 1512, 55), colors["route"], radius=4)
    text(draw, (1480, 38), "新增", 12, "#FFFFFF", role="medium", anchor="mm")

    main_x = 260
    aside_x = 1230
    draw.line((sc(aside_x), sc(74), sc(aside_x), sc(HEIGHT)), fill=colors["divider"], width=sc(1))
    text(draw, (main_x, 102), "今日重点", 18, colors["ink"], role="display")
    text(draw, (1198, 106), "已锁定 3 项", 11, colors["route"], anchor="ra")

    tasks = [
        ("01 · 已完成", "整理衍射实验数据与误差记录", "预计 50 分钟 · 证据已记录", "marker"),
        ("02 · 进行中", "校对论文图 3 的坐标轴与单位", "预计 35 分钟 · 当前重点", "route"),
        ("03 · 待开始", "阅读角谱传播采样条件笔记", "预计 25 分钟", "muted"),
    ]
    card_w = 300
    for index, (state, title, detail, accent) in enumerate(tasks):
        x = main_x + index * (card_w + 12)
        rect(draw, (x, 136, x + card_w, 250), colors["surface"], radius=6, outline=colors["divider"])
        rect(draw, (x, 136, x + 3, 250), colors[accent], radius=1)
        text(draw, (x + 16, 151), state, 11, colors["muted"])
        text(draw, (x + 16, 184), title, 13, colors["ink"], role="medium")
        text(draw, (x + 16, 221), detail, 11, colors["muted"])

    text(draw, (main_x, 284), "下一时间块", 18, colors["ink"], role="display")
    draw.line((sc(main_x), sc(320), sc(1198), sc(320)), fill=colors["divider"], width=sc(1))
    text(draw, (main_x, 344), "14:00", 13, colors["route"], role="mono")
    text(draw, (main_x + 76, 340), "文献阅读", 13, colors["ink"], role="medium")
    text(draw, (main_x + 76, 364), "50 分钟 · 与今日重点关联", 11, colors["muted"])
    rect(draw, (1090, 334, 1198, 368), colors["surface"], radius=4, outline=colors["divider"])
    text(draw, (1144, 351), "安排专注", 11, colors["route"], anchor="mm")
    draw.line((sc(main_x), sc(388), sc(1198), sc(388)), fill=colors["divider"], width=sc(1))

    text(draw, (main_x, 424), "今日时间线", 18, colors["ink"], role="display")
    timeline = [
        ("09:00", "实验数据清洗", "90 分钟 · 已完成", "marker", "✓"),
        ("10:00", "论文图复核", "75 分钟 · 时间冲突", "signal", "!"),
        ("14:00", "文献阅读", "50 分钟 · 进行中", "route", "●"),
    ]
    rail_x = main_x + 12
    draw.line((sc(rail_x + 8), sc(474), sc(rail_x + 8), sc(684)), fill=colors["divider"], width=sc(1))
    for index, (time_value, title, detail, status_color, symbol) in enumerate(timeline):
        y = 474 + index * 78
        rect(draw, (rail_x, y, rail_x + 17, y + 17), colors["surface"], radius=9, outline=colors[status_color], width=2)
        text(draw, (rail_x + 8.5, y + 8.5), symbol, 8, colors[status_color], role="medium", anchor="mm")
        text(draw, (rail_x + 34, y - 1), title, 13, colors["ink"], role="medium")
        text(draw, (rail_x + 34, y + 25), time_value, 11, colors["route"], role="mono")
        text(draw, (rail_x + 92, y + 25), detail, 11, colors["muted"])

    aside_left = aside_x + 20
    text(draw, (aside_left, 104), "执行证据", 17, colors["ink"], role="display")
    text(draw, (aside_left, 150), "01 / 03", 26, colors["marker"], role="mono")
    text(draw, (aside_left, 184), "今日承诺", 11, colors["muted"])
    draw.line((sc(aside_left), sc(210), sc(1514), sc(210)), fill=colors["divider"], width=sc(1))
    facts = [("完成承诺 1", "+20 XP"), ("完成计分习惯", "+5 XP")]
    for index, (label, value) in enumerate(facts):
        y = 235 + index * 46
        text(draw, (aside_left, y), label, 11, colors["muted"])
        text(draw, (1514, y), value, 11, colors["ink"], role="mono", anchor="ra")
        draw.line((sc(aside_left), sc(y + 28), sc(1514), sc(y + 28)), fill=colors["divider"], width=sc(1))
    text(draw, (aside_left, 366), "每日收尾", 17, colors["ink"], role="display")
    text(draw, (aside_left, 408), "今日尚未日结", 13, colors["ink"], role="medium")
    text(draw, (aside_left, 438), "处理剩余事项，并为明天", 11, colors["muted"])
    text(draw, (aside_left, 458), "留下清晰起点。", 11, colors["muted"])
    rect(draw, (aside_left, 492, 1514, 530), colors["surface"], radius=4, outline=colors["divider"])
    text(draw, ((aside_left + 1514) / 2, 511), "查看清单", 12, colors["route"], role="medium", anchor="mm")

    image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS).save(output)


if __name__ == "__main__":
    render("light", ROOT / "glass_today_light.png")
    render("dark", ROOT / "glass_today_dark.png")
    print("generated theme acceptance PNGs")
