from __future__ import annotations

import base64
import json
import urllib.error
import urllib.request
from pathlib import Path

import pytest

from hopa_pc_agent.bridge import BridgeError, BridgeServer
from hopa_pc_agent.layout import parse_layout

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
        self.foreground_bundle = ""

    def devices(self) -> list[str]:
        return ["127.0.0.1:5555"]

    def foreground(self) -> str:
        return self.foreground_bundle

    def dump_layout(self, **_kwargs):
        return LAYOUT

    def tap(self, x: int, y: int) -> None:
        self.calls.append(("tap", x, y))

    def type_text(self, text: str, *, x=None, y=None) -> None:
        self.calls.append(("type", text, x, y))

    def launch(self, bundle: str, ability: str = "") -> None:
        self.calls.append(("launch", bundle, ability))
        self.foreground_bundle = bundle

    def press_key(self, name: str) -> None:
        self.calls.append(("key", name))

    def swipe(self, *args, velocity: int = 600) -> None:
        self.calls.append(("swipe", *args, velocity))


@pytest.fixture()
def bridge():
    device = FakeDevice()
    server = BridgeServer(device, "secret", port=0, pair_code="123456")
    server.start()
    try:
        yield server, device
    finally:
        server.stop()


def _call(server: BridgeServer, path: str, payload: dict | None = None, token: str = "secret"):
    url = f"http://127.0.0.1:{server.port}{path}"
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url, data=data, method="POST" if data else "GET")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    if data:
        request.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(request, timeout=3) as response:
        return json.loads(response.read().decode("utf-8"))


def test_health_needs_no_token(bridge) -> None:
    server, _ = bridge
    assert _call(server, "/health", token="")["ok"] is True


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
        ("launch", "com.x", ""),
        ("key", "Back"),
        ("swipe", 1, 2, 3, 4, 600),
    ]


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


def test_pair_returns_token_for_the_right_code(bridge) -> None:
    server, _ = bridge
    assert _call(server, "/pair", {"code": "123456"}, token="") == {"token": "secret"}


def test_pair_rejects_a_wrong_code(bridge) -> None:
    server, _ = bridge
    with pytest.raises(urllib.error.HTTPError) as error:
        _call(server, "/pair", {"code": "000000"}, token="")
    assert error.value.code == 401
