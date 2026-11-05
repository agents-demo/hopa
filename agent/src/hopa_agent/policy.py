"""The approval policy: the one place that decides read / ask / block.

Payment is detected from the **screen and the action**, never from a model
flag. A tap on a screen that looks like checkout is a payment action even if
the model says otherwise. Denials are final and are never remembered.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from enum import StrEnum

from .actions import Action
from .observation import Observation

POLICY_VERSION = "1"

PAYMENT_KINDS = {
    "payment.pay",
    "payment.confirm",
    "payment.checkout",
    "payment.enterCard",
    "payment.authorize",
}

PAYMENT_SCREEN_WORDS = {
    "pay",
    "payment",
    "checkout",
    "confirm order",
    "place order",
    "buy now",
    "purchase",
    "subscribe",
    "amount",
    "total",
    "merchant",
    "currency",
    "card number",
    "支付",
    "付款",
    "结算",
    "确认订单",
    "立即购买",
    "金额",
    "商户",
    "银行卡",
}

SENSITIVE_KINDS = {
    "system.openLink",
    "system.share",
    "system.sendMessage",
    "system.call",
    "system.delete",
    "system.uninstall",
    "system.reset",
    "sandbox.run",
}

READ_KINDS = {
    "ui.observe",
    "ui.tap",
    "ui.doubleTap",
    "ui.longPress",
    "ui.type",
    "ui.swipe",
    "ui.scroll",
    "ui.back",
    "ui.home",
    "ui.launch",
    "ui.stop",
    "ui.wait",
    "web.navigate",
    "web.read",
    "web.click",
    "web.type",
}

EMERGENCY_NUMBERS = {"110", "112", "119", "120", "122", "999"}

AMOUNT_RE = re.compile(
    r"(?:¥|￥|\$|€|£|CNY|RMB|USD)\s?[\d,]+(?:\.\d{1,2})?"
    r"|[\d,]+(?:\.\d{1,2})?\s?(?:元|CNY|RMB|USD)",
    re.IGNORECASE,
)
MERCHANT_RE = re.compile(r"(?i)(?:merchant|payee|to|商户|收款方|付款给)\s*[:：]?\s*(.+)")


class RiskLevel(StrEnum):
    READ = "read"
    SENSITIVE = "sensitive"
    PAYMENT = "payment"


class Decision(StrEnum):
    ALLOW = "allow"
    ASK = "ask"
    BLOCK = "block"


@dataclass
class ApprovalRequest:
    classification: str
    reason: str
    amount: str = ""
    merchant: str = ""
    consequence: str = ""
    excerpt: str = ""

    def to_dict(self) -> dict:
        return {
            "classification": self.classification,
            "reason": self.reason,
            "amount": self.amount,
            "merchant": self.merchant,
            "consequence": self.consequence,
            "excerpt": self.excerpt,
        }


class ApprovalPolicy:
    """Classify actions and decide whether they may run."""

    def __init__(self, *, payment_words: set[str] | None = None) -> None:
        self.payment_words = payment_words or PAYMENT_SCREEN_WORDS

    def is_payment_screen(self, observation: Observation) -> bool:
        return observation.contains_any(self.payment_words)

    def classify(self, action: Action, observation: Observation) -> RiskLevel:
        if action.kind in PAYMENT_KINDS:
            return RiskLevel.PAYMENT
        if self.is_payment_screen(observation) and action.kind not in {
            "ui.observe",
            "ui.wait",
            "ui.back",
            "ui.home",
        }:
            return RiskLevel.PAYMENT
        if action.kind in SENSITIVE_KINDS:
            return RiskLevel.SENSITIVE
        if action.kind in READ_KINDS:
            return RiskLevel.READ
        # Unknown kinds never run without a human.
        return RiskLevel.SENSITIVE

    def is_emergency_call(self, action: Action) -> bool:
        if action.kind != "system.call":
            return False
        digits = re.sub(r"\D", "", action.text)
        return digits in EMERGENCY_NUMBERS

    def decide(self, action: Action, observation: Observation) -> Decision:
        if self.is_emergency_call(action):
            return Decision.BLOCK
        level = self.classify(action, observation)
        if level == RiskLevel.READ:
            return Decision.ALLOW
        return Decision.ASK

    def approval_request(self, action: Action, observation: Observation) -> ApprovalRequest:
        level = self.classify(action, observation)
        amount, merchant = extract_payment_context(observation)
        if self.is_emergency_call(action):
            return ApprovalRequest(
                classification=level.value,
                reason="Emergency numbers are never dialled by HOPA.",
                consequence="The user must place the call.",
                excerpt=observation.text[:200],
            )
        if level == RiskLevel.PAYMENT:
            reason = "This screen looks like a checkout or payment screen."
            consequence = "Money may leave the account. HOPA never repeats a payment."
        elif level == RiskLevel.SENSITIVE:
            reason = f"{action.kind} is irreversible or leaves the app."
            consequence = "The action may not be undoable."
        else:
            reason = "No approval needed."
            consequence = ""
        return ApprovalRequest(
            classification=level.value,
            reason=reason,
            amount=amount,
            merchant=merchant,
            consequence=consequence,
            excerpt=observation.text[:200],
        )


def extract_payment_context(observation: Observation) -> tuple[str, str]:
    text = observation.text
    amount_match = AMOUNT_RE.search(text)
    amount = amount_match.group(0).strip() if amount_match else ""

    merchant = ""
    for line in text.splitlines():
        match = MERCHANT_RE.search(line)
        if match:
            merchant = match.group(1).strip()[:80]
            break
    if not merchant:
        for line in text.splitlines():
            stripped = line.strip()
            if stripped and stripped != amount and not AMOUNT_RE.search(stripped):
                merchant = stripped[:80]
                break
    return amount, merchant
