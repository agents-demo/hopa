#!/usr/bin/env python3
"""Generate the neutral app/site catalogue and its platform renderings.

Sources of truth:
  * ``services/brain/knowledge/apps/*/APP.md``
  * ``services/brain/knowledge/sites/*/SITE.md``

Outputs:
  * ``contracts/catalog/catalog.v1.json`` - platform-neutral ids, names,
    aliases, purposes and actions, plus a ``platforms`` map for launch details.
  * ``apps/harmony/app/src/main/ets/services/AppCatalog.ets`` - the ArkTS copy
    the phone and laptop compile in (an app cannot read a repo file at runtime).
  * an optional Kotlin source (``--kotlin PATH``) for the Android client; the
    Android build generates its own copy in A11 of the Android plan.

The generated files are committed. CI checks that they are current, so a
description changes once and every platform is regenerated from it (ADR-0018).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KNOWLEDGE = ROOT / "services" / "brain" / "knowledge" / "apps"
SITES = ROOT / "services" / "brain" / "knowledge" / "sites"
CATALOG = ROOT / "contracts" / "catalog" / "catalog.v1.json"
TARGET = (
    ROOT
    / "apps"
    / "harmony"
    / "app"
    / "src"
    / "main"
    / "ets"
    / "services"
    / "AppCatalog.ets"
)

MAX_PURPOSE = 200
MAX_ACTION = 120
MAX_ACTIONS = 4


def parse_front_matter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        raise ValueError("missing front matter")
    end = text.find("\n---", 4)
    if end < 0:
        raise ValueError("unterminated front matter")
    fields: dict[str, str] = {}
    for line in text[4:end].split("\n"):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        key, _, value = stripped.partition(":")
        fields[key.strip()] = value.strip()
    return fields


def parse_list(raw: str) -> list[str]:
    inner = raw.removeprefix("[").removesuffix("]")
    return [item.strip().strip('"') for item in inner.split(",") if item.strip()]


def parse_body(text: str) -> tuple[str, list[str]]:
    """Return the first paragraph and the bullet list of a Markdown body."""
    end = text.find("\n---", 4)
    body = text[end + 4 :] if end >= 0 else text
    paragraph: list[str] = []
    bullets: list[str] = []
    bullet: str | None = None

    def flush_paragraph() -> None:
        nonlocal paragraph
        if paragraph:
            paragraph = [" ".join(part.strip() for part in paragraph)]

    def flush_bullet() -> None:
        nonlocal bullet
        if bullet is not None:
            bullets.append(bullet.strip())
            bullet = None

    for line in body.split("\n"):
        stripped = line.strip()
        if not stripped:
            flush_paragraph()
            flush_bullet()
            continue
        if stripped.startswith("#"):
            flush_paragraph()
            flush_bullet()
            continue
        if stripped.startswith(("- ", "* ")):
            flush_paragraph()
            flush_bullet()
            bullet = stripped[2:]
            continue
        if bullet is not None:
            bullet = f"{bullet} {stripped}"
        else:
            paragraph.append(stripped)
    flush_paragraph()
    flush_bullet()
    return (paragraph[0] if paragraph else ""), bullets


def shorten(value: str, limit: int) -> str:
    value = " ".join(value.split())
    if len(value) <= limit:
        return value
    return value[: limit - 1].rstrip() + "…"


def collect_apps() -> list[dict]:
    entries: list[dict] = []
    for path in sorted(KNOWLEDGE.glob("*/APP.md")):
        text = path.read_text(encoding="utf-8")
        fields = parse_front_matter(text)
        paragraph, bullets = parse_body(text)
        purpose = bullets[0] if bullets else paragraph
        actions = bullets[1 : MAX_ACTIONS + 1]
        bundle = fields["bundle"]
        confirmed = bundle.upper() not in {"UNCONFIRMED", "UNKNOWN"}
        verified = confirmed and bool(fields.get("bundle_verified", "").strip())
        entries.append(
            {
                "id": fields["name"],
                "display": fields["display"],
                "aliases": parse_list(fields.get("aliases", "[]")),
                "purpose": shorten(purpose, MAX_PURPOSE),
                "actions": [shorten(action, MAX_ACTION) for action in actions],
                "platforms": {
                    "harmonyos": {
                        "bundle": bundle if confirmed else "",
                        "ability": fields.get("ability", "").strip(),
                        "confirmed": confirmed,
                        "verified": verified,
                    }
                },
            }
        )
    entries.sort(
        key=lambda item: (
            not item["platforms"]["harmonyos"]["verified"],
            not item["platforms"]["harmonyos"]["confirmed"],
            item["display"].lower(),
        )
    )
    return entries


def collect_sites() -> list[dict]:
    entries: list[dict] = []
    for path in sorted(SITES.glob("*/SITE.md")):
        text = path.read_text(encoding="utf-8")
        fields = parse_front_matter(text)
        paragraph, bullets = parse_body(text)
        entries.append(
            {
                "id": fields["name"],
                "display": fields["display"],
                "domains": parse_list(fields.get("domains", "[]")),
                "aliases": parse_list(fields.get("aliases", "[]")),
                "validated": fields.get("validated", "pending"),
                "purpose": shorten(paragraph, MAX_PURPOSE),
                "actions": [
                    shorten(action, MAX_ACTION) for action in bullets[:MAX_ACTIONS]
                ],
                "platforms": {"harmonyos": {}},
            }
        )
    entries.sort(key=lambda item: item["display"].lower())
    return entries


def document(apps: list[dict], sites: list[dict]) -> dict:
    return {
        "schemaVersion": "1",
        "description": (
            "Platform-neutral app and site descriptions. Launch details live "
            "under platforms; every client renders this file (ADR-0018)."
        ),
        "apps": apps,
        "sites": sites,
    }


def render_json(data: dict) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def escape(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def render_ets(data: dict) -> str:
    apps = data["apps"]
    sites = data["sites"]
    lines = [
        "// Generated by tools/scripts/build-app-catalog.py. Do not edit by hand.",
        "// Source: contracts/catalog/catalog.v1.json",
        "",
        "export class CatalogApp {",
        "  name: string = '';",
        "  display: string = '';",
        "  bundle: string = '';",
        "  aliases: string[] = [];",
        "  confirmed: boolean = false;",
        "  verified: boolean = false;",
        "  ability: string = '';",
        "  purpose: string = '';",
        "  actions: string[] = [];",
        "}",
        "",
        "export class CatalogSite {",
        "  name: string = '';",
        "  display: string = '';",
        "  domains: string[] = [];",
        "  aliases: string[] = [];",
        "  validated: string = '';",
        "  purpose: string = '';",
        "  actions: string[] = [];",
        "}",
        "",
        "export const APP_CATALOG: CatalogApp[] = [",
    ]
    for app in apps:
        harmony = app["platforms"].get("harmonyos", {})
        aliases = ", ".join(escape(alias) for alias in app["aliases"])
        actions = ", ".join(escape(action) for action in app["actions"])
        lines.append("  {")
        lines.append(f"    name: {escape(app['id'])},")
        lines.append(f"    display: {escape(app['display'])},")
        lines.append(f"    bundle: {escape(harmony.get('bundle', ''))},")
        lines.append(f"    aliases: [{aliases}],")
        lines.append(f"    confirmed: {str(harmony.get('confirmed', False)).lower()},")
        lines.append(f"    verified: {str(harmony.get('verified', False)).lower()},")
        lines.append(f"    ability: {escape(harmony.get('ability', ''))},")
        lines.append(f"    purpose: {escape(app['purpose'])},")
        lines.append(f"    actions: [{actions}],")
        lines.append("  },")
    lines.append("];")
    lines.append("")
    lines.append("export const SITE_CATALOG: CatalogSite[] = [")
    for site in sites:
        domains = ", ".join(escape(domain) for domain in site["domains"])
        aliases = ", ".join(escape(alias) for alias in site["aliases"])
        actions = ", ".join(escape(action) for action in site["actions"])
        lines.append("  {")
        lines.append(f"    name: {escape(site['id'])},")
        lines.append(f"    display: {escape(site['display'])},")
        lines.append(f"    domains: [{domains}],")
        lines.append(f"    aliases: [{aliases}],")
        lines.append(f"    validated: {escape(site['validated'])},")
        lines.append(f"    purpose: {escape(site['purpose'])},")
        lines.append(f"    actions: [{actions}],")
        lines.append("  },")
    lines.append("];")
    lines.append("")
    return "\n".join(lines)


def kotlin_string(value: str) -> str:
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("$", "\\$")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )
    return f'"{escaped}"'


def kotlin_list(values: list[str]) -> str:
    return "listOf(" + ", ".join(kotlin_string(value) for value in values) + ")"


def render_kotlin(data: dict) -> str:
    lines = [
        "// Generated by tools/scripts/build-app-catalog.py. Do not edit by hand.",
        "// Source: contracts/catalog/catalog.v1.json",
        "package com.hopa.catalog",
        "",
        "data class CatalogApp(",
        "    val id: String,",
        "    val display: String,",
        "    val aliases: List<String>,",
        "    val purpose: String,",
        "    val actions: List<String>,",
        "    val bundle: String,",
        "    val activity: String,",
        "    val verified: Boolean,",
        ")",
        "",
        "data class CatalogSite(",
        "    val id: String,",
        "    val display: String,",
        "    val domains: List<String>,",
        "    val aliases: List<String>,",
        "    val validated: String,",
        "    val purpose: String,",
        "    val actions: List<String>,",
        ")",
        "",
        "val APP_CATALOG: List<CatalogApp> = listOf(",
    ]
    for app in data["apps"]:
        android = app["platforms"].get("android", {})
        lines.append("    CatalogApp(")
        lines.append(f"        id = {kotlin_string(app['id'])},")
        lines.append(f"        display = {kotlin_string(app['display'])},")
        lines.append(f"        aliases = {kotlin_list(app['aliases'])},")
        lines.append(f"        purpose = {kotlin_string(app['purpose'])},")
        lines.append(f"        actions = {kotlin_list(app['actions'])},")
        lines.append(f"        bundle = {kotlin_string(android.get('package', ''))},")
        lines.append(f"        activity = {kotlin_string(android.get('activity', ''))},")
        lines.append(f"        verified = {str(android.get('verified', False)).lower()},")
        lines.append("    ),")
    lines.append(")")
    lines.append("")
    lines.append("val SITE_CATALOG: List<CatalogSite> = listOf(")
    for site in data["sites"]:
        lines.append("    CatalogSite(")
        lines.append(f"        id = {kotlin_string(site['id'])},")
        lines.append(f"        display = {kotlin_string(site['display'])},")
        lines.append(f"        domains = {kotlin_list(site['domains'])},")
        lines.append(f"        aliases = {kotlin_list(site['aliases'])},")
        lines.append(f"        validated = {kotlin_string(site['validated'])},")
        lines.append(f"        purpose = {kotlin_string(site['purpose'])},")
        lines.append(f"        actions = {kotlin_list(site['actions'])},")
        lines.append("    ),")
    lines.append(")")
    lines.append("")
    return "\n".join(lines)


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def main() -> int:
    data = document(collect_apps(), collect_sites())
    catalog = render_json(data)
    ets = render_ets(data)

    kotlin_path: Path | None = None
    if "--kotlin" in sys.argv:
        index = sys.argv.index("--kotlin")
        kotlin_path = Path(sys.argv[index + 1])

    if "--check" in sys.argv:
        stale = []
        if not CATALOG.exists() or CATALOG.read_text(encoding="utf-8") != catalog:
            stale.append(CATALOG)
        if not TARGET.exists() or TARGET.read_text(encoding="utf-8") != ets:
            stale.append(TARGET)
        if kotlin_path is not None:
            expected = render_kotlin(data)
            if not kotlin_path.exists() or kotlin_path.read_text(encoding="utf-8") != expected:
                stale.append(kotlin_path)
        if stale:
            for path in stale:
                print(f"{path} is stale; run tools/scripts/build-app-catalog.py", file=sys.stderr)
            return 1
        print(f"catalog is current ({len(data['apps'])} apps, {len(data['sites'])} sites)")
        return 0

    write(CATALOG, catalog)
    write(TARGET, ets)
    if kotlin_path is not None:
        write(kotlin_path, render_kotlin(data))
    confirmed = sum(1 for app in data["apps"] if app["platforms"]["harmonyos"]["confirmed"])
    verified = sum(1 for app in data["apps"] if app["platforms"]["harmonyos"]["verified"])
    print(
        f"wrote {CATALOG.relative_to(ROOT)} and {TARGET.relative_to(ROOT)} "
        f"with {len(data['apps'])} apps and {len(data['sites'])} sites "
        f"({confirmed} bundles, {verified} verified on a device)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
