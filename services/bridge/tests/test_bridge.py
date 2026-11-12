from __future__ import annotations

import base64
import json
import time
import urllib.error
import urllib.request
from pathlib import Path

import pytest

from hopa_bridge.bridge import BridgeError, BridgeServer
from hopa_bridge.layout import parse_layout

LAYOUT = parse_layout(
    {
        "attributes": {"text": "Root", "bounds": "[0,0][1080,2400]"},
        "children": [
            {
                "attributes": {
                    "type": "Button",
                    "text": "WLAN",
                    "bounds": "[10,20][210,120]",
                    "clickable": "true",
                }
            }
        ],
    }
)

FAKE_JPEG = b"\xff\xd8fakejpeg"


class FakeHdc:
    def shell(self, command: str, timeout: float | None = None) -> str:
        return ""

    def file_recv(self, remote: str, local, timeout: float | None = None) -> None:
        Path(local).write_bytes(FAKE_JPEG)


class FakeDevice:
    def __init__(self) -> None:
        self.calls: list[tuple] = []
        self.hdc = FakeHdc()
        self.serial = "fake"
        self.platform = "harmony"
        self.foreground_bundle = ""
        self.raise_after_stop = False
        self.stopped = False

    def devices(self) -> list[str]:
        return ["127.0.0.1:5555"]

    def shell(self, command: str) -> str:
        return self.hdc.shell(command)

    def pull(self, remote: str, local: str) -> None:
        self.hdc.file_recv(remote, local)

    def foreground(self) -> str:
        return self.foreground_bundle

    def dump_layout(self, **_kwargs):
        return LAYOUT

    def tap(self, x: int, y: int) -> None:
        self.calls.append(("tap", x, y))

    def type_text(self, text: str, *, x=None, y=None) -> None:
        self.calls.append(("type", text, x, y))

    def launch(self, bundle: str, ability: str = "", raise_window: bool = False) -> None:
        self.calls.append(("launch", bundle, ability, raise_window))
        if self.raise_after_stop and not self.stopped:
            return
        self.foreground_bundle = bundle

    def stop(self, bundle: str) -> None:
        self.calls.append(("stop", bundle))
        self.stopped = True

    def press_key(self, name: str) -> None:
        self.calls.append(("key", name))

    def swipe(self, *args, velocity: int = 600) -> None:
        self.calls.append(("swipe", *args, velocity))


def test_the_bootstrap_token_keeps_working_after_pairing(bridge):
    server, _device = bridge
    server.issue_tokens()
    assert "nodes" in _call(server, "/observe", {}, token="secret")


def test_stop_closes_the_app(bridge):
    server, device = bridge
    body = _call(server, "/stop", {"bundle": "com.huawei.hmos.settings"})
    assert body["ok"] is True
    assert ("stop", "com.huawei.hmos.settings") in device.calls


def test_focus_restarts_when_the_window_does_not_raise(bridge):
    server, device = bridge
    # The first launch takes the intent but never raises the window; only a
    # cold restart does. That is the singleton case seen on the 2in1.
    device.raise_after_stop = True
    body = _call(server, "/focus", {"bundle": "com.huawei.hmos.clock"}, timeout=20)
    assert body["ok"] is True
    assert body["restarted"] is True
    assert ("stop", "com.huawei.hmos.clock") in device.calls


def test_focus_does_not_restart_a_working_launch(bridge):
    server, device = bridge
    body = _call(server, "/focus", {"bundle": "com.huawei.hmos.clock"})
    assert body["restarted"] is False
    assert device.stopped is False
    assert any(call[0] == "launch" and call[3] is True for call in device.calls)


def test_focus_never_cold_restarts_hopa(bridge):
    server, device = bridge
    # Even when the window query says the raise did not land, restarting HOPA
    # would kill the run that is asking to come back and lose its answer.
    device.raise_after_stop = True
    body = _call(server, "/focus", {"bundle": "com.hopa.agent"}, timeout=20)
    assert body["restarted"] is False
    assert device.stopped is False
    assert all(call[0] != "stop" for call in device.calls)


def test_pair_survives_a_restart(tmp_path):
    state = tmp_path / "bridge.json"
    first = BridgeServer(FakeDevice(), "secret", port=0, state_path=state)
    pair = first.issue_tokens()
    first.stop()
    second = BridgeServer(FakeDevice(), "secret", port=0, state_path=state)
    assert second.restored is True
    assert second.token == pair["token"]
    assert second.token_live() is True
    second.stop()


def test_a_different_token_starts_a_new_pair(tmp_path):
    state = tmp_path / "bridge.json"
    first = BridgeServer(FakeDevice(), "secret", port=0, state_path=state)
    pair = first.issue_tokens()
    first.stop()
    second = BridgeServer(FakeDevice(), "other", port=0, state_path=state)
    assert second.restored is False
    assert second.token != pair["token"]
    second.stop()


def test_an_expired_pair_is_not_restored(tmp_path):
    state = tmp_path / "bridge.json"
    first = BridgeServer(FakeDevice(), "secret", port=0, state_path=state)
    first.issue_tokens()
    first.stop()
    data = json.loads(state.read_text(encoding="utf-8"))
    data["issued_at"] = time.time() - 24 * 3600
    state.write_text(json.dumps(data), encoding="utf-8")
    second = BridgeServer(FakeDevice(), "secret", port=0, state_path=state)
    assert second.restored is False
    second.stop()


@pytest.fixture()
def bridge():
    device = FakeDevice()
    server = BridgeServer(device, "secret", port=0, pair_code="123456")
    server.start()
    try:
        yield server, device
    finally:
        server.stop()


def _call(
    server: BridgeServer,
    path: str,
    payload: dict | None = None,
    token: str = "secret",
    timeout: float = 3.0,
):
    url = f"http://127.0.0.1:{server.port}{path}"
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=data, method="POST" if data else "GET")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    if data:
        request.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def test_health_needs_no_token(bridge) -> None:
    server, _ = bridge
    assert _call(server, "/health", token="")["ok"] is True


def test_whoami_confirms_the_token(bridge) -> None:
    server, _ = bridge
    assert _call(server, "/whoami")["ok"] is True


def test_whoami_rejects_a_wrong_token(bridge) -> None:
    server, _ = bridge
    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/whoami", token="wrong")
    assert error.value.code == 401


def test_post_requires_token(bridge) -> None:
    server, _ = bridge
    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/observe", {}, token="wrong")
    assert error.value.code == 401


def test_observe_returns_nodes(bridge) -> None:
    server, _ = bridge
    result = _call(server, "/observe", {})
    assert "WLAN" in result["text"]
    assert result["width"] == 1080
    assert result["height"] == 2400
    wlan = next(node for node in result["nodes"] if node["text"] == "WLAN")
    assert wlan["ref"].startswith("e")
    assert wlan["clickable"] is True


def test_chats_roundtrip(bridge) -> None:
    server, _ = bridge
    empty = _call(server, "/chats")
    assert empty["rev"] == 0
    assert empty["sessions"] == []

    payload = {
        "sessions": [
            {
                "id": "s1",
                "title": "Hello",
                "titleAt": 10,
                "created": 1,
                "updated": 2,
                "turns": [{"id": "t1", "role": "user", "text": "hi", "at": 1}],
            }
        ]
    }
    merged = _call(server, "/chats", payload)
    assert merged["rev"] == 1
    assert merged["sessions"][0]["id"] == "s1"
    assert merged["sessions"][0]["turns"][0]["text"] == "hi"

    # The same turn arriving twice is still one turn, so rev does not move.
    again = _call(server, "/chats", payload)
    assert again["rev"] == 1
    assert len(again["sessions"][0]["turns"]) == 1

    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/chats", payload, token="wrong")
    assert error.value.code == 401


def test_launch_confirms_the_foreground_app(bridge) -> None:
    server, device = bridge
    result = _call(server, "/launch", {"bundle": "com.huawei.hmos.settings"})
    assert result["ok"] is True
    assert result["foreground"] == "com.huawei.hmos.settings"
    assert _call(server, "/foreground", {})["bundle"] == "com.huawei.hmos.settings"


def test_tap_and_type_and_launch(bridge) -> None:
    server, device = bridge
    _call(server, "/tap", {"x": 5, "y": 6})
    _call(server, "/type", {"text": "hi", "x": 1, "y": 2})
    _call(server, "/launch", {"bundle": "com.x"})
    _call(server, "/key", {"name": "Back"})
    _call(server, "/swipe", {"from_x": 1, "from_y": 2, "to_x": 3, "to_y": 4})
    assert device.calls == [
        ("tap", 5, 6),
        ("type", "hi", 1, 2),
        ("launch", "com.x", "", False),
        ("key", "Back"),
        ("swipe", 1, 2, 3, 4, 600),
    ]


def test_sessions_round_trip(bridge) -> None:
    server, _ = bridge
    payload = {"sessions": [{"id": "a", "title": "Plan", "turns": []}]}
    assert _call(server, "/sessions", payload)["count"] == 1
    pulled = _call(server, "/sessions", None)
    assert pulled["sessions"] == payload["sessions"]
    assert pulled["updated"] > 0


def test_sessions_key_is_read_only(bridge) -> None:
    server, _ = bridge
    key = server.sessions_key
    _call(server, "/sessions", {"sessions": []})  # control token writes
    pulled = _call(server, "/sessions", None, token=key)
    assert pulled["sessions"] == []
    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/tap", {"x": 1, "y": 2}, token=key)
    assert error.value.code == 401


def test_sessions_need_a_token(bridge) -> None:
    server, _ = bridge
    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/sessions", None, token="wrong")
    assert error.value.code == 401


def test_sessions_snapshot_is_capped(bridge) -> None:
    server, _ = bridge
    huge = {"sessions": [{"id": "x", "title": "y" * 600000, "turns": []}]}
    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/sessions", huge)
    assert error.value.code == 400


def test_unknown_endpoint(bridge) -> None:
    server, _ = bridge
    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/nope", {})
    assert error.value.code == 400


def test_screenshot_returns_base64(bridge) -> None:
    server, _ = bridge
    result = _call(server, "/screenshot", {})
    assert result["mime"] == "image/jpeg"
    assert result["bytes"] == len(FAKE_JPEG)
    assert base64.b64decode(result["image"]) == FAKE_JPEG


def test_bad_body(bridge) -> None:
    server, _ = bridge
    url = f"http://127.0.0.1:{server.port}/tap"
    request = urllib.request.Request(url, data=b"not json", method="POST")
    request.add_header("Authorization", "Bearer secret")
    with pytest.raises(urllib.error.HTTPError) as error:
        urllib.request.urlopen(request, timeout=3)
    assert error.value.code == 400


def test_token_is_required() -> None:
    with pytest.raises(BridgeError):
        BridgeServer(FakeDevice(), "")


def test_pair_rotates_and_returns_a_session(bridge) -> None:
    server, _ = bridge
    session = _call(server, "/pair", {"code": "123456"}, token="")
    assert session["token"] and session["token"] != "secret"
    assert len(session["refresh"]) >= 32
    assert session["expires_in"] > 0
    # The bootstrap token stays valid: a dev laptop holds it and must not be
    # stranded by a restart. The paired token is the rotating one.
    assert "WLAN" in _call(server, "/observe", {}, token="secret")["text"]
    assert "WLAN" in _call(server, "/observe", {}, token=session["token"])["text"]


def test_refresh_rotates_again_and_retires_the_old_pair(bridge) -> None:
    server, _ = bridge
    first = _call(server, "/pair", {"code": "123456"}, token="")
    second = _call(server, "/refresh", {"refresh": first["refresh"]}, token="")
    assert second["token"] != first["token"]
    assert second["refresh"] != first["refresh"]
    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/observe", {}, token=first["token"])
    assert error.value.code == 401
    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/refresh", {"refresh": first["refresh"]}, token="")
    assert error.value.code == 401
    _call(server, "/observe", {}, token=second["token"])


def test_expired_token_says_so_and_can_be_refreshed() -> None:
    device = FakeDevice()
    server = BridgeServer(device, "secret", port=0, pair_code="123456", token_ttl=0.15)
    server.start()
    try:
        session = _call(server, "/pair", {"code": "123456"}, token="")
        time.sleep(0.3)
        with pytest.raises(urllib.error.HTTPError) as error:
            _call(server, "/observe", {}, token=session["token"])
        assert error.value.code == 401
        assert json.loads(error.value.read().decode())["error"] == "token expired"
        renewed = _call(server, "/refresh", {"refresh": session["refresh"]}, token="")
        assert renewed["token"] != session["token"]
        _call(server, "/observe", {}, token=renewed["token"])
    finally:
        server.stop()


def test_pair_rejects_a_wrong_code(bridge) -> None:
    server, _ = bridge
    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/pair", {"code": "000000"}, token="")
    assert error.value.code == 401
