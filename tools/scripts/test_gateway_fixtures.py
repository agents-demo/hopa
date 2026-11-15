"""Protocol v0 fixtures: every vector carries its expected outcome.

The fixture file is the executable part of the gateway contract. The Kotlin
codec and validator replay the same file, so a change here breaks both sides.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "contracts" / "fixtures" / "gateway-v0.json"
SCHEMA = ROOT / "contracts" / "schemas" / "gateway.v1.schema.json"


def load():
    return json.loads(FIXTURES.read_text(encoding="utf-8"))


def test_at_least_fourteen_unique_cases():
    names = [c["name"] for c in load()["cases"]]
    assert len(names) >= 14
    assert len(names) == len(set(names))


def test_every_case_matches_its_expectation():
    from jsonschema import Draft202012Validator

    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    validator = Draft202012Validator(schema)
    for case in load()["cases"]:
        errors = list(validator.iter_errors(case["message"]))
        schema_valid = case.get("schema", case["ok"])
        if schema_valid:
            assert not errors, (case["name"], errors)
        else:
            assert errors, f"{case['name']} must be refused by the schema"


def test_refused_messages_name_a_gateway_error():
    allowed = {
        "E_AUTH",
        "E_TENANT",
        "E_VERSION",
        "E_RATE",
        "E_QUEUE",
        "E_SCHEMA",
        "E_UNSUPPORTED",
    }
    for case in load()["cases"]:
        if case["ok"]:
            assert case.get("error") is None, case["name"]
        else:
            assert case.get("error") in allowed, case["name"]
