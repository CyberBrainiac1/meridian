import re
from pathlib import Path


CSS = Path("meridian_hub_ui/app/globals.css")


def _relative_luminance(hex_color: str) -> float:
    channels = [int(hex_color[index:index + 2], 16) / 255 for index in (1, 3, 5)]

    def linear(channel: float) -> float:
        return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4

    red, green, blue = (linear(channel) for channel in channels)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def _contrast(foreground: str, background: str) -> float:
    first, second = sorted((_relative_luminance(foreground), _relative_luminance(background)), reverse=True)
    return (first + 0.05) / (second + 0.05)


def test_meridian_hub_action_and_body_colours_meet_wcag_aa_contrast():
    css = CSS.read_text(encoding="utf-8")
    tokens = dict(re.findall(r"--([a-z-]+):\s*(#[0-9a-fA-F]{6})", css))

    # Senior-facing controls use 20px+ text, but we hold every text/control
    # combination to the stricter normal-text 4.5:1 threshold.
    for foreground, background in [
        (tokens["foreground"], "#ffffff"),
        (tokens["foreground"], tokens["background"]),
        (tokens["foreground-muted"], "#ffffff"),
        ("#ffffff", tokens["primary"]),
        ("#ffffff", tokens["destructive"]),
        ("#ffffff", tokens["success"]),
        ("#ffffff", tokens["warning"]),
    ]:
        assert _contrast(foreground, background) >= 4.5, (foreground, background)
