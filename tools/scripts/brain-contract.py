#!/usr/bin/env python3
"""Cross-language contract test for the Kotlin brain service.

Starts the JVM server, calls /decide, and validates the reply against the same
JSON Schema the Python and ArkTS implementations use.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

try:
    import jsonschema
    from referencing import Registry, Resource
except ImportError:  # pragma: no cover - CI installs it
    print("brain-contract: jsonschema is required", file=sys.stderr)
    raise SystemExit(2)

ROOT = Path(__file__).resolve().parents[2]


def wait_for_port(process: subprocess.Popen[str], timeout: float = 20.0) -> int:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        line = process.stdout.readline() if process.stdout else ""
        if "listening on http://127.0.0.1:" in line:
            return int(line.rsplit(":", 1)[1].strip())
        if process.poll() is not None:
            stderr = process.stderr.read() if process.stderr else ""
            raise RuntimeError(f"brain exited early: {stderr}")
    raise TimeoutError("brain did not start")


def request(url: str, payload: dict | None = None) -> tuple[int, dict]:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST" if payload is not None else "GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode("utf-8") or "{}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--jar", default=str(ROOT / "services" / "brain" / "build" / "brain.jar"))
    parser.add_argument("--gson", default=str(ROOT / ".tools" / "gson-2.11.0.jar"))
    args = parser.parse_args()

    classpath = args.jar + os.pathsep + args.gson
    process = subprocess.Popen(
        ["java", "-cp", classpath, "hopa.brain.ServerKt", "0"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    try:
        port = wait_for_port(process)
        base = f"http://127.0.0.1:{port}"

        status, health = request(f"{base}/health")
        assert status == 200 and health["status"] == "ok", health

        status, version = request(f"{base}/version")
        assert status == 200 and version["contract"] == "1", version

        status, decision = request(
            f"{base}/decide",
            {
                "goal": "打开设置",
                "settings": {
                    "installed": [
                        {"bundle": "com.huawei.hmos.settings", "label": "Settings"}
                    ]
                },
                "sessionId": "contract",
            },
        )
        assert status == 200, decision
        schema = json.loads((ROOT / "contracts" / "schemas" / "decision.schema.json").read_text("utf-8"))
        action_schema = json.loads((ROOT / "contracts" / "schemas" / "action.schema.json").read_text("utf-8"))
        registry = Registry().with_resources(
            [
                ("action.schema.json", Resource.from_contents(action_schema)),
                (action_schema["$id"], Resource.from_contents(action_schema)),
            ]
        )
        jsonschema.Draft202012Validator(schema, registry=registry).validate(decision)
        assert decision["action"]["kind"] == "ui.launch", decision
        assert decision["action"]["app"] == "com.huawei.hmos.settings", decision

        status, session = request(f"{base}/session/contract")
        assert status == 200 and len(session["decisions"]) == 1, session

        print("brain contract: ok")
        return 0
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()


if __name__ == "__main__":
    raise SystemExit(main())
