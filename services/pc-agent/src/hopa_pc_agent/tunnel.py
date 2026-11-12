"""Carry an hdc byte stream through the relay as a binary WebSocket tunnel.

The phone and the PC both dial *out* to the relay, so neither needs an inbound
port. One session pairs one phone side with one host side. The host
multiplexes its local hdc TCP connections onto numbered streams:

    OPEN   [type][stream]
    DATA   [type][stream][bytes]
    CLOSE  [type][stream]
    STATUS [type][b"ready" | b"waiting"]        (relay -> both sides)

The relay forwards OPEN/DATA/CLOSE verbatim between the two sides and owns
STATUS. Frame boundaries are not meaningful: the byte order is what matters.
"""

from __future__ import annotations

import socket
import struct
import threading
import time
from dataclasses import dataclass, field
from typing import Any
from urllib.parse import quote

from .ws import WebSocketClient, WebSocketConnection, WebSocketError

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


class HdcTunnel:
    """The PC half: a local TCP listener that pipes to the relay tunnel."""

    def __init__(
        self,
        relay_url: str,
        link_token: str,
        *,
        listen_host: str = "127.0.0.1",
        listen_port: int = 5556,
        session: str = "default",
        retry_seconds: float = 5.0,
        connect_timeout: float = 15.0,
        ready_timeout: float = 60.0,
    ) -> None:
        self.relay_url = relay_url.rstrip("/")
        self.link_token = link_token
        self.listen_host = listen_host
        self.listen_port = listen_port
        self.session = session
        self.retry_seconds = retry_seconds
        self.connect_timeout = connect_timeout
        self.ready_timeout = ready_timeout

        self._listener: socket.socket | None = None
        self._ws: WebSocketConnection | None = None
        self._ready = threading.Event()
        self._stop = threading.Event()
        self._send_lock = threading.Lock()
        self._stream_lock = threading.Lock()
        self._streams: dict[int, socket.socket] = {}
        self._next_stream = 1

    @property
    def port(self) -> int:
        if self._listener is None:
            return self.listen_port
        return int(self._listener.getsockname()[1])

    @property
    def ready(self) -> bool:
        """True while a phone side is attached to the same session."""
        return self._ready.is_set()

    def url(self) -> str:
        base = self.relay_url
        if base.startswith("https://"):
            base = "wss://" + base[len("https://") :]
        elif base.startswith("http://"):
            base = "ws://" + base[len("http://") :]
        return f"{base}/tunnel?role=host&session={quote(self.session)}"

    def start(self) -> int:
        """Bind the local listener. Safe to call twice."""
        if self._listener is not None:
            return self.port
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind((self.listen_host, self.listen_port))
        listener.listen(8)
        self._listener = listener
        threading.Thread(target=self._accept_loop, name="hdc-accept", daemon=True).start()
        return self.port

    def stop(self) -> None:
        self._stop.set()
        listener = self._listener
        self._listener = None
        if listener is not None:
            try:
                listener.close()
            except OSError:
                pass
        with self._send_lock:
            ws = self._ws
            self._ws = None
        if ws is not None:
            ws.close()
        self._ready.clear()
        self._close_all_streams()

    # -- local TCP side -----------------------------------------------------

    def _accept_loop(self) -> None:
        while not self._stop.is_set():
            listener = self._listener
            if listener is None:
                return
            try:
                client, _address = listener.accept()
            except OSError:
                return
            threading.Thread(
                target=self._serve_client,
                args=(client,),
                name="hdc-stream",
                daemon=True,
            ).start()

    def _serve_client(self, client: socket.socket) -> None:
        stream = 0
        try:
            deadline = time.monotonic() + self.ready_timeout
            while not self._stop.is_set() and not self._ready.is_set():
                if time.monotonic() >= deadline:
                    return
                time.sleep(0.1)
            if not self._ready.is_set():
                return
            with self._stream_lock:
                stream = self._next_stream
                self._next_stream = 1 if stream >= MAX_STREAM_ID else stream + 1
                self._streams[stream] = client
            print(f"hdc-tunnel: stream {stream} open", flush=True)
            if not self._send(open_frame(stream)):
                return
            client.settimeout(1.0)
            while not self._stop.is_set():
                try:
                    chunk = client.recv(MAX_CHUNK)
                except TimeoutError:
                    continue
                except OSError:
                    break
                if not chunk:
                    break
                if not self._send(data_frame(stream, chunk)):
                    break
        finally:
            if stream:
                with self._stream_lock:
                    current = self._streams.get(stream)
                    if current is client:
                        self._streams.pop(stream, None)
                self._send(close_frame(stream))
                print(f"hdc-tunnel: stream {stream} closed", flush=True)
            try:
                client.close()
            except OSError:
                pass

    def _close_stream(self, stream: int) -> None:
        with self._stream_lock:
            client = self._streams.pop(stream, None)
        if client is None:
            return
        try:
            client.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        try:
            client.close()
        except OSError:
            pass

    def _close_all_streams(self) -> None:
        with self._stream_lock:
            streams = list(self._streams)
        for stream in streams:
            self._close_stream(stream)

    # -- relay side ---------------------------------------------------------

    def _send(self, frame: bytes) -> bool:
        with self._send_lock:
            ws = self._ws
            if ws is None or ws.closed:
                return False
            try:
                ws.send_binary(frame)
            except (OSError, WebSocketError, ValueError):
                return False
            return True

    def _read_loop(self, ws: WebSocketConnection) -> None:
        for frame in ws.messages():
            if not frame:
                continue
            kind = frame[0]
            if kind == STATUS:
                if frame[1:] == READY:
                    if not self._ready.is_set():
                        print("hdc-tunnel: phone ready", flush=True)
                    self._ready.set()
                elif frame[1:] == WAITING:
                    if self._ready.is_set():
                        print("hdc-tunnel: phone waiting", flush=True)
                    self._ready.clear()
                continue
            if len(frame) < 5:
                continue
            stream = parse_stream(frame)
            if kind == DATA:
                with self._stream_lock:
                    client = self._streams.get(stream)
                if client is not None:
                    try:
                        client.sendall(frame[5:])
                    except OSError:
                        self._close_stream(stream)
            elif kind == CLOSE:
                self._close_stream(stream)

    def run_forever(self) -> None:  # pragma: no cover - exercised on a PC
        port = self.start()
        print(f"hdc-tunnel: listening on tcp://{self.listen_host}:{port}", flush=True)
        print(f"hdc-tunnel: relay {self.url()}", flush=True)
        backoff = self.retry_seconds
        while not self._stop.is_set():
            try:
                ws = WebSocketClient.connect(
                    self.url(),
                    headers={"Authorization": f"Bearer {self.link_token}"},
                    timeout=self.connect_timeout,
                )
            except Exception as exc:  # noqa: BLE001 - retry is the contract
                print(
                    f"hdc-tunnel: relay unavailable ({exc}); retrying in {backoff:.0f}s",
                    flush=True,
                )
                self._stop.wait(backoff)
                backoff = min(backoff * 2, 30.0)
                continue
            backoff = self.retry_seconds
            with self._send_lock:
                self._ws = ws
            self._ready.clear()
            print("hdc-tunnel: relay connected", flush=True)
            try:
                self._read_loop(ws)
            finally:
                self._ready.clear()
                with self._send_lock:
                    if self._ws is ws:
                        self._ws = None
                ws.close()
                self._close_all_streams()
                if not self._stop.is_set():
                    print("hdc-tunnel: relay disconnected; retrying", flush=True)
            if not self._stop.is_set():
                self._stop.wait(backoff)
        self.stop()


def serve_hdc_tunnel(args: Any) -> int:
    """CLI entry point for ``pc-agent hdc-tunnel``."""
    relay_url = str(getattr(args, "relay", ""))
    token = str(getattr(args, "link_token", ""))
    if not relay_url:
        raise ValueError("--relay is required")
    if not token:
        raise ValueError("--link-token is required")
    listen = str(getattr(args, "listen", "127.0.0.1:5556"))
    host, _, port_text = listen.rpartition(":")
    if not host or not port_text.isdigit():
        raise ValueError("--listen must be HOST:PORT")
    tunnel = HdcTunnel(
        relay_url,
        token,
        listen_host=host.strip("[]"),
        listen_port=int(port_text),
        session=str(getattr(args, "session", "default")),
        retry_seconds=float(getattr(args, "retry_seconds", 5.0)),
    )
    try:
        tunnel.run_forever()
    except KeyboardInterrupt:
        tunnel.stop()
    return 0
