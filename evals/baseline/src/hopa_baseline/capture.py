"""Capture an observation from a real device through ``pc-agent``."""

from __future__ import annotations

import time
from pathlib import Path

from hopa_bridge.device import Device
from hopa_bridge.layout import Layout

from .observation import Observation, observation_from_layout


def capture(
    device: Device,
    *,
    app: str = "",
    screenshot: bool = False,
    out_dir: str | Path | None = None,
    display_id: int = 0,
    window_id: str = "active",
    rotation: int = 0,
    density: float = 1.0,
    max_nodes: int = 400,
    now_ms: int | None = None,
) -> Observation:
    """Dump the layout, optionally take a screenshot, and build an observation."""
    layout: Layout = device.dump_layout()
    screenshot_ref = ""
    if screenshot:
        directory = Path(out_dir or ".hopa/screens")
        directory.mkdir(parents=True, exist_ok=True)
        stamp = int(time.time() * 1000) if now_ms is None else now_ms
        path = directory / f"screen_{stamp}.jpeg"
        saved = device.screenshot(path)
        screenshot_ref = str(saved)

    return observation_from_layout(
        layout,
        app=app,
        screenshot_ref=screenshot_ref,
        display_id=display_id,
        window_id=window_id,
        rotation=rotation,
        density=density,
        max_nodes=max_nodes,
        now_ms=now_ms,
    )
