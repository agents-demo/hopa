from __future__ import annotations

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
    assert hdc.calls == ["uitest uiInput inputText 5 6 'hello world'"]


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
    assert hdc.calls == [
        "aa start -a MainAbility -b com.example.app",
        "aa force-stop com.example.app",
    ]


def test_press_key() -> None:
    hdc = FakeHdc()
    Device(hdc=hdc).press_key("Back")  # type: ignore[arg-type]
    assert hdc.calls == ["uitest uiInput keyEvent Back"]


def test_devices_delegates() -> None:
    hdc = FakeHdc()
    assert Device(hdc=hdc).devices() == ["fake-device"]  # type: ignore[arg-type]
