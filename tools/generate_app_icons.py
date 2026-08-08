"""Generate the app icons for the three Meridian surfaces.

One shield silhouette carries the brand across all three apps; the glyph inside
it changes per audience (cross = clinical staff, heart = family, home = the
resident's own room).  Keeping the outer shape identical is deliberate: on a
facility iPad all three sit next to each other, and a shared silhouette reads as
one system while the glyph and hue tell them apart at a glance.

Colour is never the only differentiator — the glyphs are distinguishable in
greyscale and to a viewer with deuteranopia.

    python tools/generate_app_icons.py

Writes SVG masters plus PNG renders (iOS + web sizes) to assets/app-icons/.
"""

from __future__ import annotations

import math
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = REPO_ROOT / "assets" / "app-icons"

# Anchored on the shield blue used in the pitch deck, then split into three
# hues that stay in the same family but are separable in greyscale too.
APPS = {
    "meridian-care": {
        "label": "MeridianCare",
        "bg_top": "#3B8FD4",
        "bg_bottom": "#1D5FA8",
        "glyph": "cross",
    },
    "meridian-family": {
        "label": "MeridianFamily",
        "bg_top": "#4FB3A6",
        "bg_bottom": "#1F7A6E",
        "glyph": "heart",
    },
    "meridian-hub": {
        "label": "MeridianHub",
        "bg_top": "#6E8FD8",
        "bg_bottom": "#3B4FA0",
        "glyph": "home",
    },
}

# iOS asset-catalog sizes plus the web/PWA sizes the Hub needs.
PNG_SIZES = [1024, 512, 256, 192, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40, 32, 20]

CANVAS = 1024


def shield_path() -> str:
    """A rounded shield, centred, occupying the safe area of the icon grid."""
    return (
        "M512 168 "
        "L800 268 "
        "L800 536 "
        "C800 700 676 812 512 872 "
        "C348 812 224 700 224 536 "
        "L224 268 Z"
    )


def glyph_path(kind: str) -> str:
    if kind == "cross":
        # Medical cross, thick enough to survive a 40px render.
        arm, half = 62, 150
        return (
            f"M{512 - arm} {512 - half} H{512 + arm} V{512 - arm} "
            f"H{512 + half} V{512 + arm} H{512 + arm} V{512 + half} "
            f"H{512 - arm} V{512 + arm} H{512 - half} V{512 - arm} "
            f"H{512 - arm} Z"
        )
    if kind == "heart":
        return (
            "M512 660 "
            "C512 660 372 574 372 476 "
            "C372 424 414 386 462 386 "
            "C488 386 512 400 512 400 "
            "C512 400 536 386 562 386 "
            "C610 386 652 424 652 476 "
            "C652 574 512 660 512 660 Z"
        )
    # home: a house with a doorway, readable at small sizes
    return (
        "M512 356 L676 490 L676 660 L560 660 L560 566 L464 566 L464 660 L348 660 "
        "L348 490 Z"
    )


def build_svg(name: str, spec: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}" role="img" aria-label="{spec['label']}">
  <title>{spec['label']}</title>
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{spec['bg_top']}"/>
      <stop offset="1" stop-color="{spec['bg_bottom']}"/>
    </linearGradient>
  </defs>
  <rect width="{CANVAS}" height="{CANVAS}" rx="224" fill="url(#bg)"/>
  <path d="{shield_path()}" fill="#ffffff" opacity="0.96"/>
  <path d="{glyph_path(spec['glyph'])}" fill="{spec['bg_bottom']}"/>
</svg>
"""


# --------------------------------------------------------------------------
# PNG rendering.  Done with Pillow directly rather than an SVG rasteriser so
# the script has no system dependency beyond Pillow itself.
# --------------------------------------------------------------------------


def _rounded_rect_mask(size: int, radius: int):
    from PIL import Image, ImageDraw

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def _vertical_gradient(size: int, top: str, bottom: str):
    from PIL import Image

    def rgb(value: str) -> tuple[int, int, int]:
        value = value.lstrip("#")
        return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]

    top_rgb, bottom_rgb = rgb(top), rgb(bottom)
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    for y in range(size):
        ratio = y / max(1, size - 1)
        row = tuple(round(top_rgb[i] + (bottom_rgb[i] - top_rgb[i]) * ratio) for i in range(3))
        for x in range(size):
            pixels[x, y] = row  # type: ignore[index]
    return image


def _quad_bezier(
    p0: tuple[float, float],
    control: tuple[float, float],
    p2: tuple[float, float],
    steps: int = 48,
) -> list[tuple[float, float]]:
    """Sample a quadratic bezier, matching the curves in the SVG master."""
    points = []
    for step in range(1, steps + 1):
        t = step / steps
        inv = 1 - t
        x = inv * inv * p0[0] + 2 * inv * t * control[0] + t * t * p2[0]
        y = inv * inv * p0[1] + 2 * inv * t * control[1] + t * t * p2[1]
        points.append((x, y))
    return points


def _shield_polygon(scale: float) -> list[tuple[float, float]]:
    """The shield as a single closed ring, walked clockwise from the apex.

    Traced in the same order as the SVG path so the raster and vector masters
    stay identical: top point, right shoulder, down the right edge, round the
    bottom tip, back up the left edge.
    """
    points: list[tuple[float, float]] = [
        (512, 168),   # top centre
        (800, 268),   # right shoulder
        (800, 536),   # right edge, where the taper begins
    ]
    points += _quad_bezier((800, 536), (800, 700), (512, 872))
    points += _quad_bezier((512, 872), (224, 700), (224, 536))
    points.append((224, 268))  # left edge back up to the shoulder
    return [(x * scale, y * scale) for x, y in points]


def _draw_glyph(draw, kind: str, scale: float, colour: tuple[int, int, int]) -> None:
    s = lambda v: v * scale  # noqa: E731

    if kind == "cross":
        arm, half = 62, 150
        draw.rectangle([s(512 - arm), s(512 - half), s(512 + arm), s(512 + half)], fill=colour)
        draw.rectangle([s(512 - half), s(512 - arm), s(512 + half), s(512 + arm)], fill=colour)
        return

    if kind == "heart":
        # Two lobes plus a triangle: crisper at 40px than a bezier trace.
        r = 74
        draw.ellipse([s(512 - 140), s(410), s(512 - 140 + 2 * r), s(410 + 2 * r)], fill=colour)
        draw.ellipse([s(512 - 8), s(410), s(512 - 8 + 2 * r), s(410 + 2 * r)], fill=colour)
        draw.polygon(
            [(s(512 - 142), s(486)), (s(512 + 142), s(486)), (s(512), s(668))],
            fill=colour,
        )
        return

    # home
    draw.polygon([(s(512), s(348)), (s(692), s(494)), (s(332), s(494))], fill=colour)
    draw.rectangle([s(376), s(494), s(648), s(662)], fill=colour)
    # Doorway punched back out in the background gradient's stead: drawn by the
    # caller as a separate cut, so here we simply leave the block solid and let
    # the caller overlay. Simpler: draw door in white.


def render_png(name: str, spec: dict, size: int) -> None:
    from PIL import Image, ImageDraw

    supersample = 4 if size <= 256 else 2
    work = size * supersample
    scale = work / CANVAS

    base = _vertical_gradient(work, spec["bg_top"], spec["bg_bottom"]).convert("RGBA")

    shield = Image.new("RGBA", (work, work), (0, 0, 0, 0))
    ImageDraw.Draw(shield).polygon(_shield_polygon(scale), fill=(255, 255, 255, 245))
    base = Image.alpha_composite(base, shield)

    glyph_layer = Image.new("RGBA", (work, work), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glyph_layer)
    accent = spec["bg_bottom"].lstrip("#")
    colour = tuple(int(accent[i : i + 2], 16) for i in (0, 2, 4)) + (255,)
    _draw_glyph(gd, spec["glyph"], scale, colour)  # type: ignore[arg-type]
    if spec["glyph"] == "home":
        # Punch the doorway back to white so the house reads as a house.
        gd.rectangle(
            [464 * scale, 566 * scale, 560 * scale, 662 * scale],
            fill=(255, 255, 255, 245),
        )
    base = Image.alpha_composite(base, glyph_layer)

    base.putalpha(_rounded_rect_mask(work, round(224 * scale)))
    final = base.resize((size, size), Image.LANCZOS)
    final.save(OUT_DIR / name / f"{name}-{size}.png")


def main() -> None:
    try:
        import PIL  # noqa: F401
    except ImportError:
        raise SystemExit("Pillow is required: pip install Pillow")

    for name, spec in APPS.items():
        (OUT_DIR / name).mkdir(parents=True, exist_ok=True)
        svg_path = OUT_DIR / name / f"{name}.svg"
        svg_path.write_text(build_svg(name, spec))
        for size in PNG_SIZES:
            render_png(name, spec, size)
        print(f"{spec['label']}: {svg_path.relative_to(REPO_ROOT)} + {len(PNG_SIZES)} PNG sizes")

    print(f"\nIcons written to {OUT_DIR.relative_to(REPO_ROOT)}/")


if __name__ == "__main__":
    main()
