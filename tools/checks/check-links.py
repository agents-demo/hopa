#!/usr/bin/env python3
"""Fail when a relative Markdown link points at a missing file."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LINK = re.compile(r"\]\(([^)\s]+)\)")
SUFFIXES = (".md", ".json", ".yaml", ".yml", ".ets", ".py")


def markdown_files() -> list[Path]:
    files = list(ROOT.glob("*.md")) + list((ROOT / "docs").rglob("*.md"))
    return [path for path in files if "node_modules" not in path.parts]


def main() -> int:
    broken: list[tuple[Path, str]] = []
    for path in markdown_files():
        text = path.read_text(encoding="utf-8", errors="replace")
        for raw in LINK.findall(text):
            target = raw.split("#", 1)[0]
            if not target or target.startswith(("http://", "https://", "mailto:")):
                continue
            if not target.endswith(SUFFIXES):
                continue
            resolved = (path.parent / target).resolve()
            if not resolved.exists():
                broken.append((path.relative_to(ROOT), raw))
    for path, target in broken:
        print(f"{path}: {target}")
    print(f"{len(broken)} broken link(s)")
    return 1 if broken else 0


if __name__ == "__main__":
    raise SystemExit(main())
