from __future__ import annotations

from hopa_bench.runner import Runner
from hopa_bench.task import Action, SuccessCheck, Task
from hopa_bridge.errors import HdcError
from hopa_bridge.layout import parse_layout

LAYOUT = parse_layout(
    {
        "attributes": {"type": "Root"},
        "children": [
            {
                "attributes": {
                    "type": "Button",
                    "text": "Bluetooth",
                    "bounds": "[0,0][100,100]",
                    "clickable": "true",
                }
            }
        ],
    }
)


class FakeDevice:
    def __init__(self) -> None:
        self.calls: list[tuple] = []

    def launch(self, bundle: str, ability: str = "EntryAbility") -> None:
        self.calls.append(("launch", bundle, ability))

    def tap(self, x: int, y: int) -> None:
        self.calls.append(("tap", x, y))

    def dump_layout(self, **kwargs):
        return LAYOUT

    def type_text(self, text: str, *, x=None, y=None) -> None:
        self.calls.append(("type", text))

    def swipe(self, *args, velocity: int = 600) -> None:
        self.calls.append(("swipe", *args))

    def press_key(self, name: str) -> None:
        self.calls.append(("key", name))


def _task(steps, success=None) -> Task:
    return Task(
        id="t",
        goal="g",
        app="Settings",
        bundle="com.huawei.hmos.settings",
        success=success or SuccessCheck(type="text_visible", any=["Bluetooth"]),
        steps=steps,
    )


def test_launch_and_tap_text() -> None:
    device = FakeDevice()
    result = Runner(device, sleep=lambda _: None).run_task(
        _task([Action("launch"), Action("tap_text", {"text": "Bluetooth"})])
    )
    assert result.success is True
    assert ("launch", "com.huawei.hmos.settings", "") in device.calls
    assert ("tap", 50, 50) in device.calls


def test_missing_text_marks_step_failed() -> None:
    device = FakeDevice()
    result = Runner(device, sleep=lambda _: None).run_task(
        _task(
            [Action("tap_text", {"text": "Nope"})],
            success=SuccessCheck(type="text_visible", any=["Nope"]),
        )
    )
    assert result.success is False
    assert result.steps[0].ok is False
    assert "not found" in result.steps[0].detail


def test_failed_step_cannot_pass_on_visible_text() -> None:
    # "Bluetooth" is already visible, but the tap failed; that must not be a pass.
    device = FakeDevice()
    result = Runner(device, sleep=lambda _: None).run_task(
        _task(
            [Action("tap_text", {"text": "Nope"})],
            success=SuccessCheck(type="text_visible", any=["Bluetooth"]),
        )
    )
    assert result.success is False
    assert result.failure == "target_not_found"


def test_wait_is_executed_without_sleeping_for_real() -> None:
    slept: list[float] = []
    device = FakeDevice()
    Runner(device, sleep=slept.append).run_task(_task([Action("wait", {"seconds": 1.5})]))
    assert slept == [1.5]


def test_always_success() -> None:
    device = FakeDevice()
    result = Runner(device, sleep=lambda _: None).run_task(
        _task([], success=SuccessCheck(type="always"))
    )
    assert result.success is True


def test_step_error_is_recorded() -> None:
    class BrokenDevice(FakeDevice):
        def launch(self, bundle: str, ability: str = "EntryAbility") -> None:
            raise HdcError("no device")

    result = Runner(BrokenDevice(), sleep=lambda _: None).run_task(_task([Action("launch")]))
    assert result.steps[0].ok is False
    assert "no device" in result.steps[0].detail


def test_observation_error_is_captured() -> None:
    class BrokenDevice(FakeDevice):
        def dump_layout(self, **kwargs):
            raise HdcError("cannot observe")

    result = Runner(BrokenDevice(), sleep=lambda _: None).run_task(
        _task([], success=SuccessCheck(type="text_visible", any=["Bluetooth"]))
    )
    assert result.success is False
    assert result.error == "cannot observe"


def test_unknown_action_fails_cleanly() -> None:
    result = Runner(FakeDevice(), sleep=lambda _: None).run_task(_task([Action("teleport")]))
    assert result.steps[0].ok is False
    assert "unsupported" in result.steps[0].detail
