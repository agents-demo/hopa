"""High-level device operations built on ``hdc`` + ``uitest``."""

from __future__ import annotations

import json
import shlex
import tempfile
import time
from pathlib import Path

from .errors import DeviceError
from .hdc import Hdc
from .layout import Layout, parse_layout


class Device:
    """A HarmonyOS device/emulator controlled through hdc and uitest."""

    def __init__(
        self,
        hdc: Hdc | None = None,
        *,
        target: str | None = None,
        hdc_path: str | None = None,
        timeout: float = 60.0,
    ) -> None:
        self.hdc = hdc or Hdc(hdc_path=hdc_path, target=target, timeout=timeout)
        self._counter = 0

    # -- helpers -------------------------------------------------------------

    def _remote(self, kind: str, suffix: str) -> str:
        self._counter += 1
        stamp = int(time.time() * 1000)
        return f"/data/local/tmp/hopa_{kind}_{stamp}_{self._counter}{suffix}"

    def devices(self) -> list[str]:
        return self.hdc.list_targets()

    def apps(self) -> list[dict[str, str]]:
        """List installed bundles as ``[{bundle, label}]``."""
        from .apps import parse_installed_apps

        return parse_installed_apps(self.hdc.shell("bm dump -a"))

    # -- observation ---------------------------------------------------------

    def dump_layout(self, *, include_attrs: bool = False, timeout: float | None = None) -> Layout:
        remote = self._remote("layout", ".json")
        command = f"uitest dumpLayout -p {shlex.quote(remote)}"
        if include_attrs:
            command += " -a"
        self.hdc.shell(command, timeout=timeout)
        try:
            with tempfile.TemporaryDirectory(prefix="hopa-layout-") as tmp:
                local = Path(tmp) / "layout.json"
                self.hdc.file_recv(remote, local, timeout=timeout)
                data = json.loads(local.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise DeviceError(f"layout dump is not valid JSON: {exc}") from exc
        finally:
            self.hdc.shell(f"rm -f {shlex.quote(remote)}", check=False)
        return parse_layout(data)

    def screenshot(self, local_path: str | Path | None = None) -> Path:
        remote = self._remote("screen", ".jpeg")
        self.hdc.shell(f"snapshot_display -f {shlex.quote(remote)}")
        try:
            if local_path:
                destination = Path(local_path)
            else:
                destination = Path(f"screen_{int(time.time())}.jpeg")
            self.hdc.file_recv(remote, destination)
        finally:
            self.hdc.shell(f"rm -f {shlex.quote(remote)}", check=False)
        return destination

    # -- input ---------------------------------------------------------------

    def tap(self, x: int, y: int) -> None:
        self.hdc.shell(f"uitest uiInput click {int(x)} {int(y)}")

    def double_tap(self, x: int, y: int) -> None:
        self.hdc.shell(f"uitest uiInput doubleClick {int(x)} {int(y)}")

    def long_press(self, x: int, y: int) -> None:
        self.hdc.shell(f"uitest uiInput longClick {int(x)} {int(y)}")

    def swipe(
        self,
        from_x: int,
        from_y: int,
        to_x: int,
        to_y: int,
        *,
        velocity: int = 600,
    ) -> None:
        self.hdc.shell(
            f"uitest uiInput swipe {int(from_x)} {int(from_y)} "
            f"{int(to_x)} {int(to_y)} {int(velocity)}"
        )

    def type_text(self, text: str, *, x: int | None = None, y: int | None = None) -> None:
        quoted = shlex.quote(text)
        if x is not None and y is not None:
            self.hdc.shell(f"uitest uiInput inputText {int(x)} {int(y)} {quoted}")
        else:
            self.hdc.shell(f"uitest uiInput text {quoted}")

    def press_key(self, key: str) -> None:
        self.hdc.shell(f"uitest uiInput keyEvent {shlex.quote(key)}")

    # -- app lifecycle -------------------------------------------------------

    def launch(self, bundle: str, ability: str = "EntryAbility") -> None:
        self.hdc.shell(f"aa start -a {shlex.quote(ability)} -b {shlex.quote(bundle)}")

    def stop(self, bundle: str) -> None:
        self.hdc.shell(f"aa force-stop {shlex.quote(bundle)}")

    def install(self, hap: str | Path) -> str:
        return self.hdc.install(hap)

    def uninstall(self, bundle: str) -> str:
        return self.hdc.uninstall(bundle)
