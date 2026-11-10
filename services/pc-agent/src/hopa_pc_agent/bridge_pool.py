"""One port, several devices.

A ``BridgeServer`` owns one device: every endpoint resolves against the serial
it was built with. That is the right unit of isolation, but running one process
per device means two ports, two reverse tunnels and two things that can die.

``BridgePool`` keeps the per-device servers and puts a single listener in front.
Callers say which device they mean, and the pool forwards the request verbatim,
so authentication, rate limits and locks stay in the device server that owns
them.

Routing, first match wins:

1. ``/d/<serial>/...``          explicit, always wins;
2. ``X-Hopa-Role: phone``       the device whose ``devicetype`` is a phone;
3. ``X-Hopa-Role: 2in1``        the 2-in-1;
4. ``/sessions`` (no role)      the phone: the snapshot is a phone concept;
5. exactly one device           legacy callers that send no role at all;
6. otherwise ``400``            ambiguous, and guessing would be rude.

The device-side reverse port is still one per device: ``hdc`` will not let two
devices listen on the same local port, so the phone uses 8768 and the laptop
8766, both forwarding to this one listener.
"""

from __future__ import annotations

import hmac
import http.client
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from .bridge import BridgeServer
from .device import Device

PHONE_ROLES = ("phone", "tablet")


class BridgePool:
    def __init__(
        self,
        devices: list[dict[str, Any]],
        *,
        host: str = "127.0.0.1",
        port: int = 8766,
        token_ttl: float = 12 * 60 * 60,
        device_factory: Any = None,
    ) -> None:
        if not devices:
            raise ValueError("a pool needs at least one device")
        self.nodes: dict[str, BridgeServer] = {}
        self.roles: dict[str, str] = {}
        for entry in devices:
            serial = str(entry["serial"])
            device = (device_factory(serial) if device_factory else Device(target=serial))
            node = BridgeServer(
                device,
                str(entry["token"]),
                host="127.0.0.1",
                port=0,
                pair_code=str(entry.get("pair", "")),
                token_ttl=token_ttl,
                sessions_key=str(entry.get("sessions_key", "")),
                state_path=entry.get("state") or None,
            )
            node.start()
            self.nodes[serial] = node
            role = str(entry.get("role", "")).strip()
            if not role:
                role = self._device_role(device)
            if role:
                self.roles[role] = serial
        self.httpd = ThreadingHTTPServer((host, port), _PoolHandler)
        self.httpd.pool = self  # type: ignore[attr-defined]
        self.thread: threading.Thread | None = None

    @staticmethod
    def _device_role(device: Device) -> str:
        try:
            kind = device.hdc.shell("param get const.product.devicetype").strip()
        except Exception:  # noqa: BLE001 - a role is a convenience, not a must
            return ""
        if kind in ("phone", "tablet"):
            return "phone"
        if kind == "2in1":
            return "2in1"
        return kind

    @property
    def port(self) -> int:
        return int(self.httpd.server_address[1])

    def node_for(self, serial: str) -> BridgeServer | None:
        return self.nodes.get(serial)

    def phone_serial(self) -> str:
        serial = self.roles.get("phone", "")
        if serial:
            return serial
        return next(iter(self.nodes), "")

    def resolve(self, path: str, role: str) -> tuple[BridgeServer | None, str]:
        """Return (node, path) or (None, reason)."""
        if path.startswith("/d/"):
            rest = path[3:]
            serial, _, tail = rest.partition("/")
            node = self.nodes.get(serial)
            if node is None:
                return None, f"unknown device: {serial}"
            return node, "/" + tail
        wanted = role.strip()
        if wanted:
            if wanted in self.roles:
                return self.nodes[self.roles[wanted]], path
            if wanted in self.nodes:
                return self.nodes[wanted], path
            return None, f"unknown role: {wanted}"
        if path == "/sessions":
            return self.nodes[self.phone_serial()], path
        if len(self.nodes) == 1:
            return next(iter(self.nodes.values())), path
        return None, "say which device: X-Hopa-Role, or /d/<serial>/..."

    def authorized_any(self, presented: str) -> bool:
        """True when one of the devices accepts this token.

        Used for cross-reads: the phone may read the laptop's snapshot with the
        phone's own credential, never the laptop's token.
        """
        for node in self.nodes.values():
            if hmac.compare_digest(presented, node.sessions_key):
                return True
            if hmac.compare_digest(presented, node.token) and node.token_live():
                return True
        return False

    def start(self) -> None:
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()

    def stop(self) -> None:
        if self.thread is not None and self.thread.is_alive():
            self.httpd.shutdown()
        self.httpd.server_close()
        if self.thread is not None:
            self.thread.join(timeout=2)
        for node in self.nodes.values():
            node.stop()


class _PoolHandler(BaseHTTPRequestHandler):
    server_version = "hopa-bridge-pool/0.1"

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        import sys

        print(f"{self.command} {self.path}", file=sys.stderr, flush=True)

    @property
    def pool(self) -> BridgePool:
        return self.server.pool  # type: ignore[attr-defined]

    def _send(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _role(self) -> str:
        return self.headers.get("X-Hopa-Role", "")

    def _body(self) -> bytes:
        length = int(self.headers.get("Content-Length", "0") or 0)
        return self.rfile.read(length) if length else b""

    def _forward(self, path: str, role: str, body: bytes) -> None:
        node, target = self.pool.resolve(path, role)
        if node is None:
            self._send(400, {"error": target})
            return
        headers: dict[str, str] = {}
        for name in ("Authorization", "Content-Type"):
            value = self.headers.get(name)
            if value:
                headers[name] = value
        connection = http.client.HTTPConnection("127.0.0.1", node.port, timeout=120)
        try:
            connection.request(self.command, target, body=body, headers=headers)
            response = connection.getresponse()
            data = response.read()
        except OSError as exc:
            self._send(502, {"error": f"device server unreachable: {exc}"})
            return
        finally:
            connection.close()
        self.send_response(response.status)
        self.send_header("Content-Type", response.getheader("Content-Type") or "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _cross_sessions(self, read_role: str) -> None:
        node, target = self.pool.resolve("/sessions", read_role)
        if node is None:
            self._send(400, {"error": target})
            return
        header = self.headers.get("Authorization", "")
        presented = header[len("Bearer "):] if header.startswith("Bearer ") else ""
        if not self.pool.authorized_any(presented):
            self._send(401, {"error": "unauthorized"})
            return
        self._send(200, {
            "sessions": node.sessions,
            "updated": node.sessions_updated,
        })

    def do_GET(self) -> None:  # noqa: N802
        read_role = self.headers.get("X-Hopa-Read", "").strip()
        if read_role and self.path == "/sessions":
            self._cross_sessions(read_role)
            return
        if self.path == "/health":
            self._send(200, {
                "ok": True,
                "devices": [
                    {"serial": serial, "role": role}
                    for role, serial in sorted(self.pool.roles.items())
                ],
            })
            return
        self._forward(self.path, self._role(), b"")

    def do_POST(self) -> None:  # noqa: N802
        self._forward(self.path, self._role(), self._body())
