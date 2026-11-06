from __future__ import annotations

import json

from hopa_pc_agent.mcp_server import McpServer


class FakeDevice:
    def __init__(self) -> None:
        self.calls: list[tuple] = []

    def devices(self) -> list[str]:
        return ["127.0.0.1:5555"]

    def dump_layout(self, *, include_attrs: bool = False):
        from hopa_pc_agent.layout import parse_layout

        return parse_layout({"attributes": {"text": "Hello"}, "children": []})

    def tap(self, x: int, y: int) -> None:
        self.calls.append(("tap", x, y))

    def swipe(self, *args, velocity: int = 600) -> None:
        self.calls.append(("swipe", *args, velocity))

    def type_text(self, text: str, *, x=None, y=None) -> None:
        self.calls.append(("type", text, x, y))

    def screenshot(self, path=None):
        raise AssertionError("not used in this test")

    def launch(self, bundle: str, ability: str = "EntryAbility") -> None:
        self.calls.append(("launch", bundle, ability))

    def press_key(self, name: str) -> None:
        self.calls.append(("key", name))

    def apps(self) -> list[dict[str, str]]:
        return [
            {"bundle": "com.huawei.hmos.settings", "label": "Settings"},
            {"bundle": "com.huawei.hmos.calendar", "label": "Calendar"},
        ]

    def stop(self, bundle: str) -> None:
        self.calls.append(("stop", bundle))


def _server() -> tuple[McpServer, FakeDevice]:
    device = FakeDevice()
    return McpServer(device), device  # type: ignore[arg-type]


def test_initialize_echoes_protocol_version() -> None:
    server, _ = _server()
    response = server.handle(
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {"protocolVersion": "2025-03-26"},
        }
    )
    assert response is not None
    assert response["result"]["protocolVersion"] == "2025-03-26"
    assert response["result"]["serverInfo"]["name"] == "hopa-pc-agent"


def test_tools_list_contains_core_tools() -> None:
    server, _ = _server()
    response = server.handle({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
    names = {tool["name"] for tool in response["result"]["tools"]}
    assert {"hopa_tap", "hopa_dump_layout", "hopa_screenshot"} <= names
    assert {"hopa_list_apps", "hopa_stop_app"} <= names


def test_tools_call_tap() -> None:
    server, device = _server()
    response = server.handle(
        {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {"name": "hopa_tap", "arguments": {"x": 10, "y": 20}},
        }
    )
    assert response["result"]["isError"] is False
    assert device.calls == [("tap", 10, 20)]


def test_tools_call_launch_alias() -> None:
    server, device = _server()
    response = server.handle(
        {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {"name": "hopa_launch_app", "arguments": {"bundle": "settings"}},
        }
    )
    assert response["result"]["isError"] is False
    assert device.calls == [("launch", "com.huawei.hmos.settings", "")]


def test_tools_call_list_apps() -> None:
    server, _ = _server()
    response = server.handle(
        {
            "jsonrpc": "2.0",
            "id": 5,
            "method": "tools/call",
            "params": {"name": "hopa_list_apps", "arguments": {}},
        }
    )
    text = response["result"]["content"][0]["text"]
    apps = json.loads(text)
    assert [app["bundle"] for app in apps] == [
        "com.huawei.hmos.settings",
        "com.huawei.hmos.calendar",
    ]


def test_tools_call_list_apps_filter() -> None:
    server, _ = _server()
    response = server.handle(
        {
            "jsonrpc": "2.0",
            "id": 6,
            "method": "tools/call",
            "params": {"name": "hopa_list_apps", "arguments": {"filter": "cal"}},
        }
    )
    apps = json.loads(response["result"]["content"][0]["text"])
    assert [app["bundle"] for app in apps] == ["com.huawei.hmos.calendar"]


def test_tools_call_stop_app_alias() -> None:
    server, device = _server()
    response = server.handle(
        {
            "jsonrpc": "2.0",
            "id": 7,
            "method": "tools/call",
            "params": {"name": "hopa_stop_app", "arguments": {"bundle": "settings"}},
        }
    )
    assert response["result"]["isError"] is False
    assert device.calls == [("stop", "com.huawei.hmos.settings")]


def test_notifications_get_no_response() -> None:
    server, _ = _server()
    assert server.handle({"jsonrpc": "2.0", "method": "notifications/initialized"}) is None


def test_unknown_method_is_jsonrpc_error() -> None:
    server, _ = _server()
    response = server.handle({"jsonrpc": "2.0", "id": 9, "method": "nope"})
    assert response["error"]["code"] == -32601


def test_serve_reads_newline_delimited_json() -> None:
    import io

    stdin = io.StringIO(
        json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}) + "\n"
    )
    stdout = io.StringIO()
    server, _ = _server()
    server.stdin = stdin
    server.stdout = stdout
    server.serve()
    line = stdout.getvalue().strip()
    assert json.loads(line)["id"] == 1
