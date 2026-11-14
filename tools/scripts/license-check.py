#!/usr/bin/env python3
"""Fail if the repo is not Apache-2.0 or a source file carries a GPL header."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE_SUFFIXES = {".py", ".kt", ".ets", ".ts", ".js"}
SKIP_DIRS = {
    ".git",
    ".tools",
    "node_modules",
    "oh_modules",
    "build",
    "dist",
    "coverage",
}
BAD_MARKERS = (
    "GNU General Public License",
    "GNU Affero General Public License",
    "GPL-3.0",
    "AGPL-3.0",
    "GPLv3",
)


def main() -> int:
    errors: list[str] = []

    license_path = ROOT / "LICENSE"
    if not license_path.is_file():
        errors.append("LICENSE is missing")
    elif "Apache License" not in license_path.read_text(
        encoding="utf-8", errors="replace"
    ):
        errors.append("LICENSE does not contain the Apache License text")

    if not (ROOT / "NOTICE").is_file():
        errors.append("NOTICE is missing")

    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix not in SOURCE_SUFFIXES:
            continue
        if path.resolve() == Path(__file__).resolve():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for marker in BAD_MARKERS:
            if marker in text:
                errors.append(f"{path.relative_to(ROOT)}: contains {marker!r}")
        for match in re.finditer(r"SPDX-License-Identifier:\s*(\S+)", text):
            if "GPL" in match.group(1).upper():
                errors.append(f"{path.relative_to(ROOT)}: SPDX {match.group(1)}")

    if errors:
        for error in errors:
            print(f"FAIL {error}", file=sys.stderr)
        return 1
    print("license check: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
