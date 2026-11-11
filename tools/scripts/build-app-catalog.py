#!/usr/bin/env python3
"""Generate the app catalogue consumed by the entry UI.

Sources of truth:
  * ``services/brain/knowledge/apps/*/APP.md``
  * ``services/brain/knowledge/sites/*/SITE.md``

The generated file is committed so the ArkTS app needs no file parsing at
runtime. Re-run this after adding or changing a Markdown file, and CI checks
that the output is current.

Each entry carries a short purpose and the first few actions, so the model can
recognise the task domain ("check my alarm" -> Clock) instead of only seeing a
bundle name.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KNOWLEDGE = ROOT / "services" / "brain" / "knowledge" / "apps"
SITES = ROOT / "services" / "brain" / "knowledge" / "sites"
TARGET = ROOT / "apps" / "harmony" / "app" / "src" / "main" / "ets" / "services" / "AppCatalog.ets"

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
        if stripped.startswith("- ") or stripped.startswith("* "):
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


def escape(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def collect() -> list[dict]:
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
                "name": fields["name"],
                "display": fields["display"],
                "bundle": bundle if confirmed else "",
                "aliases": parse_list(fields.get("aliases", "[]")),
                "confirmed": confirmed,
                "verified": verified,
                "ability": fields.get("ability", "").strip(),
                "purpose": shorten(purpose, MAX_PURPOSE),
                "actions": [shorten(action, MAX_ACTION) for action in actions],
            }
        )
    entries.sort(
        key=lambda item: (
            not item["verified"],
            not item["confirmed"],
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
                "name": fields["name"],
                "display": fields["display"],
                "domains": parse_list(fields.get("domains", "[]")),
                "aliases": parse_list(fields.get("aliases", "[]")),
                "validated": fields.get("validated", "pending"),
                "purpose": shorten(paragraph, MAX_PURPOSE),
                "actions": [shorten(action, MAX_ACTION) for action in bullets[:MAX_ACTIONS]],
            }
        )
    entries.sort(key=lambda item: item["display"].lower())
    return entries


def render(entries: list[dict], sites: list[dict]) -> str:
    lines = [
        "// Generated by tools/scripts/build-app-catalog.py. Do not edit by hand.",
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
    for entry in entries:
        aliases = ", ".join(escape(alias) for alias in entry["aliases"])
        actions = ", ".join(escape(action) for action in entry["actions"])
        lines.append("  {")
        lines.append(f"    name: {escape(entry['name'])},")
        lines.append(f"    display: {escape(entry['display'])},")
        lines.append(f"    bundle: {escape(entry['bundle'])},")
        lines.append(f"    aliases: [{aliases}],")
        lines.append(f"    confirmed: {str(entry['confirmed']).lower()},")
        lines.append(f"    verified: {str(entry['verified']).lower()},")
        lines.append(f"    ability: {escape(entry['ability'])},")
        lines.append(f"    purpose: {escape(entry['purpose'])},")
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
        lines.append(f"    name: {escape(site['name'])},")
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


def main() -> int:
    entries = collect()
    sites = collect_sites()
    output = render(entries, sites)
    if "--check" in sys.argv:
        if not TARGET.exists() or TARGET.read_text(encoding="utf-8") != output:
            print(
                f"{TARGET} is stale; run scripts/build-app-catalog.py", file=sys.stderr
            )
            return 1
        print(f"{len(entries)} apps and {len(sites)} sites are current")
        return 0
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(output, encoding="utf-8", newline="\n")
    confirmed = sum(1 for entry in entries if entry["confirmed"])
    verified = sum(1 for entry in entries if entry["verified"])
    print(
        f"wrote {TARGET} with {len(entries)} apps and {len(sites)} sites "
        f"({confirmed} bundles, {verified} verified on a device)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
