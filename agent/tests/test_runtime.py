from __future__ import annotations

import pytest

from hopa_agent.errors import ScrollLimit, TimeoutFailure
from hopa_agent.runtime import scroll_to, wait_for


def test_wait_for_returns_immediately(settings_observation):
    observation = wait_for(
        lambda: settings_observation,
        lambda item: "Settings" in item.text,
        timeout=1,
        sleep=lambda _: None,
    )
    assert observation is settings_observation


def test_wait_for_times_out(settings_observation):
    ticks = iter([0, 10, 20, 30])

    def clock():
        return next(ticks)

    with pytest.raises(TimeoutFailure):
        wait_for(
            lambda: settings_observation,
            lambda item: False,
            timeout=1,
            clock=clock,
            sleep=lambda _: None,
        )


def test_scroll_to_stops_after_a_match(settings_observation):
    calls = {"n": 0}
    scrolls: list[str] = []

    def observe():
        calls["n"] += 1
        return settings_observation

    observation = scroll_to(
        observe,
        lambda item: calls["n"] >= 2,
        scrolls.append,
        max_attempts=3,
        sleep=lambda _: None,
    )
    assert observation is settings_observation
    assert scrolls == ["down"]


def test_scroll_to_has_a_hard_limit(settings_observation):
    scrolls: list[str] = []
    with pytest.raises(ScrollLimit):
        scroll_to(
            lambda: settings_observation,
            lambda item: False,
            scrolls.append,
            max_attempts=2,
            sleep=lambda _: None,
        )
    assert scrolls == ["down", "down"]
