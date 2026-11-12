"""The PC half of the relay: poll the cloud and replay requests locally.

Kept in services/bridge on purpose: a relay host must never install device code,
and a PC must never be required to install cloud code (ADR-0009).
"""

from __future__ import annotations

import base64
import json
import threading
import time
import urllib.error
import urllib.request
from typing import Any

from hopa_wire.errors import RelayError


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
