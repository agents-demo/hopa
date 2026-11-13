from __future__ import annotations

from pathlib import Path

from hopa_baseline.capture import capture

from .conftest import SETTINGS, FakeDevice


def test_capture_without_a_screenshot():
    observation = capture(FakeDevice([SETTINGS]), now_ms=1000)
    assert observation.screenshot_ref == ""
    assert observation.hash.startswith("sha256:")


def test_capture_with_a_screenshot(tmp_path: Path):
    observation = capture(FakeDevice([SETTINGS]), screenshot=True, out_dir=tmp_path, now_ms=1000)
    assert observation.screenshot_ref.endswith(".jpeg")
    assert Path(observation.screenshot_ref).exists()
