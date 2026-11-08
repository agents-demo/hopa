#!/usr/bin/env python3
"""Report which known app bundles are installed on a device.

The catalogue in ``services/brain/knowledge/apps`` is the source of truth. This
tool compares it with a device's ``bm dump -a`` output, so a real phone can show
exactly which apps are present and which bundles still need to be verified.

Usage:
    py tools/scripts/verify-bundles.py
    py tools/scripts/verify-bundles.py --device 127.0.0.1:5555
    py tools/scripts/verify-bundles.py --input bm-dump.txt
    py tools/scripts/verify-bundles.py --check   # exit 1 if a verified app is missing
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APPS = ROOT / "services" / "brain" / "knowledge" / "apps"
BUNDLE_RE = re.compile(r"^\s*([A-Za-z][\w]*\.[\w.]+)\s*$")


def parse_installed(text: str) -> set[str]:
    bundles: set[str] = set()
    for line in text.splitlines():
        match = BUNDLE_RE.match(line)
        if match:
            bundles.add(match.group(1))
    return bundles


def parse_front_matter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---", 4)
    if end < 0:
        return {}
    fields: dict[str, str] = {}
    for line in text[4:end].split("\n"):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        key, _, value = stripped.partition(":")
        fields[key.strip()] = value.strip()
    return fields


def load_apps() -> list[dict[str, str]]:
    apps: list[dict[str, str]] = []
    for path in sorted(APPS.glob("*/APP.md")):
        fields = parse_front_matter(path.read_text(encoding="utf-8"))
        bundle = fields.get("bundle", "").strip()
        if bundle.upper() in {"", "UNCONFIRMED", "UNKNOWN"}:
            bundle = ""
        apps.append(
            {
                "name": fields.get("name", path.parent.name),
                "display": fields.get("display", path.parent.name),
                "bundle": bundle,
                "verified": fields.get("bundle_verified", "").strip(),
                "ability": fields.get("ability", "").strip(),
                "validated": fields.get("validated", "").strip(),
            }
        )
    return apps


def report(apps: list[dict[str, str]], installed: set[str]) -> str:
    lines = [f"{'App':20s} {'Bundle':42s} {'Installed':10s} Verified"]
    lines.append("-" * 88)
    for app in apps:
        bundle = app["bundle"] if app["bundle"] else "(no bundle)"
        present = "yes" if app["bundle"] and app["bundle"] in installed else "no"
        verified = "yes" if app["verified"] else "-"
        lines.append(f"{app['display']:20.20s} {bundle:42.42s} {present:10s} {verified}")
    with_bundle = sum(1 for app in apps if app["bundle"])
    present = sum(1 for app in apps if app["bundle"] and app["bundle"] in installed)
    missing = sum(1 for app in apps if app["bundle"] and app["bundle"] not in installed)
    lines.append("")
    lines.append(
        f"{len(apps)} apps: {with_bundle} with a bundle, {present} installed, "
        f"{missing} missing, {len(apps) - with_bundle} with no bundle."
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hdc", default="hdc", help="hdc executable")
    parser.add_argument("--device", default="", help="device id for hdc -t")
    parser.add_argument("--input", default="", help="read bm dump -a output from a file")
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 1 when an app marked bundle_verified is not installed",
    )
    args = parser.parse_args()

    if args.input:
        text = Path(args.input).read_text(encoding="utf-8")
    else:
        command = [args.hdc]
        if args.device:
            command += ["-t", args.device]
        command += ["shell", "bm dump -a"]
        try:
            result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=60)
        except (OSError, subprocess.SubprocessError) as error:
            print(f"could not read the device: {error}", file=sys.stderr)
            return 2
        text = result.stdout

    apps = load_apps()
    installed = parse_installed(text)
    print(report(apps, installed))

    if args.check:
        missing_verified = [
            app["display"]
            for app in apps
            if app["verified"] and app["bundle"] and app["bundle"] not in installed
        ]
        if missing_verified:
            print("\nVerified bundles missing from this device:", file=sys.stderr)
            for app in missing_verified:
                print(f"  {app}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
