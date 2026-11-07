from __future__ import annotations

import pytest

from hopa_agent.actions import Action
from hopa_agent.policy import ApprovalPolicy, Decision, RiskLevel


def test_payment_screen_tap_asks(payment_observation):
    policy = ApprovalPolicy()
    action = Action.from_dict({"kind": "ui.tap", "ref": "e5"})
    assert policy.classify(action, payment_observation) == RiskLevel.PAYMENT
    assert policy.decide(action, payment_observation) == Decision.ASK


def test_model_flag_cannot_clear_payment(payment_observation):
    policy = ApprovalPolicy()
    action = Action.from_dict({"kind": "ui.tap", "ref": "e5", "isPayment": False})
    assert policy.classify(action, payment_observation) == RiskLevel.PAYMENT


def test_normal_tap_is_allowed(settings_observation):
    policy = ApprovalPolicy()
    action = Action.from_dict({"kind": "ui.tap", "ref": "e3"})
    assert policy.classify(action, settings_observation) == RiskLevel.READ
    assert policy.decide(action, settings_observation) == Decision.ALLOW


@pytest.mark.parametrize(
    "kind",
    [
        "system.share",
        "system.openLink",
        "system.sendMessage",
        "system.call",
        "system.delete",
        "system.uninstall",
        "system.reset",
        "sandbox.run",
    ],
)
def test_sensitive_kinds_ask(kind, settings_observation):
    policy = ApprovalPolicy()
    action = Action.from_dict({"kind": kind, "text": "12345"})
    assert policy.classify(action, settings_observation) == RiskLevel.SENSITIVE
    assert policy.decide(action, settings_observation) == Decision.ASK


@pytest.mark.parametrize(
    "kind",
    [
        "payment.pay",
        "payment.confirm",
        "payment.checkout",
        "payment.enterCard",
        "payment.authorize",
    ],
)
def test_payment_kinds_are_payment(kind, settings_observation):
    policy = ApprovalPolicy()
    action = Action.from_dict({"kind": kind})
    assert policy.classify(action, settings_observation) == RiskLevel.PAYMENT
    assert policy.decide(action, settings_observation) == Decision.ASK


@pytest.mark.parametrize(
    "action",
    [
        {"kind": "ui.tap", "ref": "e5"},
        {"kind": "ui.type", "text": "x"},
        {"kind": "web.click"},
        {"kind": "ui.swipe", "direction": "down"},
    ],
)
def test_interactive_on_payment_screen_asks(action, payment_observation):
    policy = ApprovalPolicy()
    assert policy.decide(Action.from_dict(action), payment_observation) == Decision.ASK


@pytest.mark.parametrize("number", ["110", "112", "119", "120", "122", "999"])
def test_emergency_numbers_are_blocked(number, settings_observation):
    policy = ApprovalPolicy()
    action = Action.from_dict({"kind": "system.call", "text": number})
    assert policy.decide(action, settings_observation) == Decision.BLOCK


def test_ordinary_call_is_sensitive_not_blocked(settings_observation):
    policy = ApprovalPolicy()
    action = Action.from_dict({"kind": "system.call", "text": "12345"})
    assert policy.decide(action, settings_observation) == Decision.ASK


def test_read_only_action_on_payment_screen_is_allowed(payment_observation):
    policy = ApprovalPolicy()
    assert (
        policy.decide(Action.from_dict({"kind": "ui.observe"}), payment_observation)
        == Decision.ALLOW
    )


def test_approval_request_has_amount_and_merchant(payment_observation):
    policy = ApprovalPolicy()
    action = Action.from_dict({"kind": "ui.tap", "ref": "e5"})
    request = policy.approval_request(action, payment_observation)
    assert "1,299" in request.amount
    assert request.merchant == "Acme Store"
    assert request.consequence
