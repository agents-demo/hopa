"""High-level device operations built on ``hdc`` + ``uitest``."""

from __future__ import annotations

import json
import re
import shlex
import time
from pathlib import Path

from .errors import DeviceError, HdcError
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
        try:
            text = self.hdc.shell("aa dump -a", timeout=10)
        except HdcError:
            # A stale tunnel target can make the first read time out. Reset it
            # once; the next read tells the truth.
            recover = getattr(self.hdc, "recover", None)
            if callable(recover):
                recover()
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
        marker_start = "__HOPA_BEGIN__"
        marker_end = "__HOPA_END__"
        last_error: Exception | None = None
        for attempt in range(3):
            remote = self._remote("layout", ".json")
            # One hdc command per observation. A tunneled target drops its
            # session after a handful of commands, and dump + file recv + rm
            # costs three of them. Dumping, reading and cleaning up in a single
            # shell keeps `/observe` to one command.
            command = (
                f"uitest dumpLayout -p {shlex.quote(remote)} >/dev/null 2>&1; "
                f"echo {marker_start}; cat {shlex.quote(remote)}; echo; "
                f"echo {marker_end}; rm -f {shlex.quote(remote)}"
            )
            if include_attrs:
                command = command.replace("dumpLayout -p", "dumpLayout -a -p")
            try:
                output = self.hdc.shell(command, timeout=timeout)
                start = output.find(marker_start)
                end = output.find(marker_end, start + 1) if start >= 0 else -1
                if start < 0 or end < 0:
                    raise DeviceError("layout dump produced no file")
                payload = output[start + len(marker_start) : end].strip()
                if not payload:
                    raise DeviceError("layout dump produced no file")
                data = json.loads(payload)
                layout = parse_layout(data)
                if not layout.roots:
                    raise DeviceError("layout dump had no nodes")
                return layout
            except json.JSONDecodeError as exc:
                last_error = DeviceError(f"layout dump is not valid JSON: {exc}")
            except (DeviceError, HdcError) as exc:
                last_error = exc
            if attempt < 2:
                # Restart the local hdc server before replaying. `tconn` alone
                # says "already connected" on a session that returns nothing.
                recover = getattr(self.hdc, "recover", None)
                if callable(recover):
                    recover()
                time.sleep(0.4)
        raise last_error or DeviceError("layout dump failed")

    def screenshot(self, local_path: str | Path | None = None) -> Path:
        last_error: Exception | None = None
        for attempt in range(2):
            remote = self._remote("screen", ".jpeg")
            try:
                self.hdc.shell(f"snapshot_display -f {shlex.quote(remote)}")
                if local_path:
                    destination = Path(local_path)
                else:
                    destination = Path(f"screen_{int(time.time())}.jpeg")
                self.hdc.file_recv(remote, destination)
                data = destination.read_bytes()
                if len(data) < 1024 or not data.startswith(b"\xff\xd8"):
                    raise DeviceError("screenshot produced no image")
                return destination
            except (DeviceError, HdcError, OSError) as exc:
                last_error = exc
            finally:
                self.hdc.shell(f"rm -f {shlex.quote(remote)}", check=False)
            if attempt == 0:
                recover = getattr(self.hdc, "recover", None)
                if callable(recover):
                    recover()
                time.sleep(0.4)
        raise last_error or DeviceError("screenshot failed")

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
            f"i=0; while [ $i -lt {count} ]; do uitest uiInput keyEvent {safe}; i=$((i+1)); done"
        )

    # -- app lifecycle -------------------------------------------------------

    def main_ability(self, bundle: str, dump: str | None = None) -> str:
        """The ability the launcher would start, read from the manifest."""
        if dump is None:
            try:
                dump = self.hdc.shell(f"bm dump -n {shlex.quote(bundle)}", check=False)
            except Exception:  # noqa: BLE001
                return ""
        # HarmonyOS versions name this field differently: mainElement on some
        # builds, mainElementName on others (the Clock app uses the latter).
        match = re.search(r'"mainElement(?:Name)?"\s*:\s*"([^"]+)"', dump)
        return match.group(1) if match else ""

    def launch(self, bundle: str, ability: str = "", raise_window: bool = False) -> None:
        # The catalogue ability can be device-specific; always keep a fallback
        # list and a bundle-only start, so one stale name cannot block a launch.
        def probe() -> str:
            try:
                # Read only the launcher-ability line. A full `bm dump` is tens
                # of kilobytes and the tunnel can truncate it; a one-line result
                # is what actually keeps the first launch after idle reliable.
                return self.hdc.shell(
                    f"bm dump -n {shlex.quote(bundle)} 2>/dev/null "
                    "| grep -m1 -E '\"mainElement(Name)?\"'",
                    check=False,
                    timeout=12,
                )
            except HdcError:
                return ""

        def transport_error(text: str) -> bool:
            low = text.lower()
            return (
                "device not found" in low
                or "connect-key" in low
                or "connect failed" in low
                or "session is dead" in low
            )

        manifest = probe()
        if not manifest.strip() or transport_error(manifest):
            # A tunneled target can answer with nothing, a transport error, or
            # not at all while still looking connected. Reset the session and
            # ask once more.
            recover = getattr(self.hdc, "recover", None)
            if callable(recover):
                recover()
            manifest = probe()
        if not manifest.strip() or transport_error(manifest):
            check = ""
            try:
                check = self.hdc.shell(
                    f"bm dump -n {shlex.quote(bundle)} 2>&1 | head -2",
                    check=False,
                    timeout=8,
                )
            except HdcError:
                check = ""
            if "error:" in check.lower():
                raise DeviceError(f"{bundle} is not installed on this phone")
            if not check.strip() or transport_error(check):
                raise DeviceError(
                    f"the phone did not answer while reading {bundle}; "
                    "retry when the tunnel is ready"
                )
            # The device answered and the app exists, but this build has no
            # mainElement line: keep the legacy ability fallbacks below.
            manifest = ""
        candidates: list[str] = []
        resolved = self.main_ability(bundle, manifest)
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
                command = f"aa start -a {shlex.quote(name)} -b {shlex.quote(bundle)}"
                if raise_window:
                    # -N raises an existing singleton window instead of only
                    # delivering the intent to the mission.
                    command += " -N"
                try:
                    result = self.hdc.run(
                        "shell",
                        command,
                        check=False,
                        timeout=15,
                    )
                except HdcError as exc:
                    errors.append(f"{name}: {exc}")
                    continue
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
