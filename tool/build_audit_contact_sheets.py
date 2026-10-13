"""Assemble ten 35-page audit overviews from current golden images."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
GOLDENS = ROOT / "test" / "goldens" / "ui_audit"
OUTPUT = ROOT / "docs" / "jade-redesign" / "screenshots"
FONT = ROOT / "assets" / "fonts" / "IBMPlexSansSC-Regular.otf"
SIZES = {
    "320x568_text200": (5, 220, 370, 195, 346),
    "390x568": (7, 209, 320, 195, 284),
    "800x450_text200": (5, 297, 198, 273, 154),
    "800x450": (5, 297, 198, 273, 154),
    "1200x900": (5, 314, 261, 290, 218),
}


def render(theme: str, size: str) -> None:
    columns, cell_width, cell_height, thumb_width, thumb_height = SIZES[size]
    files = sorted(GOLDENS.glob(f"matrix_*_{theme}_{size}.png"))
    if len(files) != 35:
        raise ValueError(f"Expected 35 {theme} {size} screenshots, got {len(files)}")
    background = "#e8eee9" if theme == "light" else "#1c342c"
    foreground = "#334b40" if theme == "light" else "#dcebe1"
    rows = (len(files) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * cell_width, rows * cell_height), background)
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(str(FONT), 12)
    for index, path in enumerate(files):
        column, row = index % columns, index // columns
        x, y = column * cell_width + 12, row * cell_height
        name = path.name[len("matrix_") : -len(f"_{theme}_{size}.png")]
        draw.text((x, y + 3), f"{index + 1:02d} {name}", fill=foreground, font=font)
        with Image.open(path) as source:
            thumbnail = ImageOps.contain(
                source.convert("RGB"),
                (thumb_width, thumb_height),
                Image.Resampling.LANCZOS,
            )
        sheet.paste(thumbnail, (x, y + 24))
    target = OUTPUT / f"contact_sheet_{theme}_{size}.png"
    sheet.save(target, optimize=True)
    print(f"{target.relative_to(ROOT)}: {sheet.width}x{sheet.height}")


if __name__ == "__main__":
    for current_theme in ("light", "dark"):
        for current_size in SIZES:
            render(current_theme, current_size)
