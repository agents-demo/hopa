#!/usr/bin/env python3
"""Render the HOPA mascot into the launcher icon and the brand raster.

The mark is the shared one: body, feet and face come from
``apps/harmony/app/src/main/resources/base/media/hopa_body.svg`` and the waving
arm from ``apps/android/.../ui/component/HopaMascot.kt``, both in a 512 x 512
view box.

The launcher icon is a layered adaptive icon: an opaque cream background layer
plus a transparent mascot foreground that stays inside the 66 dp safe zone, so
the launcher mask never cuts the face. Every PNG written here carries an alpha
channel and has no baked-in background.

Needs Pillow and numpy.

Usage:
    python tools/scripts/make-icon.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "apps" / "android" / "app" / "src" / "main" / "res"
DOCS = ROOT / "docs" / "media"

VIEW = 512.0
SUPERSAMPLE = 4

SCREEN_COLOR = (255, 249, 240, 255)
INK = (28, 27, 24, 255)
ACCENT = (232, 112, 58, 255)
CORAL_START = np.array([0xF0, 0x8A, 0x5B], np.float32)
CORAL_END = np.array([0xE8, 0x70, 0x3A], np.float32)

# x, y, width, height, corner radius, in view-box units.
BODY = (140.0, 88.0, 230.0, 336.0, 72.0)
SCREEN = (173.0, 130.0, 164.0, 232.0, 42.0)
EYE_LEFT = (212.0, 204.0, 26.0, 58.0, 13.0)
EYE_RIGHT = (280.0, 204.0, 26.0, 58.0, 13.0)
FOOT_LEFT = (180.0, 422.0, 44.0, 44.0, 14.0)
FOOT_RIGHT = (266.0, 422.0, 44.0, 44.0, 14.0)
ARM_START = (350.0, 226.0)
ARM_END = (412.0, 164.0)
ARM_WIDTH = 32.0
SMILE = ((236.0, 292.0), (261.0, 312.0), (286.0, 292.0))
SMILE_WIDTH = 13.0

# Figure bounds and the point that must land on the canvas centre.
FIGURE_TOP = 88.0
FIGURE_BOTTOM = 466.0
CENTRE = (255.0, 277.0)

# Figure height as a fraction of the canvas.
LEGACY_FILL = 0.86
FOREGROUND_DP = 57.5
ADS_DP = 108.0
BRAND_FILL = 0.88

DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}


def coral(size: int, scale: float, left: float, top: float) -> Image.Image:
    """The coral gradient, in view-box space (same direction as HopaMascot)."""
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    vx = (xs - left) / scale
    vy = (ys - top) / scale
    start = np.array([VIEW * 0.30, VIEW * 0.20], np.float32)
    end = np.array([VIEW * 0.72, VIEW * 0.82], np.float32)
    along = end - start
    t = ((vx - start[0]) * along[0] + (vy - start[1]) * along[1]) / float(
        along @ along
    )
    t = np.clip(t, 0.0, 1.0)
    rgb = CORAL_START + (CORAL_END - CORAL_START) * t[..., None]
    alpha = np.full((size, size, 1), 255.0, np.float32)
    return Image.fromarray(np.concatenate([rgb, alpha], axis=2).astype(np.uint8))


def rounded(draw: ImageDraw.ImageDraw, box, fill, scale, left, top) -> None:
    x, y, w, h, radius = box
    draw.rounded_rectangle(
        [
            left + x * scale,
            top + y * scale,
            left + (x + w) * scale,
            top + (y + h) * scale,
        ],
        radius=radius * scale,
        fill=fill,
    )


def render(size: int, figure_height: float) -> Image.Image:
    """Draw the mascot, ``figure_height`` pixels tall, centred, transparent."""
    canvas_px = size * SUPERSAMPLE
    scale = figure_height * SUPERSAMPLE / (FIGURE_BOTTOM - FIGURE_TOP)
    left = canvas_px / 2 - CENTRE[0] * scale
    top = canvas_px / 2 - CENTRE[1] * scale

    image = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # The arm sits behind the body, so its base hides under the shell.
    draw.line(
        [
            left + ARM_START[0] * scale,
            top + ARM_START[1] * scale,
            left + ARM_END[0] * scale,
            top + ARM_END[1] * scale,
        ],
        fill=ACCENT,
        width=round(ARM_WIDTH * scale),
    )
    for point in (ARM_START, ARM_END):
        cx = left + point[0] * scale
        cy = top + point[1] * scale
        radius = ARM_WIDTH * scale / 2
        draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=ACCENT)

    rounded(draw, FOOT_LEFT, ACCENT, scale, left, top)
    rounded(draw, FOOT_RIGHT, ACCENT, scale, left, top)

    body_mask = Image.new("L", (canvas_px, canvas_px), 0)
    rounded(ImageDraw.Draw(body_mask), BODY, 255, scale, left, top)
    image.paste(coral(canvas_px, scale, left, top), (0, 0), body_mask)

    rounded(draw, SCREEN, SCREEN_COLOR, scale, left, top)
    rounded(draw, EYE_LEFT, INK, scale, left, top)
    rounded(draw, EYE_RIGHT, INK, scale, left, top)

    start, control, end = SMILE
    points = []
    for step in range(25):
        t = step / 24
        x = (1 - t) ** 2 * start[0] + 2 * (1 - t) * t * control[0] + t * t * end[0]
        y = (1 - t) ** 2 * start[1] + 2 * (1 - t) * t * control[1] + t * t * end[1]
        points.append((left + x * scale, top + y * scale))
    width = max(1, round(SMILE_WIDTH * scale))
    draw.line(points, fill=INK, width=width, joint="curve")
    for px, py in (points[0], points[-1]):
        draw.ellipse(
            [px - width / 2, py - width / 2, px + width / 2, py + width / 2],
            fill=INK,
        )

    return image.resize((size, size), Image.LANCZOS)


def write(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"{path.relative_to(ROOT)}: {image.width}x{image.height}, alpha")


def main() -> None:
    for name, factor in DENSITIES.items():
        legacy = round(48 * factor)
        write(
            RES / f"mipmap-{name}" / "ic_launcher.png",
            render(legacy, legacy * LEGACY_FILL),
        )

        ads = round(ADS_DP * factor)
        write(
            RES / f"mipmap-{name}" / "ic_launcher_foreground.png",
            render(ads, FOREGROUND_DP * factor),
        )

    write(DOCS / "mascot-2026.png", render(512, 512 * BRAND_FILL))


if __name__ == "__main__":
    main()
