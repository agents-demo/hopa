"""The relay tunnel, end to end without a phone."""

from __future__ import annotations

import json
import socket
import threading
import time
import urllib.request

import pytest
from hopa_relay.registry import TunnelRegistry
from hopa_relay.relay_server import Relay, RelayServer
from hopa_wire.tunnel import (
    CLOSE,
    DATA,
    OPEN,
    READY,
    STATUS,
    WAITING,
    close_frame,
    data_frame,
    parse_stream,
)
from hopa_wire.ws import WebSocketClient, WebSocketError

from hopa_bridge.tunnel import HdcTunnel

PHONE = "phone-token"
LINK = "link-token"


def _wait_until(predicate, timeout: float = 5.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.02)
    raise AssertionError("condition was never true")


@pytest.fixture()
def relay_server():
    relay = Relay(PHONE, LINK, wait_seconds=2.0, poll_seconds=1.0)
    server = RelayServer(relay, port=0)
    server.start()
    yield relay, server
    server.stop()


@pytest.fixture()
def echo_port():
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", 0))
    listener.listen(8)

    def echo(client: socket.socket) -> None:
        try:
            while True:
                chunk = client.recv(32 * 1024)
                if not chunk:
                    return
                client.sendall(chunk)
        except OSError:
            return
        finally:
            client.close()

    def accept() -> None:
        while True:
            try:
                client, _address = listener.accept()
            except OSError:
                return
            threading.Thread(target=echo, args=(client,), daemon=True).start()

    threading.Thread(target=accept, daemon=True).start()
    yield listener.getsockname()[1]
    listener.close()


class _FakePhone:
    """The app side: dial 127.0.0.1:5555 for every OPEN stream."""

    def __init__(self, ws: WebSocketClient, target: tuple[str, int]) -> None:
        self.ws = ws
        self.target = target
        self.ready = threading.Event()
        self._sockets: dict[int, socket.socket] = {}
        self._lock = threading.Lock()

    def start(self) -> None:
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self) -> None:
        try:
            for frame in self.ws.messages():
                if not frame:
                    continue
                if frame[0] == STATUS:
                    if frame[1:] == READY:
                        self.ready.set()
                    else:
                        self.ready.clear()
                    continue
                if len(frame) < 5:
                    continue
                stream = parse_stream(frame)
                if frame[0] == OPEN:
                    self._open(frame)
                elif frame[0] == DATA:
                    with self._lock:
                        client = self._sockets.get(stream)
                    if client is not None:
                        client.sendall(frame[5:])
                elif frame[0] == CLOSE:
                    self._close(stream)
        finally:
            with self._lock:
                streams = list(self._sockets)
            for stream in streams:
                self._close(stream)
            self.ready.clear()

    def _pump(self, stream: int, client: socket.socket) -> None:
        try:
            while True:
                chunk = client.recv(32 * 1024)
                if not chunk:
                    break
                self.ws.send_binary(data_frame(stream, chunk))
        except OSError:
            pass
        finally:
            self.ws.send_binary(close_frame(stream))
            self._close(stream)

    def _close(self, stream: int) -> None:
        with self._lock:
            client = self._sockets.pop(stream, None)
        if client is not None:
            try:
                client.close()
            except OSError:
                pass

    def _open(self, frame: bytes) -> None:
        stream = parse_stream(frame)
        client = socket.create_connection(self.target, timeout=5)
        with self._lock:
            self._sockets[stream] = client
        threading.Thread(target=self._pump, args=(stream, client), daemon=True).start()


def _health(port: int) -> dict:
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))


def test_relay_exposes_tunnel_status(relay_server):
    _relay, server = relay_server
    health = _health(server.port)["tunnel"]
    assert health["ready"] is False
    assert health["links"] == []


def test_status_reports_how_long_each_side_has_been_attached():
    registry = TunnelRegistry()
    registry.attach("host", "default", _FakeWs())  # type: ignore[arg-type]

    link = registry.status()["links"][0]

    assert link["session"] == "default"
    assert link["host"] is True
    assert link["phone"] is False
    assert link["phone_age_seconds"] is None
    assert 0 <= link["host_age_seconds"] < 5


class _FakeWs:
    def __init__(self) -> None:
        self.frames: list[bytes] = []
        self.closed = False

    def send_binary(self, payload: bytes) -> None:
        self.frames.append(payload)

    def close(self) -> None:
        self.closed = True


def test_replacing_a_side_does_not_report_waiting():
    registry = TunnelRegistry()
    old_ws = _FakeWs()
    phone_ws = _FakeWs()
    old = registry.attach("host", "default", old_ws)  # type: ignore[arg-type]
    registry.attach("phone", "default", phone_ws)  # type: ignore[arg-type]
    registry.attach("host", "default", _FakeWs())  # type: ignore[arg-type]
    phone_ws.frames.clear()
    registry.detach(old)
    assert all(frame[1:] != WAITING for frame in phone_ws.frames)
    assert old_ws.closed is True


def test_a_wrong_token_is_rejected(relay_server):
    _relay, server = relay_server
    with pytest.raises(WebSocketError):
        WebSocketClient.connect(
            f"ws://127.0.0.1:{server.port}/tunnel?role=phone",
            headers={"Authorization": "Bearer wrong"},
        )


def test_a_byte_stream_crosses_the_tunnel(relay_server, echo_port):
    _relay, server = relay_server
    base = f"http://127.0.0.1:{server.port}"
    tunnel = HdcTunnel(base, LINK, listen_port=0, ready_timeout=5.0, retry_seconds=0.2)
    port = tunnel.start()
    worker = threading.Thread(target=tunnel.run_forever, daemon=True)
    worker.start()
    phone_ws = WebSocketClient.connect(
        f"ws://127.0.0.1:{server.port}/tunnel?role=phone&session=default",
        headers={"Authorization": f"Bearer {PHONE}"},
    )
    phone = _FakePhone(phone_ws, ("127.0.0.1", echo_port))
    phone.start()
    try:
        assert phone.ready.wait(5.0)
        _wait_until(lambda: tunnel.ready)
        _wait_until(lambda: _health(server.port)["tunnel"]["ready"])
        links = _health(server.port)["tunnel"]["links"]
        assert any(
            item["session"] == "default" and item["host"] and item["phone"] for item in links
        )

        client = socket.create_connection(("127.0.0.1", port), timeout=5)
        client.settimeout(5)
        try:
            payload = b"hello through the tunnel"
            client.sendall(payload)
            received = b""
            while len(received) < len(payload):
                received += client.recv(len(payload) - len(received))
            assert received == payload
        finally:
            client.close()
    finally:
        tunnel.stop()
        phone_ws.close()
        worker.join(timeout=5)
