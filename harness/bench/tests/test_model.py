from __future__ import annotations

from hopa_bench.model import StubModel
from hopa_bench.task import Action, Task


def test_replays_steps_then_stops() -> None:
    task = Task(
        id="t",
        goal="g",
        app="Settings",
        steps=[Action("launch"), Action("tap", {"x": 1, "y": 2})],
    )
    model = StubModel.for_task(task)
    assert model.propose(task, [], None).action == "launch"  # type: ignore[union-attr]
    assert model.propose(task, [], None).action == "tap"  # type: ignore[union-attr]
    assert model.propose(task, [], None) is None


def test_empty_script_stops_immediately() -> None:
    task = Task(id="t", goal="g", app="Settings")
    assert StubModel.for_task(task).propose(task, [], None) is None
