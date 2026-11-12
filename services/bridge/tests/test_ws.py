"""The minimal WebSocket used by the tunnel, without a device."""

from __future__ import annotations

import io
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

from hopa_bridge.ws import (
    OP_BINARY,
    WebSocketClient,
    WebSocketError,
    accept_key,
    encode_frame,
    read_frame,
    server_handshake,
)


def test_accept_key_matches_rfc6455():
    assert accept_key("dGhlIHNhbXBsZSBub25jZQ==") == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="


def test_a_masked_frame_round_trips():
    payload = b"hello hdc"
    frame = encode_frame(OP_BINARY, payload, mask=True)
    fin, opcode, decoded = read_frame(io.BytesIO(frame))
    assert fin is True
    assert opcode == OP_BINARY
    assert decoded == payload


def test_a_large_frame_round_trips():
    payload = bytes(range(256)) * 400
    fin, opcode, decoded = read_frame(io.BytesIO(encode_frame(OP_BINARY, payload)))
    assert fin is True
    assert opcode == OP_BINARY
    assert decoded == payload


def test_a_short_frame_is_rejected():
    with pytest.raises(WebSocketError):
        read_frame(io.BytesIO(b"\x82\x04ab"))


class _Echo(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        return

    def do_GET(self) -> None:  # noqa: N802
        connection = server_handshake(self)
        try:
            for message in connection.messages():
                connection.send_binary(message)
        finally:
            connection.close()


@pytest.fixture()
def echo_server():
    server = ThreadingHTTPServer(("127.0.0.1", 0), _Echo)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield server.server_address[1]
    server.shutdown()
    server.server_close()


def test_client_and_server_exchange_binary_frames(echo_server):
    client = WebSocketClient.connect(f"ws://127.0.0.1:{echo_server}/tunnel")
    try:
        client.send_binary(b"first")
        client.send_binary(b"second")
        received = []
        for message in client.messages():
            received.append(message)
            if len(received) == 2:
                break
        assert received == [b"first", b"second"]
    finally:
        client.close()
