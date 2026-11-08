"""Tests for the bundle verification report."""

from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "scripts" / "verify-bundles.py"


def _module():
    spec = importlib.util.spec_from_file_location("verify_bundles", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_parse_installed_reads_bm_dump_lines() -> None:
    module = _module()
    text = "ID: 100:\n\tcom.hopa.agent\n\tcom.huawei.hmos.settings\n\tnot a bundle\n"
    assert module.parse_installed(text) == {"com.hopa.agent", "com.huawei.hmos.settings"}


def test_front_matter_and_catalogue() -> None:
    module = _module()
    sample = (
        "---\n"
        "name: settings\n"
        "display: Settings\n"
        "bundle: com.huawei.hmos.settings\n"
        "bundle_verified: 2026-11-07\n"
        "ability: MainAbility\n"
        "---\n"
    )
    fields = module.parse_front_matter(sample)
    assert fields["bundle"] == "com.huawei.hmos.settings"
    apps = module.load_apps()
    assert len(apps) == 27
    settings = next(app for app in apps if app["name"] == "settings")
    assert settings["bundle"] == "com.huawei.hmos.settings"
    assert settings["verified"]


def test_report_counts_installed_and_missing() -> None:
    module = _module()
    apps = [
        {"display": "One", "bundle": "com.example.one", "verified": "2026-11-08", "name": "one"},
        {"display": "Two", "bundle": "com.example.two", "verified": "", "name": "two"},
        {"display": "Three", "bundle": "", "verified": "", "name": "three"},
    ]
    output = module.report(apps, {"com.example.one"})
    assert "1 installed" in output
    assert "1 missing" in output
    assert "1 with no bundle" in output
