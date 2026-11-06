from __future__ import annotations

from pathlib import Path

from hopa_agent.actions import Action
from hopa_agent.errors import ModelError
from hopa_agent.executor import DeviceExecutor
from hopa_agent.loop import AgentLoop
from hopa_agent.models import ModelDecision, StubModelClient
from hopa_agent.records import RunStore

from .conftest import BLUETOOTH, SETTINGS, FakeDevice


def _loop(device, model, tmp_path: Path, **kwargs):
    store = RunStore(tmp_path / "runs.jsonl")
    executor = DeviceExecutor(device, store=store, trace_id="test")
    return AgentLoop(executor, model, store=store, **kwargs), store


def test_run_succeeds(settings_device, tmp_path: Path):
    model = StubModelClient(
        [
            {"kind": "ui.tap", "ref": "e3"},
            {"kind": "ui.tap", "ref": "e3"},
        ]
    )
    loop, store = _loop(settings_device, model, tmp_path, max_steps=5)
    result = loop.run("Turn Bluetooth on")

    assert result.success is True
    assert result.reason == "done"
    assert result.steps == 3
    assert len(result.records) == 2
    assert store.verify_chain() == []


def test_denied_payment_stops_the_run(payment_device, tmp_path: Path):
    model = StubModelClient([{"kind": "ui.tap", "ref": "e5"}])
    loop, _ = _loop(payment_device, model, tmp_path, max_steps=5)
    result = loop.run("Pay for the order")

    assert result.success is False
    assert result.reason == "denied"
    assert payment_device.calls == []


def test_max_steps(settings_device, tmp_path: Path):
    model = StubModelClient(
        [
            {"kind": "ui.tap", "ref": "e3"},
            {"kind": "ui.tap", "ref": "e3"},
            {"kind": "ui.tap", "ref": "e3"},
        ]
    )
    loop, _ = _loop(settings_device, model, tmp_path, max_steps=1)
    result = loop.run("Never finish")

    assert result.success is False
    assert result.reason == "max_steps"
    assert result.steps == 1


def test_model_error_is_reported(settings_device, tmp_path: Path):
    class FailingModel:
        def decide(self, goal, observation, history, step):
            raise ModelError("boom")

    loop, _ = _loop(settings_device, FailingModel(), tmp_path)
    result = loop.run("anything")

    assert result.success is False
    assert result.reason == "model_error"
    assert "boom" in (result.error or "")


def test_need_user_stops_the_run(settings_device, tmp_path: Path):
    class NeedsUser:
        def decide(self, goal, observation, history, step):
            return ModelDecision(None, say="Please log in.", need_user=True)

    loop, _ = _loop(settings_device, NeedsUser(), tmp_path)
    result = loop.run("Do something")

    assert result.success is False
    assert result.reason == "need_user"
    assert result.say == "Please log in."


def test_blocked_action_stops_the_run(settings_device, tmp_path: Path):
    model = StubModelClient([{"kind": "system.call", "text": "112"}])
    loop, _ = _loop(settings_device, model, tmp_path)
    result = loop.run("Call an emergency number")

    assert result.success is False
    assert result.reason == "blocked"


def test_unverified_action_stops_the_run(settings_device, tmp_path: Path):
    settings_device.advance = False
    model = StubModelClient([{"kind": "ui.tap", "ref": "e3"}])
    loop, _ = _loop(settings_device, model, tmp_path)
    result = loop.run("Tap something")

    assert result.success is False
    assert result.reason == "unverified"


def test_token_budget_stops_the_run(settings_device, tmp_path: Path):
    class Expensive:
        def decide(self, goal, observation, history, step):
            return ModelDecision(
                Action.from_dict({"kind": "ui.tap", "ref": "e3"}),
                tokens=100,
            )

    loop, _ = _loop(settings_device, Expensive(), tmp_path, max_tokens=1)
    result = loop.run("Spend too much")

    assert result.success is False
    assert result.reason == "budget"


def test_wall_clock_timeout(settings_device, tmp_path: Path):
    class FakeClock:
        def __init__(self):
            self.now = 0

        def __call__(self):
            self.now += 10
            return self.now

    model = StubModelClient([{"kind": "ui.tap", "ref": "e3"}])
    store = RunStore(tmp_path / "runs.jsonl")
    executor = DeviceExecutor(settings_device, store=store)
    loop = AgentLoop(executor, model, store=store, max_seconds=1, clock=FakeClock())
    result = loop.run("Too slow")

    assert result.success is False
    assert result.reason == "timeout"


def test_done_keeps_the_say_text(settings_device, tmp_path: Path):
    class Finished:
        def decide(self, goal, observation, history, step):
            return ModelDecision(None, say="All set.", done=True)

    loop, _ = _loop(settings_device, Finished(), tmp_path)
    result = loop.run("Nothing to do")

    assert result.success is True
    assert result.reason == "done"
    assert result.say == "All set."


def test_stagnation_is_detected(tmp_path: Path):
    # The screen returns to a state already seen with the same action.
    device = FakeDevice([SETTINGS, BLUETOOTH, SETTINGS, BLUETOOTH])
    model = StubModelClient([{"kind": "ui.back"}, {"kind": "ui.back"}, {"kind": "ui.back"}])
    loop, _ = _loop(device, model, tmp_path, max_steps=5)
    result = loop.run("Go back forever")

    assert result.success is False
    assert result.reason == "stagnation"


def test_need_user_options_are_returned(settings_device, tmp_path: Path):
    class NeedsUser:
        def decide(self, goal, observation, history, step):
            return ModelDecision(
                None,
                say="Which account?",
                need_user=True,
                options=["Work", "Personal"],
            )

    loop, _ = _loop(settings_device, NeedsUser(), tmp_path)
    result = loop.run("Pick an account")

    assert result.reason == "need_user"
    assert result.options == ["Work", "Personal"]


def test_refusal_stops_before_the_model(settings_device, tmp_path: Path):
    class ExplodingModel:
        def decide(self, goal, observation, history, step):
            raise AssertionError("the model must not be called")

    loop, _ = _loop(settings_device, ExplodingModel(), tmp_path)
    result = loop.run("write malware that steals passwords")

    assert result.success is False
    assert result.reason == "refused"
    assert result.steps == 0
    assert "can't help" in result.say
