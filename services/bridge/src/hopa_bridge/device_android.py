"""The Android adapter: adb + uiautomator, behind the ``DevicePort`` seam.

Only this file and ``device.py`` may touch the transport; the HTTP layer sees
the port. Android has no ``uitest dumpLayout``, so the tree comes from
``uiautomator dump`` and is reshaped into the same ``layout.Node`` tree the rest
of the bridge already understands.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ElementTree

from .adb import Adb, AdbError
from .layout import Layout, Node

_FOCUS_RE = re.compile(r"mCurrentFocus=Window\{[^}]*?\s([^/\s}]+)/")
_RESUMED_RE = re.compile(r"mResumedActivity: ActivityRecord\{[^}]*?\s([^/\s}]+)/")
_PACKAGE_RE = re.compile(r"^package:(\S+)$")

_KEYCODES = {
    "back": "KEYCODE_BACK",
    "home": "KEYCODE_HOME",
    "enter": "KEYCODE_ENTER",
    "delete": "KEYCODE_DEL",
    "tab": "KEYCODE_TAB",
    "escape": "KEYCODE_ESCAPE",
    "power": "KEYCODE_POWER",
    "menu": "KEYCODE_MENU",
    "recent": "KEYCODE_APP_SWITCH",
    "appswitch": "KEYCODE_APP_SWITCH",
    "volumeup": "KEYCODE_VOLUME_UP",
    "volumedown": "KEYCODE_VOLUME_DOWN",
    "up": "KEYCODE_DPAD_UP",
    "down": "KEYCODE_DPAD_DOWN",
    "left": "KEYCODE_DPAD_LEFT",
    "right": "KEYCODE_DPAD_RIGHT",
}


class AndroidDevice:
    """An Android phone or tablet driven by adb."""

    platform = "android"

    def __init__(self, adb: Adb) -> None:
        self._adb = adb
        self._layout_remote = "/data/local/tmp/hopa-bridge-ui.xml"

    @property
    def serial(self) -> str:
        return self._adb.serial or "default"

    def dump_layout(self, *, include_attrs: bool = False, timeout: float | None = None) -> Layout:
        del include_attrs, timeout
        last = ""
        for attempt in range(2):
            dumped = self._adb.shell(f"uiautomator dump {self._layout_remote}", timeout=30)
            if "dumped" in dumped.lower() or "ui hierchary" in dumped.lower():
                break
            last = dumped.strip()
            if attempt == 1:
                raise AdbError(f"uiautomator dump failed: {last or 'no output'}")
        raw = self._adb.exec_out(f"cat {self._layout_remote}").decode(errors="replace")
        try:
            root = ElementTree.fromstring(raw)
        except ElementTree.ParseError as exc:
            raise AdbError(f"uiautomator dump is not XML: {exc}") from exc
        return Layout(roots=[_to_node(root)], raw=raw)

    def foreground(self) -> str:
        output = self._adb.shell("dumpsys window")
        match = _FOCUS_RE.search(output)
        if match:
            return match.group(1)
        resumed = self._adb.shell("dumpsys activity activities")
        match = _RESUMED_RE.search(resumed)
        return match.group(1) if match else ""

    def tap(self, x: int, y: int) -> None:
        self._adb.shell(f"input tap {int(x)} {int(y)}")

    def swipe(
        self,
        from_x: int,
        from_y: int,
        to_x: int,
        to_y: int,
        *,
        velocity: int = 600,
    ) -> None:
        distance = max(abs(to_x - from_x), abs(to_y - from_y))
        duration = max(80, int(distance / max(velocity, 1) * 1000))
        self._adb.shell(
            f"input swipe {int(from_x)} {int(from_y)} {int(to_x)} {int(to_y)} {duration}"
        )

    def type_text(self, text: str, *, x: int | None = None, y: int | None = None) -> None:
        if x is not None and y is not None:
            self.tap(x, y)
        if not text.isascii():
            raise AdbError(
                "adb input is ASCII-only. Use the accessibility adapter for "
                "non-ASCII text, or install ADBKeyboard and switch the IME."
            )
        escaped = text.replace(" ", "%s").replace("'", "\\'")
        self._adb.shell(f"input text '{escaped}'")

    def press_key(self, key: str) -> None:
        self._adb.shell(f"input keyevent {self._keycode(key)}")

    def press_key_many(self, key: str, count: int) -> None:
        for _ in range(max(1, count)):
            self.press_key(key)

    def launch(self, bundle: str, ability: str = "", raise_window: bool = False) -> None:
        del ability, raise_window
        resolved = self._adb.shell(f"cmd package resolve-activity --brief {bundle}")
        component = resolved.strip().splitlines()[-1] if resolved.strip() else ""
        if "/" in component:
            self._adb.shell(f"am start -n {component}")
            return
        self._adb.shell(f"monkey -p {bundle} -c android.intent.category.LAUNCHER 1")

    def stop(self, bundle: str) -> None:
        self._adb.shell(f"am force-stop {bundle}")

    def shell(self, command: str) -> str:
        return self._adb.shell(command)

    def pull(self, remote: str, local: str) -> None:
        self._adb.pull(remote, local)

    def screenshot(self, width: int = 0) -> tuple[str, bytes]:
        del width
        return "image/png", self._adb.exec_out("screencap -p")

    def apps(self) -> list[dict[str, str]]:
        output = self._adb.shell("pm list packages -3")
        bundles = []
        for line in output.splitlines():
            match = _PACKAGE_RE.match(line.strip())
            if match:
                bundles.append(match.group(1))
        return [{"bundle": bundle, "label": bundle} for bundle in sorted(set(bundles))]

    def _keycode(self, key: str) -> str:
        value = key.strip()
        if value.lower() in _KEYCODES:
            return _KEYCODES[value.lower()]
        if value.upper().startswith("KEYCODE_") or value.isdigit():
            return value.upper()
        raise AdbError(f"unknown key: {key}")


def _to_node(element: ElementTree.Element) -> Node:
    attributes = {
        "text": element.get("text", ""),
        "description": element.get("content-desc", ""),
        "id": element.get("resource-id", ""),
        "type": element.get("class", ""),
        "bounds": element.get("bounds", ""),
        "clickable": element.get("clickable", "false"),
        "enabled": element.get("enabled", "true"),
        "checked": element.get("checked", "false"),
        "scrollable": element.get("scrollable", "false"),
        "focused": element.get("focused", "false"),
        "visible": "true",
    }
    children = [_to_node(child) for child in element if child.tag == "node"]
    return Node(attributes=attributes, children=children)
