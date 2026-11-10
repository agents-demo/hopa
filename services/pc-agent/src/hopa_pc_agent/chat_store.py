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
        # Older clients have no turn ids; keep them stable by content and order.
        return f"{index}:{turn.get('role', '')}:{turn.get('at', 0)}:{str(turn.get('text', ''))[:40]}"

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
        if title and title_at >= int(current.get("titleAt", 0) or 0) and title != current.get("title"):
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
                turns.append({
                    "id": str(turn.get("id", "")),
                    "role": str(turn.get("role", "")),
                    "text": str(turn.get("text", "")),
                    "at": int(turn.get("at", 0) or 0),
                })
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
