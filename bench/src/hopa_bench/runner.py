"""Executes benchmark tasks against a device using the pc-agent library."""

from __future__ import annotations

import time
from collections.abc import Callable
from dataclasses import dataclass, field

from hopa_pc_agent.device import Device
from hopa_pc_agent.errors import HopaError
from hopa_pc_agent.layout import Layout, Node

from .model import Model, StubModel
from .task import Action, Task


@dataclass
class StepResult:
    action: str
    ok: bool
    detail: str = ""


@dataclass
class TaskResult:
    task_id: str
    goal: str
    app: str
    success: bool | None
    steps: list[StepResult] = field(default_factory=list)
    error: str | None = None
    duration_s: float = 0.0

    def as_dict(self) -> dict:
        return {
            "task_id": self.task_id,
            "goal": self.goal,
            "app": self.app,
            "success": self.success,
            "error": self.error,
            "duration_s": round(self.duration_s, 3),
            "steps": [
                {"action": step.action, "ok": step.ok, "detail": step.detail}
                for step in self.steps
            ],
        }


class Runner:
    def __init__(
        self,
        device: Device,
        *,
        model_factory: Callable[[Task], Model] = StubModel.for_task,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self.device = device
        self.model_factory = model_factory
        self.sleep = sleep

    def run_task(self, task: Task) -> TaskResult:
        started = time.monotonic()
        model = self.model_factory(task)
        history: list[StepResult] = []
        error: str | None = None

        try:
            for _ in range(task.max_steps):
                action = model.propose(task, history, None)
                if action is None or action.action == "finish":
                    break
                result = self.execute(action, task)
                history.append(result)
                if not result.ok:
                    break
            success = self.check(task)
        except HopaError as exc:
            error = str(exc)
            success = False
        except Exception as exc:  # noqa: BLE001 - a task failure must not stop the run
            error = f"{type(exc).__name__}: {exc}"
            success = False

        return TaskResult(
            task_id=task.id,
            goal=task.goal,
            app=task.app,
            success=success,
            steps=history,
            error=error,
            duration_s=time.monotonic() - started,
        )

    # -- action execution ----------------------------------------------------

    def execute(self, action: Action, task: Task) -> StepResult:
        name = action.action
        params = action.params
        try:
            if name == "launch":
                bundle = str(params.get("bundle") or task.resolved_bundle)
                ability = str(params.get("ability", "EntryAbility"))
                self.device.launch(bundle, ability=ability)
                return StepResult(name, True, f"launched {bundle}")

            if name == "tap":
                self.device.tap(int(params["x"]), int(params["y"]))
                return StepResult(name, True, f"tapped {params['x']},{params['y']}")

            if name in {"tap_text", "tap_id"}:
                layout = self.device.dump_layout()
                matches = (
                    layout.find_by_text(str(params["text"]))
                    if name == "tap_text"
                    else layout.find_by_id(str(params["id"]))
                )
                node = _best_node(matches)
                if node is None or node.center is None:
                    return StepResult(name, False, f"target not found: {params}")
                x, y = node.center
                self.device.tap(x, y)
                return StepResult(name, True, f"tapped {x},{y}")

            if name == "type":
                x = params.get("x")
                y = params.get("y")
                self.device.type_text(
                    str(params.get("text", "")),
                    x=int(x) if x is not None else None,
                    y=int(y) if y is not None else None,
                )
                return StepResult(name, True, str(params.get("text", "")))

            if name == "swipe":
                self.device.swipe(
                    int(params["from_x"]),
                    int(params["from_y"]),
                    int(params["to_x"]),
                    int(params["to_y"]),
                    velocity=int(params.get("velocity", 600)),
                )
                return StepResult(name, True, "swiped")

            if name == "key":
                self.device.press_key(str(params["name"]))
                return StepResult(name, True, str(params["name"]))

            if name == "wait":
                seconds = float(params.get("seconds", 1))
                self.sleep(seconds)
                return StepResult(name, True, f"{seconds}s")

            return StepResult(name, False, f"unsupported action: {name}")
        except HopaError as exc:
            return StepResult(name, False, str(exc))
        except (KeyError, TypeError, ValueError) as exc:
            return StepResult(name, False, f"bad parameters: {exc}")

    # -- success evaluation --------------------------------------------------

    def check(self, task: Task) -> bool | None:
        spec = task.success
        if spec.type == "always":
            return True
        if spec.type == "text_visible":
            layout = self.device.dump_layout()
            haystack = [text.lower() for text in layout.texts()]
            haystack.extend(
                node.description.lower() for node in layout.walk() if node.description
            )

            def present(needle: str) -> bool:
                return any(needle.lower() in text for text in haystack)

            if spec.all:
                return all(present(item) for item in spec.all)
            return any(present(item) for item in spec.any)
        if spec.type == "app_foreground":
            return self._app_foreground(spec.bundle or task.resolved_bundle)
        return None

    def _app_foreground(self, bundle: str) -> bool | None:
        try:
            output = self.device.hdc.shell(
                "hidumper -s WindowManagerService -a '-a'", check=False
            )
        except Exception:  # noqa: BLE001 - best-effort check
            return None
        if not output:
            return None
        return bundle in output


def _best_node(nodes: list[Node]) -> Node | None:
    candidates = [node for node in nodes if node.center is not None]
    if not candidates:
        return None
    for node in candidates:
        if node.clickable:
            return node
    return candidates[0]


def layout_texts(layout: Layout) -> list[str]:
    """Small helper used by tests and debugging output."""
    return [text for text in layout.texts() if text.strip()]
