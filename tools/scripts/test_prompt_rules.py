"""Tests for the shared prompt rules and their ArkTS rendering."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "scripts" / "build-prompt-rules.py"
SOURCE = ROOT / "contracts" / "prompts" / "rules.v1.json"
GENERATED = ROOT / "apps" / "harmony" / "core" / "src" / "main" / "ets" / "agent" / "PromptRules.ets"
PROMPT = ROOT / "apps" / "harmony" / "core" / "src" / "main" / "ets" / "agent" / "PromptBuilder.ets"
TEST = ROOT / "apps" / "harmony" / "core" / "src" / "test" / "PromptContract.test.ets"


def _module():
    spec = importlib.util.spec_from_file_location("build_prompt_rules", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_rules_are_unique_and_non_empty() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    assert data["schemaVersion"] == "1"
    ids = [rule["id"] for rule in data["rules"]]
    assert len(ids) == len(set(ids))
    for rule in data["rules"]:
        assert rule["phrases"], rule["id"]
        assert all(phrase.strip() == phrase for phrase in rule["phrases"])


def test_every_phrase_is_in_the_harmony_prompt_source() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    text = PROMPT.read_text(encoding="utf-8")
    for rule in data["rules"]:
        for phrase in rule["phrases"]:
            assert phrase in text, f"{rule['id']}: {phrase!r}"


def test_generated_file_is_current() -> None:
    module = _module()
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    assert GENERATED.read_text(encoding="utf-8") == module.render(data)


def test_client_test_is_wired() -> None:
    assert TEST.exists()
    index = (ROOT / "apps" / "harmony" / "core" / "src" / "test" / "List.test.ets").read_text(
        encoding="utf-8"
    )
    assert "PromptContract.test" in index
    assert "promptContractTest()" in index
