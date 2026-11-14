"""The HarmonyOS adapter: today's `Device`, behind the `DevicePort` seam.

Only this file and `device.py` may touch `hdc`; the HTTP layer imports the port.
"""

from __future__ import annotations

import tempfile
from pathlib import Path
from typing import Any

from .apps import parse_installed_apps
from .device import Device


class HarmonyDevice:
    """HarmonyOS phone or 2-in-1, driven by hdc + uitest."""

    platform = "harmony"

    def __init__(self, device: Device) -> None:
        self._device = device

    @property
    def serial(self) -> str:
        return str(getattr(self._device.hdc, "target", "") or "default")

    def dump_layout(self, *, include_attrs: bool = False, timeout: float | None = None) -> Any:
        return self._device.dump_layout(include_attrs=include_attrs, timeout=timeout)

    def foreground(self) -> str:
        return self._device.foreground()

    def tap(self, x: int, y: int) -> None:
        self._device.tap(x, y)

    def swipe(self, from_x: int, from_y: int, to_x: int, to_y: int, *, velocity: int = 600) -> None:
        self._device.swipe(from_x, from_y, to_x, to_y, velocity=velocity)

    def type_text(self, text: str, *, x: int | None = None, y: int | None = None) -> None:
        self._device.type_text(text, x=x, y=y)

    def press_key(self, key: str) -> None:
        self._device.press_key(key)

    def press_key_many(self, key: str, count: int) -> None:
        self._device.press_key_many(key, count)

    def launch(self, bundle: str, ability: str = "", raise_window: bool = False) -> None:
        self._device.launch(bundle, ability=ability, raise_window=raise_window)

    def stop(self, bundle: str) -> None:
        self._device.stop(bundle)

    def shell(self, command: str) -> str:
        return self._device.hdc.shell(command)

    def pull(self, remote: str, local: str) -> None:
        self._device.hdc.file_recv(remote, local)

    def screenshot(self, width: int = 0) -> tuple[str, bytes]:
        remote = "/data/local/tmp/hopa-bridge.jpeg"
        size = f" -w {width}" if width > 0 else ""
        self.shell(f"snapshot_display -f {remote}{size}")
        with tempfile.TemporaryDirectory(prefix="hopa-shot-") as tmp:
            local = Path(tmp) / "screen.jpeg"
            self.pull(remote, str(local))
            return "image/jpeg", local.read_bytes()

    def apps(self) -> list[dict[str, str]]:
        return parse_installed_apps(self._device.hdc.shell("bm dump -a"))
