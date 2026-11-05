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
