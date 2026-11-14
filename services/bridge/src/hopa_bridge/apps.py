"""Parse ``bm dump -a`` output into installed application bundles.

HarmonyOS releases differ: some print one bundle per line, some print
``BundleName: ...`` records, some print JSON. The parser accepts all three and
never guesses a label it does not have.
"""

from __future__ import annotations

import json
import re
from typing import Any

BUNDLE_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+){2,}$")

NOISE = {
    "bundlename",
    "bundle",
    "name",
    "error",
    "failed",
    "list",
}


def _is_bundle(value: str) -> bool:
    value = value.strip()
    if not value or value.lower() in NOISE:
        return False
    return bool(BUNDLE_RE.match(value))


def parse_installed_apps(text: str) -> list[dict[str, str]]:
    """Return ``[{bundle, label}]`` sorted by bundle name."""
    bundles: set[str] = set()

    stripped = (text or "").strip()
    if stripped.startswith(("[", "{")):
        try:
            data: Any = json.loads(stripped)
            bundles.update(_bundles_from_json(data))
        except json.JSONDecodeError:
            pass

    if not bundles:
        for raw in (text or "").splitlines():
            line = raw.strip().strip(",")
            if not line:
                continue
            if ":" in line:
                key, value = line.split(":", 1)
                if key.strip().lower() in {"bundlename", "bundle", "name"}:
                    line = value.strip().strip('"')
            line = line.strip('"').strip()
            if _is_bundle(line):
                bundles.add(line)
                continue
            # Tolerant fallback: pull bundle-shaped tokens out of a noisy line.
            for token in re.findall(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+){2,}", line):
                if _is_bundle(token):
                    bundles.add(token)

    return [{"bundle": bundle, "label": bundle} for bundle in sorted(bundles)]


def _bundles_from_json(data: Any) -> set[str]:
    found: set[str] = set()
    if isinstance(data, list):
        for item in data:
            found.update(_bundles_from_json(item))
    elif isinstance(data, dict):
        for key in ("bundleName", "bundle", "name"):
            value = data.get(key)
            if isinstance(value, str) and _is_bundle(value):
                found.add(value)
        for value in data.values():
            if isinstance(value, (dict, list)):
                found.update(_bundles_from_json(value))
    return found
