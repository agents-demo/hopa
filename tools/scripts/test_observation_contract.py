"""Tests for the observation contract data and the cross-client hash vector."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECK = ROOT / "tools" / "checks" / "check-observation-hash.py"
LIMITS = ROOT / "contracts" / "observation" / "limits.v1.json"
FIXTURES = ROOT / "contracts" / "fixtures" / "observation-hash.json"


def _module():
    spec = importlib.util.spec_from_file_location("check_observation_hash", CHECK)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_fixture_hash_matches() -> None:
    assert _module().check() == []


def test_projection_ignores_metadata() -> None:
    module = _module()
    document = json.loads(FIXTURES.read_text(encoding="utf-8"))
    observation = document["cases"][0]["observation"]
    before = module.digest(observation)
    changed = dict(observation)
    changed["id"] = "obs-other"
    changed["timestamp"] = 999
    changed["screenshotRef"] = "/tmp/shot.jpeg"
    assert module.digest(changed) == before
    changed["text"] = "different"
    assert module.digest(changed) != before


def test_limits_are_the_contract_numbers() -> None:
    limits = json.loads(LIMITS.read_text(encoding="utf-8"))
    assert limits["schemaVersion"] == "1"
    assert limits["maxNodes"] == 400
    assert limits["maxTextChars"] == 6000
    assert limits["maxElementLines"] == 120
    assert limits["maxBrowserTextChars"] == 20000
    assert limits["keepFocusPath"] is True
    assert set(limits["redact"]) == {"email", "phone", "card", "password", "otp"}
