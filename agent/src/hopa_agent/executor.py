"""The single execution path.

Every action goes: validate -> classify -> approve -> execute -> observe ->
verify -> record. Nothing else may call a capability directly.
"""

from __future__ import annotations

import time
from collections.abc import Callable
from dataclasses import dataclass

from hopa_pc_agent.device import Device
from hopa_pc_agent.errors import HopaError

from .actions import Action
from .capture import capture
from .errors import ActionError, AgentError, CapabilityError
from .logging import JsonlLogger
from .net import UrlPolicy
from .observation import Observation
from .policy import ApprovalPolicy, ApprovalRequest, Decision, RiskLevel
from .records import RunRecord, RunStore

Approver = Callable[[ApprovalRequest], bool]
Observer = Callable[[], Observation]

NOOP_KINDS = {"ui.observe", "ui.wait"}


@dataclass
class Outcome:
    action: Action
    decision: Decision
    classification: RiskLevel
    approval: ApprovalRequest | None = None
    approved: bool | None = None
    executed: bool = False
    verified: bool = False
    before: Observation | None = None
    after: Observation | None = None
    error: str | None = None
    record: RunRecord | None = None

    @property
    def ok(self) -> bool:
        return self.executed and self.verified and self.error is None

    def as_dict(self) -> dict:
        return {
            "action": self.action.to_dict(),
            "decision": self.decision.value,
            "classification": self.classification.value,
            "approval": self.approval.to_dict() if self.approval else None,
            "approved": self.approved,
            "executed": self.executed,
            "verified": self.verified,
            "beforeHash": self.before.hash if self.before else "",
            "afterHash": self.after.hash if self.after else "",
            "error": self.error,
        }


class DeviceExecutor:
    def __init__(
        self,
        device: Device,
        *,
        policy: ApprovalPolicy | None = None,
        approver: Approver | None = None,
        store: RunStore | None = None,
        trace_id: str = "",
        observer: Observer | None = None,
        screenshot: bool = False,
        out_dir: str | None = None,
        url_policy: UrlPolicy | None = None,
        logger: JsonlLogger | None = None,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self.device = device
        self.policy = policy or ApprovalPolicy()
        self.approver = approver
        self.store = store
        self.trace_id = trace_id
        self.sleep = sleep
        self.screenshot = screenshot
        self.out_dir = out_dir
        self.url_policy = url_policy or UrlPolicy()
        self.logger = logger
        self.observer = observer or (
            lambda: capture(device, screenshot=screenshot, out_dir=out_dir)
        )
        self._last_key: tuple[str, str] | None = None

    def observe(self) -> Observation:
        return self.observer()

    def execute(self, action: Action, *, run_id: str = "run", step: int = 0) -> Outcome:
        before = self.observe()
        decision = self.policy.decide(action, before)
        classification = self.policy.classify(action, before)
        request = (
            self.policy.approval_request(action, before)
            if decision in {Decision.ASK, Decision.BLOCK}
            else None
        )

        approved: bool | None = None
        executed = False
        verified = False
        after: Observation | None = before
        error: str | None = None

        if decision == Decision.BLOCK:
            approved = False
            error = request.reason if request else "blocked by policy"
        elif decision == Decision.ASK:
            if self.approver is None:
                approved = False
                error = "approval required and no approver is configured (fail-closed)"
            else:
                approved = bool(self.approver(request))  # type: ignore[arg-type]
                if not approved:
                    error = "denied by the user"
        else:
            approved = True

        if approved:
            key = (action.hash(), before.hash)
            if self._last_key == key and action.kind not in NOOP_KINDS:
                error = "duplicate action on the same observation"
                approved = False
            else:
                try:
                    self._dispatch(action, before)
                    executed = True
                    self._last_key = key
                except AgentError as exc:
                    error = str(exc)
                except HopaError as exc:
                    error = str(exc)
                except Exception as exc:  # noqa: BLE001 - the record must survive
                    error = f"{type(exc).__name__}: {exc}"

                if executed:
                    after = self.observe()
                    verified = self._verify(action, before, after)

        record = RunRecord(
            run_id=run_id,
            step=step,
            trace_id=self.trace_id,
            action=action.to_dict(),
            classification=classification.value,
            approved=approved,
            observation_hash=before.hash,
            before_hash=before.hash,
            after_hash=after.hash if after else "",
            verified=verified,
            executed=executed,
            error=error,
        )
        if self.store is not None:
            self.store.append(record)
        if self.logger is not None:
            self.logger.log(
                "step",
                runId=run_id,
                step=step,
                kind=action.kind,
                classification=classification.value,
                approved=approved,
                executed=executed,
                verified=verified,
                error=error,
            )

        return Outcome(
            action=action,
            decision=decision,
            classification=classification,
            approval=request,
            approved=approved,
            executed=executed,
            verified=verified,
            before=before,
            after=after,
            error=error,
            record=record,
        )

    # -- dispatch ------------------------------------------------------------

    def _dispatch(self, action: Action, observation: Observation) -> None:
        kind = action.kind

        if kind == "ui.observe":
            return

        if kind == "ui.wait":
            seconds = _wait_seconds(action)
            self.sleep(seconds)
            return

        if kind in {"ui.tap", "ui.doubleTap", "ui.longPress"}:
            x, y = _point(action, observation)
            if kind == "ui.tap":
                self.device.tap(x, y)
            elif kind == "ui.doubleTap":
                self.device.double_tap(x, y)
            else:
                self.device.long_press(x, y)
            return

        if kind == "ui.type":
            if action.ref:
                x, y = _point(action, observation)
                self.device.type_text(action.text, x=x, y=y)
            else:
                self.device.type_text(action.text)
            return

        if kind == "ui.swipe":
            if all(value is not None for value in (action.x, action.y, action.to_x, action.to_y)):
                self.device.swipe(
                    int(action.x),  # type: ignore[arg-type]
                    int(action.y),  # type: ignore[arg-type]
                    int(action.to_x),  # type: ignore[arg-type]
                    int(action.to_y),  # type: ignore[arg-type]
                )
                return
            from_x, from_y, to_x, to_y = _swipe_for_direction(action.direction, observation)
            self.device.swipe(from_x, from_y, to_x, to_y)
            return

        if kind == "ui.scroll":
            center = observation.center(action.ref) if action.ref else None
            if center is None:
                center = (observation.width // 2, observation.height // 2)
            from_x, from_y, to_x, to_y = _swipe_for_direction(
                action.direction or "down", observation, center=center
            )
            self.device.swipe(from_x, from_y, to_x, to_y)
            return

        if kind in {"ui.back", "ui.home"}:
            self.device.press_key("Back" if kind == "ui.back" else "Home")
            return

        if kind == "ui.launch":
            self.device.launch(action.app)
            return

        if kind == "ui.stop":
            self.device.stop(action.app)
            return

        if kind == "web.navigate":
            self.url_policy.check(action.url)
            raise CapabilityError(f"{kind} is not implemented in the PC harness")

        if kind == "system.openLink":
            self.url_policy.check(action.url or action.text)
            raise CapabilityError(f"{kind} is not implemented in the PC harness")

        raise CapabilityError(f"{kind} is not implemented in the PC harness")

    # -- verification --------------------------------------------------------

    def _verify(self, action: Action, before: Observation, after: Observation) -> bool:
        if action.kind in NOOP_KINDS:
            return True
        if after is None:
            return False
        return after.hash != before.hash


def _point(action: Action, observation: Observation) -> tuple[int, int]:
    if action.ref:
        point = observation.center(action.ref)
        if point is None:
            raise ActionError(f"ref {action.ref} is stale or has no bounds")
        return point
    if action.x is None or action.y is None:
        raise ActionError(f"{action.kind} needs a ref or coordinates")
    return action.x, action.y


def _wait_seconds(action: Action) -> float:
    try:
        return max(0.0, float(action.text)) if action.text else 1.0
    except ValueError:
        return 1.0


def _swipe_for_direction(
    direction: str,
    observation: Observation,
    *,
    center: tuple[int, int] | None = None,
) -> tuple[int, int, int, int]:
    width = max(observation.width, 1)
    height = max(observation.height, 1)
    cx, cy = center or (width // 2, height // 2)
    dx = width // 4
    dy = height // 4
    direction = (direction or "down").lower()

    if direction in {"up", "上"}:
        # Scroll toward the top: the finger moves down.
        return cx, cy - dy, cx, cy + dy
    if direction in {"left", "左"}:
        # Reveal content on the right: the finger moves left.
        return cx + dx, cy, cx - dx, cy
    if direction in {"right", "右"}:
        # Reveal content on the left: the finger moves right.
        return cx - dx, cy, cx + dx, cy
    # "down" means reveal content below: the finger moves up.
    return cx, cy + dy, cx, cy - dy
