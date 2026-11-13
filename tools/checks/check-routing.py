#!/usr/bin/env python3
"""Run the shared routing fixtures through a reference matcher.

The fixtures are the behaviour every client loop must reproduce; the ArkTS
implementation is ``apps/harmony/core/src/main/ets/router/AppRouter.ets`` and the
Android client will port the same rules (ADR-0018). This checker proves the
fixtures are coherent and gives a second implementation to compare against.

Rules (copied from AppRouter):
  * lower-case the goal; an empty goal matches nothing;
  * score a target by the longest matched term: display, name, aliases, then
    (length >= 3) domains and the bundle;
  * a term shorter than 2 is skipped; generic words are skipped; an all-digit
    term shorter than 3 is skipped;
  * an ASCII term must sit on a word boundary; non-ASCII terms do not need one;
  * the highest score wins; a tie is won by a target that can be opened.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "contracts" / "fixtures" / "routing.json"


def is_ascii_alnum(value: str) -> bool:
    return bool(value) and (
        "a" <= value <= "z" or "0" <= value <= "9"
    )


def contains_term(text: str, term: str) -> bool:
    start = 0
    while True:
        index = text.find(term, start)
        if index < 0:
            return False
        before = text[index - 1] if index > 0 else ""
        after = text[index + len(term)] if index + len(term) < len(text) else ""
        left_ok = not is_ascii_alnum(term[0]) or not before or not is_ascii_alnum(before)
        right_ok = (
            not is_ascii_alnum(term[-1]) or not after or not is_ascii_alnum(after)
        )
        if left_ok and right_ok:
            return True
        start = index + 1


def normalise_host(value: str) -> str:
    host = value.strip().lower()
    return host.removeprefix("www.")


def can_open(target: dict) -> bool:
    return bool(target.get("bundle")) or bool(target.get("domains"))


def score(target: dict, text: str, generic: set[str]) -> tuple[int, str] | None:
    best = -1
    term = ""
    for raw in [target.get("display", ""), target.get("name", "")] + target.get(
        "aliases", []
    ):
        value = raw.strip().lower()
        if len(value) < 2 or value in generic:
            continue
        if value.isdigit() and len(value) < 3:
            continue
        if contains_term(text, value) and len(value) > best:
            best = len(value)
            term = value
    for domain in target.get("domains", []):
        value = normalise_host(domain)
        if len(value) >= 3 and value in text and len(value) > best:
            best = len(value)
            term = value
    bundle = target.get("bundle", "").lower()
    if len(bundle) >= 3 and bundle in text and len(bundle) > best:
        best = len(bundle)
        term = bundle
    if best < 0:
        return None
    return best, term


def route(goal: str, targets: list[dict], generic: set[str]) -> dict | None:
    text = goal.strip().lower()
    if not text:
        return None
    best_target: dict | None = None
    best_score = -1
    best_term = ""
    for target in targets:
        scored = score(target, text, generic)
        if scored is None:
            continue
        value, term = scored
        if (
            best_target is None
            or value > best_score
            or (value == best_score and can_open(target) and not can_open(best_target))
        ):
            best_target = target
            best_score = value
            best_term = term
    if best_target is None:
        return None
    return {
        "matched": True,
        "name": best_target.get("name", ""),
        "kind": best_target.get("kind", ""),
        "score": best_score,
        "term": best_term,
        "canOpen": can_open(best_target),
    }


def check(path: Path = FIXTURES) -> list[str]:
    problems: list[str] = []
    if not path.exists():
        return [f"missing fixtures: {path.relative_to(ROOT)}"]
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schemaVersion") != "1":
        problems.append("routing: schemaVersion must be '1'")
    if not document.get("generic"):
        problems.append("routing: generic words are required")
    cases = document.get("cases")
    if not isinstance(cases, list) or not cases:
        return problems + ["routing: no cases"]

    generic = set(document["generic"])
    names = set()
    for case in cases:
        name = case.get("name") or "<unnamed>"
        if name in names:
            problems.append(f"{name}: duplicate case name")
        names.add(name)
        for key in ("goal", "targets", "expect"):
            if key not in case:
                problems.append(f"{name}: missing '{key}'")
        expect = case.get("expect", {})
        if not isinstance(expect.get("matched"), bool):
            problems.append(f"{name}: expect.matched must be true or false")
            continue
        actual = route(case.get("goal", ""), case.get("targets", []), generic)
        if expect["matched"] is False:
            if actual is not None:
                problems.append(f"{name}: expected no match, got {actual}")
            continue
        if actual is None:
            problems.append(f"{name}: expected a match, got none")
            continue
        for key in ("name", "kind", "score", "term"):
            if key not in expect:
                problems.append(f"{name}: expect.{key} is required")
            elif actual[key] != expect[key]:
                problems.append(
                    f"{name}: expect.{key}={expect[key]!r}, got {actual[key]!r}"
                )

    return problems


def main() -> int:
    problems = check()
    for problem in problems:
        print(f"FAIL  {problem}")
    print(f"{len(problems)} routing fixture problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
