"""The one conversation store.

Modern chat apps put the threads on a server and treat each device as a view.
HOPA has no cloud, but it does have the PC bridge, so the bridge becomes that
server: one list, append-only messages, and every device reads and writes it.

The rules are deliberately small:

* a turn is identified by its id, so the same turn arriving twice is one turn;
* a title is last-writer-wins on ``titleAt``;
* a delete is a tombstone on ``deletedAt`` instead of a removal, so a delete
  cannot be undone by an older copy arriving later;
* ``rev`` grows on every accepted change, so a client can tell whether anything
  happened without diffing.

That is enough for two devices typing on the same thread: messages only append,
so there is nothing to merge and nothing to lose.
"""

from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any


class ChatStore:
    def __init__(self, state_path: str | Path | None = None) -> None:
        self.rev: int = 0
        self.sessions: dict[str, dict[str, Any]] = {}
        self._path = Path(state_path) if state_path is not None else None
        self._lock = threading.Lock()
        self._load()

    # -- persistence ---------------------------------------------------------

    def _load(self) -> None:
        if self._path is None or not self._path.exists():
            return
        try:
            data = json.loads(self._path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return
        if not isinstance(data, dict):
            return
        sessions = data.get("sessions")
        if isinstance(sessions, dict):
            self.sessions = {str(k): v for k, v in sessions.items() if isinstance(v, dict)}
        try:
            self.rev = int(data.get("rev", 0))
        except (TypeError, ValueError):
            self.rev = 0
        # Self-healing: an older build could append the same turn again under a
        # fresh index, so a single message grew into hundreds. Collapse those.
        repaired = False
        for session in self.sessions.values():
            turns = session.get("turns")
            if not isinstance(turns, list):
                continue
            seen: set[str] = set()
            kept: list[Any] = []
            for index, turn in enumerate(turns):
                if not isinstance(turn, dict):
                    continue
                key = self._turn_key(turn, index)
                if key in seen:
                    continue
                # A broken push repeated the whole thread; the repeats are
                # adjacent and identical in role and words. Collapse those even
                # when their timestamps differ.
                if kept:
                    last = kept[-1]
                    same_role = last.get("role") == turn.get("role")
                    if same_role and last.get("text") == turn.get("text"):
                        continue
                seen.add(key)
                kept.append(turn)
            kept = self._collapse_cycle(kept)
            if len(kept) != len(turns):
                session["turns"] = kept
                repaired = True
        if repaired:
            self.rev += 1
            self._save()

    def _save(self) -> None:
        if self._path is None:
            return
        try:
            self._path.parent.mkdir(parents=True, exist_ok=True)
            payload = json.dumps({"rev": self.rev, "sessions": self.sessions})
            tmp = self._path.with_suffix(".tmp")
            tmp.write_text(payload, encoding="utf-8")
            tmp.replace(self._path)
        except OSError:
            pass

    # -- merge ---------------------------------------------------------------

    @staticmethod
    def _turn_key(turn: dict[str, Any], index: int) -> str:
        tid = str(turn.get("id", "")).strip()
        if tid:
            return tid
        # Older clients have no turn ids. Never key on the index: a merge can
        # change it, and an index in the key turns one message into many.
        return f"{turn.get('role', '')}:{turn.get('at', 0)}:{turn.get('text', '')}"

    @staticmethod
    def _collapse_cycle(turns: list[Any]) -> list[Any]:
        """A broken client could push the whole thread again and again.

        The repeat is periodic, not adjacent (user, assistant, user, ...), so
        look for the shortest period that reproduces the list and keep one.
        """
        count = len(turns)
        for period in range(1, count // 2 + 1):
            if count % period:
                continue
            matches = True
            for index in range(period, count):
                here = turns[index]
                there = turns[index - period]
                if here.get("role") != there.get("role") or here.get("text") != there.get("text"):
                    matches = False
                    break
            if matches:
                return turns[:period]
        return turns

    def _merge_session(self, incoming: dict[str, Any]) -> bool:
        sid = str(incoming.get("id", "")).strip()
        if not sid:
            return False
        changed = False
        current = self.sessions.get(sid)
        if current is None:
            current = {
                "id": sid,
                "title": "",
                "titleAt": 0,
                "created": int(incoming.get("created", 0) or 0),
                "updated": 0,
                "deletedAt": 0,
                "turns": [],
            }
            self.sessions[sid] = current
            changed = True

        title = str(incoming.get("title", ""))
        try:
            title_at = int(incoming.get("titleAt", 0) or 0)
        except (TypeError, ValueError):
            title_at = 0
        saved_at = int(current.get("titleAt", 0) or 0)
        if title and title_at >= saved_at and title != current.get("title"):
            current["title"] = title
            current["titleAt"] = title_at
            changed = True

        try:
            deleted_at = int(incoming.get("deletedAt", 0) or 0)
        except (TypeError, ValueError):
            deleted_at = 0
        if deleted_at > int(current.get("deletedAt", 0) or 0):
            current["deletedAt"] = deleted_at
            changed = True

        turns = current.get("turns")
        if not isinstance(turns, list):
            turns = []
            current["turns"] = turns
        known = {self._turn_key(turn, index) for index, turn in enumerate(turns)}
        incoming_turns = incoming.get("turns")
        if isinstance(incoming_turns, list):
            for index, turn in enumerate(incoming_turns):
                if not isinstance(turn, dict):
                    continue
                key = self._turn_key(turn, index)
                if key in known:
                    continue
                known.add(key)
                turns.append(
                    {
                        "id": str(turn.get("id", "")),
                        "role": str(turn.get("role", "")),
                        "text": str(turn.get("text", "")),
                        "at": int(turn.get("at", 0) or 0),
                    }
                )
                changed = True

        try:
            updated = int(incoming.get("updated", 0) or 0)
        except (TypeError, ValueError):
            updated = 0
        latest = max((int(turn.get("at", 0) or 0) for turn in turns), default=0)
        stamp = max(updated, latest, int(current.get("created", 0) or 0))
        if stamp > int(current.get("updated", 0) or 0):
            current["updated"] = stamp
            changed = True
        if not current.get("created"):
            current["created"] = stamp
        return changed

    def merge(self, sessions: Any) -> dict[str, Any]:
        """Take whatever a device has and keep everything both sides know."""
        with self._lock:
            if isinstance(sessions, list):
                changed = False
                for item in sessions:
                    if isinstance(item, dict) and self._merge_session(item):
                        changed = True
                if changed:
                    self.rev += 1
                    self._save()
            return self._snapshot_locked()

    # -- reads ---------------------------------------------------------------

    def _snapshot_locked(self) -> dict[str, Any]:
        live = [s for s in self.sessions.values() if not int(s.get("deletedAt", 0) or 0)]
        live.sort(key=lambda s: int(s.get("updated", 0) or 0), reverse=True)
        return {"rev": self.rev, "sessions": live}

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return self._snapshot_locked()

    def session(self, session_id: str) -> dict[str, Any] | None:
        with self._lock:
            return self.sessions.get(session_id)
