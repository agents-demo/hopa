from __future__ import annotations

import pytest

from hopa_baseline.observation import (
    observation_from_layout,
    redact,
)
from hopa_bridge.layout import parse_layout

from .conftest import SETTINGS


def test_refs_are_deterministic():
    first = observation_from_layout(parse_layout(SETTINGS), now_ms=1000)
    second = observation_from_layout(parse_layout(SETTINGS), now_ms=2000)
    first_refs = [(node.ref, node.text) for node in first.walk()]
    second_refs = [(node.ref, node.text) for node in second.walk()]
    assert first_refs == second_refs
    assert first.hash == second.hash
    assert first.id != second.id


def test_hash_changes_with_text():
    first = observation_from_layout(parse_layout(SETTINGS), now_ms=1000)
    changed = {
        "attributes": {"type": "Root", "bounds": "[0,0][1080,2400]"},
        "children": [
            {"attributes": {"type": "Text", "text": "Different", "bounds": "[0,100][1080,220]"}}
        ],
    }
    second = observation_from_layout(parse_layout(changed), now_ms=1000)
    assert first.hash != second.hash


def test_find_text_and_center(settings_observation):
    node = settings_observation.find_text("bluetooth")[0]
    assert node.ref
    assert settings_observation.center(node.ref) == (540, 360)


def test_redacts_email_phone_card_and_secret():
    assert "a.b@example.com" not in redact("mail a.b@example.com")
    assert "138 0013 8000" not in redact("call 138 0013 8000")
    assert "4111 1111 1111 1111" not in redact("card 4111 1111 1111 1111")
    assert "hunter2" not in redact("password: hunter2")
    assert redact("Order 123456 shipped") == "Order 123456 shipped"
    assert "123456" not in redact("Your verification code is 123456")


def test_truncation_keeps_focus_path():
    many = {
        "attributes": {"type": "Root", "bounds": "[0,0][1080,2400]"},
        "children": [
            {
                "attributes": {
                    "type": "Button",
                    "text": f"Item {index}",
                    "bounds": f"[0,{index * 40}][1080,{index * 40 + 30}]",
                    "clickable": "true",
                }
            }
            for index in range(80)
        ],
    }
    observation = observation_from_layout(parse_layout(many), now_ms=1000, max_nodes=10)
    assert observation.truncated is True
    assert sum(1 for _ in observation.walk()) <= 11
    assert observation.hash.startswith("sha256:")


@pytest.mark.parametrize(
    ("text", "secret"),
    [
        ("mail a.b@example.com", "a.b@example.com"),
        ("call 138 0013 8000", "138 0013 8000"),
        ("call +86 13800138000", "13800138000"),
        ("card 4111 1111 1111 1111", "4111"),
        ("card 4111-1111-1111-1111", "4111"),
        ("password: hunter2", "hunter2"),
        ("passcode=9988", "9988"),
        ("PIN: 4321", "4321"),
        ("密码: abc123", "abc123"),
        ("Your code is 123456", "123456"),
        ("验证码 654321", "654321"),
        ("OTP: 998877", "998877"),
        ("one-time code 445566", "445566"),
        ("verification code: 112233", "112233"),
        ("pin 778899", "778899"),
        ("Contact: user+tag@example.co.uk", "user+tag@example.co.uk"),
        ("card 5500 0000 0000 0004", "5500"),
        ("密码：qwerty", "qwerty"),
        ("口令=abc", "abc"),
        ("手机号 13900139000", "13900139000"),
    ],
)
def test_redaction_cases(text: str, secret: str):
    assert secret not in redact(text)


def test_ordinary_numbers_survive():
    assert redact("Order 123456 shipped") == "Order 123456 shipped"
    assert "2026" in redact("Year 2026")
    assert "1299" in redact("Price 1299")
