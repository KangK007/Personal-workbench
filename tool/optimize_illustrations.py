"""Export the selected theme illustrations for Flutter without bundling source PNGs."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "design_preview" / "theme_concepts" / "assets"
OUTPUT = ROOT / "assets" / "illustrations"
KINDS = ("today", "project", "capture", "focus", "notes", "review", "growth")
MAX_EDGE = 1100


def source_for(theme: str, kind: str) -> Path:
    if kind in ("today", "project"):
        return PREVIEW / ("green" if theme == "day" else "night") / f"{kind}.png"
    return PREVIEW / "generated" / theme / f"{kind}.png"


def main() -> None:
    for theme in ("day", "night"):
        destination = OUTPUT / theme
        destination.mkdir(parents=True, exist_ok=True)
        for kind in KINDS:
            source = source_for(theme, kind)
            if not source.is_file():
                raise FileNotFoundError(source)
            target = destination / f"{kind}.webp"
            with Image.open(source) as original:
                art = original.convert("RGBA")
                art.thumbnail((MAX_EDGE, MAX_EDGE), Image.Resampling.LANCZOS)
                art.save(target, "WEBP", quality=88, method=6, exact=True)
                print(f"{theme}/{kind}: {art.width}x{art.height}, {target.stat().st_size} bytes")


if __name__ == "__main__":
    main()
