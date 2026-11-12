"""Models used by the benchmark.

The real agent uses an LLM. The benchmark ships a deterministic ``StubModel`` so
the rig can be exercised without network access or an API key. It simply
replays the task's scripted ``steps``; success is still evaluated against the
device, so a wrong script is reported as a failure.
"""

from __future__ import annotations

from collections.abc import Iterable
from typing import Protocol

from .task import Action, Task


class Model(Protocol):
    def propose(self, task: Task, history: list, observation: object) -> Action | None:
        """Return the next action, or ``None`` to stop."""


class StubModel:
    """Replays a fixed list of actions (the task's ``steps``)."""

    def __init__(self, steps: Iterable[Action]) -> None:
        self._steps = list(steps)
        self._index = 0

    @classmethod
    def for_task(cls, task: Task) -> StubModel:
        return cls(task.steps)

    def propose(self, task: Task, history: list, observation: object) -> Action | None:
        if self._index >= len(self._steps):
            return None
        action = self._steps[self._index]
        self._index += 1
        return action
