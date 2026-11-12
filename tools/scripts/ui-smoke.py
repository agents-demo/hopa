#!/usr/bin/env python3
"""Bridge-driven UI smoke test.

Runs against a live `hopa-bridge bridge` and the HOPA app on the phone:

  py -3 tools/scripts/ui-smoke.py --url http://127.0.0.1:8766 --token hopaphone

Checks: the bridge answers, HOPA comes to the front, the screen dump has
content, and a screenshot decodes. Exit code 0 means the shell is healthy.

It deliberately does not call the model, so it works with no phone internet.
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
import time
import urllib.error
import urllib.request

BUNDLE = "com.hopa.agent"


class Bridge:
    def __init__(self, url: str, token: str) -> None:
        self.url = url.rstrip("/")
        self.token = token

    def call(
        self, path: str, payload: dict | None = None, timeout: float = 30.0
    ) -> dict:
        request = urllib.request.Request(
            f"{self.url}{path}",
            data=json.dumps(payload or {}).encode(),
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))

    def health(self) -> bool:
        request = urllib.request.Request(
            f"{self.url}/health", headers={"Authorization": f"Bearer {self.token}"}
        )
        try:
            with urllib.request.urlopen(request, timeout=5) as response:
                return response.status == 200
        except (urllib.error.URLError, TimeoutError):
            return False


def check(name: str, ok: bool, detail: str = "") -> bool:
    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {name}" + (f" — {detail}" if detail and not ok else ""))
    return ok


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8766")
    parser.add_argument("--token", default="hopaphone")
    parser.add_argument("--bundle", default=BUNDLE)
    args = parser.parse_args()

    bridge = Bridge(args.url, args.token)
    results: list[bool] = []

    results.append(check("bridge answers /health", bridge.health()))

    try:
        launched = bridge.call("/launch", {"bundle": args.bundle})
        results.append(check("app launches", bool(launched.get("ok")), str(launched)))
    except Exception as error:  # noqa: BLE001 - the report is the point
        results.append(check("app launches", False, str(error)))
        print("stopping: cannot reach the app")
        return 1

    time.sleep(2.5)
    try:
        foreground = bridge.call("/foreground").get("bundle", "")
        results.append(check("HOPA is in front", foreground == args.bundle, foreground))
    except Exception as error:  # noqa: BLE001
        results.append(check("HOPA is in front", False, str(error)))

    try:
        observation = bridge.call("/observe")
        text = observation.get("text", "")
        nodes = observation.get("nodes", [])
        results.append(
            check("screen dump has text", len(text.strip()) > 0, f"{len(text)} chars")
        )
        results.append(
            check("screen dump has nodes", len(nodes) > 0, f"{len(nodes)} nodes")
        )
    except Exception as error:  # noqa: BLE001
        results.append(check("screen dump", False, str(error)))

    try:
        shot = bridge.call("/screenshot").get("image", "")
        raw = base64.b64decode(shot) if shot else b""
        looks_like_image = raw.startswith((b"\xff\xd8", b"\x89PNG"))
        results.append(
            check("screenshot decodes", looks_like_image, f"{len(raw)} bytes")
        )
    except Exception as error:  # noqa: BLE001
        results.append(check("screenshot decodes", False, str(error)))

    passed = sum(1 for item in results if item)
    print(f"\n{passed}/{len(results)} checks passed")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
