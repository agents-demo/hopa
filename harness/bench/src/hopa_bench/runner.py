"""Executes benchmark tasks against a device using the pc-agent library."""

from __future__ import annotations

import hashlib
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
    latency_ms: float = 0.0


@dataclass
class TaskResult:
    task_id: str
    goal: str
    app: str
    success: bool | None
    steps: list[StepResult] = field(default_factory=list)
    error: str | None = None
    failure: str | None = None
    tokens: int = 0
    duration_s: float = 0.0

    def as_dict(self) -> dict:
        return {
            "task_id": self.task_id,
            "goal": self.goal,
            "app": self.app,
            "success": self.success,
            "error": self.error,
            "failure": self.failure,
            "tokens": self.tokens,
            "duration_s": round(self.duration_s, 3),
            "steps": [
                {
                    "action": step.action,
                    "ok": step.ok,
                    "detail": step.detail,
                    "latency_ms": round(step.latency_ms, 1),
                }
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
        failure: str | None = None
        step_failed = False
        tokens = 0

        # Reset the app so a previous task cannot leave it on a success screen.
        try:
            self.device.stop(task.resolved_bundle)
        except Exception:  # noqa: BLE001 - best effort on fake devices
            pass

        try:
            for _ in range(task.max_steps):
                action = model.propose(task, history, None)
                if action is None or action.action == "finish":
                    break
                result = self.execute(action, task)
                history.append(result)
                tokens += int(getattr(model, "last_tokens", 0) or 0)
                if not result.ok:
                    failure = classify_failure(result.detail)
                    step_failed = True
                    break
            success = self.check(task)
            # A scripted step that failed cannot count as a pass, even when the
            # success text happened to be visible before the step ran.
            if step_failed and success:
                success = False
        except HopaError as exc:
            error = str(exc)
            failure = "device"
            success = False
        except Exception as exc:  # noqa: BLE001 - a task failure must not stop the run
            error = f"{type(exc).__name__}: {exc}"
            failure = "exception"
            success = False

        if success is False and failure is None:
            failure = "predicate_not_met"

        return TaskResult(
            task_id=task.id,
            goal=task.goal,
            app=task.app,
            success=success,
            steps=history,
            error=error,
            failure=failure,
            tokens=tokens,
            duration_s=time.monotonic() - started,
        )

    # -- action execution ----------------------------------------------------

    def execute(self, action: Action, task: Task) -> StepResult:
        started = time.monotonic()
        result = self._execute(action, task)
        result.latency_ms = (time.monotonic() - started) * 1000.0
        return result

    def _execute(self, action: Action, task: Task) -> StepResult:
        name = action.action
        params = action.params
        try:
            if name == "launch":
                bundle = str(params.get("bundle") or task.resolved_bundle)
                ability = str(params.get("ability", ""))
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
            haystack.extend(node.description.lower() for node in layout.walk() if node.description)

            def present(needle: str) -> bool:
                return any(needle.lower() in text for text in haystack)

            if spec.all:
                return all(present(item) for item in spec.all)
            return any(present(item) for item in spec.any)
        if spec.type == "app_foreground":
            return self._app_foreground(spec.bundle or task.resolved_bundle)
        if spec.type == "node_exists":
            layout = self.device.dump_layout()
            if spec.node_id:
                return bool(layout.find_by_id(spec.node_id))
            haystack = [text.lower() for text in layout.texts()]
            haystack.extend(node.description.lower() for node in layout.walk() if node.description)

            def present(needle: str) -> bool:
                return any(needle.lower() in text for text in haystack)

            if spec.all:
                return all(present(item) for item in spec.all)
            return any(present(item) for item in spec.any)
        if spec.type == "screen_hash":
            return layout_hash(self.device.dump_layout()) == spec.hash
        return None

    def _app_foreground(self, bundle: str) -> bool | None:
        try:
            output = self.device.hdc.shell("hidumper -s WindowManagerService -a '-a'", check=False)
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


def layout_hash(layout: Layout) -> str:
    """Stable hash of the visible text, used by ``screen_hash`` tasks."""
    payload = "\n".join(layout_texts(layout))
    return "sha256:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


def classify_failure(detail: str) -> str:
    """Map a step failure to a small, stable taxonomy."""
    lowered = (detail or "").lower()
    if "not found" in lowered:
        return "target_not_found"
    if "unsupported" in lowered:
        return "unsupported_action"
    if "bad parameters" in lowered:
        return "schema"
    if "no device" in lowered or "hdc" in lowered or "cannot observe" in lowered:
        return "device"
    return "step_failed"
