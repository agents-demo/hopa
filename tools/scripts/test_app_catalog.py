"""Tests for the generated app/site catalogue and its platform renderings."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "scripts" / "build-app-catalog.py"


def _module():
    spec = importlib.util.spec_from_file_location("build_app_catalog", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_front_matter_parsing() -> None:
    module = _module()
    text = (
        "---\n"
        "name: x\n"
        "display: X\n"
        "bundle: com.example.x\n"
        "aliases: [a, b]\n"
        "pace: careful\n"
        "validated: pending\n"
        "platform: harmonyos\n"
        "---\n"
        "# X\n"
    )
    fields = module.parse_front_matter(text)
    assert fields["name"] == "x"
    assert fields["bundle"] == "com.example.x"
    assert module.parse_list(fields["aliases"]) == ["a", "b"]


def test_list_parsing_handles_empty() -> None:
    module = _module()
    assert module.parse_list("[]") == []
    assert module.parse_list("") == []


def test_catalogue_counts_and_status() -> None:
    module = _module()
    data = module.document(module.collect_apps(), module.collect_sites())
    assert len(data["apps"]) == 35
    assert len(data["sites"]) == 21
    harmony = [app["platforms"]["harmonyos"] for app in data["apps"]]
    assert sum(1 for item in harmony if item["verified"]) == 26
    assert sum(1 for item in harmony if not item["confirmed"]) == 9
    # Verified apps must carry a launchable ability.
    assert all(item["ability"] for item in harmony if item["verified"])


def test_unconfirmed_apps_have_no_bundle() -> None:
    module = _module()
    for app in module.collect_apps():
        harmony = app["platforms"]["harmonyos"]
        if not harmony["confirmed"]:
            assert harmony["bundle"] == ""
            assert harmony["verified"] is False


def test_render_emits_both_catalogues() -> None:
    module = _module()
    data = module.document(module.collect_apps(), module.collect_sites())
    output = module.render_ets(data)
    assert "export const APP_CATALOG" in output
    assert "export const SITE_CATALOG" in output
    assert "verified: true" in output
    assert "verified: false" in output
    assert all("://" not in app["platforms"]["harmonyos"]["bundle"] for app in data["apps"])
    assert all("://" not in domain for site in data["sites"] for domain in site["domains"])


def test_neutral_json_is_platform_free() -> None:
    module = _module()
    data = module.document(module.collect_apps(), module.collect_sites())
    parsed = json.loads(module.render_json(data))
    assert parsed["schemaVersion"] == "1"
    app = next(item for item in parsed["apps"] if item["id"] == "alipay")
    assert "bundle" not in app
    assert app["platforms"]["harmonyos"]["bundle"] == "com.alipay.mobile.client"
    site = next(item for item in parsed["sites"] if item["id"] == "amazon.com")
    assert site["domains"]
    assert "purpose" in site


def test_kotlin_rendering_matches_the_same_entries() -> None:
    module = _module()
    data = module.document(module.collect_apps(), module.collect_sites())
    output = module.render_kotlin(data)
    assert "package com.hopa.catalog" in output
    assert 'id = "alipay"' in output
    for app in data["apps"]:
        assert f'id = "{app["id"]}"' in output
    # Kotlin needs $ escaped inside a string literal.
    assert module.kotlin_string("cost $5") == '"cost \\$5"'


def test_entries_carry_purpose_and_actions() -> None:
    module = _module()
    apps = module.collect_apps()
    assert all(app["purpose"] for app in apps)
    clock = next(app for app in apps if app["id"] == "clock")
    assert "alarm" in clock["purpose"].lower()
    assert clock["actions"]
    sites = module.collect_sites()
    assert all(site["domains"] for site in sites)
    assert any(site["aliases"] for site in sites)


def test_committed_files_are_current() -> None:
    module = _module()
    data = module.document(module.collect_apps(), module.collect_sites())
    assert module.CATALOG.read_text(encoding="utf-8") == module.render_json(data)
    assert module.TARGET.read_text(encoding="utf-8") == module.render_ets(data)
