#!/usr/bin/env python3
"""Count checkboxes in docs/rebuild-plan.md.

Usage:
    python scripts/plan-status.py
    python scripts/plan-status.py --json
    python scripts/plan-status.py --require-complete
    python scripts/plan-status.py --list-unchecked

Exit codes:
    0  normal run, or --require-complete and everything is checked
    1  --require-complete and at least one box is unchecked
    2  plan file not found
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

CHECKBOX = re.compile(r"^\s*-\s+\[([ xX])\]\s+(.*)$")
HEADING = re.compile(r"^##\s+(.+?)\s*$")
FENCE = re.compile(r"^\s*(```|~~~)")


def parse(path: Path) -> dict:
    sections: list[dict] = []
    current = {"title": "Preamble", "done": 0, "total": 0, "items": []}
    sections.append(current)
    in_fence = False

    for line in path.read_text(encoding="utf-8").splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue

        heading = HEADING.match(line)
        if heading:
            current = {"title": heading.group(1), "done": 0, "total": 0, "items": []}
            sections.append(current)
            continue

        box = CHECKBOX.match(line)
        if box:
            done = box.group(1).lower() == "x"
            text = box.group(2).strip()
            current["total"] += 1
            if done:
                current["done"] += 1
            current["items"].append({"text": text, "done": done})

    total = sum(s["total"] for s in sections)
    done = sum(s["done"] for s in sections)
    return {
        "path": str(path),
        "done": done,
        "total": total,
        "remaining": total - done,
        "percent": round(100.0 * done / total, 1) if total else 100.0,
        "sections": [
            {
                "title": s["title"],
                "done": s["done"],
                "total": s["total"],
                "remaining": s["total"] - s["done"],
                "percent": round(100.0 * s["done"] / s["total"], 1) if s["total"] else 100.0,
                "items": s["items"],
            }
            for s in sections
        ],
    }


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
    print(f"{'Section':<{width}}  {'Done':>5}  {'Total':>5}  {'Left':>5}  {'%':>6}")
    print(f"{'-' * width}  {'-' * 5}  {'-' * 5}  {'-' * 5}  {'-' * 6}")
    for s in rows:
        print(
            f"{s['title']:<{width}}  {s['done']:>5}  {s['total']:>5}"
            f"  {s['remaining']:>5}  {s['percent']:>5.1f}%"
        )
    print(f"{'-' * width}  {'-' * 5}  {'-' * 5}  {'-' * 5}  {'-' * 6}")
    print(
        f"{'TOTAL':<{width}}  {report['done']:>5}  {report['total']:>5}"
        f"  {report['remaining']:>5}  {report['percent']:>5.1f}%"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--plan",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "docs" / "rebuild-plan.md",
        help="path to the plan markdown file",
    )
    parser.add_argument("--json", action="store_true", help="print machine-readable JSON")
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help="exit 1 unless every checkbox is checked",
    )
    parser.add_argument(
        "--list-unchecked",
        action="store_true",
        help="print every unchecked item, grouped by section",
    )
    args = parser.parse_args(argv)

    # Windows consoles default to cp1252; the plan and JSON contain Unicode.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

    if not args.plan.is_file():
        print(f"plan not found: {args.plan}", file=sys.stderr)
        return 2

    report = parse(args.plan)

    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        print_table(report)
        if args.list_unchecked:
            for section in report["sections"]:
                pending = [i for i in section["items"] if not i["done"]]
                if not pending:
                    continue
                print(f"\n{display(section['title'])} ({len(pending)} left)")
                for item in pending:
                    print(f"  - {display(item['text'])}")

    if args.require_complete and report["remaining"] > 0:
        if not args.json:
            print(f"\nNOT FINISHED: {report['remaining']} checkbox(es) remain.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
