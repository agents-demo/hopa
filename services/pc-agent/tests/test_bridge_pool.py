from __future__ import annotations

import json
import urllib.error
import urllib.request

import pytest

from hopa_pc_agent.bridge_pool import BridgePool


class FakeHdc:
    def shell(self, command: str, timeout: float | None = None) -> str:
        return ""

    def file_recv(self, remote: str, local, timeout: float | None = None) -> None:
        pass


class FakeDevice:
    def __init__(self) -> None:
        self.calls: list[tuple] = []
        self.hdc = FakeHdc()
        self.foreground_bundle = ""

    def devices(self) -> list[str]:
        return ["x"]

    def foreground(self) -> str:
        return self.foreground_bundle

    def dump_layout(self, **_kwargs):
        raise RuntimeError("not used")

    def tap(self, x: int, y: int) -> None:
        self.calls.append(("tap", x, y))

    def type_text(self, text: str, *, x=None, y=None) -> None:
        self.calls.append(("type", text, x, y))

    def launch(self, bundle: str, ability: str = "") -> None:
        self.calls.append(("launch", bundle, ability))

    def press_key(self, name: str) -> None:
        self.calls.append(("key", name))

    def swipe(self, *args, velocity: int = 600) -> None:
        self.calls.append(("swipe", *args, velocity))


@pytest.fixture()
def pool():
    devices = {"1111": FakeDevice(), "2222": FakeDevice()}
    entries = [
        {"serial": "1111", "token": "phone-token", "role": "phone", "pair": "123456"},
        {"serial": "2222", "token": "pc-token", "role": "2in1", "pair": "123456"},
    ]
    server = BridgePool(entries, port=0, device_factory=lambda serial: devices[serial])
    server.start()
    try:
        yield server, devices
    finally:
        server.stop()


def call(pool, path, *, role="", token="phone-token", method="POST", payload=None):
    url = f"http://127.0.0.1:{pool.port}{path}"
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Authorization": f"Bearer {token}"}
    if role:
        headers["X-Hopa-Role"] = role
    if body is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    with urllib.request.urlopen(request, timeout=5) as response:
        return response.status, json.loads(response.read())


def test_health_lists_both_devices(pool):
    server, _ = pool
    status, body = call(server, "/health", method="GET")
    assert status == 200
    assert body["ok"] is True
    roles = {entry["role"] for entry in body["devices"]}
    assert roles == {"phone", "2in1"}


def test_role_routes_the_tap(pool):
    server, devices = pool
    assert call(server, "/tap", role="2in1", token="pc-token", payload={"x": 10, "y": 20})[0] == 200
    assert devices["2222"].calls == [("tap", 10, 20)]
    assert devices["1111"].calls == []


def test_explicit_path_wins_over_the_role(pool):
    server, devices = pool
    assert call(server, "/d/1111/tap", role="2in1", token="phone-token", payload={"x": 1, "y": 2})[0] == 200
    assert devices["1111"].calls == [("tap", 1, 2)]


def test_sessions_goes_to_the_phone(pool):
    server, _ = pool
    status, body = call(server, "/sessions", token="phone-token", method="GET")
    assert status == 200
    assert body["sessions"] == []


def test_no_role_is_ambiguous_with_two_devices(pool):
    server, _ = pool
    with pytest.raises(urllib.error.HTTPError) as error:
        call(server, "/tap", payload={"x": 1, "y": 2})
    assert error.value.code == 400
    assert "which device" in json.loads(error.value.read())["error"]


def test_unknown_role_is_rejected(pool):
    server, _ = pool
    with pytest.raises(urllib.error.HTTPError) as error:
        call(server, "/tap", role="watch", payload={"x": 1, "y": 2})
    assert error.value.code == 400


def test_wrong_token_is_rejected_by_the_device_server(pool):
    server, _ = pool
    with pytest.raises(urllib.error.HTTPError) as error:
        call(server, "/tap", role="2in1", token="phone-token", payload={"x": 1, "y": 2})
    assert error.value.code == 401
