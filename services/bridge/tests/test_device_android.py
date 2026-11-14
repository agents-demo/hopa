"""The Android adapter: uiautomator XML, input commands, apps and keys."""

from __future__ import annotations

import subprocess

import pytest

from hopa_bridge.adb import AdbError
from hopa_bridge.device_android import AndroidDevice

DUMP = """<?xml version="1.0" encoding="UTF-8"?>
<hierarchy rotation="0">
  <node index="0" text="" resource-id="" class="android.widget.FrameLayout"
        package="com.android.settings" content-desc="" clickable="false"
        enabled="true" bounds="[0,0][1080,2400]">
    <node index="0" text="Settings" resource-id="com.android.settings:id/title"
          class="android.widget.TextView" package="com.android.settings"
          content-desc="" clickable="true" enabled="true"
          bounds="[40,200][400,280]" />
  </node>
</hierarchy>
"""


class Runner:
    def __init__(self, handler):
        self.handler = handler
        self.commands: list[list[str]] = []

    def __call__(self, args, capture_output=True, timeout=None):
        del capture_output, timeout
        self.commands.append(list(args))
        stdout, code = self.handler(args)
        if isinstance(stdout, str):
            stdout = stdout.encode()
        return subprocess.CompletedProcess(args, code, stdout, b"boom" if code else b"")


def device(handler) -> tuple[AndroidDevice, Runner]:
    runner = Runner(handler)
    from hopa_bridge.adb import Adb

    return AndroidDevice(Adb(serial="emulator-5554", executable="adb", runner=runner)), runner


def test_dump_layout_becomes_the_shared_tree() -> None:
    def handler(args):
        if args[-1].startswith("uiautomator dump"):
            return ("UI hierchary dumped to: /data/local/tmp/hopa-bridge-ui.xml", 0)
        return (DUMP, 0)

    target, _ = device(handler)
    layout = target.dump_layout()
    texts = layout.texts()
    assert "Settings" in texts
    node = layout.find_by_text("Settings")[0]
    assert node.bounds == (40, 200, 400, 280)
    assert node.clickable


def test_foreground_is_read_from_the_window_dump() -> None:
    output = "mCurrentFocus=Window{42 u0 com.android.settings/com.android.settings.Home}"
    target, _ = device(lambda _args: (output, 0))
    assert target.foreground() == "com.android.settings"


def test_tap_swipe_and_keys_become_input_commands() -> None:
    target, runner = device(lambda _args: ("", 0))
    target.tap(10, 20)
    target.swipe(0, 0, 100, 200, velocity=500)
    target.press_key("back")
    commands = [row[-1] for row in runner.commands]
    assert "input tap 10 20" in commands
    assert "input swipe 0 0 100 200 400" in commands
    assert "input keyevent KEYCODE_BACK" in commands


def test_non_ascii_typing_is_refused_with_a_pointer() -> None:
    target, _ = device(lambda _args: ("", 0))
    with pytest.raises(AdbError, match="accessibility adapter"):
        target.type_text("привет")


def test_ascii_text_escapes_spaces() -> None:
    target, runner = device(lambda _args: ("", 0))
    target.type_text("hello world")
    assert "input text 'hello%sworld'" in runner.commands[-1]


def test_launch_resolves_a_component_before_starting() -> None:
    target, runner = device(lambda _args: ("priority=0\ncom.android.settings/.Settings\n", 0))
    target.launch("com.android.settings")
    commands = [row[-1] for row in runner.commands]
    assert commands[0].startswith("cmd package resolve-activity")
    assert commands[-1] == "am start -n com.android.settings/.Settings"


def test_launch_falls_back_to_monkey_without_a_component() -> None:
    target, runner = device(lambda _args: ("", 0))
    target.launch("com.example")
    assert runner.commands[-1][-1].startswith("monkey -p com.example")


def test_apps_come_from_third_party_packages() -> None:
    target, _ = device(lambda _args: ("package:com.zeta\npackage:com.alpha\n", 0))
    apps = target.apps()
    assert [app["bundle"] for app in apps] == ["com.alpha", "com.zeta"]


def test_screenshot_is_png_bytes() -> None:
    target, _ = device(lambda _args: (b"\x89PNG\r\n", 0))
    mime, data = target.screenshot()
    assert mime == "image/png"
    assert data.startswith(b"\x89PNG")
