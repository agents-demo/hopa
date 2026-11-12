from __future__ import annotations

import time

from hopa_bridge.bridge import BridgeServer
from hopa_bridge.cli import _cmd_bridge, build_parser, main


class _NoDevice:
    pass


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


def test_bridge_command_starts_serving(monkeypatch) -> None:
    events: list[str] = []

    def fake_start(self: BridgeServer) -> None:
        events.append("start")

    def fake_stop(self: BridgeServer) -> None:
        events.append("stop")

    monkeypatch.setattr(BridgeServer, "start", fake_start)
    monkeypatch.setattr(BridgeServer, "stop", fake_stop)

    def no_sleep(_seconds: float) -> None:
        raise KeyboardInterrupt

    monkeypatch.setattr(time, "sleep", no_sleep)

    args = build_parser().parse_args(["bridge", "--port", "0", "--token", "t"])
    assert _cmd_bridge(args, _NoDevice()) == 0  # type: ignore[arg-type]
    assert events == ["start", "stop"]
