"""Tests for the routing fixtures and the reference matcher."""

from __future__ import annotations

import ast
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECK = ROOT / "tools" / "checks" / "check-routing.py"
FIXTURES = ROOT / "contracts" / "fixtures" / "routing.json"
ROUTER = ROOT / "apps" / "harmony" / "core" / "src" / "main" / "ets" / "router" / "AppRouter.ets"


def _module():
    spec = importlib.util.spec_from_file_location("check_routing", CHECK)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_fixtures_pass() -> None:
    assert _module().check() == []


def test_generic_words_match_the_arkts_router() -> None:
    text = ROUTER.read_text(encoding="utf-8")
    start = text.index("GENERIC: string[] = [")
    start = text.index("= [", start) + 2
    end = text.index("];", start)
    arkts = ast.literal_eval(text[start : end + 1])
    fixture = json.loads(FIXTURES.read_text(encoding="utf-8"))["generic"]
    assert set(arkts) == set(fixture)


def test_ascii_boundaries() -> None:
    module = _module()
    assert module.contains_term("open clock", "clock")
    assert not module.contains_term("clockwork", "clock")
    assert module.contains_term("打开支付宝", "支付宝")


def test_digit_and_generic_rules() -> None:
    module = _module()
    generic = {"open", "app"}
    target = {"name": "five", "display": "Five", "bundle": "x", "aliases": ["5"]}
    assert module.score(target, "5", generic) is None
    target["aliases"] = ["555"]
    assert module.score(target, "555", generic) == (3, "555")
    assert module.score({"name": "open", "display": "Open", "aliases": []}, "open", generic) is None
