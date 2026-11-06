from __future__ import annotations

from hopa_pc_agent.cli import build_parser, main


def test_parser_tap() -> None:
    args = build_parser().parse_args(["tap", "12", "34"])
    assert args.command == "tap"
    assert (args.x, args.y) == (12, 34)


def test_parser_global_flags_before_subcommand() -> None:
    args = build_parser().parse_args(["--target", "dev1", "--json", "devices"])
    assert args.target == "dev1"
    assert args.json is True
    assert args.command == "devices"


def test_parser_type_with_coordinates() -> None:
    args = build_parser().parse_args(["type", "hello", "--x", "5", "--y", "6"])
    assert args.text == "hello"
    assert (args.x, args.y) == (5, 6)


def test_parser_swipe_defaults() -> None:
    args = build_parser().parse_args(["swipe", "1", "2", "3", "4"])
    assert args.velocity == 600


def test_parser_apps_query() -> None:
    args = build_parser().parse_args(["apps", "--query", "huawei"])
    assert args.command == "apps"
    assert args.query == "huawei"


def test_main_returns_error_for_missing_hdc(monkeypatch, capsys) -> None:
    monkeypatch.setenv("HOPA_HDC", "C:/definitely/not/here/hdc.exe")
    code = main(["--hdc", "C:/definitely/not/here/hdc.exe", "devices"])
    assert code == 2
    assert "pc-agent:" in capsys.readouterr().err


def test_parser_bridge_defaults() -> None:
    args = build_parser().parse_args(["bridge"])
    assert args.host == "127.0.0.1"
    assert args.port == 8765
