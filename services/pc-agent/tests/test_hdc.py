from __future__ import annotations

from hopa_pc_agent.hdc import Hdc, parse_targets


def test_parse_targets_skips_empty_marker() -> None:
    assert parse_targets("[Empty]\n") == []


def test_parse_targets_keeps_addresses() -> None:
    output = "127.0.0.1:5555\nABCDEF0123456789\n"
    assert parse_targets(output) == ["127.0.0.1:5555", "ABCDEF0123456789"]


def test_parse_targets_deduplicates() -> None:
    assert parse_targets("dev1\ndev1\n") == ["dev1"]


def test_parse_targets_skips_noise() -> None:
    output = "Connect server failed\nerror: no device\n127.0.0.1:5555\n"
    assert parse_targets(output) == ["127.0.0.1:5555"]


def test_command_includes_target() -> None:
    hdc = Hdc(hdc_path="hdc", target="127.0.0.1:5555")
    assert hdc.command("shell", "echo hi") == [
        "hdc",
        "-t",
        "127.0.0.1:5555",
        "shell",
        "echo hi",
    ]


def test_command_without_target() -> None:
    hdc = Hdc(hdc_path="hdc")
    assert hdc.command("list", "targets") == ["hdc", "list", "targets"]
