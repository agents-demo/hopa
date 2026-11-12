"""Put the bridge behind a public relay.

The bridge is useful because it owns ``hdc``, and ``hdc`` only works next to the
device. A phone on mobile data cannot reach a PC behind a home router, so the
PC dials *out* instead: this relay runs in the cloud, the PC keeps a long-poll
open, and the phone talks to the relay as if it were the bridge.

    phone --HTTPS--> relay (cloud) <--long-poll-- pc-agent cloud-link
                                                        |
                                                     hdc + device

Two consequences worth spelling out:

* The relay is a forwarder, not a second bridge. It authenticates the phone and
  hands the request to the linked PC verbatim, so the bridge keeps its own
  validation, rate limits, device lock and conversation store.
* The long-poll is also a keep-alive. Render's free tier spins a web service
  down after 15 minutes without inbound traffic; a poll every ``--poll-seconds``
  (25 by default) is inbound traffic, so a running PC keeps the relay awake.
  When the PC stops, the relay sleeps, which is the honest behaviour.

Endpoints on the relay::

    GET  /health          public: is a PC linked, and how stale is it?
    GET  /ui              public: the browser status page (same data as /health)
    POST /pair            six-digit code -> token pair
    POST /refresh          refresh token -> a fresh pair
    GET  /link/poll       PC only: long-poll for the next request
    POST /link/result     PC only: hand back the bridge's answer
    *                     everything else, forwarded to the linked PC
"""

from __future__ import annotations

import base64
import hmac
import json
import secrets
import threading
import time
import urllib.error
import urllib.request
from collections import deque
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlsplit

from .tunnel import TunnelRegistry
from .ws import WebSocketError, server_handshake

MAX_BODY_BYTES = 32 * 1024 * 1024
MAX_QUEUED = 200
PAIR_ATTEMPTS_PER_MINUTE = 5

# The browser view. It is deliberately self-contained: no CDN, no build step,
# no token. It only reads /health, so it shows the same numbers the machine
# endpoints report and cannot act on the relay.
_UI_PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark">
<title>HOPA Relay</title>
<style>
  :root {
    --bg: #0a0f1e;
    --panel: #131a2e;
    --panel-2: #0f1627;
    --line: #24304f;
    --text: #e8edf9;
    --muted: #94a1bf;
    --ok: #2fcc71;
    --warn: #f0b42f;
    --bad: #e05b5b;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    min-height: 100vh;
    padding: 32px 20px 56px;
    background:
      radial-gradient(1200px 600px at 15% -10%, #1b2748 0%, transparent 60%),
      radial-gradient(900px 500px at 100% 0%, #142035 0%, transparent 55%),
      var(--bg);
    color: var(--text);
    font: 15px/1.5 ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  main { width: min(860px, 100%); margin: 0 auto; }
  header { display: flex; flex-wrap: wrap; align-items: baseline; gap: 10px 14px; }
  h1 { margin: 0; font-size: 22px; letter-spacing: 0.2px; }
  h1 span { color: var(--muted); font-weight: 500; }
  #updated {
    margin-left: auto; color: var(--muted); font-size: 13px;
    font-variant-numeric: tabular-nums;
  }
  .chips { display: flex; flex-wrap: wrap; gap: 8px; margin: 18px 0 22px; }
  .chip {
    display: inline-flex; align-items: center; gap: 8px;
    padding: 7px 12px; border: 1px solid var(--line); border-radius: 999px;
    background: var(--panel-2); color: var(--muted); font-size: 13px;
  }
  .chip b { color: var(--text); font-weight: 600; font-variant-numeric: tabular-nums; }
  .devices { display: grid; gap: 14px; }
  .card {
    border: 1px solid var(--line); border-radius: 14px; background: var(--panel);
    padding: 18px 20px 8px; box-shadow: 0 12px 30px rgba(0, 0, 0, 0.22);
  }
  .card-head { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; }
  .card-head h2 { margin: 0; font-size: 17px; }
  .card-head code { color: var(--muted); font-size: 12px; }
  .badge {
    margin-left: auto; padding: 3px 10px; border-radius: 999px;
    font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.6px;
  }
  .badge.ok { color: #062; background: rgba(47, 204, 113, 0.18); }
  .badge.warn { color: var(--warn); background: rgba(240, 180, 47, 0.14); }
  .row {
    display: flex; align-items: center; gap: 10px;
    padding: 11px 0; border-top: 1px solid var(--line); font-size: 14px;
  }
  .row .name { color: var(--muted); min-width: 132px; }
  .row .state { font-weight: 600; }
  .row .age {
    margin-left: auto; color: var(--muted);
    font-variant-numeric: tabular-nums; font-size: 13px;
  }
  .led { width: 9px; height: 9px; border-radius: 50%; background: var(--bad); flex: none; }
  .led.on { background: var(--ok); box-shadow: 0 0 0 4px rgba(47, 204, 113, 0.14); }
  .empty {
    border: 1px dashed var(--line); border-radius: 14px; padding: 34px 20px;
    text-align: center; color: var(--muted);
  }
  footer { margin-top: 26px; color: var(--muted); font-size: 12px; text-align: center; }
  footer a { color: #8aa4d6; }
</style>
</head>
<body>
<main>
  <header>
    <h1>HOPA <span>relay</span></h1>
    <div id="updated">loading…</div>
  </header>

  <div class="chips">
    <span class="chip">
      <span class="led" id="link-led"></span>PC link <b id="link-state">…</b>
    </span>
    <span class="chip">Queued <b id="queued">–</b></span>
    <span class="chip">Waiting <b id="waiting">–</b></span>
  </div>

  <section class="devices" id="devices"></section>

  <footer>Refreshes every 3 s · <a href="/health">/health</a></footer>
</main>
<script>
(function () {
  var LABELS = { default: "Phone", laptop: "Laptop" };
  var POLL_MS = 3000;

  function label(session) {
    if (LABELS[session]) return LABELS[session];
    return session.charAt(0).toUpperCase() + session.slice(1);
  }

  function human(seconds) {
    if (seconds === null || seconds === undefined) return "";
    var s = Math.max(0, Math.round(seconds));
    if (s < 60) return s + "s";
    var m = Math.floor(s / 60);
    if (m < 60) return m + "m";
    var h = Math.floor(m / 60);
    if (h < 24) return h + "h " + (m % 60) + "m";
    return Math.floor(h / 24) + "d " + (h % 24) + "h";
  }

  function row(name, on, age) {
    var row = document.createElement("div");
    row.className = "row";

    var led = document.createElement("span");
    led.className = "led" + (on ? " on" : "");

    var nameEl = document.createElement("span");
    nameEl.className = "name";
    nameEl.textContent = name;

    var state = document.createElement("span");
    state.className = "state";
    state.textContent = on ? "connected" : "not connected";

    row.appendChild(led);
    row.appendChild(nameEl);
    row.appendChild(state);

    if (on && age !== null && age !== undefined) {
      var ageEl = document.createElement("span");
      ageEl.className = "age";
      ageEl.textContent = "for " + human(age);
      row.appendChild(ageEl);
    }
    return row;
  }

  function card(entry) {
    var ready = entry.host && entry.phone;
    var box = document.createElement("article");
    box.className = "card";

    var head = document.createElement("div");
    head.className = "card-head";

    var title = document.createElement("h2");
    title.textContent = label(entry.session);

    var code = document.createElement("code");
    code.textContent = entry.session;

    var badge = document.createElement("span");
    badge.className = "badge " + (ready ? "ok" : "warn");
    badge.textContent = ready ? "ready" : (entry.host || entry.phone ? "partial" : "idle");

    head.appendChild(title);
    head.appendChild(code);
    head.appendChild(badge);

    box.appendChild(head);
    box.appendChild(row("PC tunnel", entry.host, entry.host_age_seconds));
    box.appendChild(row(label(entry.session) + " app", entry.phone, entry.phone_age_seconds));
    return box;
  }

  function render(data) {
    document.getElementById("queued").textContent = data.queued;
    document.getElementById("waiting").textContent = data.waiting;

    document.getElementById("link-state").textContent = data.linked ? "connected" : "offline";
    document.getElementById("link-led").className = "led" + (data.linked ? " on" : "");

    var host = document.getElementById("devices");
    host.textContent = "";

    var links = (data.tunnel && data.tunnel.links) || [];
    links.sort(function (a, b) {
      if (a.session === "default") return -1;
      if (b.session === "default") return 1;
      return a.session < b.session ? -1 : 1;
    });

    if (!links.length) {
      var empty = document.createElement("div");
      empty.className = "empty";
      empty.textContent = "No device session is connected.";
      host.appendChild(empty);
    } else {
      links.forEach(function (entry) { host.appendChild(card(entry)); });
    }

    document.getElementById("updated").textContent = "updated " + new Date().toLocaleTimeString();
  }

  function fail() {
    document.getElementById("updated").textContent = "relay unreachable — retrying";
    document.getElementById("link-led").className = "led";
    document.getElementById("link-state").textContent = "unknown";
  }

  function tick() {
    fetch("/health", { headers: { Accept: "application/json" }, cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error(String(r.status)); return r.json(); })
      .then(render)
      .catch(fail)
      .then(function () { setTimeout(tick, POLL_MS); });
  }

  tick();
})();
</script>
</body>
</html>
"""


class RelayError(Exception):
    """A request the relay cannot serve."""


class RelayBusy(RelayError):
    """Too many requests are already waiting for the PC."""


class RelayTimeout(RelayError):
    """The PC did not answer in time."""


@dataclass
class Job:
    """One phone request waiting for the PC to execute it."""

    id: str
    method: str
    path: str
    content_type: str
    body: bytes
    role: str = ""


@dataclass
class Pending:
    """The slot a job's answer lands in."""

    event: threading.Event = field(default_factory=threading.Event)
    status: int = 0
    content_type: str = ""
    body: bytes = b""
    done: bool = False


class Relay:
    """Queue phone requests and match them with the one linked PC."""

    def __init__(
        self,
        token: str,
        link_token: str,
        *,
        pair_code: str = "",
        token_ttl: float = 12 * 60 * 60,
        wait_seconds: float = 45.0,
        poll_seconds: float = 25.0,
    ) -> None:
        if not token:
            raise ValueError("a phone token is required")
        if not link_token:
            raise ValueError("a link token is required")
        self.token = token
        self.link_token = link_token
        self.pair_code = pair_code
        self.token_ttl = token_ttl
        self.wait_seconds = wait_seconds
        self.poll_seconds = min(max(poll_seconds, 1.0), 55.0)
        self.refresh_token = secrets.token_urlsafe(32)
        self._cond = threading.Condition()
        self._jobs: deque[Job] = deque()
        self._pending: dict[str, Pending] = {}
        self._last_link = 0.0
        self._pollers = 0
        self._pairs: deque[float] = deque(maxlen=20)
        self._refreshes: deque[float] = deque(maxlen=20)
        self.tunnels = TunnelRegistry()

    # -- auth ---------------------------------------------------------------

    def phone_authorized(self, presented: str) -> bool:
        return bool(presented) and hmac.compare_digest(presented, self.token)

    def link_authorized(self, presented: str) -> bool:
        return bool(presented) and hmac.compare_digest(presented, self.link_token)

    def refresh_authorized(self, presented: str) -> bool:
        return bool(presented) and hmac.compare_digest(presented, self.refresh_token)

    def issue_tokens(self) -> dict[str, Any]:
        return {
            "token": self.token,
            "refresh": self.refresh_token,
            "expires_in": int(self.token_ttl),
        }

    @staticmethod
    def _rate_ok(attempts: deque[float]) -> bool:
        now = time.monotonic()
        while attempts and now - attempts[0] > 60.0:
            attempts.popleft()
        if len(attempts) >= PAIR_ATTEMPTS_PER_MINUTE:
            return False
        attempts.append(now)
        return True

    def pair_allowed(self) -> bool:
        return self._rate_ok(self._pairs)

    def refresh_allowed(self) -> bool:
        return self._rate_ok(self._refreshes)

    # -- link state ---------------------------------------------------------

    def linked_age(self) -> float:
        """Seconds since the PC last spoke to the relay (``inf`` if never)."""
        with self._cond:
            if self._last_link == 0.0:
                return float("inf")
            return max(0.0, time.time() - self._last_link)

    def counts(self) -> tuple[int, int]:
        with self._cond:
            return len(self._jobs), len(self._pending)

    def pollers(self) -> int:
        """How many long-polls are in flight (normally one)."""
        with self._cond:
            return self._pollers

    # -- the queue ----------------------------------------------------------

    def poll(self, timeout: float | None = None) -> Job | None:
        """Wait for the next job. This call is the keep-alive."""
        deadline = time.monotonic() + (self.poll_seconds if timeout is None else timeout)
        with self._cond:
            self._pollers += 1
            try:
                self._last_link = time.time()
                while not self._jobs:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        return None
                    self._cond.wait(remaining)
                    self._last_link = time.time()
                return self._jobs.popleft()
            finally:
                self._pollers -= 1

    def enqueue(
        self, method: str, path: str, content_type: str, body: bytes, role: str = ""
    ) -> Pending:
        if len(body) > MAX_BODY_BYTES:
            raise RelayBusy("request body is too large")
        job = Job(
            id=secrets.token_hex(12),
            method=method,
            path=path,
            content_type=content_type,
            body=body,
            role=role[:32],
        )
        pending = Pending()
        with self._cond:
            if len(self._jobs) >= MAX_QUEUED:
                raise RelayBusy("the PC is behind; retry shortly")
            if self._pollers == 0 and (
                self._last_link == 0.0 or time.time() - self._last_link > 120
            ):
                raise RelayTimeout("no PC is linked to this relay")
            self._pending[job.id] = pending
            self._jobs.append(job)
            self._cond.notify()
        if not pending.event.wait(self.wait_seconds):
            with self._cond:
                self._pending.pop(job.id, None)
            raise RelayTimeout("the PC did not answer in time")
        with self._cond:
            self._pending.pop(job.id, None)
        return pending

    def resolve(self, job_id: str, status: int, content_type: str, body: bytes) -> bool:
        with self._cond:
            pending = self._pending.get(job_id)
        if pending is None:
            return False
        pending.status = status
        pending.content_type = content_type
        pending.body = body
        pending.done = True
        pending.event.set()
        return True


class _Handler(BaseHTTPRequestHandler):
    server_version = "hopa-relay/0.1"
    # 101 Switching Protocols is an HTTP/1.1 response. Without this the
    # BaseHTTPRequestHandler writes an HTTP/1.0 status line and some clients
    # refuse the upgrade.
    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        # Path only: never log tokens or bodies.
        print(f"{self.command} {self.path.split('?')[0]} {args[0] if args else ''}", flush=True)

    @property
    def relay(self) -> Relay:
        return self.server.relay  # type: ignore[attr-defined]

    # -- plumbing -----------------------------------------------------------

    def _presented(self) -> str:
        header = self.headers.get("Authorization", "")
        prefix = "Bearer "
        return header[len(prefix) :] if header.startswith(prefix) else ""

    def _read_body(self) -> bytes:
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length <= 0:
            return b""
        if length > MAX_BODY_BYTES:
            raise RelayBusy("request body is too large")
        return self.rfile.read(length)

    def _read_json(self) -> dict[str, Any]:
        raw = self._read_body()
        try:
            data = json.loads(raw.decode("utf-8") or "{}")
        except (UnicodeDecodeError, ValueError) as exc:
            raise RelayError("body is not JSON") from exc
        if not isinstance(data, dict):
            raise RelayError("body must be an object")
        return data

    def _send(self, status: int, body: bytes, content_type: str = "application/json") -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        self._send(status, json.dumps(payload).encode("utf-8"))

    def _send_html(self, html: str) -> None:
        body = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    # -- the binary tunnel --------------------------------------------------

    def _handle_tunnel(self) -> None:
        # Every tunnel attempt owns the connection: a rejected upgrade must not
        # fall back to HTTP keep-alive, or the handler blocks reading a request
        # that will never come.
        self.close_connection = True
        parts = urlsplit(self.path)
        query = parse_qs(parts.query)
        role = (query.get("role", ["host"])[0] or "host").lower()
        if role not in ("host", "phone"):
            self._send_json(400, {"error": "role must be host or phone"})
            return
        session = (query.get("session", ["default"])[0] or "default").strip()
        if (
            not session
            or len(session) > 64
            or not all(char.isalnum() or char in "-_" for char in session)
        ):
            self._send_json(400, {"error": "bad session id"})
            return
        # A browser cannot set an Authorization header on a WebSocket, so the
        # token may also arrive in the query. It is never logged: log_message
        # strips the query string.
        presented = self._presented() or query.get("token", [""])[0]
        allowed = (
            self.relay.link_authorized(presented)
            if role == "host"
            else self.relay.phone_authorized(presented)
        )
        if not allowed:
            self._send_json(401, {"error": "unauthorized"})
            return
        if self.headers.get("Upgrade", "").lower() != "websocket":
            self._send_json(426, {"error": "upgrade required"})
            return
        try:
            ws = server_handshake(self)
        except WebSocketError as exc:
            self._send_json(400, {"error": str(exc)})
            return
        try:
            self.relay.tunnels.serve(role, session, ws)
        finally:
            ws.close()

    # -- routes -------------------------------------------------------------

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/tunnel":
            self._handle_tunnel()
            return
        if self.path.startswith("/tunnel?"):
            self._handle_tunnel()
            return
        if self.path == "/":
            # A browser wants the status page; scripts and uptime probes want
            # JSON. Content negotiation keeps both working on the bare URL.
            if "text/html" in self.headers.get("Accept", "").lower():
                self._send_html(_UI_PAGE)
                return
            age = self.relay.linked_age()
            self._send_json(
                200,
                {
                    "ok": True,
                    "role": "relay",
                    "linked": age < 60.0,
                    "health": "/health",
                    "ui": "/ui",
                },
            )
            return
        if self.path.split("?")[0] in ("/ui", "/ui/"):
            self._send_html(_UI_PAGE)
            return
        if self.path == "/favicon.ico":
            self._send(204, b"")
            return
        if self.path == "/health":
            age = self.relay.linked_age()
            queued, waiting = self.relay.counts()
            self._send_json(
                200,
                {
                    "ok": True,
                    "role": "relay",
                    "linked": age < 60.0,
                    "link_age_seconds": None if age == float("inf") else round(age, 1),
                    "queued": queued,
                    "waiting": waiting,
                    "tunnel": self.relay.tunnels.status(),
                },
            )
            return
        if self.path.startswith("/link/"):
            self._handle_link_get()
            return
        self._forward()

    def do_HEAD(self) -> None:  # noqa: N802
        # Browsers and uptime probes ask for / before anything else.
        if self.path.split("?")[0] in ("/", "/health", "/ui", "/ui/"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        self.send_response(404)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/pair":
            self._handle_pair()
            return
        if self.path == "/refresh":
            self._handle_refresh()
            return
        if self.path == "/link/result":
            self._handle_link_result()
            return
        if self.path.startswith("/link/"):
            self._send_json(404, {"error": "not found"})
            return
        self._forward()

    def do_PUT(self) -> None:  # noqa: N802
        self._forward()

    def do_DELETE(self) -> None:  # noqa: N802
        self._forward()

    # -- pairing ------------------------------------------------------------

    def _handle_pair(self) -> None:
        if not self.relay.pair_code:
            self._send_json(403, {"error": "pairing is disabled"})
            return
        if not self.relay.pair_allowed():
            self._send_json(429, {"error": "too many attempts, wait a minute"})
            return
        try:
            data = self._read_json()
        except RelayError as exc:
            self._send_json(400, {"error": str(exc)})
            return
        code = str(data.get("code", "")).strip()
        if hmac.compare_digest(code, self.relay.pair_code):
            self._send_json(200, self.relay.issue_tokens())
        else:
            self._send_json(401, {"error": "wrong code"})

    def _handle_refresh(self) -> None:
        if not self.relay.refresh_allowed():
            self._send_json(429, {"error": "too many attempts, wait a minute"})
            return
        try:
            data = self._read_json()
        except RelayError as exc:
            self._send_json(400, {"error": str(exc)})
            return
        refresh = str(data.get("refresh", "")).strip()
        if not self.relay.refresh_authorized(refresh):
            self._send_json(401, {"error": "refresh rejected"})
            return
        self._send_json(200, self.relay.issue_tokens())

    # -- the PC side --------------------------------------------------------

    def _handle_link_get(self) -> None:
        if self.path != "/link/poll":
            self._send_json(404, {"error": "not found"})
            return
        if not self.relay.link_authorized(self._presented()):
            self._send_json(401, {"error": "unauthorized"})
            return
        job = self.relay.poll()
        if job is None:
            self._send(204, b"")
            return
        self._send_json(
            200,
            {
                "id": job.id,
                "method": job.method,
                "path": job.path,
                "content_type": job.content_type,
                "body": base64.b64encode(job.body).decode("ascii"),
                "role": job.role,
            },
        )

    def _handle_link_result(self) -> None:
        if not self.relay.link_authorized(self._presented()):
            self._send_json(401, {"error": "unauthorized"})
            return
        try:
            data = self._read_json()
            job_id = str(data["id"])
            body = base64.b64decode(str(data.get("body", "")), validate=False)
        except (KeyError, ValueError, RelayError) as exc:
            self._send_json(400, {"error": f"bad result: {exc}"})
            return
        accepted = self.relay.resolve(
            job_id,
            int(data.get("status", 502)),
            str(data.get("content_type", "application/json")),
            body,
        )
        self._send_json(200, {"ok": accepted})

    # -- the phone side -----------------------------------------------------

    def _forward(self) -> None:
        if not self.relay.phone_authorized(self._presented()):
            try:
                self._read_body()
            except RelayBusy:
                pass
            self._send_json(401, {"error": "unauthorized"})
            return
        try:
            body = self._read_body()
            pending = self.relay.enqueue(
                self.command,
                self.path,
                self.headers.get("Content-Type", "application/json"),
                body,
                self.headers.get("X-Hopa-Role", ""),
            )
        except RelayBusy as exc:
            self._send_json(503, {"error": str(exc)})
            return
        except RelayTimeout as exc:
            self._send_json(504, {"error": str(exc)})
            return
        self._send(
            pending.status or 502,
            pending.body,
            pending.content_type or "application/json",
        )


class RelayServer:
    """The HTTP listener Render runs."""

    def __init__(self, relay: Relay, host: str = "127.0.0.1", port: int = 8790) -> None:
        self.relay = relay
        self.httpd = ThreadingHTTPServer((host, port), _Handler)
        self.httpd.daemon_threads = True
        self.httpd.relay = relay  # type: ignore[attr-defined]

    @property
    def port(self) -> int:
        return int(self.httpd.server_address[1])

    def start(self) -> None:
        thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        thread.start()

    def serve_forever(self) -> None:
        self.httpd.serve_forever()

    def stop(self) -> None:
        self.httpd.shutdown()
        self.httpd.server_close()


class LinkClient:
    """The PC half: poll the relay and replay requests on the local bridge."""

    def __init__(
        self,
        relay_url: str,
        link_token: str,
        local_url: str,
        *,
        local_token: str = "",
        poll_seconds: float = 25.0,
        local_timeout: float = 120.0,
        retry_seconds: float = 5.0,
    ) -> None:
        self.relay_url = relay_url.rstrip("/")
        self.link_token = link_token
        self.local_url = local_url.rstrip("/")
        self.local_token = local_token
        self.poll_seconds = min(max(poll_seconds, 1.0), 55.0)
        self.local_timeout = local_timeout
        self.retry_seconds = retry_seconds
        self._stop = threading.Event()

    def stop(self) -> None:
        self._stop.set()

    def _request(
        self,
        method: str,
        url: str,
        *,
        token: str,
        body: bytes | None = None,
        content_type: str = "",
        extra_headers: dict[str, str] | None = None,
        timeout: float = 30.0,
    ) -> tuple[int, str, bytes]:
        headers = {"Authorization": f"Bearer {token}"} if token else {}
        if content_type:
            headers["Content-Type"] = content_type
        if extra_headers:
            headers.update(extra_headers)
        request = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return (
                    response.status,
                    response.headers.get("Content-Type", "application/json"),
                    response.read(),
                )
        except urllib.error.HTTPError as exc:
            return exc.code, exc.headers.get("Content-Type", "application/json"), exc.read()

    def poll(self) -> dict[str, Any] | None:
        status, _ctype, body = self._request(
            "GET",
            f"{self.relay_url}/link/poll",
            token=self.link_token,
            timeout=self.poll_seconds + 15.0,
        )
        if status == 204:
            return None
        if status != 200:
            raise RelayError(f"poll failed: {status} {body[:200]!r}")
        data = json.loads(body.decode("utf-8"))
        if not isinstance(data, dict):
            raise RelayError("poll returned a non-object")
        return data

    def forward(self, job: dict[str, Any]) -> tuple[int, str, bytes]:
        method = str(job.get("method", "POST")).upper()
        path = str(job.get("path", "/"))
        if not path.startswith("/") or path.startswith("//"):
            raise RelayError(f"refusing path {path!r}")
        body = base64.b64decode(str(job.get("body", "")), validate=False)
        token = self.local_token or ""
        content_type = str(job.get("content_type", "")) or "application/json"
        role = str(job.get("role", "")).strip()[:32]
        return self._request(
            method,
            f"{self.local_url}{path}",
            token=token,
            body=body if method in ("POST", "PUT", "DELETE") else None,
            content_type=content_type,
            extra_headers={"X-Hopa-Role": role} if role else None,
            timeout=self.local_timeout,
        )

    def report(self, job_id: str, status: int, content_type: str, body: bytes) -> None:
        payload = json.dumps(
            {
                "id": job_id,
                "status": status,
                "content_type": content_type,
                "body": base64.b64encode(body).decode("ascii"),
            }
        ).encode("utf-8")
        code, _ctype, response = self._request(
            "POST",
            f"{self.relay_url}/link/result",
            token=self.link_token,
            body=payload,
            content_type="application/json",
            timeout=30.0,
        )
        if code != 200:
            raise RelayError(f"result rejected: {code} {response[:200]!r}")

    def run_once(self) -> bool:
        """One poll. Returns False when the relay held the poll open (idle)."""
        job = self.poll()
        if job is None:
            return False
        job_id = str(job.get("id", ""))
        try:
            status, content_type, body = self.forward(job)
        except Exception as exc:  # noqa: BLE001 - the bridge is the source of truth
            status, content_type = 502, "application/json"
            body = json.dumps({"error": f"local bridge failed: {exc}"}).encode("utf-8")
        self.report(job_id, status, content_type, body)
        return True

    def run_forever(self) -> None:  # pragma: no cover - exercised on the PC
        backoff = self.retry_seconds
        print(f"cloud-link: {self.relay_url} -> {self.local_url}", flush=True)
        while not self._stop.is_set():
            started = time.monotonic()
            try:
                busy = self.run_once()
                backoff = self.retry_seconds
                if not busy and time.monotonic() - started < 1.0:
                    # A relay that does not hold the poll must not become a hot loop.
                    time.sleep(1.0)
            except Exception as exc:  # noqa: BLE001 - keep the link alive
                print(f"cloud-link: {exc}; retrying in {backoff:.0f}s", flush=True)
                self._stop.wait(backoff)
                backoff = min(backoff * 2, 20.0)


def serve_relay(args: Any) -> int:
    """CLI entry point: run the cloud half."""
    ttl = max(0.05, float(getattr(args, "token_ttl_hours", 12.0))) * 3600
    relay = Relay(
        str(getattr(args, "token", "")),
        str(getattr(args, "link_token", "")),
        pair_code=str(getattr(args, "pair_code", "")),
        token_ttl=ttl,
        wait_seconds=max(1.0, float(getattr(args, "wait_seconds", 45.0))),
        poll_seconds=float(getattr(args, "poll_seconds", 25.0)),
    )
    server = RelayServer(relay, host=str(getattr(args, "host", "0.0.0.0")), port=int(args.port))
    print(f"relay listening on http://{args.host}:{server.port}", flush=True)
    print(f"link keep-alive: every {relay.poll_seconds:g}s", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.stop()
    return 0


def serve_link(args: Any) -> int:
    """CLI entry point: run the PC half."""
    relay_url = str(getattr(args, "relay", ""))
    if not relay_url:
        raise RelayError("--relay is required")
    link = LinkClient(
        relay_url,
        str(getattr(args, "link_token", "")),
        str(getattr(args, "local", "http://127.0.0.1:8765")),
        local_token=str(getattr(args, "local_token", "")),
        poll_seconds=float(getattr(args, "poll_seconds", 25.0)),
        local_timeout=float(getattr(args, "local_timeout", 120.0)),
    )
    link.run_forever()
    return 0
