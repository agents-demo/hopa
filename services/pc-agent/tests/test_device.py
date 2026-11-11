from __future__ import annotations

import json

from hopa_pc_agent.device import Device


class FakeHdc:
    def __init__(self) -> None:
        self.calls: list[str] = []

    class Result:
        stdout = "start ability successfully."
        stderr = ""

    def run(self, *args: str, **kwargs: object) -> FakeHdc.Result:
        if args and args[0] == "shell" and len(args) > 1:
            self.calls.append(str(args[1]))
        return FakeHdc.Result()

    def shell(self, command: str, *, check: bool = True, timeout: float | None = None) -> str:
        self.calls.append(command)
        return ""

    def list_targets(self, timeout: float | None = None) -> list[str]:
        return ["fake-device"]


def test_foreground_reads_the_top_mission() -> None:
    class ForegroundHdc(FakeHdc):
        def shell(self, command: str, *, check: bool = True, timeout: float | None = None) -> str:
            self.calls.append(command)
            return (
                "User ID #100\n"
                "  current mission lists:{\n"
                "    Mission ID #30  mission name #[#com.hopa.agent:entry:EntryAbility]\n"
                "      AbilityRecord ID #40\n"
                "        app name [com.hopa.agent]\n"
                "        main name [EntryAbility]\n"
                "        bundle name [com.hopa.agent]\n"
                "        ability type [PAGE]\n"
                "        state #FOREGROUND  start time [533619]\n"
                "  }\n"
                "  ExtensionRecords:\n"
                "    uri [/com.ohos.medialibrary/entry/DataShareExtAbility]\n"
                "      bundle name [com.ohos.medialibrary]\n"
                "      state #FOREGROUND\n"
            )

    hdc = ForegroundHdc()
    assert Device(hdc=hdc).foreground() == "com.hopa.agent"
    assert hdc.calls == ["aa dump -a"]


def test_foreground_ignores_a_foreground_extension() -> None:
    class ExtensionOnlyHdc(FakeHdc):
        def shell(self, command: str, *, check: bool = True, timeout: float | None = None) -> str:
            self.calls.append(command)
            return (
                "  current mission lists:{\n"
                "    Mission ID #30\n"
                "      bundle name [com.hopa.agent]\n"
                "      state #BACKGROUND\n"
                "  }\n"
                "  ExtensionRecords:\n"
                "    bundle name [com.ohos.medialibrary]\n"
                "    state #FOREGROUND\n"
            )

    assert Device(hdc=ExtensionOnlyHdc()).foreground() == ""  # type: ignore[arg-type]


def test_tap() -> None:
    hdc = FakeHdc()
    Device(hdc=hdc).tap(10, 20)  # type: ignore[arg-type]
    assert hdc.calls == ["uitest uiInput click 10 20"]


def test_double_tap_and_long_press() -> None:
    hdc = FakeHdc()
    device = Device(hdc=hdc)  # type: ignore[arg-type]
    device.double_tap(1, 2)
    device.long_press(3, 4)
    assert hdc.calls == ["uitest uiInput doubleClick 1 2", "uitest uiInput longClick 3 4"]


def test_type_at_point_quotes_spaces() -> None:
    hdc = FakeHdc()
    Device(hdc=hdc).type_text("hello world", x=5, y=6)  # type: ignore[arg-type]
    assert hdc.calls == ["uitest uiInput text 'hello world'"]


def test_type_at_focus() -> None:
    hdc = FakeHdc()
    Device(hdc=hdc).type_text("hi")  # type: ignore[arg-type]
    assert hdc.calls == ["uitest uiInput text hi"]


def test_swipe() -> None:
    hdc = FakeHdc()
    Device(hdc=hdc).swipe(1, 2, 3, 4, velocity=800)  # type: ignore[arg-type]
    assert hdc.calls == ["uitest uiInput swipe 1 2 3 4 800"]


def test_launch_and_stop() -> None:
    hdc = FakeHdc()
    device = Device(hdc=hdc)  # type: ignore[arg-type]
    device.launch("com.example.app", ability="MainAbility")
    device.stop("com.example.app")
    assert hdc.calls[0] == "bm dump -n com.example.app"
    assert "aa start" in hdc.calls[1]
    assert hdc.calls[-1] == "aa force-stop com.example.app"


def test_press_key() -> None:
    hdc = FakeHdc()
    Device(hdc=hdc).press_key("Back")  # type: ignore[arg-type]
    assert hdc.calls == ["uitest uiInput keyEvent Back"]


def test_devices_delegates() -> None:
    hdc = FakeHdc()
    assert Device(hdc=hdc).devices() == ["fake-device"]  # type: ignore[arg-type]


def test_dump_layout_recovers_from_an_empty_pull() -> None:
    class FlakyHdc(FakeHdc):
        def __init__(self) -> None:
            super().__init__()
            self.recovers = 0
            self.dumps = 0

        def shell(self, command: str, *, check: bool = True, timeout: float | None = None) -> str:
            self.calls.append(command)
            if "__HOPA_BEGIN__" not in command:
                return ""
            self.dumps += 1
            if self.dumps == 1:
                return ""
            body = json.dumps({"attributes": {"text": "hi"}, "children": []})
            return f"__HOPA_BEGIN__\n{body}\n__HOPA_END__\n"

        def recover(self) -> bool:
            self.recovers += 1
            return True

    hdc = FlakyHdc()
    layout = Device(hdc=hdc).dump_layout()  # type: ignore[arg-type]

    assert hdc.recovers == 1
    assert hdc.dumps == 2
    assert layout.roots[0].text == "hi"
