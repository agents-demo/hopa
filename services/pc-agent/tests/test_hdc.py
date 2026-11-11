from __future__ import annotations

from hopa_pc_agent.hdc import Hdc, HdcResult, parse_targets


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


def test_network_target_retries_after_offline(monkeypatch) -> None:
    hdc = Hdc(hdc_path="hdc", target="127.0.0.1:5556")
    calls: list[list[str]] = []
    ensured: list[bool] = []

    def fake_execute(cmd: list[str], timeout: float) -> HdcResult:
        calls.append(cmd)
        if len(calls) == 1:
            return HdcResult("", "[Fail][E001005] Device not found or connected", 0)
        return HdcResult("ok", "", 0)

    monkeypatch.setattr(hdc, "_execute", fake_execute)
    monkeypatch.setattr(hdc, "_ensure_target", lambda: ensured.append(True))

    result = hdc.run("shell", "echo hi")

    assert result.stdout == "ok"
    assert ensured == [True]
    assert len(calls) == 2


def test_usb_target_is_not_reconnected(monkeypatch) -> None:
    hdc = Hdc(hdc_path="hdc", target="63Q0226113049275")
    ensured: list[bool] = []
    monkeypatch.setattr(hdc, "_ensure_target", lambda: ensured.append(True))
    monkeypatch.setattr(hdc, "_execute", lambda cmd, timeout: HdcResult("ok", "", 0))

    hdc.run("shell", "echo hi")

    assert ensured == []


def test_network_target_resets_a_dead_session(monkeypatch) -> None:
    hdc = Hdc(hdc_path="hdc", target="127.0.0.1:5556")
    calls: list[list[str]] = []
    ensured: list[bool] = []
    resets: list[bool] = []

    def fake_execute(cmd: list[str], timeout: float) -> HdcResult:
        calls.append(cmd)
        if len(calls) <= 2:
            return HdcResult("", "[F] Send isDead Bind target session is dead", 0)
        return HdcResult("ok", "", 0)

    monkeypatch.setattr(hdc, "_execute", fake_execute)
    monkeypatch.setattr(hdc, "_ensure_target", lambda: ensured.append(True))
    monkeypatch.setattr(hdc, "_reset_hdc_server", lambda: resets.append(True))

    result = hdc.run("shell", "echo hi")

    assert result.stdout == "ok"
    assert resets == [True]
    assert ensured == [True, True]
    assert len(calls) == 3


def test_usb_target_never_resets_hdc(monkeypatch) -> None:
    hdc = Hdc(hdc_path="hdc", target="63Q0226113049275")
    resets: list[bool] = []
    monkeypatch.setattr(
        hdc,
        "_execute",
        lambda cmd, timeout: HdcResult("", "Bind target session is dead", 0),
    )
    monkeypatch.setattr(hdc, "_reset_hdc_server", lambda: resets.append(True))

    hdc.run("shell", "echo hi")

    assert resets == []


def test_recover_resets_only_network_targets(monkeypatch) -> None:
    network = Hdc(hdc_path="hdc", target="127.0.0.1:5556")
    resets: list[bool] = []
    ensured: list[bool] = []
    monkeypatch.setattr(network, "_reset_hdc_server", lambda: resets.append(True))
    monkeypatch.setattr(network, "_ensure_target", lambda: ensured.append(True))

    assert network.recover() is True
    assert resets == [True]
    assert ensured == [True]

    usb = Hdc(hdc_path="hdc", target="63Q0226113049275")
    monkeypatch.setattr(usb, "_reset_hdc_server", lambda: resets.append(False))

    assert usb.recover() is False
    assert resets == [True]
