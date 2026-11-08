from __future__ import annotations

import pytest

from hopa_agent.errors import ScrollLimit, TimeoutFailure
from hopa_agent.observation import observation_from_layout
from hopa_agent.runtime import dismiss_popup, recover, scroll_to, wait_for
from hopa_pc_agent.layout import parse_layout


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


def test_recover_goes_back_to_the_expected_screen(settings_observation):
    other = observation_from_layout(
        parse_layout(
            {
                "attributes": {"type": "Root", "bounds": "[0,0][1080,2400]"},
                "children": [
                    {
                        "attributes": {
                            "type": "Text",
                            "text": "Some other screen",
                            "bounds": "[0,0][100,100]",
                        }
                    }
                ],
            }
        ),
        now_ms=1,
    )
    screens = [other, settings_observation]
    calls = {"n": 0}
    backs: list[int] = []

    def observe():
        index = min(calls["n"], len(screens) - 1)
        calls["n"] += 1
        return screens[index]

    result = recover(
        observe,
        lambda: backs.append(1),
        lambda: None,
        "Settings",
        attempts=3,
        sleep=lambda _: None,
    )
    assert result is settings_observation
    assert backs == [1]


def test_dismiss_popup_only_uses_safe_labels(settings_observation):
    layout = parse_layout(
        {
            "attributes": {"type": "Root", "bounds": "[0,0][1080,2400]"},
            "children": [
                {
                    "attributes": {
                        "type": "Button",
                        "text": "Not now",
                        "bounds": "[0,0][400,100]",
                        "clickable": "true",
                    }
                }
            ],
        }
    )
    popup = observation_from_layout(layout, now_ms=1)
    taps: list[str] = []
    assert dismiss_popup(lambda: popup, taps.append) is True
    assert taps == ["Not now"]
