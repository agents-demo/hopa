"""The binary tunnel every hopa service speaks.

A tunnel carries an hdc byte stream over a WebSocket:

    OPEN   [type][stream]
    DATA   [type][stream][bytes]
    CLOSE  [type][stream]
    STATUS [type][b"ready" | b"waiting"]        (relay -> both sides)

The relay forwards OPEN/DATA/CLOSE verbatim between the two sides and owns
STATUS. Frame boundaries are not meaningful: the byte order is what matters.

This module and ws.py are shared by services/bridge (the PC half) and
services/relay (the server half); neither imports the other (ADR-0010).
"""

from __future__ import annotations

import struct
import threading
import time
from dataclasses import dataclass, field

from .ws import WebSocketConnection, WebSocketError

OPEN = 0x01
DATA = 0x02
CLOSE = 0x03
STATUS = 0x04

MAX_CHUNK = 32 * 1024
MAX_STREAM_ID = 0xFFFFFFFF
READY = b"ready"
WAITING = b"waiting"

_STREAM = struct.Struct("!I")


def _frame(kind: int, stream: int) -> bytes:
    return struct.pack("!BI", kind, stream)


def open_frame(stream: int) -> bytes:
    return _frame(OPEN, stream)


def close_frame(stream: int) -> bytes:
    return _frame(CLOSE, stream)


def data_frame(stream: int, payload: bytes) -> bytes:
    return _frame(DATA, stream) + payload


def status_frame(ready: bool) -> bytes:
    return bytes([STATUS]) + (READY if ready else WAITING)


def parse_stream(payload: bytes) -> int:
    if len(payload) < 5:
        raise ValueError("tunnel frame is too short")
    return _STREAM.unpack(payload[1:5])[0]


@dataclass(eq=False)
class TunnelSide:
    """One WebSocket in a tunnel session."""

    role: str
    session: str
    ws: WebSocketConnection
    attached_at: float = field(default_factory=time.time)
    _closed: bool = False
    _lock: threading.Lock = field(default_factory=threading.Lock)

    @property
    def closed(self) -> bool:
        return self._closed

    def send(self, frame: bytes) -> None:
        if self._closed:
            return
        try:
            self.ws.send_binary(frame)
        except (OSError, WebSocketError, ValueError):
            self.close()

    def close(self) -> None:
        with self._lock:
            if self._closed:
                return
            self._closed = True
        self.ws.close()
