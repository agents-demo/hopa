#!/usr/bin/env python3
"""Remove the accessibility extension from a module.json5 for a retail build.

HarmonyOS refuses to install a HAP that declares an accessibility extension
without the vendor ACL, so the phone manifest keeps it for development and the
build script strips it, builds, then restores the file from git.

The file is JSON5 (allows comments), so this removes the object by matching
braces instead of parsing JSON. Running it twice is harmless: the second run
finds nothing and exits 0.

    python tools/scripts/strip-accessibility.py \
        apps/harmony/phone/src/main/module.json5
"""

from __future__ import annotations

import sys
from pathlib import Path

MARKER = '"HopaAccessibilityExtension"'


def object_bounds(text: str, marker: str) -> tuple[int, int] | None:
    """Return (start, end) of the object containing ``marker``."""
    at = text.find(marker)
    if at < 0:
        return None
    start = text.rfind("{", 0, at)
    if start < 0:
        return None
    depth = 0
    in_string = False
    escaped = False
    for index in range(start, len(text)):
        char = text[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return start, index + 1
    return None


def strip(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    bounds = object_bounds(text, MARKER)
    if bounds is None:
        return False
    start, end = bounds

    # Also drop the comma that joined this object to the previous one.
    head_end = start
    while head_end > 0 and text[head_end - 1] in " \t\r\n":
        head_end -= 1
    if head_end > 0 and text[head_end - 1] == ",":
        head_end -= 1

    tail = text[end:]
    stripped = tail.lstrip()
    if stripped.startswith(","):
        tail = stripped[1:]

    path.write_text(text[:head_end] + tail, encoding="utf-8")
    return True


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-2].strip(), file=sys.stderr)
        return 2
    path = Path(argv[1])
    if not path.exists():
        print(f"strip-accessibility: no such file: {path}", file=sys.stderr)
        return 2
    changed = strip(path)
    print(f"{path}: {'extension removed' if changed else 'extension not present'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
