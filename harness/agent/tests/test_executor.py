from __future__ import annotations

from pathlib import Path

from hopa_agent.actions import Action
from hopa_agent.executor import DeviceExecutor
from hopa_agent.records import RunStore


def _executor(device, *, approver=None, store=None):
    return DeviceExecutor(device, approver=approver, store=store, trace_id="test")


def test_tap_executes_and_verifies(settings_device, tmp_path: Path):
    store = RunStore(tmp_path / "runs.jsonl")
    executor = _executor(settings_device, store=store)
    outcome = executor.execute(Action.from_dict({"kind": "ui.tap", "ref": "e3"}), run_id="r1")

    assert outcome.executed is True
    assert outcome.verified is True
    assert outcome.error is None
    assert ("tap", 540, 360) in settings_device.calls
    assert store.verify_chain() == []
    assert len(store.for_run("r1")) == 1


def test_payment_without_approver_is_denied(payment_device):
    executor = _executor(payment_device)
    outcome = executor.execute(Action.from_dict({"kind": "ui.tap", "ref": "e5"}))

    assert outcome.approved is False
    assert outcome.executed is False
    assert "fail-closed" in (outcome.error or "")
    assert payment_device.calls == []


def test_payment_denied_by_user(payment_device):
    executor = _executor(payment_device, approver=lambda request: False)
    outcome = executor.execute(Action.from_dict({"kind": "ui.tap", "ref": "e5"}))

    assert outcome.approved is False
    assert outcome.executed is False
    assert payment_device.calls == []


def test_payment_approved_by_user(payment_device):
    executor = _executor(payment_device, approver=lambda request: True)
    outcome = executor.execute(Action.from_dict({"kind": "ui.tap", "ref": "e5"}))

    assert outcome.approved is True
    assert outcome.executed is True
    assert ("tap", 540, 2100) in payment_device.calls


def test_duplicate_action_is_blocked(settings_device):
    settings_device.advance = False
    executor = _executor(settings_device)
    action = Action.from_dict({"kind": "ui.tap", "ref": "e3"})

    first = executor.execute(action)
    second = executor.execute(action)

    assert first.executed is True
    assert second.executed is False
    assert "duplicate" in (second.error or "")


def test_stale_ref_is_rejected(settings_device):
    executor = _executor(settings_device)
    outcome = executor.execute(Action.from_dict({"kind": "ui.tap", "ref": "e99"}))

    assert outcome.executed is False
    assert "stale" in (outcome.error or "")


def test_emergency_call_is_blocked(settings_device):
    executor = _executor(settings_device)
    outcome = executor.execute(Action.from_dict({"kind": "system.call", "text": "112"}))

    assert outcome.executed is False
    assert "Emergency" in (outcome.error or "")
    assert settings_device.calls == []


def test_type_by_ref(settings_device):
    outcome = _executor(settings_device).execute(
        Action.from_dict({"kind": "ui.type", "ref": "e3", "text": "hello"})
    )
    assert outcome.executed is True
    assert ("type", "hello", 540, 360) in settings_device.calls


def test_swipe_coordinates(settings_device):
    action = Action.from_dict({"kind": "ui.swipe", "x": 1, "y": 2, "toX": 3, "toY": 4})
    assert _executor(settings_device).execute(action).executed is True
    assert ("swipe", 1, 2, 3, 4) in settings_device.calls


def test_scroll_uses_a_direction(settings_device):
    action = Action.from_dict({"kind": "ui.scroll", "direction": "down"})
    assert _executor(settings_device).execute(action).executed is True
    assert any(call[0] == "swipe" for call in settings_device.calls)


def test_back_and_home(settings_device):
    executor = _executor(settings_device)
    executor.execute(Action.from_dict({"kind": "ui.back"}))
    executor.execute(Action.from_dict({"kind": "ui.home"}))
    assert ("key", "Back") in settings_device.calls
    assert ("key", "Home") in settings_device.calls


def test_launch_and_stop(settings_device):
    executor = _executor(settings_device)
    executor.execute(Action.from_dict({"kind": "ui.launch", "app": "com.huawei.hmos.clock"}))
    executor.execute(Action.from_dict({"kind": "ui.stop", "app": "com.huawei.hmos.clock"}))
    assert ("launch", "com.huawei.hmos.clock", "EntryAbility") in settings_device.calls
    assert ("stop", "com.huawei.hmos.clock") in settings_device.calls


def test_wait_uses_injected_sleep(settings_device):
    slept: list[float] = []
    executor = DeviceExecutor(settings_device, sleep=slept.append)
    outcome = executor.execute(Action.from_dict({"kind": "ui.wait", "text": "0.25"}))
    assert outcome.executed is True
    assert slept == [0.25]


def test_web_navigate_reaches_the_capability(settings_device):
    outcome = _executor(settings_device).execute(
        Action.from_dict({"kind": "web.navigate", "url": "https://example.com"})
    )
    assert outcome.executed is False
    assert "not implemented" in (outcome.error or "")


def test_open_link_with_a_dangerous_url(settings_device):
    executor = _executor(settings_device, approver=lambda request: True)
    outcome = executor.execute(
        Action.from_dict({"kind": "system.openLink", "url": "javascript:alert(1)"})
    )
    assert outcome.executed is False
    assert "scheme" in (outcome.error or "")
