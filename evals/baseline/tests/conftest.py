from __future__ import annotations

import json
from pathlib import Path

import pytest

from hopa_baseline.observation import observation_from_layout
from hopa_pc_agent.layout import parse_layout

SETTINGS = {
    "attributes": {"type": "Root", "bounds": "[0,0][1080,2400]", "text": ""},
    "children": [
        {"attributes": {"type": "Text", "text": "Settings", "bounds": "[0,100][1080,220]"}},
        {
            "attributes": {
                "type": "Button",
                "text": "Bluetooth",
                "id": "bluetooth",
                "bounds": "[40,300][1040,420]",
                "clickable": "true",
            }
        },
        {
            "attributes": {
                "type": "Button",
                "text": "Wi-Fi",
                "id": "wifi",
                "bounds": "[40,440][1040,560]",
                "clickable": "true",
            }
        },
    ],
}

BLUETOOTH = {
    "attributes": {"type": "Root", "bounds": "[0,0][1080,2400]"},
    "children": [
        {"attributes": {"type": "Text", "text": "Bluetooth", "bounds": "[0,100][1080,220]"}},
        {
            "attributes": {
                "type": "Toggle",
                "text": "Bluetooth is off",
                "bounds": "[40,300][1040,420]",
                "clickable": "true",
                "checked": "false",
            }
        },
    ],
}

BLUETOOTH_ON = {
    "attributes": {"type": "Root", "bounds": "[0,0][1080,2400]"},
    "children": [
        {"attributes": {"type": "Text", "text": "Bluetooth", "bounds": "[0,100][1080,220]"}},
        {
            "attributes": {
                "type": "Toggle",
                "text": "Bluetooth is on",
                "bounds": "[40,300][1040,420]",
                "clickable": "true",
                "checked": "true",
            }
        },
    ],
}

PAYMENT = {
    "attributes": {"type": "Root", "bounds": "[0,0][1080,2400]"},
    "children": [
        {"attributes": {"type": "Text", "text": "Checkout", "bounds": "[0,100][1080,220]"}},
        {
            "attributes": {
                "type": "Text",
                "text": "Merchant: Acme Store",
                "bounds": "[0,240][1080,320]",
            }
        },
        {"attributes": {"type": "Text", "text": "Total ¥1,299.00", "bounds": "[0,340][1080,420]"}},
        {
            "attributes": {
                "type": "Button",
                "text": "Pay now",
                "id": "pay",
                "bounds": "[40,2000][1040,2200]",
                "clickable": "true",
            }
        },
    ],
}


class FakeDevice:
    """A device stand-in that serves layouts and records calls."""

    def __init__(self, layouts, *, advance: bool = True) -> None:
        self.layouts = [parse_layout(layout) for layout in layouts]
        self.index = 0
        self.advance = advance
        self.calls: list[tuple] = []

    def dump_layout(self, **kwargs):
        return self.layouts[min(self.index, len(self.layouts) - 1)]

    def _advance(self) -> None:
        if self.advance:
            self.index = min(self.index + 1, len(self.layouts) - 1)

    def tap(self, x: int, y: int) -> None:
        self.calls.append(("tap", x, y))
        self._advance()

    def double_tap(self, x: int, y: int) -> None:
        self.calls.append(("double_tap", x, y))
        self._advance()

    def long_press(self, x: int, y: int) -> None:
        self.calls.append(("long_press", x, y))
        self._advance()

    def swipe(self, *args, **kwargs) -> None:
        self.calls.append(("swipe", *args))
        self._advance()

    def type_text(self, text: str, *, x=None, y=None) -> None:
        self.calls.append(("type", text, x, y))
        self._advance()

    def press_key(self, key: str) -> None:
        self.calls.append(("key", key))
        self._advance()

    def launch(self, bundle: str, ability: str = "EntryAbility") -> None:
        self.calls.append(("launch", bundle, ability))
        self._advance()

    def stop(self, bundle: str) -> None:
        self.calls.append(("stop", bundle))
        self._advance()

    def screenshot(self, path) -> Path:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"jpeg")
        return path


@pytest.fixture
def settings_observation():
    return observation_from_layout(parse_layout(SETTINGS), now_ms=1_700_000_000_000)


@pytest.fixture
def payment_observation():
    return observation_from_layout(parse_layout(PAYMENT), now_ms=1_700_000_000_000)


@pytest.fixture
def settings_device():
    return FakeDevice([SETTINGS, BLUETOOTH, BLUETOOTH_ON])


@pytest.fixture
def payment_device():
    return FakeDevice([PAYMENT, PAYMENT], advance=False)


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))
