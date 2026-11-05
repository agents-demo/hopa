"""The agent loop: observe -> decide -> act -> verify -> record."""

from __future__ import annotations

import time
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime

from .errors import AgentError
from .executor import DeviceExecutor
from .models import ModelClient
from .observation import Observation
from .records import RunRecord, RunStore


@dataclass
class RunResult:
    run_id: str
    goal: str
    success: bool
    reason: str
    steps: int
    say: str = ""
    error: str | None = None
    records: list[RunRecord] = field(default_factory=list)
    started_at: str = ""
    finished_at: str = ""

    def as_dict(self) -> dict:
        return {
            "runId": self.run_id,
            "goal": self.goal,
            "success": self.success,
            "reason": self.reason,
            "steps": self.steps,
            "say": self.say,
            "error": self.error,
            "startedAt": self.started_at,
            "finishedAt": self.finished_at,
            "records": [record.to_dict() for record in self.records],
        }


class AgentLoop:
    def __init__(
        self,
        executor: DeviceExecutor,
        model: ModelClient,
        *,
        store: RunStore | None = None,
        max_steps: int = 15,
        max_seconds: float = 300.0,
        max_tokens: int = 50_000,
        trace_id: str | None = None,
        clock=time.monotonic,
    ) -> None:
        self.executor = executor
        self.model = model
        self.store = store
        self.max_steps = max_steps
        self.max_seconds = max_seconds
        self.max_tokens = max_tokens
        self.trace_id = trace_id or uuid.uuid4().hex[:16]
        self.clock = clock

    def run(self, goal: str, *, run_id: str | None = None) -> RunResult:
        run_id = run_id or f"run_{uuid.uuid4().hex[:12]}"
        started_at = datetime.now(UTC).isoformat()
        started = self.clock()
        observation: Observation = self.executor.observe()
        history: list[dict] = []
        seen: set[tuple[str, str]] = set()
        tokens = 0
        reason = "max_steps"
        success = False
        say = ""
        error: str | None = None
        steps = 0

        for step in range(self.max_steps):
            steps = step + 1
            if self.clock() - started > self.max_seconds:
                reason = "timeout"
                break
            try:
                decision = self.model.decide(goal, observation, history, step)
            except AgentError as exc:
                reason = "model_error"
                error = str(exc)
                break
            tokens += decision.tokens
            say = decision.say or say

            if decision.need_user:
                reason = "need_user"
                break
            if decision.action is None or decision.done:
                reason = "done"
                success = True
                break

            outcome = self.executor.execute(decision.action, run_id=run_id, step=step)
            history.append(
                {
                    "step": step,
                    "action": decision.action.describe(),
                    "result": "ok" if outcome.ok else (outcome.error or "failed"),
                    "observation": (outcome.after or observation).summary(),
                }
            )

            if outcome.decision.value == "block":
                reason = "blocked"
                error = outcome.error
                break
            if outcome.approved is False:
                reason = "denied"
                error = outcome.error
                break
            if not outcome.executed:
                reason = "error"
                error = outcome.error
                break
            if not outcome.verified:
                reason = "unverified"
                error = "the screen did not change after the action"
                break

            key = (decision.action.hash(), outcome.before.hash if outcome.before else "")
            if key in seen:
                reason = "stagnation"
                error = "the same action was repeated on the same screen"
                break
            seen.add(key)

            if outcome.after is not None:
                observation = outcome.after
            if tokens > self.max_tokens:
                reason = "budget"
                error = f"token budget exceeded ({tokens})"
                break
        else:
            reason = "max_steps"

        records = self.store.for_run(run_id) if self.store is not None else []
        return RunResult(
            run_id=run_id,
            goal=goal,
            success=success,
            reason=reason,
            steps=steps,
            say=say,
            error=error,
            records=records,
            started_at=started_at,
            finished_at=datetime.now(UTC).isoformat(),
        )
