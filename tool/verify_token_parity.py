# -*- coding: utf-8 -*-
"""校验 design_preview/assets/tokens.css 与 lib/core/theme/app_theme.dart 的逐值一致性。

项目纪律（见 .workbuddy/memory/MEMORY.md）：预览站的 tokens.css 必须与
app_theme.dart 的 AppColors 逐值对应，「改一处改两处」。此前只能靠人工比对，
本脚本把它变成可执行判据。

用法：python tool/verify_token_parity.py    → 退出码 0 表示一致
"""
import io
import re
import sys

THEME = r"D:/Project/个人工作台/lib/core/theme/app_theme.dart"
CSS = r"D:/Project/个人工作台/design_preview/assets/tokens.css"

# AppColors 字段名（小写）→ tokens.css 变量名
KEY = {
    "canvas": "canvas",
    "surface": "surface",
    "raised": "raised",
    "subtle": "subtle",
    "ink": "ink",
    "inkmuted": "ink-muted",
    "inkfaint": "ink-faint",
    "divider": "divider",
    "borderstrong": "border-strong",
    "primary": "primary",
    "primarycontainer": "primary-container",
    "primaryoncontainer": "primary-on-container",
    "signal": "signal",
    "signalcontainer": "signal-container",
    "signaloncontainer": "signal-on-container",
    "reward": "reward",
    "rewardcontainer": "reward-container",
    "rewardoncontainer": "reward-on-container",
    "info": "info",
    "infocontainer": "info-container",
    "infooncontainer": "info-on-container",
    "teal": "teal",
    "olive": "olive",
    "olivecontainer": "olive-container",
    "oliveoncontainer": "olive-on-container",
    "violet": "violet",
    "amber": "amber",
    "outline": "outline",
}


def dart_values(text):
    out = {}
    pat = r"static const (light|dark)([A-Za-z]+) = Color\(0x([0-9A-Fa-f]{8})\)"
    for scope, name, hexv in re.findall(pat, text):
        out[(scope, name.lower())] = hexv[2:].upper()
    return out


def css_values(text):
    cut = text.index('html[data-theme="dark"]')
    light, dark = text[:cut], text[cut:]
    pat = r"--([a-z-]+):\s*#([0-9A-Fa-f]{6})"
    return (
        {k: v.upper() for k, v in re.findall(pat, light)},
        {k: v.upper() for k, v in re.findall(pat, dark)},
    )


def main():
    dart = dart_values(io.open(THEME, encoding="utf-8").read())
    light, dark = css_values(io.open(CSS, encoding="utf-8").read())

    bad, checked = [], 0
    for name, key in sorted(KEY.items()):
        for scope, cm in (("light", light), ("dark", dark)):
            dv, cv = dart.get((scope, name)), cm.get(key)
            checked += 1
            if dv is None or cv is None:
                bad.append(
                    "缺失 %s.%s ←→ --%s（dart=%s css=%s）" % (scope, name, key, dv, cv)
                )
            elif dv != cv:
                bad.append("不一致 %s.%s：dart #%s ≠ css #%s" % (scope, name, dv, cv))

    if bad:
        for b in bad:
            sys.stdout.write("  FAIL %s\n" % b)
        sys.stdout.write("\n不一致 %d / 核对 %d\n" % (len(bad), checked))
        return 1
    sys.stdout.write("tokens.css 与 app_theme.dart 逐值一致（核对 %d 对）\n" % checked)
    return 0


if __name__ == "__main__":
    sys.exit(main())
