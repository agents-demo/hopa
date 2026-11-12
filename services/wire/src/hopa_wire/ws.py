"""A small RFC 6455 WebSocket used by the hdc tunnel.

The relay runs on Render with ``pip install --no-deps``, so the tunnel cannot
pull in ``websockets`` or ``aiohttp``. Only what the tunnel needs is here:
binary frames, fragmentation, ping/pong and close. Text messages are ignored.

The hdc tunnel is a byte stream, so frame boundaries are not meaningful. The
callers chunk at 32 KiB and re-frame on the other side.
"""

from __future__ import annotations

import base64
import hashlib
import os
import socket
import ssl
import struct
import threading
from collections.abc import Iterator
from typing import Any, BinaryIO
from urllib.parse import urlsplit

GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

OP_CONTINUATION = 0x0
OP_TEXT = 0x1
OP_BINARY = 0x2
OP_CLOSE = 0x8
OP_PING = 0x9
OP_PONG = 0xA

MAX_FRAME_BYTES = 1 << 20


class WebSocketError(Exception):
    """The peer is not speaking WebSocket, or the connection broke."""


def accept_key(key: str) -> str:
    """The ``Sec-WebSocket-Accept`` value for a client key."""
    digest = hashlib.sha1((key + GUID).encode("ascii")).digest()
    return base64.b64encode(digest).decode("ascii")


def encode_frame(opcode: int, payload: bytes, *, mask: bool = False) -> bytes:
    """Build one complete, unfragmented frame."""
    length = len(payload)
    first = 0x80 | (opcode & 0x0F)
    flag = 0x80 if mask else 0
    if length < 126:
        header = struct.pack("!BB", first, flag | length)
    elif length < 65536:
        header = struct.pack("!BBH", first, flag | 126, length)
    else:
        header = struct.pack("!BBQ", first, flag | 127, length)
    if not mask:
        return header + payload
    key = os.urandom(4)
    if payload:
        stream = key * (length // len(key) + 1)
        masked = bytes(byte ^ stream[index] for index, byte in enumerate(payload))
    else:
        masked = b""
    return header + key + masked


def _read_exact(reader: BinaryIO, count: int) -> bytes:
    data = reader.read(count)
    if data is None or len(data) != count:
        raise WebSocketError("connection closed")
    return data


def read_frame(reader: BinaryIO) -> tuple[bool, int, bytes]:
    """Read one frame as ``(fin, opcode, payload)``."""
    first, second = _read_exact(reader, 2)
    fin = bool(first & 0x80)
    opcode = first & 0x0F
    masked = bool(second & 0x80)
    length = second & 0x7F
    if length == 126:
        length = struct.unpack("!H", _read_exact(reader, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", _read_exact(reader, 8))[0]
    if length > MAX_FRAME_BYTES:
        raise WebSocketError(f"frame is too large: {length} bytes")
    mask = _read_exact(reader, 4) if masked else b""
    payload = _read_exact(reader, length) if length else b""
    if masked:
        payload = bytes(byte ^ mask[index % 4] for index, byte in enumerate(payload))
    return fin, opcode, payload


class WebSocketConnection:
    """One side of an established connection."""

    def __init__(
        self,
        reader: BinaryIO,
        writer: BinaryIO,
        *,
        mask_outgoing: bool,
        close_socket: Any,
    ) -> None:
        self._reader = reader
        self._writer = writer
        self._mask = mask_outgoing
        self._close_socket = close_socket
        self._lock = threading.Lock()
        self._closed = threading.Event()

    @property
    def closed(self) -> bool:
        return self._closed.is_set()

    def _send(self, opcode: int, payload: bytes) -> None:
        if self._closed.is_set():
            return
        frame = encode_frame(opcode, payload, mask=self._mask)
        with self._lock:
            self._writer.write(frame)
            self._writer.flush()

    def send_binary(self, payload: bytes) -> None:
        """Send one binary message. Raises ``OSError`` if the peer is gone."""
        self._send(OP_BINARY, payload)

    def close(self) -> None:
        if self._closed.is_set():
            return
        try:
            self._send(OP_CLOSE, b"")
        except (OSError, WebSocketError, ValueError):
            pass
        self._closed.set()
        try:
            self._close_socket()
        except (OSError, ValueError):
            pass

    def messages(self) -> Iterator[bytes]:
        """Yield reassembled binary messages until the peer closes."""
        fragments = bytearray()
        try:
            while not self._closed.is_set():
                try:
                    fin, opcode, payload = read_frame(self._reader)
                except (OSError, WebSocketError, ValueError):
                    break
                if opcode == OP_PING:
                    try:
                        self._send(OP_PONG, payload)
                    except (OSError, WebSocketError, ValueError):
                        break
                    continue
                if opcode == OP_PONG:
                    continue
                if opcode == OP_CLOSE:
                    try:
                        self._send(OP_CLOSE, payload[:125])
                    except (OSError, WebSocketError, ValueError):
                        pass
                    break
                if opcode == OP_TEXT:
                    # The tunnel is binary only; a text frame is a client bug.
                    continue
                if opcode not in (OP_BINARY, OP_CONTINUATION):
                    continue
                if opcode == OP_BINARY:
                    fragments = bytearray(payload)
                else:
                    fragments.extend(payload)
                if len(fragments) > MAX_FRAME_BYTES:
                    raise WebSocketError("message is too large")
                if fin:
                    yield bytes(fragments)
                    fragments = bytearray()
        finally:
            self._closed.set()
            try:
                self._close_socket()
            except (OSError, ValueError):
                pass

    def start_keepalive(self, interval: float = 15.0) -> None:
        """Keep an idle tunnel alive through proxies and phone power save.

        A WebSocket ping is a control frame; some stacks still suspend a socket
        that carries no application data. Send a one-byte binary no-op as well.
        Both tunnel ends ignore a frame shorter than five bytes.
        """

        def loop() -> None:
            while not self._closed.wait(interval):
                try:
                    self._send(OP_PING, b"")
                    self._send(OP_BINARY, b"\x00")
                except (OSError, WebSocketError, ValueError):
                    self.close()
                    return

        threading.Thread(target=loop, name="ws-keepalive", daemon=True).start()


class WebSocketClient(WebSocketConnection):
    """A client connection to a ``ws://`` or ``wss://`` URL."""

    @classmethod
    def connect(
        cls,
        url: str,
        *,
        headers: dict[str, str] | None = None,
        timeout: float = 30.0,
    ) -> WebSocketClient:
        parts = urlsplit(url)
        if parts.scheme not in ("ws", "wss"):
            raise WebSocketError(f"not a WebSocket URL: {url}")
        host = parts.hostname or ""
        if not host:
            raise WebSocketError(f"no host in {url}")
        port = parts.port or (443 if parts.scheme == "wss" else 80)
        path = parts.path or "/"
        if parts.query:
            path = f"{path}?{parts.query}"

        sock = socket.create_connection((host, port), timeout=timeout)
        if parts.scheme == "wss":
            context = ssl.create_default_context()
            sock = context.wrap_socket(sock, server_hostname=host)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        lines = [
            f"GET {path} HTTP/1.1",
            f"Host: {host}",
            "Upgrade: websocket",
            "Connection: Upgrade",
            f"Sec-WebSocket-Key: {key}",
            "Sec-WebSocket-Version: 13",
        ]
        for name, value in (headers or {}).items():
            lines.append(f"{name}: {value}")
        sock.sendall(("\r\n".join(lines) + "\r\n\r\n").encode("utf-8"))

        reader = sock.makefile("rb")
        status = reader.readline().decode("latin-1").strip()
        if " 101 " not in f" {status} ":
            sock.close()
            raise WebSocketError(f"handshake rejected: {status or 'no response'}")
        response: dict[str, str] = {}
        while True:
            line = reader.readline()
            if line in (b"\r\n", b"\n", b""):
                break
            name, _, value = line.decode("latin-1").partition(":")
            response[name.strip().lower()] = value.strip()
        if response.get("sec-websocket-accept") != accept_key(key):
            sock.close()
            raise WebSocketError("handshake returned a wrong accept key")
        writer = sock.makefile("wb")
        connection = cls(
            reader,
            writer,
            mask_outgoing=True,
            close_socket=sock.close,
        )
        connection.start_keepalive()
        return connection


def server_handshake(handler: Any) -> WebSocketConnection:
    """Complete the upgrade for a ``BaseHTTPRequestHandler``."""
    key = handler.headers.get("Sec-WebSocket-Key", "")
    if not key:
        raise WebSocketError("missing Sec-WebSocket-Key")
    if handler.headers.get("Upgrade", "").lower() != "websocket":
        raise WebSocketError("missing Upgrade: websocket")

    handler.send_response_only(101)
    handler.send_header("Upgrade", "websocket")
    handler.send_header("Connection", "Upgrade")
    handler.send_header("Sec-WebSocket-Accept", accept_key(key))
    handler.end_headers()
    handler.wfile.flush()

    connection = WebSocketConnection(
        handler.rfile,
        handler.wfile,
        mask_outgoing=False,
        close_socket=handler.connection.close,
    )
    connection.start_keepalive()
    return connection
