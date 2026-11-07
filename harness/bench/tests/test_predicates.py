from __future__ import annotations

from hopa_bench.runner import Runner, classify_failure, layout_hash
from hopa_bench.task import SuccessCheck, Task
from hopa_pc_agent.layout import parse_layout

LAYOUT = parse_layout(
    {
        "attributes": {"type": "Root", "bounds": "[0,0][1080,2400]"},
        "children": [
            {
                "attributes": {
                    "type": "Button",
                    "id": "bluetooth",
                    "text": "Bluetooth",
                    "bounds": "[0,0][100,100]",
                    "clickable": "true",
                }
            }
        ],
    }
)


class FakeDevice:
    def dump_layout(self, **kwargs):
        return LAYOUT


def _task(check: SuccessCheck) -> Task:
    return Task(id="t", goal="g", app="Settings", bundle="x", success=check)


def test_node_exists_by_id() -> None:
    runner = Runner(FakeDevice())
    assert runner.check(_task(SuccessCheck(type="node_exists", node_id="bluetooth"))) is True


def test_node_exists_by_text() -> None:
    runner = Runner(FakeDevice())
    assert runner.check(_task(SuccessCheck(type="node_exists", any=["Bluetooth"]))) is True


def test_node_exists_missing() -> None:
    runner = Runner(FakeDevice())
    assert runner.check(_task(SuccessCheck(type="node_exists", any=["Nope"]))) is False


def test_screen_hash_matches() -> None:
    runner = Runner(FakeDevice())
    assert runner.check(_task(SuccessCheck(type="screen_hash", hash=layout_hash(LAYOUT)))) is True


def test_screen_hash_differs() -> None:
    runner = Runner(FakeDevice())
    assert runner.check(_task(SuccessCheck(type="screen_hash", hash="sha256:bad"))) is False


def test_failure_taxonomy() -> None:
    assert classify_failure("target not found: {'text': 'x'}") == "target_not_found"
    assert classify_failure("unsupported action: teleport") == "unsupported_action"
    assert classify_failure("bad parameters: 'x'") == "schema"
    assert classify_failure("no device") == "device"
    assert classify_failure("something else") == "step_failed"
