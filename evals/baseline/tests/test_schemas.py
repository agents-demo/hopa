from __future__ import annotations

import json
from pathlib import Path

import pytest

from hopa_pc_agent.layout import parse_layout

jsonschema = pytest.importorskip("jsonschema")
from jsonschema import Draft202012Validator  # noqa: E402
from referencing import Registry, Resource  # noqa: E402

from hopa_baseline.actions import Action  # noqa: E402
from hopa_baseline.models import ModelDecision  # noqa: E402
from hopa_baseline.observation import observation_from_layout  # noqa: E402
from hopa_baseline.records import RunRecord  # noqa: E402

from .conftest import SETTINGS  # noqa: E402

SCHEMAS = Path(__file__).resolve().parents[3] / "contracts" / "schemas"
NAMES = [
    "observation.schema.json",
    "action.schema.json",
    "decision.schema.json",
    "run-record.schema.json",
]


def _load(name: str) -> dict:
    return json.loads((SCHEMAS / name).read_text(encoding="utf-8"))


def _registry() -> Registry:
    pairs = []
    for name in NAMES:
        schema = _load(name)
        resource = Resource.from_contents(schema)
        pairs.append((name, resource))
        pairs.append((schema["$id"], resource))
    return Registry().with_resources(pairs)


def _validate(name: str, instance: dict) -> None:
    Draft202012Validator(_load(name), registry=_registry()).validate(instance)


def test_observation_matches_schema():
    observation = observation_from_layout(parse_layout(SETTINGS), now_ms=1000)
    _validate("observation.schema.json", observation.to_dict())


def test_action_matches_schema():
    action = Action.from_dict({"kind": "ui.tap", "ref": "e1"})
    _validate("action.schema.json", action.to_dict())


def test_decision_matches_schema():
    action = Action.from_dict({"kind": "ui.observe"})
    decision = ModelDecision(action=action, say="ok", done=False, need_user=False)
    _validate("decision.schema.json", decision.to_dict())


def test_run_record_matches_schema():
    action = Action.from_dict({"kind": "ui.tap", "ref": "e1"})
    record = RunRecord(
        run_id="r1",
        step=0,
        trace_id="t1",
        action=action.to_dict(),
        classification="read",
        approved=True,
        observation_hash="h",
        verified=True,
        executed=True,
    ).seal("")
    _validate("run-record.schema.json", record.to_dict())
