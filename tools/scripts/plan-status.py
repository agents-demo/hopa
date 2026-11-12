#!/usr/bin/env python3
"""Count checkboxes in docs/plan and gate completion.

Usage:
    python scripts/plan-status.py
    python scripts/plan-status.py --json
    python scripts/plan-status.py --lint
    python scripts/plan-status.py --require-complete
    python scripts/plan-status.py --list-unchecked

Decision pairs
--------------
A checkbox whose text ends with "(one of the two must be checked)" is the
second half of a decision pair. When exactly one half is checked, the other
half is *decided*, not remaining work. This is what makes
``--require-complete`` reachable: otherwise the unchecked half of every pair
would block the finish gate forever.

Exit codes:
    0  normal run, or --require-complete and everything is checked/decided
    1  --require-complete with work left, or --lint with an error
    2  plan file not found
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

CHECKBOX = re.compile(r"^\s*-\s+\[([ xX])\]\s+(.*)$")
ANY_BOX = re.compile(r"^\s*-\s*\[")
HEADING = re.compile(r"^##\s+(.+?)\s*$")
FENCE = re.compile(r"^\s*(```|~~~)")
PAIR_MARKER = "(one of the two must be checked)"
CONDITIONAL = re.compile(r"^\s*If\b", re.IGNORECASE)
EVIDENCE = "(evidence:"


def _plan_text(path: Path) -> str:
    """Read one plan file or a plan directory (one file per phase)."""
    if path.is_dir():
        files = sorted(
            path.glob("*.md"), key=lambda item: (item.name != "README.md", item.name)
        )
        return "\n".join(item.read_text(encoding="utf-8") for item in files)
    return path.read_text(encoding="utf-8")


def parse(path: Path) -> dict:
    sections: list[dict] = []
    current = {"title": "Preamble", "items": []}
    sections.append(current)
    in_fence = False
    line_no = 0

    for line in _plan_text(path).splitlines():
        line_no += 1
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        heading = HEADING.match(line)
        if heading:
            current = {"title": heading.group(1), "items": []}
            sections.append(current)
            continue

        box = CHECKBOX.match(line)
        if box:
            current["items"].append(
                {
                    "text": box.group(2).strip(),
                    "done": box.group(1).lower() == "x",
                    "line": line_no,
                    "decided": False,
                    "pair": None,
                }
            )
            continue

        if ANY_BOX.match(line) and not box:
            current["items"].append(
                {
                    "text": line.strip(),
                    "done": False,
                    "line": line_no,
                    "decided": False,
                    "pair": None,
                    "malformed": True,
                }
            )

    _resolve_pairs(sections)
    return _report(path, sections)


def _resolve_pairs(sections: list[dict]) -> None:
    """Mark the unchecked half of a satisfied decision pair as decided."""
    for section in sections:
        items = section["items"]
        for index, item in enumerate(items):
            if PAIR_MARKER not in item["text"] or index == 0:
                continue
            first = items[index - 1]
            second = item
            if first.get("malformed") or second.get("malformed"):
                continue
            pair_key = second["line"]
            first["pair"] = pair_key
            second["pair"] = pair_key
            checked = [first["done"], second["done"]]
            if checked.count(True) == 1:
                unchecked = first if not first["done"] else second
                unchecked["decided"] = True


def _report(path: Path, sections: list[dict]) -> dict:
    out_sections = []
    for section in sections:
        items = section["items"]
        done = sum(1 for i in items if i["done"])
        decided = sum(1 for i in items if i.get("decided"))
        total = len(items)
        out_sections.append(
            {
                "title": section["title"],
                "done": done,
                "decided": decided,
                "total": total,
                "remaining": total - done - decided,
                "percent": (
                    round(100.0 * (done + decided) / total, 1) if total else 100.0
                ),
                "items": items,
            }
        )

    total = sum(s["total"] for s in out_sections)
    done = sum(s["done"] for s in out_sections)
    decided = sum(s["decided"] for s in out_sections)
    return {
        "path": str(path),
        "done": done,
        "decided": decided,
        "total": total,
        "remaining": total - done - decided,
        "percent": round(100.0 * (done + decided) / total, 1) if total else 100.0,
        "sections": out_sections,
    }


def _normalise(text: str) -> str:
    text = re.sub(r"\s*\(evidence:.*?\)\s*$", "", text)
    return re.sub(r"\s+", " ", text).strip().lower()


def lint(report: dict) -> list[str]:
    errors: list[str] = []
    seen: dict[str, int] = {}
    items = [i for s in report["sections"] for i in s["items"]]

    for item in items:
        line = item["line"]
        if item.get("malformed"):
            errors.append(f"line {line}: malformed checkbox: {item['text']}")
            continue
        if item["done"] and EVIDENCE not in item["text"]:
            errors.append(
                f"line {line}: checked box has no (evidence: ...): {item['text']}"
            )
        if item["done"] and re.search(r"\(evidence:\s*\)", item["text"]):
            errors.append(f"line {line}: empty evidence: {item['text']}")
        if item["pair"] is None and CONDITIONAL.match(item["text"]):
            errors.append(
                f"line {line}: conditional work must be prose, not a checkbox: {item['text']}"
            )
        key = _normalise(item["text"])
        if key in seen:
            errors.append(f"line {line}: duplicate of line {seen[key]}: {item['text']}")
        else:
            seen[key] = line

    # A decision pair may be pending, but never double-checked.
    by_pair: dict[int, list[dict]] = {}
    for item in items:
        if item.get("pair") is not None:
            by_pair.setdefault(item["pair"], []).append(item)
    for pair in by_pair.values():
        if len(pair) != 2:
            continue
        if all(i["done"] for i in pair):
            errors.append(
                "line {}: decision pair has both sides checked: {}".format(
                    pair[0]["line"], pair[0]["text"]
                )
            )
    return errors


def display(text: str) -> str:
    """Keep table output readable on consoles that are not UTF-8."""
    return (
        text.replace("\u2014", "-")
        .replace("\u2013", "-")
        .replace("\u2192", "->")
        .replace("\u2265", ">=")
        .replace("\u2018", "'")
        .replace("\u2019", "'")
        .replace("\u201c", '"')
        .replace("\u201d", '"')
        .replace("\u00a7", "S")
    )


def print_table(report: dict) -> None:
    rows = [s for s in report["sections"] if s["total"] > 0]
    rows = [dict(s, title=display(s["title"])) for s in rows]
    width = max([len(s["title"]) for s in rows] + [len("Section")])
    print(
        f"{'Section':<{width}}  {'Done':>5}  {'Decided':>7}  {'Total':>5}"
        f"  {'Open':>5}  {'%':>6}"
    )
    print(f"{'-' * width}  {'-' * 5}  {'-' * 7}  {'-' * 5}  {'-' * 5}  {'-' * 6}")
    for s in rows:
        print(
            f"{s['title']:<{width}}  {s['done']:>5}  {s['decided']:>7}"
            f"  {s['total']:>5}  {s['remaining']:>5}  {s['percent']:>5.1f}%"
        )
    print(f"{'-' * width}  {'-' * 5}  {'-' * 7}  {'-' * 5}  {'-' * 5}  {'-' * 6}")
    print(
        f"{'TOTAL':<{width}}  {report['done']:>5}  {report['decided']:>7}"
        f"  {report['total']:>5}  {report['remaining']:>5}  {report['percent']:>5.1f}%"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--plan",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "docs" / "plan",
        help="path to the plan markdown file or its directory",
    )
    parser.add_argument(
        "--json", action="store_true", help="print machine-readable JSON"
    )
    parser.add_argument(
        "--lint", action="store_true", help="check evidence and plan rules"
    )
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help="exit 1 unless every checkbox is checked or decided",
    )
    parser.add_argument(
        "--list-unchecked",
        action="store_true",
        help="print every open item, grouped by section",
    )
    args = parser.parse_args(argv)

    # Windows consoles default to cp1252; the plan and JSON contain Unicode.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

    if not args.plan.exists():
        print(f"plan not found: {args.plan}", file=sys.stderr)
        return 2

    report = parse(args.plan)
    errors = lint(report)

    if args.json:
        print(
            json.dumps({**report, "lint_errors": errors}, indent=2, ensure_ascii=False)
        )
    else:
        print_table(report)
        if args.list_unchecked:
            for section in report["sections"]:
                pending = [
                    i
                    for i in section["items"]
                    if not i["done"] and not i.get("decided")
                ]
                if not pending:
                    continue
                print(f"\n{display(section['title'])} ({len(pending)} open)")
                for item in pending:
                    print(f"  - {display(item['text'])}")

    if errors and (args.lint or args.require_complete):
        print(f"\nLINT FAILED: {len(errors)} problem(s).", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1

    if args.require_complete and report["remaining"] > 0:
        if not args.json:
            print(
                f"\nNOT FINISHED: {report['remaining']} checkbox(es) remain.",
                file=sys.stderr,
            )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
