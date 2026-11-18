#!/usr/bin/env python3
"""Render the HOPA plush into the Android and Windows icons and avatars.

The mark is one user-supplied photo, cropped once and composed the same way
everywhere:

* Android gets a full adaptive icon set: legacy 48 dp rasters, 108 dp
  foreground layers (cream field plus the figure at 47% so the raised hand
  stays inside the 66 dp safe circle), a 512 px avatar and a 512 px blink
  frame.
* Windows gets the same avatars plus a multi-size ICO with rounded corners,
  because Windows does not mask its icons.

The blink frame is edited locally: the fur beside each eye is pasted over the
eye and a closed-eye arc is drawn. Every other pixel is unchanged, so a blink
cannot shimmer.

Needs Pillow. The source photo stays at ``tools/assets/hopa-plush-2026.jpg``.

Usage:
    python tools/scripts/make-icon.py
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools" / "assets" / "hopa-plush-2026.jpg"

# The square around the figure, in source pixels: the saturated bbox is
# (10, 306)..(441, 703), so this leaves a few pixels of air on every side.
CROP = (0, 274, 462, 736)

# The photo's own studio field, sampled from the crop edges. Android's
# adaptive background uses the same value so the feathered foreground has no
# seam when the launcher applies parallax.
FIELD = (247, 241, 230)

# Figure size as a fraction of the icon canvas. At 0.47 the farthest point
# (the raised hand) sits about 31.8 dp from the centre of a 108 dp canvas,
# inside the 66 dp safe circle. Legacy and Windows icons have no safe circle,
# so they can fill more of the tile.
ICON_FRACTION = 0.47
LEGACY_FRACTION = 0.60
WINDOWS_ICON_FRACTION = 0.72

# Rounded-square radius for the avatar badge and the ICO.
BADGE_RADIUS = 0.20

AVATAR = 512
DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]

# Eye centres in crop coordinates.
EYES = ((186, 175), (282, 175))
INK = (28, 27, 24, 255)


@lru_cache(maxsize=4)
def load_source(path: Path = SOURCE) -> Image.Image:
    return Image.open(path).convert("RGBA")


def square_crop(image: Image.Image) -> Image.Image:
    return image.crop(CROP)


def compose_icon(size: int, fraction: float = ICON_FRACTION) -> Image.Image:
    """The cream field with the figure at ``fraction`` of ``size``."""
    crop = square_crop(load_source())
    side = max(1, round(size * fraction))
    scaled = crop.resize((side, side), Image.LANCZOS)

    inset = max(1, side // 24)
    mask = Image.new("L", (side, side), 0)
    ImageDraw.Draw(mask).rectangle(
        [inset, inset, side - 1 - inset, side - 1 - inset], fill=255
    )
    mask = mask.filter(ImageFilter.GaussianBlur(inset))

    canvas = Image.new("RGBA", (size, size), FIELD + (255,))
    offset = ((size - side) // 2, (size - side) // 2)
    canvas.paste(scaled, offset, mask)
    return canvas


def blink_frame(image: Image.Image) -> Image.Image:
    """Close both eyes without touching any other pixel."""
    frame = image.copy()
    draw = ImageDraw.Draw(frame)
    for cx, cy in EYES:
        # Fur from the forehead, one eye-height above, so no eye or mouth
        # pixel can leak into the patch. A feathered ellipse keeps the seam
        # invisible at every size.
        patch = frame.crop((cx - 20, cy - 54, cx + 20, cy - 14))
        patch = patch.filter(ImageFilter.GaussianBlur(1.0))
        mask = Image.new("L", patch.size, 0)
        ImageDraw.Draw(mask).ellipse([4, 3, 35, 36], fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(5))
        frame.paste(patch, (cx - 20, cy - 20), mask)
        draw.arc(
            [cx - 12, cy - 7, cx + 12, cy + 7],
            start=20,
            end=160,
            fill=INK,
            width=5,
        )
    return frame


def apply_badge_mask(image: Image.Image) -> Image.Image:
    """Clip the image to a rounded square with a transparent outside."""
    width, height = image.size
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, width - 1, height - 1],
        radius=round(min(width, height) * BADGE_RADIUS),
        fill=255,
    )
    out = image.copy()
    out.putalpha(mask)
    return out


def _write(path: Path, image: Image.Image) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"{path}: {image.width}x{image.height}")
    return path


def write_all(root: Path = ROOT) -> list[Path]:
    root = Path(root)
    res = root / "apps" / "android" / "app" / "src" / "main" / "res"
    windows = root / "apps" / "windows" / "Hopa.Windows" / "Assets"
    docs = root / "docs" / "media"

    crop = square_crop(load_source())
    avatar = crop.resize((AVATAR, AVATAR), Image.LANCZOS)
    blink = blink_frame(crop).resize((AVATAR, AVATAR), Image.LANCZOS)

    paths: list[Path] = []
    for name, factor in DENSITIES.items():
        paths.append(
            _write(
                res / f"mipmap-{name}" / "ic_launcher.png",
                compose_icon(round(48 * factor), LEGACY_FRACTION),
            )
        )
        paths.append(
            _write(
                res / f"mipmap-{name}" / "ic_launcher_foreground.png",
                compose_icon(round(108 * factor)),
            )
        )

    paths.append(_write(res / "drawable-nodpi" / "hopa_plush.png", avatar))
    paths.append(_write(res / "drawable-nodpi" / "hopa_plush_blink.png", blink))

    paths.append(_write(windows / "mascot.png", avatar))
    paths.append(_write(windows / "mascot-blink.png", blink))

    ico = apply_badge_mask(compose_icon(256, WINDOWS_ICON_FRACTION))
    ico_path = windows / "hopa.ico"
    ico_path.parent.mkdir(parents=True, exist_ok=True)
    ico.save(ico_path, format="ICO", sizes=ICO_SIZES)
    print(f"{ico_path}: {', '.join(f'{w}x{h}' for w, h in ICO_SIZES)}")
    paths.append(ico_path)

    paths.append(_write(docs / "hopa-plush-2026.png", avatar))
    return paths


def main() -> None:
    write_all(ROOT)


if __name__ == "__main__":
    main()
