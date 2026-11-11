"""High-level device operations built on ``hdc`` + ``uitest``."""

from __future__ import annotations

import json
import re
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

    def foreground(self) -> str:
        """The bundle of the foreground mission, or '' when it cannot be read.

        ``aa dump -a`` prints the current mission first, then extension records.
        Only the mission section is considered: a service extension can also say
        ``state #FOREGROUND`` and would otherwise be mistaken for the app.
        """
        text = self.hdc.shell("aa dump -a", timeout=10)
        start = text.find("current mission lists")
        end = text.find("ExtensionRecords")
        if start < 0:
            section = text
        elif end > start:
            section = text[start:end]
        else:
            section = text[start:]
        lines = section.splitlines()
        for index, line in enumerate(lines):
            if "state #FOREGROUND" not in line:
                continue
            for offset in range(index, max(-1, index - 8), -1):
                match = re.search(r"bundle name \[([^\]]+)\]", lines[offset])
                if match:
                    return match.group(1)
        return ""

    # -- observation ---------------------------------------------------------

    def dump_layout(self, *, include_attrs: bool = False, timeout: float | None = None) -> Layout:
        last_error: Exception | None = None
        for attempt in range(2):
            remote = self._remote("layout", ".json")
            command = f"uitest dumpLayout -p {shlex.quote(remote)}"
            if include_attrs:
                command += " -a"
            try:
                output = self.hdc.shell(command, timeout=timeout)
                if "failed" in output.lower():
                    raise DeviceError(f"uitest dumpLayout failed: {output.strip()}")
                with tempfile.TemporaryDirectory(prefix="hopa-layout-") as tmp:
                    local = Path(tmp) / "layout.json"
                    self.hdc.file_recv(remote, local, timeout=timeout)
                    if not local.exists() or local.stat().st_size == 0:
                        raise DeviceError("layout dump produced no file")
                    data = json.loads(local.read_text(encoding="utf-8"))
                return parse_layout(data)
            except json.JSONDecodeError as exc:
                last_error = DeviceError(f"layout dump is not valid JSON: {exc}")
            except DeviceError as exc:
                last_error = exc
            finally:
                self.hdc.shell(f"rm -f {shlex.quote(remote)}", check=False)
            if attempt == 0:
                time.sleep(0.7)
        raise last_error or DeviceError("layout dump failed")

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
        # Type into whatever field is focused. Re-tapping (x, y) is unsafe: once
        # the keyboard opens the layout moves and the tap lands on a key ("V").
        # Callers focus the field first with ui.tap.
        quoted = shlex.quote(text)
        self.hdc.shell(f"uitest uiInput text {quoted}")

    # `uitest` accepts numeric key codes reliably; names such as Backspace do
    # not reach ArkUI text fields, while 2055 does.
    _KEY_CODES = {
        "backspace": "2055",
        "del": "2055",
        "delete": "2071",
        "enter": "2054",
        "tab": "2049",
        "escape": "2070",
        "space": "2050",
    }

    def press_key(self, key: str) -> None:
        code = self._KEY_CODES.get(key.strip().lower(), key)
        self.hdc.shell(f"uitest uiInput keyEvent {shlex.quote(code)}")

    def press_key_many(self, key: str, count: int) -> None:
        """Repeat a key in one hdc call; one round-trip instead of `count`."""
        if count <= 0:
            return
        code = self._KEY_CODES.get(key.strip().lower(), key)
        safe = shlex.quote(code)
        self.hdc.shell(
            f"i=0; while [ $i -lt {count} ]; do uitest uiInput keyEvent {safe}; "
            f"i=$((i+1)); done"
        )

    # -- app lifecycle -------------------------------------------------------

    def main_ability(self, bundle: str, dump: str | None = None) -> str:
        """The ability the launcher would start, read from the manifest."""
        if dump is None:
            try:
                dump = self.hdc.shell(f"bm dump -n {shlex.quote(bundle)}", check=False)
            except Exception:  # noqa: BLE001
                return ""
        match = re.search(r'"mainElement"\s*:\s*"([^"]+)"', dump)
        return match.group(1) if match else ""

    def launch(self, bundle: str, ability: str = "") -> None:
        # The catalogue ability can be device-specific; always keep a fallback
        # list and a bundle-only start, so one stale name cannot block a launch.
        probe = self.hdc.shell(f"bm dump -n {shlex.quote(bundle)}", check=False)
        if "error:" in probe.lower():
            raise DeviceError(f"{bundle} is not installed on this phone")
        candidates: list[str] = []
        resolved = self.main_ability(bundle, probe)
        if resolved:
            candidates.append(resolved)
        if ability:
            candidates.append(ability)
        for name in (
            "EntryAbility",
            "MainAbility",
            f"{bundle}.EntryAbility",
            f"{bundle}.MainAbility",
        ):
            if name not in candidates:
                candidates.append(name)
        errors: list[str] = []
        for attempt in range(2):
            for name in candidates:
                result = self.hdc.run(
                    "shell",
                    f"aa start -a {shlex.quote(name)} -b {shlex.quote(bundle)}",
                    check=False,
                )
                output = f"{result.stdout}\n{result.stderr}".strip()
                if "successfully" in output.lower():
                    return
                errors.append(f"{name}: {output}")
            if attempt == 0:
                time.sleep(0.7)
        raise DeviceError(f"failed to launch {bundle}: " + " | ".join(errors[-4:]))

    def stop(self, bundle: str) -> None:
        self.hdc.shell(f"aa force-stop {shlex.quote(bundle)}")

    def install(self, hap: str | Path) -> str:
        return self.hdc.install(hap)

    def uninstall(self, bundle: str) -> str:
        return self.hdc.uninstall(bundle)
