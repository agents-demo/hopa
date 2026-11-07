"""HTTP bridge for PC-tethered control.

The phone app can drive other apps through this server, which uses ``hdc`` and
``uitest`` on the PC. It is the M4 fallback when the accessibility ACL cannot be
enabled. Every request needs a bearer token; the default bind is 127.0.0.1.

Endpoints (JSON):
    GET  /health
    POST /observe              -> {"text": str, "nodes": [...], "width": int, "height": int}
    POST /tap                  {"x": int, "y": int}
    POST /type                 {"text": str, "x": int?, "y": int?}
    POST /launch               {"bundle": str, "ability": str?}
    POST /key                  {"name": str}
    POST /swipe                {"from_x", "from_y", "to_x", "to_y", "velocity"?}
    POST /screenshot           -> {"mime": "image/jpeg", "bytes": int, "image": "base64"}
"""

from __future__ import annotations

import base64
import hmac
import json
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

from .device import Device


class BridgeError(Exception):
    pass


def _node_payload(node: Any, ref: str) -> dict[str, Any]:
    return {
        "ref": ref,
        "text": node.text,
        "description": node.description,
        "type": node.type,
        "bounds": list(node.bounds) if node.bounds else [],
        "clickable": bool(node.clickable),
    }


def _observe(device: Device) -> dict[str, Any]:
    layout = device.dump_layout()
    nodes: list[dict[str, Any]] = []
    refs: dict[str, Any] = {}
    width = 0
    height = 0
    index = 0
    for node in layout.walk():
        if node.bounds:
            width = max(width, node.bounds[2])
            height = max(height, node.bounds[3])
        if not (node.text or node.description or node.clickable):
            continue
        index += 1
        ref = f"e{index}"
        refs[ref] = node
        nodes.append(_node_payload(node, ref))
    return {
        "text": "\n".join(layout.texts()),
        "nodes": nodes,
        "width": width,
        "height": height,
        "refs": refs,
    }


def _screenshot(device: Device) -> dict[str, Any]:
    remote = "/data/local/tmp/hopa-bridge.jpeg"
    device.hdc.shell(f"snapshot_display -f {remote}")
    with tempfile.TemporaryDirectory(prefix="hopa-shot-") as tmp:
        local = Path(tmp) / "screen.jpeg"
        device.hdc.file_recv(remote, local)
        raw = local.read_bytes()
    return {
        "mime": "image/jpeg",
        "bytes": len(raw),
        "image": base64.b64encode(raw).decode("ascii"),
    }


class _Handler(BaseHTTPRequestHandler):
    server_version = "hopa-bridge/0.1"

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        print(
            f"{self.command} {self.path} {args[0] if args else ''}",
            file=sys.stderr,
            flush=True,
        )

    @property
    def bridge(self) -> BridgeServer:
        return self.server.bridge  # type: ignore[attr-defined]

    def _send(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self) -> bool:
        header = self.headers.get("Authorization", "")
        expected = f"Bearer {self.bridge.token}"
        return hmac.compare_digest(header, expected)

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        try:
            data = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise BridgeError("body is not JSON") from exc
        if not isinstance(data, dict):
            raise BridgeError("body must be an object")
        return data

    def do_GET(self) -> None:  # noqa: N802
        if self.path != "/health":
            self._send(404, {"error": "not found"})
            return
        # Do not probe the device here: a slow hdc must not make the bridge
        # look unreachable.
        self._send(200, {"ok": True})

    def do_POST(self) -> None:  # noqa: N802
        if not self._authorized():
            # Drain the body so the client does not see a connection reset.
            length = int(self.headers.get("Content-Length", "0"))
            if length:
                self.rfile.read(length)
            self.close_connection = True
            self._send(401, {"error": "unauthorized"})
            return
        try:
            data = self._read_json()
            result = self._dispatch(data)
        except BridgeError as exc:
            self._send(400, {"error": str(exc)})
            return
        except Exception as exc:  # noqa: BLE001 - bridge reports device errors
            self._send(500, {"error": f"{type(exc).__name__}: {exc}"})
            return
        self._send(200, result)

    def _dispatch(self, data: dict[str, Any]) -> dict[str, Any]:
        device = self.bridge.device
        if self.path == "/observe":
            started = time.perf_counter()
            observation = _observe(device)
            print(f"observe {time.perf_counter() - started:.2f}s", file=sys.stderr, flush=True)
            # The app only needs serialisable fields.
            observation.pop("refs", None)
            return observation
        if self.path == "/tap":
            device.tap(int(data["x"]), int(data["y"]))
            return {"ok": True}
        if self.path == "/screenshot":
            started = time.perf_counter()
            shot = _screenshot(device)
            print(f"screenshot {time.perf_counter() - started:.2f}s", file=sys.stderr, flush=True)
            return shot
        if self.path == "/type":
            x = data.get("x")
            y = data.get("y")
            device.type_text(
                str(data["text"]),
                x=int(x) if x is not None else None,
                y=int(y) if y is not None else None,
            )
            return {"ok": True}
        if self.path == "/launch":
            device.launch(str(data["bundle"]), ability=str(data.get("ability", "")))
            return {"ok": True}
        if self.path == "/key":
            device.press_key(str(data["name"]))
            return {"ok": True}
        if self.path == "/swipe":
            device.swipe(
                int(data["from_x"]),
                int(data["from_y"]),
                int(data["to_x"]),
                int(data["to_y"]),
                velocity=int(data.get("velocity", 600)),
            )
            return {"ok": True}
        raise BridgeError(f"unknown endpoint: {self.path}")


class BridgeServer:
    def __init__(
        self,
        device: Device,
        token: str,
        *,
        host: str = "127.0.0.1",
        port: int = 8765,
    ) -> None:
        if not token:
            raise BridgeError("a token is required")
        self.device = device
        self.token = token
        self.httpd = ThreadingHTTPServer((host, port), _Handler)
        self.httpd.bridge = self  # type: ignore[attr-defined]
        self.thread: threading.Thread | None = None

    @property
    def port(self) -> int:
        return int(self.httpd.server_address[1])

    def start(self) -> None:
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()

    def stop(self) -> None:
        if self.thread is not None and self.thread.is_alive():
            self.httpd.shutdown()
        self.httpd.server_close()
        if self.thread is not None:
            self.thread.join(timeout=2)
