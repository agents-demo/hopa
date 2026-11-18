"""Tests for the plush icon and avatar generator."""

from __future__ import annotations

import importlib.util
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "scripts" / "make-icon.py"


def _module():
    spec = importlib.util.spec_from_file_location("make_icon", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _saturated(image: Image.Image) -> tuple[np.ndarray, np.ndarray]:
    data = np.asarray(image.convert("RGB")).astype(np.float32) / 255.0
    high = data.max(axis=2)
    low = data.min(axis=2)
    sat = np.where(high > 0, (high - low) / np.maximum(high, 1e-6), 0)
    return np.nonzero((sat > 0.18) & (high > 0.25))


def test_square_crop_contains_the_figure() -> None:
    module = _module()
    crop = module.square_crop(module.load_source())
    assert crop.size == (462, 462)
    ys, xs = _saturated(crop)
    assert abs(int(xs.min()) - 10) <= 2
    assert abs(int(ys.min()) - 32) <= 2
    assert abs(int(xs.max()) - 441) <= 2
    assert abs(int(ys.max()) - 429) <= 2


def test_icon_keeps_the_figure_in_the_safe_circle() -> None:
    module = _module()
    icon = module.compose_icon(108)
    ys, xs = _saturated(icon)
    radius = float(np.sqrt((xs - 54.0) ** 2 + (ys - 54.0) ** 2).max())
    assert radius <= 33.0
    assert int(xs.max() - xs.min()) >= 40


def test_blink_diff_is_confined_to_the_eyes() -> None:
    module = _module()
    base = module.square_crop(module.load_source())
    blink = module.blink_frame(base)
    diff = np.abs(np.asarray(base, np.int16) - np.asarray(blink, np.int16)).sum(axis=2) > 8
    ys, xs = np.nonzero(diff)
    assert ys.size > 50

    def inside(x: int, y: int, box: tuple[int, int, int, int]) -> bool:
        left, top, right, bottom = box
        return left <= x <= right and top <= y <= bottom

    left_eye = (160, 146, 212, 204)
    right_eye = (256, 146, 308, 204)
    assert all(
        inside(int(x), int(y), left_eye) or inside(int(x), int(y), right_eye)
        for x, y in zip(xs, ys)
    )


def test_blink_patch_matches_the_surrounding_fur() -> None:
    module = _module()
    base = module.square_crop(module.load_source())
    blink = module.blink_frame(base)
    base_rgb = np.asarray(base.convert("RGB")).astype(np.float32)
    blink_rgb = np.asarray(blink.convert("RGB")).astype(np.float32)
    grid = np.mgrid[-20:20, -20:20]
    ring = (grid[1] ** 2 + grid[0] ** 2) > 16**2
    upper = ((grid[1] ** 2 + grid[0] ** 2) <= 14**2) & (grid[0] < -2)
    for cx, cy in module.EYES:
        base_patch = base_rgb[cy - 20 : cy + 20, cx - 20 : cx + 20]
        blink_patch = blink_rgb[cy - 20 : cy + 20, cx - 20 : cx + 20]
        surround = base_patch[ring].mean(axis=0)
        patched = blink_patch[upper].mean(axis=0)
        assert np.abs(patched - surround).max() <= 20.0, (cx, patched, surround)


def test_outputs_have_expected_sizes(tmp_path: Path) -> None:
    module = _module()
    module.write_all(tmp_path)
    android = tmp_path / "apps" / "android" / "app" / "src" / "main" / "res"
    windows = tmp_path / "apps" / "windows" / "Hopa.Windows" / "Assets"
    assert Image.open(android / "drawable-nodpi" / "hopa_plush.png").size == (512, 512)
    assert Image.open(android / "drawable-nodpi" / "hopa_plush_blink.png").size == (512, 512)
    for name, factor in module.DENSITIES.items():
        legacy = round(48 * factor)
        foreground = round(108 * factor)
        assert Image.open(android / f"mipmap-{name}" / "ic_launcher.png").size == (legacy, legacy)
        assert Image.open(android / f"mipmap-{name}" / "ic_launcher_foreground.png").size == (
            foreground,
            foreground,
        )
    assert Image.open(windows / "mascot.png").size == (512, 512)
    ico = Image.open(windows / "hopa.ico")
    assert {
        (16, 16),
        (24, 24),
        (32, 32),
        (48, 48),
        (64, 64),
        (128, 128),
        (256, 256),
    } <= ico.info["sizes"]
