"""Minimal MCP (Model Context Protocol) stdio server for pc-agent.

Implements the JSON-RPC subset that MCP clients need: ``initialize``, ``ping``,
``tools/list`` and ``tools/call``. Messages are newline-delimited JSON on stdio,
as required by the MCP stdio transport. No third-party SDK is required.
"""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path
from typing import Any, TextIO

from . import __version__
from .device import Device
from .errors import HopaError

DEFAULT_PROTOCOL_VERSION = "2024-11-05"
SERVER_NAME = "hopa-pc-agent"

TOOLS: list[dict[str, Any]] = [
    {
        "name": "hopa_list_devices",
        "description": "List HarmonyOS devices/emulators visible to hdc.",
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "hopa_dump_layout",
        "description": "Dump the current on-screen UI tree (uitest dumpLayout).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "include_attrs": {"type": "boolean", "default": False},
                "full": {"type": "boolean", "default": True},
            },
            "additionalProperties": False,
        },
    },
    {
        "name": "hopa_list_apps",
        "description": "List installed app bundles on the device, optionally filtered.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "filter": {"type": "string", "description": "case-insensitive bundle/label filter"},
            },
            "additionalProperties": False,
        },
    },
    {
        "name": "hopa_stop_app",
        "description": "Force-stop an app by bundle name.",
        "inputSchema": {
            "type": "object",
            "properties": {"bundle": {"type": "string"}},
            "required": ["bundle"],
            "additionalProperties": False,
        },
    },
    {
        "name": "hopa_tap",
        "description": "Tap a screen coordinate.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "x": {"type": "integer"},
                "y": {"type": "integer"},
            },
            "required": ["x", "y"],
            "additionalProperties": False,
        },
    },
    {
        "name": "hopa_swipe",
        "description": "Swipe from one coordinate to another.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "from_x": {"type": "integer"},
                "from_y": {"type": "integer"},
                "to_x": {"type": "integer"},
                "to_y": {"type": "integer"},
                "velocity": {"type": "integer", "default": 600},
            },
            "required": ["from_x", "from_y", "to_x", "to_y"],
            "additionalProperties": False,
        },
    },
    {
        "name": "hopa_type_text",
        "description": "Type text, optionally tapping a text box coordinate first.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "text": {"type": "string"},
                "x": {"type": "integer"},
                "y": {"type": "integer"},
            },
            "required": ["text"],
            "additionalProperties": False,
        },
    },
    {
        "name": "hopa_screenshot",
        "description": "Capture a JPEG screenshot and return it as image content.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "out": {"type": "string", "description": "local output path"},
            },
            "additionalProperties": False,
        },
    },
    {
        "name": "hopa_launch_app",
        "description": "Launch an app by bundle name or alias (settings, clock, calendar, notes).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "bundle": {"type": "string"},
                "ability": {"type": "string", "default": ""},
            },
            "required": ["bundle"],
            "additionalProperties": False,
        },
    },
    {
        "name": "hopa_press_key",
        "description": "Send a key event such as Back or Home.",
        "inputSchema": {
            "type": "object",
            "properties": {"name": {"type": "string"}},
            "required": ["name"],
            "additionalProperties": False,
        },
    },
]

_ALIASES = {
    "settings": "com.huawei.hmos.settings",
    "clock": "com.huawei.hmos.clock",
    "calendar": "com.huawei.hmos.calendar",
    "browser": "com.huawei.hmos.browser",
    "notes": "com.huawei.hmos.notepad",
}


def _text_result(text: str, *, is_error: bool = False) -> dict[str, Any]:
    return {"content": [{"type": "text", "text": text}], "isError": is_error}


class McpServer:
    def __init__(self, device: Device, stdin: TextIO | None = None, stdout: TextIO | None = None):
        self.device = device
        self.stdin = stdin or sys.stdin
        self.stdout = stdout or sys.stdout

    def serve(self) -> None:
        for line in self.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            response = self.handle(message)
            if response is not None:
                self.send(response)

    def send(self, message: dict[str, Any]) -> None:
        self.stdout.write(json.dumps(message, ensure_ascii=False) + "\n")
        self.stdout.flush()

    def handle(self, message: Any) -> dict[str, Any] | None:
        if not isinstance(message, dict):
            return None
        method = message.get("method")
        if not isinstance(method, str):
            return None
        # Notifications have no id and must not receive a response.
        if "id" not in message:
            return None
        request_id = message["id"]
        params = message.get("params") or {}

        try:
            if method == "initialize":
                result = self._initialize(params)
            elif method == "ping":
                result = {}
            elif method == "tools/list":
                result = {"tools": TOOLS}
            elif method == "tools/call":
                result = self._call_tool(params)
            else:
                return self._error(request_id, -32601, f"Method not found: {method}")
            return {"jsonrpc": "2.0", "id": request_id, "result": result}
        except HopaError as exc:
            result = _text_result(str(exc), is_error=True)
            return {"jsonrpc": "2.0", "id": request_id, "result": result}
        except Exception as exc:  # noqa: BLE001 - report any tool failure to the client
            return self._error(request_id, -32603, str(exc))

    def _initialize(self, params: dict[str, Any]) -> dict[str, Any]:
        requested = params.get("protocolVersion")
        version = DEFAULT_PROTOCOL_VERSION
        if isinstance(requested, str) and requested:
            version = requested
        return {
            "protocolVersion": version,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": SERVER_NAME, "version": __version__},
        }

    def _call_tool(self, params: dict[str, Any]) -> dict[str, Any]:
        name = params.get("name")
        arguments = params.get("arguments") or {}
        if not isinstance(arguments, dict):
            return _text_result("arguments must be an object", is_error=True)

        if name == "hopa_list_devices":
            return _text_result(json.dumps(self.device.devices(), ensure_ascii=False))

        if name == "hopa_dump_layout":
            include_attrs = bool(arguments.get("include_attrs", False))
            layout = self.device.dump_layout(include_attrs=include_attrs)
            if arguments.get("full", True):
                payload: Any = layout.to_dict()
            else:
                payload = {
                    "nodes": sum(1 for _ in layout.walk()),
                    "texts": [t for t in layout.texts() if t.strip()],
                }
            return _text_result(json.dumps(payload, ensure_ascii=False))

        if name == "hopa_tap":
            self.device.tap(int(arguments["x"]), int(arguments["y"]))
            return _text_result("tapped")

        if name == "hopa_swipe":
            self.device.swipe(
                int(arguments["from_x"]),
                int(arguments["from_y"]),
                int(arguments["to_x"]),
                int(arguments["to_y"]),
                velocity=int(arguments.get("velocity", 600)),
            )
            return _text_result("swiped")

        if name == "hopa_type_text":
            self.device.type_text(
                str(arguments["text"]),
                x=int(arguments["x"]) if "x" in arguments else None,
                y=int(arguments["y"]) if "y" in arguments else None,
            )
            return _text_result("typed")

        if name == "hopa_screenshot":
            path = self.device.screenshot(arguments.get("out"))
            data = base64.b64encode(Path(path).read_bytes()).decode("ascii")
            return {
                "content": [
                    {"type": "text", "text": f"saved {path}"},
                    {"type": "image", "data": data, "mimeType": "image/jpeg"},
                ],
                "isError": False,
            }

        if name == "hopa_launch_app":
            raw = str(arguments["bundle"])
            bundle = _ALIASES.get(raw.lower(), raw)
            self.device.launch(bundle, ability=str(arguments.get("ability", "")))
            return _text_result(f"launched {bundle}")

        if name == "hopa_list_apps":
            needle = str(arguments.get("filter", "")).lower()
            apps = [
                app
                for app in self.device.apps()
                if needle in app["bundle"].lower() or needle in app.get("label", "").lower()
            ]
            return _text_result(json.dumps(apps, ensure_ascii=False))

        if name == "hopa_stop_app":
            raw = str(arguments["bundle"])
            bundle = _ALIASES.get(raw.lower(), raw)
            self.device.stop(bundle)
            return _text_result(f"stopped {bundle}")

        if name == "hopa_press_key":
            self.device.press_key(str(arguments["name"]))
            return _text_result("key sent")

        return _text_result(f"unknown tool: {name}", is_error=True)

    @staticmethod
    def _error(request_id: Any, code: int, message: str) -> dict[str, Any]:
        return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def serve_stdio(device: Device) -> None:
    McpServer(device).serve()
