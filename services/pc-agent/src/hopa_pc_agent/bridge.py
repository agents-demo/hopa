"""HTTP bridge for PC-tethered control.

The phone app can drive other apps through this server, which uses ``hdc`` and
``uitest`` on the PC. It is the M4 fallback when the accessibility ACL cannot be
enabled. Every request needs a bearer token; the default bind is 127.0.0.1.

Endpoints (JSON):
    GET  /health
    POST /observe              -> {"text": str, "nodes": [...], "width": int, "height": int}
    POST /foreground           -> {"bundle": str}
    POST /tap                  {"x": int, "y": int}
    POST /type                 {"text": str, "x": int?, "y": int?}
    POST /launch               {"bundle": str, "ability": str?} -> {"ok", "foreground"}
    POST /key                  {"name": str}
    POST /swipe                {"from_x", "from_y", "to_x", "to_y", "velocity"?}
    POST /screenshot           -> {"mime": "image/jpeg", "bytes": int, "image": "base64"}
    POST /transcribe           {"audio": base64 WAV} -> {"text": str}
    POST /speak                {"text": str} -> {"mime": "audio/wav", "audio": base64}
    POST /pair                 {"code": str} -> {"token", "refresh", "expires_in"}
    POST /refresh              {"refresh": str} -> {"token", "refresh", "expires_in"}
    GET  /sessions             -> {"sessions": [...], "updated": unix}
    POST /sessions             {"sessions": [...]} -> {"ok", "count"}

Access tokens expire (12 h by default) and every pair or refresh rotates both
tokens, so a leaked token stops working once the phone refreshes.
"""

from __future__ import annotations

import base64
import hmac
import json
import os
import secrets
import subprocess
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


# A session snapshot is a convenience, not a database: cap it hard.
SESSIONS_LIMIT_BYTES = 512 * 1024


def _retry(fn: Any, *args: Any) -> Any:
    """Run a device call twice: one stalled hdc call must not fail a whole turn."""
    try:
        return fn(*args)
    except Exception:  # noqa: BLE001 - retried once, then surfaced
        time.sleep(0.4)
        return fn(*args)


def _position_hint(bounds: list[int], width: int, height: int) -> str:
    """Describe an unlabeled clickable node so the model can aim at it.

    Icon-only buttons (Weibo's orange +, toolbars) expose no text, description
    or id. Without a hint they are indistinguishable refs, so the agent guesses.
    The centre coordinates are included so a known hit area ("the + is near
    x=1210, y=200") can be matched exactly.
    """
    if width <= 0 or height <= 0 or len(bounds) != 4:
        return "unlabeled button"
    cx = (bounds[0] + bounds[2]) // 2
    cy = (bounds[1] + bounds[3]) // 2
    horizontal = "left" if cx < width * 0.33 else ("right" if cx > width * 0.66 else "centre")
    vertical = "top" if cy < height * 0.15 else ("bottom" if cy > height * 0.85 else "middle")
    corner = ""
    if vertical == "top" and horizontal in ("left", "right"):
        corner = f", {horizontal}-most corner"
    return f"unlabeled icon button at ({cx},{cy}) - {horizontal} {vertical}{corner}"


def _node_payload(node: Any, ref: str, width: int = 0, height: int = 0) -> dict[str, Any]:
    bounds: list[int] = list(node.bounds) if node.bounds else []
    description: str = node.description
    if not description and not node.text and node.clickable and bounds:
        description = _position_hint(bounds, width, height)
    return {
        "ref": ref,
        "text": node.text,
        "description": description,
        "id": node.id,
        "type": node.type,
        "bounds": bounds,
        "clickable": bool(node.clickable),
    }


def _observe(device: Device) -> dict[str, Any]:
    layout = device.dump_layout()
    width = 0
    height = 0
    for node in layout.walk():
        if node.bounds:
            width = max(width, node.bounds[2])
            height = max(height, node.bounds[3])

    nodes: list[dict[str, Any]] = []
    refs: dict[str, Any] = {}
    index = 0
    for node in layout.walk():
        if not (node.text or node.description or node.clickable):
            continue
        index += 1
        ref = f"e{index}"
        refs[ref] = node
        nodes.append(_node_payload(node, ref, width, height))
    return {
        "text": "\n".join(layout.texts()),
        "nodes": nodes,
        "width": width,
        "height": height,
        "refs": refs,
    }


def _wait_for_foreground(device: Device, bundle: str, timeout: float = 6.0) -> str:
    """Poll the foreground bundle after a launch; '' when it cannot be confirmed."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            if device.foreground() == bundle:
                return bundle
        except Exception:  # noqa: BLE001 - a slow hdc is not a launch failure
            pass
        time.sleep(0.5)
    return ""


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


# No Speech Kit ships with this SDK, so voice borrows the PC's speak engine.
# Both directions are WAV: the phone records 16 kHz mono PCM and plays the
# reply back through its own speaker.
_SPEECH_PS1 = r"""
param(
  [Parameter(Mandatory=$true)][ValidateSet('transcribe','speak','voices')][string]$Mode,
  [string]$Path = '',
  [string]$Text = '',
  [string]$Out = '',
  [string]$Voice = '',
  [string]$Rate = ''
)
Add-Type -AssemblyName System.Speech
if ($Mode -eq 'transcribe') {
  $engine = New-Object System.Speech.Recognition.SpeechRecognitionEngine
  $engine.LoadGrammar((New-Object System.Speech.Recognition.DictationGrammar))
  $engine.SetInputToWaveFile($Path)
  $result = $null
  try { $result = $engine.Recognize() } catch { $result = $null }
  $engine.Dispose()
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  if ($null -ne $result) { Write-Output $result.Text }
} elseif ($Mode -eq 'voices') {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
  foreach ($v in $synth.GetInstalledVoices()) {
    if ($v.Enabled) { Write-Output $v.VoiceInfo.Name }
  }
  $synth.Dispose()
} else {
  $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
  if ($Rate -ne '') { $synth.Rate = [int]$Rate } else { $synth.Rate = 0 }
  if ($Voice -ne '') {
    try { $synth.SelectVoice($Voice) } catch { }
  }
  $synth.SetOutputToWaveFile($Out)
  $synth.Speak($Text)
  $synth.Dispose()
}
"""

_speech_script: Path | None = None


def _powershell(script: Path, args: list[str], timeout: float = 30.0) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
            *args,
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def _speech_script_path() -> Path:
    global _speech_script
    if _speech_script is None or not _speech_script.exists():
        handle = tempfile.NamedTemporaryFile(
            "w", suffix=".ps1", prefix="hopa-speech-", delete=False, encoding="utf-8"
        )
        handle.write(_SPEECH_PS1)
        handle.close()
        _speech_script = Path(handle.name)
    return _speech_script


def transcribe_wav(wav: bytes) -> str:
    """Offline ASR through the PC's System.Speech engine; '' when unclear."""
    with tempfile.TemporaryDirectory(prefix="hopa-voice-") as tmp:
        source = Path(tmp) / "speech.wav"
        source.write_bytes(wav)
        result = _powershell(_speech_script_path(), ["-Mode", "transcribe", "-Path", str(source)])
    if result.returncode != 0:
        raise BridgeError(f"speech engine failed: {result.stderr.strip()[:200]}")
    return result.stdout.strip()


def list_voices() -> list[str]:
    """Installed System.Speech voices, in the order the PC reports them."""
    result = _powershell(_speech_script_path(), ["-Mode", "voices"])
    if result.returncode != 0:
        raise BridgeError(f"speech engine failed: {result.stderr.strip()[:200]}")
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def speak_wav(text: str, voice: str = '') -> bytes:
    """Render `text` to a WAV file with the PC's speech synthesiser."""
    with tempfile.TemporaryDirectory(prefix="hopa-tts-") as tmp:
        target = Path(tmp) / "reply.wav"
        args = ["-Mode", "speak", "-Text", text, "-Out", str(target)]
        if voice:
            args.extend(["-Voice", voice])
        result = _powershell(_speech_script_path(), args)
        if result.returncode != 0 or not target.exists():
            raise BridgeError(f"speech engine failed: {result.stderr.strip()[:200]}")
        return target.read_bytes()


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

    def _authorized_sessions(self) -> bool:
        presented = self._presented_token()
        if hmac.compare_digest(presented, self.bridge.sessions_key):
            return True
        return hmac.compare_digest(presented, self.bridge.token) and self.bridge.token_live()

    def _presented_token(self) -> str:
        header = self.headers.get("Authorization", "")
        prefix = "Bearer "
        return header[len(prefix):] if header.startswith(prefix) else ""

    def _authorized(self) -> bool:
        presented = self._presented_token()
        if not hmac.compare_digest(presented, self.bridge.token):
            return False
        return self.bridge.token_live()

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
        if self.path == "/sessions":
            if not self._authorized_sessions():
                self._send(401, {"error": "unauthorized"})
                return
            self._send(200, {
                "sessions": self.bridge.sessions,
                "updated": self.bridge.sessions_updated,
            })
            return
        if self.path != "/health":
            self._send(404, {"error": "not found"})
            return
        # Do not probe the device here: a slow hdc must not make the bridge
        # look unreachable.
        self._send(200, {"ok": True})

    def do_POST(self) -> None:  # noqa: N802
        # Pairing and refresh must work before the app holds a live token.
        if self.path == "/pair":
            self._handle_pair()
            return
        if self.path == "/refresh":
            self._handle_refresh()
            return
        if not self._authorized():
            # Drain the body so the client does not see a connection reset.
            length = int(self.headers.get("Content-Length", "0"))
            if length:
                self.rfile.read(length)
            self.close_connection = True
            expired = hmac.compare_digest(self._presented_token(), self.bridge.token)
            self._send(401, {"error": "token expired" if expired else "unauthorized"})
            return
        try:
            data = self._read_json()
            # hdc/uitest is one device: serialise observe, taps and screenshots
            # so two clients cannot interleave commands on the same device.
            with self.bridge.lock:
                result = self._dispatch(data)
        except BridgeError as exc:
            self._send(400, {"error": str(exc)})
            return
        except Exception as exc:  # noqa: BLE001 - bridge reports device errors
            self._send(500, {"error": f"{type(exc).__name__}: {exc}"})
            return
        self._send(200, result)

    def _handle_pair(self) -> None:
        if not self.bridge.pair_code:
            self.close_connection = True
            self._send(403, {"error": "pairing is disabled"})
            return
        if not self.bridge.pair_allowed():
            self.close_connection = True
            self._send(429, {"error": "too many attempts, wait a minute"})
            return
        try:
            data = self._read_json()
        except BridgeError as exc:
            self._send(400, {"error": str(exc)})
            return
        code = str(data.get("code", "")).strip()
        if hmac.compare_digest(code, self.bridge.pair_code):
            self.bridge.reset_pair_attempts()
            self._send(200, self.bridge.issue_tokens())
        else:
            self._send(401, {"error": "wrong code"})

    def _handle_refresh(self) -> None:
        if not self.bridge.refresh_allowed():
            self.close_connection = True
            self._send(429, {"error": "too many attempts, wait a minute"})
            return
        try:
            data = self._read_json()
        except BridgeError as exc:
            self._send(400, {"error": str(exc)})
            return
        refresh = str(data.get("refresh", "")).strip()
        if not refresh or not hmac.compare_digest(refresh, self.bridge.refresh_token):
            self.close_connection = True
            self._send(401, {"error": "refresh rejected"})
            return
        self._send(200, self.bridge.issue_tokens())

    def _dispatch(self, data: dict[str, Any]) -> dict[str, Any]:
        device = self.bridge.device
        if self.path == "/sessions":
            sessions = data.get("sessions")
            if not isinstance(sessions, list):
                raise BridgeError("sessions must be a list")
            encoded = json.dumps(sessions, ensure_ascii=False).encode("utf-8")
            if len(encoded) > SESSIONS_LIMIT_BYTES:
                raise BridgeError("sessions snapshot is too large")
            self.bridge.sessions = sessions
            self.bridge.sessions_updated = int(time.time())
            print(f"sessions: {len(sessions)}", file=sys.stderr, flush=True)
            return {"ok": True, "count": len(sessions)}
        if self.path == "/observe":
            started = time.perf_counter()
            observation = _observe(device)
            print(f"observe {time.perf_counter() - started:.2f}s", file=sys.stderr, flush=True)
            # The app only needs serialisable fields.
            observation.pop("refs", None)
            return observation
        if self.path == "/foreground":
            return {"bundle": device.foreground()}
        if self.path == "/tap":
            print(f"tap {data.get('x')},{data.get('y')}", file=sys.stderr, flush=True)
            _retry(device.tap, int(data["x"]), int(data["y"]))
            return {"ok": True}
        if self.path == "/screenshot":
            started = time.perf_counter()
            shot = _screenshot(device)
            print(f"screenshot {time.perf_counter() - started:.2f}s", file=sys.stderr, flush=True)
            return shot
        if self.path == "/type":
            x = data.get("x")
            y = data.get("y")
            _retry(
                lambda: device.type_text(
                    str(data["text"]),
                    x=int(x) if x is not None else None,
                    y=int(y) if y is not None else None,
                )
            )
            return {"ok": True}
        if self.path == "/launch":
            bundle = str(data["bundle"])
            device.launch(bundle, ability=str(data.get("ability", "")))
            return {"ok": True, "foreground": _wait_for_foreground(device, bundle)}
        if self.path == "/key":
            count = max(1, min(int(data.get("count", 1)), 120))
            if count == 1:
                _retry(device.press_key, str(data["name"]))
            else:
                _retry(device.press_key_many, str(data["name"]), count)
            return {"ok": True}
        if self.path == "/transcribe":
            audio = str(data.get("audio", ""))
            if not audio:
                raise BridgeError("audio is required (base64 WAV)")
            try:
                wav = base64.b64decode(audio, validate=True)
            except Exception as exc:  # noqa: BLE001
                raise BridgeError("audio is not base64") from exc
            return {"text": transcribe_wav(wav)}
        if self.path == "/speak":
            text = str(data.get("text", "")).strip()
            if not text:
                raise BridgeError("text is required")
            if len(text) > 1200:
                text = text[:1200]
            voice = str(data.get("voice", "")).strip()
            return {
                "mime": "audio/wav",
                "audio": base64.b64encode(speak_wav(text, voice)).decode("ascii"),
            }
        if self.path == "/voices":
            return {"voices": list_voices()}
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
        pair_code: str = "",
        token_ttl: float = 12 * 60 * 60,
        sessions_key: str = "",
        state_path: str | Path | None = None,
    ) -> None:
        if not token:
            raise BridgeError("a token is required")
        self.device = device
        self.token = token
        self.refresh_token = secrets.token_urlsafe(32)
        self.token_ttl = token_ttl
        self.token_issued_at = time.monotonic()
        self.pair_code = pair_code.strip()
        self.pair_attempts: list[float] = []
        self.pair_lock = threading.Lock()
        self.refresh_attempts: list[float] = []
        self.refresh_lock = threading.Lock()
        self.sessions: list[Any] = []
        self.sessions_updated: int = 0
        # Read-only key for other devices: it can read the session snapshot
        # and nothing else, so a laptop never needs the token that can tap.
        self.sessions_key = sessions_key or secrets.token_urlsafe(24)
        # A pair must survive a restart: otherwise every `Ctrl+C` on the PC
        # forces the phone to pair again and looks like "bridge offline".
        self._explicit_sessions_key = bool(sessions_key)
        self._base_token = token
        self._state_path = Path(state_path) if state_path is not None else None
        self.restored = False
        self.lock = threading.Lock()
        if self._state_path is not None:
            self._restore_state()
            self._save_state()
        self.httpd = ThreadingHTTPServer((host, port), _Handler)
        self.httpd.bridge = self  # type: ignore[attr-defined]
        self.thread: threading.Thread | None = None

    def _state(self) -> dict[str, Any]:
        return {
            "base": self._base_token,
            "token": self.token,
            "refresh": self.refresh_token,
            "issued_at": time.time() - (time.monotonic() - self.token_issued_at),
            "sessions_key": self.sessions_key,
        }

    def _save_state(self) -> None:
        """Write the pair and the read-only key for the next process.

        Best effort: a bridge with no writable state still works, it just
        asks clients to pair again after a restart.
        """
        if self._state_path is None:
            return
        try:
            self._state_path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self._state_path.with_suffix(".tmp")
            tmp.write_text(json.dumps(self._state()), encoding="utf-8")
            try:
                os.chmod(tmp, 0o600)
            except OSError:
                pass
            tmp.replace(self._state_path)
        except OSError:
            pass

    def _restore_state(self) -> None:
        """Adopt a live pair from the previous process, never an expired one."""
        if self._state_path is None or not self._state_path.exists():
            return
        try:
            data = json.loads(self._state_path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return
        if not isinstance(data, dict) or data.get("base") != self._base_token:
            return
        token = str(data.get("token", ""))
        refresh = str(data.get("refresh", ""))
        try:
            issued = float(data.get("issued_at", 0.0))
        except (TypeError, ValueError):
            return
        age = time.time() - issued
        if not token or not refresh or age < 0 or age >= self.token_ttl:
            return
        self.token = token
        self.refresh_token = refresh
        self.token_issued_at = time.monotonic() - age
        if not self._explicit_sessions_key:
            key = str(data.get("sessions_key", ""))
            if key:
                self.sessions_key = key
        self.restored = True

    def token_live(self) -> bool:
        return time.monotonic() - self.token_issued_at < self.token_ttl

    def issue_tokens(self) -> dict[str, Any]:
        """Rotate both tokens; the previous pair stops working immediately."""
        with self.pair_lock:
            self.token = secrets.token_urlsafe(32)
            self.refresh_token = secrets.token_urlsafe(32)
            self.token_issued_at = time.monotonic()
            self._save_state()
            return {
                "token": self.token,
                "refresh": self.refresh_token,
                "expires_in": int(self.token_ttl),
            }

    def refresh_allowed(self) -> bool:
        """Five refreshes a minute: a leaked token cannot be churned."""
        now = time.monotonic()
        with self.refresh_lock:
            self.refresh_attempts = [stamp for stamp in self.refresh_attempts if now - stamp < 60.0]
            if len(self.refresh_attempts) >= 5:
                return False
            self.refresh_attempts.append(now)
            return True

    def pair_allowed(self) -> bool:
        """At most five attempts a minute, to keep a short code cheap to guess-proof."""
        now = time.monotonic()
        with self.pair_lock:
            self.pair_attempts = [stamp for stamp in self.pair_attempts if now - stamp < 60.0]
            if len(self.pair_attempts) >= 5:
                return False
            self.pair_attempts.append(now)
            return True

    def reset_pair_attempts(self) -> None:
        with self.pair_lock:
            self.pair_attempts.clear()

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
