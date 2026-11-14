"""Repair the shared conversation store.

A position-based turn id once made every sync look like new messages, so a
thread could grow to hundreds of turns. The store self-heals on load by
collapsing adjacent and periodic repeats; this script is the stronger one-off
pass for data that is already distorted: within a session, a turn is kept only
once per (role, text), preserving the order it first appeared in.

    py -3 services/tools/scripts/repair-chats.py            # repair ~/.hopa/chats.json
    py -3 services/tools/scripts/repair-chats.py <path>     # repair a copy
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def repair(path: Path) -> tuple[int, int, int]:
    data = json.loads(path.read_text(encoding="utf-8"))
    sessions = data.get("sessions")
    if isinstance(sessions, dict):
        items = list(sessions.values())
    elif isinstance(sessions, list):
        items = sessions
    else:
        items = []

    before = 0
    after = 0
    for session in items:
        turns = session.get("turns")
        if not isinstance(turns, list):
            continue
        before += len(turns)
        seen: set[tuple[str, str]] = set()
        kept = []
        for turn in turns:
            if not isinstance(turn, dict):
                continue
            key = (str(turn.get("role", "")), str(turn.get("text", "")))
            if key in seen:
                continue
            seen.add(key)
            kept.append(turn)
        session["turns"] = kept
        after += len(kept)

    if after != before:
        data["rev"] = int(data.get("rev", 0) or 0) + 1
        path.write_text(json.dumps(data), encoding="utf-8")
    return len(items), before, after


def main() -> int:
    path = (
        Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / ".hopa" / "chats.json"
    )
    if not path.exists():
        print(f"hopa-bridge: no store at {path}", file=sys.stderr)
        return 2
    sessions, before, after = repair(path)
    print(f"{path}: {sessions} sessions, turns {before} -> {after}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
