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


def recover(
    observe: Observer,
    press_back: Callable[[], None],
    press_home: Callable[[], None],
    expected_text: str,
    *,
    attempts: int = 3,
    sleep: Callable[[float], None] = time.sleep,
) -> Observation:
    """Return to a screen containing ``expected_text``: back, then home."""
    needle = expected_text.lower()
    for _ in range(attempts):
        observation = observe()
        if needle in observation.text.lower():
            return observation
        press_back()
        sleep(0.3)
    press_home()
    sleep(0.3)
    return observe()


POPUP_LABELS = ("Not now", "Later", "No thanks", "稍后", "以后再说")


def dismiss_popup(
    observe: Observer,
    tap_text: Callable[[str], None],
    *,
    attempts: int = 2,
) -> bool:
    """Dismiss only known low-risk popups (never Cancel, Close or Deny)."""
    for _ in range(attempts):
        observation = observe()
        for label in POPUP_LABELS:
            if observation.find_text(label):
                tap_text(label)
                return True
    return False
