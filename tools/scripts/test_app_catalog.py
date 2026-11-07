"""Tests for the generated app/site catalogue."""

from __future__ import annotations

import importlib.util
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
    apps = module.collect()
    sites = module.collect_sites()
    assert len(apps) == 27
    assert len(sites) == 21
    assert sum(1 for app in apps if app["verified"]) == 7
    assert sum(1 for app in apps if not app["confirmed"]) == 15
    # Verified apps must carry a launchable ability.
    assert all(app["ability"] for app in apps if app["verified"])


def test_unconfirmed_apps_have_no_bundle() -> None:
    module = _module()
    apps = module.collect()
    for app in apps:
        if not app["confirmed"]:
            assert app["bundle"] == ""
            assert app["verified"] is False


def test_render_emits_both_catalogues() -> None:
    module = _module()
    output = module.render(module.collect(), module.collect_sites())
    assert "export const APP_CATALOG" in output
    assert "export const SITE_CATALOG" in output
    assert "verified: true" in output
    assert "verified: false" in output
    assert "https" not in output  # no URLs leaked into the generated file


def test_committed_file_is_current() -> None:
    module = _module()
    expected = module.render(module.collect(), module.collect_sites())
    target = (
        ROOT / "apps" / "harmony" / "entry" / "src" / "main" / "ets" / "services" / "AppCatalog.ets"
    )
    assert target.read_text(encoding="utf-8") == expected
