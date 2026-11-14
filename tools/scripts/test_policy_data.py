"""Tests for the shared approval vocabularies and their ArkTS rendering."""

from __future__ import annotations

import importlib.util
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "scripts" / "build-policy-data.py"
SOURCE = ROOT / "contracts" / "policy" / "approval.v1.json"
GENERATED = ROOT / "apps" / "harmony" / "core" / "src" / "main" / "ets" / "gate" / "PolicyData.ets"
SCHEMA = ROOT / "contracts" / "schemas" / "action.schema.json"
POLICY = ROOT / "apps" / "harmony" / "core" / "src" / "main" / "ets" / "gate" / "ApprovalPolicy.ets"

# Names the Harmony parser still emits that the JSON Schema does not (yet) list.
LEGACY_KINDS = {"ui.sendMessage", "ui.call", "a11y.observe", "sandbox.runNetworked"}


def _module():
    spec = importlib.util.spec_from_file_location("build_policy_data", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _data() -> dict:
    return json.loads(SOURCE.read_text(encoding="utf-8"))


def test_lists_are_not_empty() -> None:
    data = _data()
    for key in (
        "paymentKinds",
        "paymentWords",
        "paymentActions",
        "interactiveKinds",
        "sensitiveKinds",
        "allowedKinds",
        "trustedAppKinds",
    ):
        assert data[key], key
        assert len(set(data[key])) == len(data[key]), f"{key} has duplicates"


def test_kinds_exist_in_the_schema_apart_from_legacy_names() -> None:
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    kinds = set(schema["properties"]["kind"]["enum"])
    data = _data()
    used = set(data["paymentKinds"]) | set(data["interactiveKinds"])
    used |= set(data["sensitiveKinds"]) | set(data["allowedKinds"])
    used |= set(data["trustedAppKinds"])
    unknown = used - kinds
    assert unknown <= LEGACY_KINDS, f"unknown kinds: {sorted(unknown - LEGACY_KINDS)}"
    assert "payment.pay" in kinds


def test_payment_regexes_are_shared() -> None:
    data = _data()["payment"]
    assert data["currencyFlags"] == "i"
    assert data["totalFlags"] == "i"
    assert re.search(data["currencyPattern"], "Total ¥19.99", re.IGNORECASE)
    assert re.search(data["totalPattern"], "总金额 199", re.IGNORECASE)
    assert data["merchantPrefixes"] == ["merchant:", "商户"]


def test_generated_file_is_current() -> None:
    module = _module()
    output = module.render(_data())
    assert GENERATED.read_text(encoding="utf-8") == output
    assert "--check" in SCRIPT.read_text(encoding="utf-8")
    for constant in (
        "PAYMENT_KINDS",
        "PAYMENT_WORDS",
        "PAYMENT_ACTIONS",
        "INTERACTIVE_KINDS",
        "SENSITIVE_KINDS",
        "ALLOWED_KINDS",
        "TRUSTED_APP_KINDS",
        "CURRENCY_RE",
        "TOTAL_RE",
        "PAYMENT_CONSEQUENCE",
    ):
        assert f"export const {constant}" in output, constant


def test_kotlin_rendering_uses_the_same_values() -> None:
    module = _module()
    data = _data()
    output = module.render_kotlin(data)
    assert "package com.hopa.policy" in output
    assert "object ApprovalPolicyData" in output
    for kind in data["paymentKinds"]:
        assert module.kotlin_string(kind) in output
    assert "Regex(" in output
    assert "RegexOption.IGNORE_CASE" in output
    assert module.kotlin_string("cost $5") == '"cost \\$5"'
    assert module.kotlin_string("a\\s") == '"a\\\\s"'


def test_policy_code_reads_the_generated_data() -> None:
    text = POLICY.read_text(encoding="utf-8")
    for constant in (
        "PAYMENT_KINDS",
        "PAYMENT_WORDS",
        "PAYMENT_ACTIONS",
        "INTERACTIVE_KINDS",
        "SENSITIVE_KINDS",
        "ALLOWED_KINDS",
        "TRUSTED_APP_KINDS",
        "CURRENCY_RE",
        "TOTAL_RE",
        "MERCHANT_PREFIXES",
    ):
        assert constant in text, constant
    for constant in (
        "PAYMENT_KINDS",
        "INTERACTIVE_KINDS",
        "SENSITIVE_KINDS",
        "ALLOWED_KINDS",
    ):
        assert f"new Set<string>({constant})" in text, constant
    # The vocabulary must not be copied back into the policy class.
    assert "private paymentWords: string[] = [" not in text
    assert "private paymentActions: string[] = [" not in text
