"""Runtime helpers: bounded waiting and bounded scrolling.

These are the small policies that keep the loop from spinning forever. They
take an ``observe`` callable so they work with a fake device in tests and with
the real executor in production.
"""

from __future__ import annotations

import time
from collections.abc import Callable

from .errors import ScrollLimit, TimeoutFailure
from .observation import Observation

Observer = Callable[[], Observation]
Predicate = Callable[[Observation], bool]
Scroll = Callable[[str], None]


def wait_for(
    observe: Observer,
    predicate: Predicate,
    *,
    timeout: float = 10.0,
    interval: float = 0.5,
    clock: Callable[[], float] = time.monotonic,
    sleep: Callable[[float], None] = time.sleep,
) -> Observation:
    """Observe until ``predicate`` is true or the timeout expires."""
    started = clock()
    while True:
        observation = observe()
        if predicate(observation):
            return observation
        if clock() - started >= timeout:
            raise TimeoutFailure(f"condition not met within {timeout:.1f}s")
        sleep(interval)


def scroll_to(
    observe: Observer,
    predicate: Predicate,
    scroll: Scroll,
    *,
    direction: str = "down",
    max_attempts: int = 5,
    interval: float = 0.3,
    sleep: Callable[[float], None] = time.sleep,
) -> Observation:
    """Scroll until ``predicate`` is true, with a hard attempt limit."""
    observation = observe()
    for _ in range(max_attempts):
        if predicate(observation):
            return observation
        scroll(direction)
        sleep(interval)
        observation = observe()
    if predicate(observation):
        return observation
    raise ScrollLimit(f"target not found after {max_attempts} scrolls")
