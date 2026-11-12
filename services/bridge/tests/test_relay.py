"""The cloud relay and the PC link, without a phone or a device."""

from __future__ import annotations

import json
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

from hopa_bridge.relay import LinkClient, Relay, RelayError, RelayServer, RelayTimeout

PHONE = "phone-token"
LINK = "link-token"
CODE = "246810"


def _wait_for_poller(relay: Relay, timeout: float = 2.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if relay.pollers() > 0:
            return
        time.sleep(0.01)
    raise AssertionError("the link never started polling")


class _LocalBridge(BaseHTTPRequestHandler):
    """A stand-in for the real bridge on the PC."""

    seen: list[dict[str, str]] = []

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        return

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", "0") or 0)
        body = self.rfile.read(length) if length else b""
        _LocalBridge.seen.append(
            {
                "path": self.path,
                "auth": self.headers.get("Authorization", ""),
                "role": self.headers.get("X-Hopa-Role", ""),
                "body": body.decode("utf-8"),
            }
        )
        payload = json.dumps({"local": True, "path": self.path}).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


@pytest.fixture()
def relay_server():
    relay = Relay(PHONE, LINK, pair_code=CODE, wait_seconds=2.0, poll_seconds=1.0)
    server = RelayServer(relay, port=0)
    server.start()
    yield relay, server
    server.stop()


@pytest.fixture()
def local_bridge():
    _LocalBridge.seen = []
    server = ThreadingHTTPServer(("127.0.0.1", 0), _LocalBridge)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield f"http://127.0.0.1:{server.server_address[1]}"
    server.shutdown()
    server.server_close()


def _call(
    url: str,
    *,
    method: str = "GET",
    token: str = "",
    role: str = "",
    payload: dict | None = None,
) -> tuple[int, dict]:
    headers = {}
    body = None
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if role:
        headers["X-Hopa-Role"] = role
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode("utf-8") or "{}")


def test_health_reports_the_link(relay_server):
    _relay, server = relay_server
    base = f"http://127.0.0.1:{server.port}"

    status, health = _call(f"{base}/health")
    assert status == 200
    assert health["linked"] is False
    assert health["link_age_seconds"] is None

    _relay.poll(timeout=0.05)
    status, health = _call(f"{base}/health")
    assert health["linked"] is True
    assert health["link_age_seconds"] is not None


def test_root_and_head_are_public(relay_server):
    _relay, server = relay_server
    base = f"http://127.0.0.1:{server.port}"

    status, body = _call(f"{base}/")
    assert status == 200
    assert body["role"] == "relay"
    assert body["health"] == "/health"
    assert body["ui"] == "/ui"

    for path in ("/", "/health", "/ui"):
        request = urllib.request.Request(f"{base}{path}", method="HEAD")
        with urllib.request.urlopen(request, timeout=5) as response:
            assert response.status == 200


def _get_text(base: str, path: str, accept: str) -> tuple[int, str, str]:
    request = urllib.request.Request(f"{base}{path}", headers={"Accept": accept})
    with urllib.request.urlopen(request, timeout=5) as response:
        return response.status, response.headers.get("Content-Type", ""), response.read().decode()


def test_the_status_page_is_html_without_a_token(relay_server):
    _relay, server = relay_server
    base = f"http://127.0.0.1:{server.port}"

    status, content_type, body = _get_text(base, "/ui", "text/html")

    assert status == 200
    assert content_type.startswith("text/html")
    assert "<title>HOPA Relay</title>" in body
    # The page reads /health; it must not embed credentials.
    assert "/health" in body
    assert CODE not in body
    assert PHONE not in body
    assert LINK not in body


def test_a_browser_on_the_root_gets_the_status_page(relay_server):
    _relay, server = relay_server
    base = f"http://127.0.0.1:{server.port}"

    status, content_type, _body = _get_text(base, "/", "text/html,application/xhtml+xml")
    assert status == 200
    assert content_type.startswith("text/html")

    status, content_type, body = _get_text(base, "/", "application/json")
    assert status == 200
    assert content_type.startswith("application/json")
    assert json.loads(body)["role"] == "relay"


def test_pair_and_refresh(relay_server):
    relay, server = relay_server
    base = f"http://127.0.0.1:{server.port}"

    status, tokens = _call(f"{base}/pair", method="POST", payload={"code": CODE})
    assert status == 200
    assert tokens["token"] == PHONE
    assert tokens["refresh"] == relay.refresh_token
    assert tokens["expires_in"] > 0

    status, tokens = _call(
        f"{base}/refresh", method="POST", payload={"refresh": relay.refresh_token}
    )
    assert status == 200
    assert tokens["token"] == PHONE

    status, _ = _call(f"{base}/pair", method="POST", payload={"code": "000000"})
    assert status == 401


def test_forward_needs_the_phone_token(relay_server):
    _relay, server = relay_server
    base = f"http://127.0.0.1:{server.port}"
    status, body = _call(f"{base}/foreground", method="POST", token="wrong", payload={})
    assert status == 401
    assert body["error"] == "unauthorized"


def test_forward_times_out_without_a_pc(relay_server):
    relay, server = relay_server
    relay.wait_seconds = 0.2
    base = f"http://127.0.0.1:{server.port}"
    # A fresh relay has never seen a poll, so it fails fast.
    status, body = _call(f"{base}/foreground", method="POST", token=PHONE, payload={})
    assert status == 504
    assert "PC" in body["error"]


def test_enqueue_without_link_is_immediate():
    relay = Relay(PHONE, LINK)
    with pytest.raises(RelayTimeout):
        relay.enqueue("POST", "/foreground", "application/json", b"{}")


def test_link_forwards_and_reports(relay_server, local_bridge):
    relay, server = relay_server
    base = f"http://127.0.0.1:{server.port}"
    link = LinkClient(
        base,
        LINK,
        local_bridge,
        local_token="local-secret",
        poll_seconds=2.0,
        local_timeout=5.0,
    )

    worker = threading.Thread(target=link.run_once, daemon=True)
    worker.start()
    _wait_for_poller(relay)

    status, body = _call(f"{base}/foreground", method="POST", token=PHONE, role="2in1", payload={})
    worker.join(timeout=5)

    assert status == 200
    assert body == {"local": True, "path": "/foreground"}
    assert _LocalBridge.seen[-1]["auth"] == "Bearer local-secret"
    assert _LocalBridge.seen[-1]["role"] == "2in1"
    assert _LocalBridge.seen[-1]["body"] == "{}"


def test_link_logs_in_with_the_link_token(relay_server):
    _relay, server = relay_server
    base = f"http://127.0.0.1:{server.port}"
    link = LinkClient(base, "wrong", "http://127.0.0.1:9", poll_seconds=1.0)
    with pytest.raises(RelayError):
        link.poll()
