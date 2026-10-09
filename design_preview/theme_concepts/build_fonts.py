"""Build browser-safe OFL font subsets for the fixed concept copy.

Requires fonttools (`pip install fonttools`). The complete source fonts and
their OFL licenses remain in ../../assets/fonts/.
"""

from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont


HERE = Path(__file__).resolve().parent
SOURCE = HERE.parents[1] / "assets" / "fonts"
DESTINATION = HERE / "assets" / "fonts"
DESTINATION.mkdir(parents=True, exist_ok=True)
COPY = "".join(
    (HERE / name).read_text(encoding="utf-8")
    for name in ("index.html", "app.js", "interactions.js", "comparison.html")
)
COPY += "".join(chr(code) for code in range(32, 127))

for weight, output in (
    ("Regular", "plex-regular.woff"),
    ("Medium", "plex-medium.woff"),
    ("SemiBold", "plex-semibold.woff"),
):
    font = TTFont(SOURCE / f"IBMPlexSansSC-{weight}.otf")
    options = subset.Options()
    options.layout_features = ["*"]
    options.notdef_glyph = True
    options.recommended_glyphs = True
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text=COPY)
    subsetter.subset(font)
    font.flavor = "woff"
    font.save(DESTINATION / output)
    print(f"Built {output}")
