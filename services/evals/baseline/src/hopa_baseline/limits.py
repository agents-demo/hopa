"""Per-action rate limits and per-task tool allow-lists."""

from __future__ import annotations

import time
from dataclasses import dataclass

from .errors import PolicyError


@dataclass(frozen=True)
class RateLimit:
    max_actions: int
    window_seconds: float


DEFAULT_LIMITS: dict[str, RateLimit] = {
    "system.sendMessage": RateLimit(20, 3600),
    "system.call": RateLimit(10, 3600),
    "system.share": RateLimit(20, 3600),
    "system.delete": RateLimit(20, 3600),
    "system.uninstall": RateLimit(5, 3600),
    "system.reset": RateLimit(2, 3600),
    "payment.pay": RateLimit(5, 3600),
    "payment.confirm": RateLimit(5, 3600),
    "payment.checkout": RateLimit(5, 3600),
    "payment.enterCard": RateLimit(5, 3600),
    "payment.authorize": RateLimit(5, 3600),
}


class ActionLimiter:
    def __init__(
        self,
        limits: dict[str, RateLimit] | None = None,
        *,
        clock=time.monotonic,
    ) -> None:
        self.limits = limits if limits is not None else DEFAULT_LIMITS
        self.clock = clock
        self._events: dict[str, list[float]] = {}

    def check(self, kind: str) -> None:
        limit = self.limits.get(kind)
        if limit is None:
            return
        now = self.clock()
        events = [
            stamp for stamp in self._events.get(kind, []) if now - stamp < limit.window_seconds
        ]
        self._events[kind] = events
        if len(events) >= limit.max_actions:
            raise PolicyError(
                f"rate limit reached for {kind}: "
                f"{limit.max_actions} per {limit.window_seconds:.0f}s"
            )

    def record(self, kind: str) -> None:
        if kind in self.limits:
            self._events.setdefault(kind, []).append(self.clock())
