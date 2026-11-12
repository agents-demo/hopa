"""Client for the JVM brain's ``/decide`` route and a first-step wrapper.

The brain owns app routing and the knowledge base; the model owns the rest of
the loop. ``BrainFirstModel`` asks the brain where to start, then delegates every
later step to the model client.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass, field
from typing import Any

from .actions import Action
from .errors import AgentError, ModelError
from .models import ModelClient, ModelDecision
from .observation import Observation


class BrainError(ModelError):
    """The brain service could not answer. Retryable, not fatal by itself."""

    def __init__(self, message: str) -> None:
        super().__init__(f"brain: {message}", retryable=True)


@dataclass
class RouteDecision:
    action: Action | None = None
    say: str = ""
    need_user: bool = False
    options: list[str] = field(default_factory=list)


class BrainClient:
    """Calls ``POST /decide`` with a goal and the installed bundles."""

    def __init__(
        self,
        base_url: str,
        *,
        timeout: float = 5.0,
        transport: Callable[[dict], dict] | None = None,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.transport = transport

    def route(self, goal: str, installed: list[str] | None = None) -> RouteDecision:
        payload = {
            "goal": goal,
            "settings": {
                "installed": [{"bundle": bundle, "label": bundle} for bundle in (installed or [])]
            },
        }
        try:
            data = self.transport(payload) if self.transport else self._http(payload)
        except BrainError:
            raise
        except Exception as exc:  # noqa: BLE001 - network and JSON both land here
            raise BrainError(str(exc)) from exc
        if not isinstance(data, dict):
            raise BrainError("reply is not a JSON object")

        action: Action | None = None
        raw_action = data.get("action")
        if raw_action is not None:
            if not isinstance(raw_action, dict):
                raise BrainError("action is not an object")
            try:
                action = Action.from_dict(raw_action, source="brain")
            except AgentError as exc:
                raise BrainError(str(exc)) from exc

        options = [str(item) for item in (data.get("options") or [])]
        return RouteDecision(
            action=action,
            say=str(data.get("say") or ""),
            need_user=bool(data.get("needUser", data.get("need_user", False))),
            options=options,
        )

    def _http(self, payload: dict) -> dict:
        body = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            f"{self.base_url}/decide",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")[:200]
            raise BrainError(f"HTTP {exc.code}: {detail}") from exc
        except urllib.error.URLError as exc:
            raise BrainError(f"network error: {exc.reason}") from exc


class BrainFirstModel:
    """Ask the brain for the first action, then use the model for the rest."""

    def __init__(
        self,
        brain: BrainClient,
        installed: list[str],
        fallback: ModelClient,
    ) -> None:
        self.brain = brain
        self.installed = installed
        self.fallback = fallback
        self.last_brain_error: str = ""

    def decide(
        self,
        goal: str,
        observation: Observation,
        history: list[dict],
        step: int,
    ) -> ModelDecision:
        if step == 0:
            try:
                route = self.brain.route(goal, self.installed)
            except BrainError as exc:
                self.last_brain_error = str(exc)
            else:
                self.last_brain_error = ""
                if route.action is not None:
                    return ModelDecision(route.action, say=route.say)
                if route.need_user:
                    return ModelDecision(
                        None,
                        say=route.say,
                        need_user=True,
                        options=route.options,
                    )
        return self.fallback.decide(goal, observation, history, step)


def installed_bundles(device: Any) -> list[str]:
    """Best-effort bundle list for the brain; returns [] on any failure."""
    try:
        return [str(app["bundle"]) for app in device.apps()]
    except Exception:  # noqa: BLE001 - routing still works without the list
        return []
