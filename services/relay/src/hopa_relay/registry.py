"""Pair one host and one phone per session and forward their frames."""

from __future__ import annotations

import threading
import time
from typing import Any

from hopa_wire.tunnel import CLOSE, DATA, OPEN, TunnelSide, status_frame
from hopa_wire.ws import WebSocketConnection


class TunnelRegistry:
    """Pair one host and one phone per session, and relay their frames."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._sessions: dict[str, dict[str, TunnelSide]] = {}

    @staticmethod
    def _peer_role(role: str) -> str:
        return "phone" if role == "host" else "host"

    def attach(self, role: str, session: str, ws: WebSocketConnection) -> TunnelSide:
        side = TunnelSide(role, session, ws)
        with self._lock:
            sides = self._sessions.setdefault(session, {})
            old = sides.get(role)
            sides[role] = side
            peer = sides.get(self._peer_role(role))
        if old is not None and old is not side:
            old.close()
        side.send(status_frame(peer is not None))
        if peer is not None and not peer.closed:
            peer.send(status_frame(True))
        return side

    def detach(self, side: TunnelSide) -> None:
        removed = False
        with self._lock:
            sides = self._sessions.get(side.session)
            if sides is None:
                return
            if sides.get(side.role) is side:
                sides.pop(side.role, None)
                removed = True
            peer = sides.get(self._peer_role(side.role))
            if not sides:
                self._sessions.pop(side.session, None)
        side.close()
        # An old side replaced by a reconnect must not tell the peer that the
        # new side is gone.
        if removed and peer is not None and not peer.closed:
            peer.send(status_frame(False))

    def forward(self, side: TunnelSide, frame: bytes) -> None:
        with self._lock:
            sides = self._sessions.get(side.session, {})
            peer = sides.get(self._peer_role(side.role))
        if peer is not None and not peer.closed:
            peer.send(frame)

    def serve(self, role: str, session: str, ws: WebSocketConnection) -> None:
        """Read frames until the peer leaves. Runs in the handler thread."""
        side = self.attach(role, session, ws)
        try:
            for frame in ws.messages():
                if frame and frame[0] in (OPEN, DATA, CLOSE):
                    self.forward(side, frame)
        finally:
            self.detach(side)

    def status(self) -> dict[str, Any]:
        now = time.time()

        def age(side: TunnelSide | None) -> float | None:
            if side is None:
                return None
            return round(max(0.0, now - side.attached_at), 1)

        with self._lock:
            sessions = [
                {
                    "session": name,
                    "host": "host" in sides,
                    "phone": "phone" in sides,
                    "host_age_seconds": age(sides.get("host")),
                    "phone_age_seconds": age(sides.get("phone")),
                }
                for name, sides in self._sessions.items()
            ]
        return {
            "sessions": len(sessions),
            "host": any(item["host"] for item in sessions),
            "phone": any(item["phone"] for item in sessions),
            "ready": any(item["host"] and item["phone"] for item in sessions),
            "links": sessions,
        }
