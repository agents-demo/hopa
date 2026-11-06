"""Refusal policy for disallowed tasks.

The policy is a first line, not a complete classifier. It refuses clearly
illegal, harmful, harassing, fraudulent or professional-advice requests and
hands CAPTCHA back to the user. The model still sees the system rules.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum


class RefusalCategory(StrEnum):
    ILLEGAL = "illegal"
    HARMFUL = "harmful"
    HARASSMENT = "harassment"
    FRAUD = "fraud"
    FINANCIAL_ADVICE = "financial_advice"
    MEDICAL_ADVICE = "medical_advice"
    LEGAL_ADVICE = "legal_advice"
    CAPTCHA = "captcha"


@dataclass
class Refusal:
    category: RefusalCategory
    message: str
    handover: bool = False


RULES: list[tuple[RefusalCategory, tuple[str, ...], str, bool]] = [
    (
        RefusalCategory.CAPTCHA,
        ("captcha", "人机验证", "滑块验证", "点选验证"),
        "I can't solve CAPTCHA. Please complete it yourself and tell me to continue.",
        True,
    ),
    (
        RefusalCategory.ILLEGAL,
        ("malware", "ransomware", "bomb", "exploit", "keylogger", "木马", "勒索", "炸弹", "盗号"),
        "I can't help with that request.",
        False,
    ),
    (
        RefusalCategory.HARMFUL,
        ("poison", "hurt someone", "weapon", "下毒", "伤害别人", "武器"),
        "I can't help with something that could hurt someone.",
        False,
    ),
    (
        RefusalCategory.HARASSMENT,
        ("harass", "stalk", "dox", "骚扰", "人肉", "跟踪"),
        "I can't help harass or track a person.",
        False,
    ),
    (
        RefusalCategory.FRAUD,
        ("scam", "phishing", "steal money", "诈骗", "钓鱼", "骗钱"),
        "I can't help with fraud or deception.",
        False,
    ),
    (
        RefusalCategory.FINANCIAL_ADVICE,
        ("should i invest", "stock tip", "which stock", "理财建议", "买哪只股票", "投资建议"),
        "I can't give financial advice. Please ask a qualified professional.",
        False,
    ),
    (
        RefusalCategory.MEDICAL_ADVICE,
        ("diagnose", "what medicine", "dosage", "诊断", "吃什么药", "用药剂量"),
        "I can't give medical advice. Please ask a doctor.",
        False,
    ),
    (
        RefusalCategory.LEGAL_ADVICE,
        ("sue ", "legal advice", "lawsuit", "起诉", "法律建议"),
        "I can't give legal advice. Please ask a lawyer.",
        False,
    ),
]


class RefusalPolicy:
    def check(self, task: str) -> Refusal | None:
        text = (task or "").lower()
        for category, words, message, handover in RULES:
            if any(word.lower() in text for word in words):
                return Refusal(category=category, message=message, handover=handover)
        return None
