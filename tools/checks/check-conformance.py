#!/usr/bin/env python3
"""Validate the conformance fixtures every client loop must pass.

The fixtures are data, not a runner. This check proves they are well formed and
internally consistent:

- the file has the expected shape and at least one valid and one invalid case;
- each observation validates against observation.schema.json;
- each model reply validates against decision.schema.json (which references
  action.schema.json);
- an invalid expectation names an error code; a valid one names the action kind,
  classification, approval and execution result;
- a reply that is `done` and also carries an action is expected to be rejected,
  because that rule lives in the loop, not in JSON Schema.

A client's own runner consumes the same file; see contracts/fixtures/README.md.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMAS = ROOT / "contracts" / "schemas"
FIXTURES = ROOT / "contracts" / "fixtures" / "conformance.json"

DECISION_KEYS = {"action", "say", "done", "needUser", "options", "sessionId", "version"}
EXECUTION_KEYS = {"actionKind", "classification", "needsApproval", "executed"}


def _registry():
    from referencing import Registry, Resource

    registry = Registry()
    for name in ("action", "decision", "observation"):
        path = SCHEMAS / f"{name}.schema.json"
        document = json.loads(path.read_text(encoding="utf-8"))
        registry = registry.with_resource(
            f"https://github.com/agents-demo/hopa/schemas/{name}.schema.json",
            Resource.from_contents(document),
        )
    return registry


def _validate(instance: object, name: str, registry) -> list[str]:
    from jsonschema import Draft202012Validator

    document = json.loads((SCHEMAS / f"{name}.schema.json").read_text(encoding="utf-8"))
    validator = Draft202012Validator(document, registry=registry)
    return [error.message for error in validator.iter_errors(instance)]


def check(path: Path = FIXTURES) -> list[str]:
    problems: list[str] = []
    if not path.exists():
        return [f"missing fixtures: {path.relative_to(ROOT)}"]

    document = json.loads(path.read_text(encoding="utf-8"))
    cases = document.get("cases")
    if document.get("schemaVersion") != "1":
        problems.append("fixtures: schemaVersion must be '1'")
    if not isinstance(cases, list) or not cases:
        return problems + ["fixtures: no cases"]

    registry = _registry()
    valid = 0
    invalid = 0
    payment = 0

    for index, case in enumerate(cases):
        label = case.get("name") or f"case {index}"
        for key in ("name", "why", "observation", "modelReply", "expect"):
            if key not in case:
                problems.append(f"{label}: missing '{key}'")

        problems += [f"{label}: observation {msg}" for msg in _validate(case.get("observation"), "observation", registry)]

        reply = case.get("modelReply") or {}
        extra = set(reply) - DECISION_KEYS
        if extra:
            problems.append(f"{label}: decision has unknown keys {sorted(extra)}")
        schema_errors = _validate(reply, "decision", registry)

        expect = case.get("expect") or {}
        semantic_invalid = (
            (reply.get("done") is True and reply.get("action") is not None)
            or (reply.get("needUser") is True and not reply.get("options"))
        )
        if expect.get("valid") is True:
            valid += 1
            problems += [f"{label}: expected valid, but {msg}" for msg in schema_errors]
            for key in EXECUTION_KEYS:
                if key not in expect:
                    problems.append(f"{label}: valid case must state '{key}'")
            if expect.get("classification") == "payment":
                payment += 1
        elif expect.get("valid") is False:
            invalid += 1
            if not expect.get("errorCode"):
                problems.append(f"{label}: invalid case must name an errorCode")
            if not schema_errors and not semantic_invalid:
                problems.append(f"{label}: expected invalid, but the reply passes")
        else:
            problems.append(f"{label}: expect.valid must be true or false")

        # Rules that live in the loop, not in the schema.
        if (
            reply.get("done") is True
            and reply.get("action") is not None
            and expect.get("valid") is not False
        ):
            problems.append(f"{label}: done with an action must be expected invalid")
        if (
            reply.get("needUser") is True
            and not reply.get("options")
            and expect.get("valid") is not False
        ):
            problems.append(f"{label}: a question without options must be expected invalid")

    if valid == 0:
        problems.append("fixtures: no valid case")
    if invalid == 0:
        problems.append("fixtures: no invalid case")
    if payment == 0:
        problems.append("fixtures: no payment case (the risk rule would go untested)")

    return problems


def main() -> int:
    problems = check()
    for problem in problems:
        print(f"FAIL  {problem}")
    print(f"{len(problems)} conformance fixture problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
