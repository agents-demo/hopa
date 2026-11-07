from __future__ import annotations

import pytest

from hopa_agent.actions import Action
from hopa_agent.errors import ActionError


def test_unknown_kind_is_rejected():
    with pytest.raises(ActionError):
        Action.from_dict({"kind": "ui.explode"})


def test_model_payment_flag_is_ignored():
    action = Action.from_dict({"kind": "ui.tap", "ref": "e1", "isPayment": False})
    assert action.ignored_fields == ["isPayment"]
    assert "isPayment" not in action.to_dict()


def test_tap_needs_a_target():
    with pytest.raises(ActionError):
        Action.from_dict({"kind": "ui.tap"})


def test_type_needs_text():
    with pytest.raises(ActionError):
        Action.from_dict({"kind": "ui.type", "ref": "e1"})


def test_json_fence_is_tolerated():
    action = Action.from_json('```json\n{"kind": "ui.tap", "ref": "e2"}\n```')
    assert action.ref == "e2"


def test_hash_is_stable():
    first = Action.from_dict({"kind": "ui.tap", "ref": "e2"})
    second = Action.from_dict({"kind": "ui.tap", "ref": "e2", "timeoutMs": 10000})
    assert first.hash() == second.hash()
