"""adb command construction, without a device attached."""

from __future__ import annotations

import subprocess

import pytest

from hopa_bridge.adb import Adb, AdbError


class Runner:
    def __init__(self, outputs):
        self.outputs = outputs
        self.commands: list[list[str]] = []

    def __call__(self, args, capture_output=True, timeout=None):
        del capture_output, timeout
        self.commands.append(list(args))
        result = self.outputs(args)
        if isinstance(result, tuple):
            stdout, code = result
        else:
            stdout, code = result, 0
        if isinstance(stdout, str):
            stdout = stdout.encode()
        stderr = b"" if code == 0 else b"device offline"
        return subprocess.CompletedProcess(args, code, stdout, stderr)


def test_serial_is_passed_to_every_command() -> None:
    runner = Runner(lambda _args: "")
    adb = Adb(serial="emulator-5554", executable="adb", runner=runner)
    adb.shell("echo hi")
    assert runner.commands[0] == ["adb", "-s", "emulator-5554", "shell", "echo hi"]


def test_no_serial_means_the_only_device() -> None:
    runner = Runner(lambda _args: "")
    adb = Adb(executable="adb", runner=runner)
    adb.shell("true")
    assert runner.commands[0] == ["adb", "shell", "true"]


def test_devices_ignores_offline_targets() -> None:
    output = "List of devices attached\nemulator-5554\tdevice\nabc\toffline\n"
    runner = Runner(lambda _args: output)
    adb = Adb(executable="adb", runner=runner)
    assert adb.devices() == ["emulator-5554"]


def test_exec_out_returns_bytes() -> None:
    runner = Runner(lambda _args: b"\x89PNG")
    adb = Adb(executable="adb", runner=runner)
    assert adb.exec_out("screencap -p") == b"\x89PNG"


def test_a_failed_command_raises_with_stderr() -> None:
    runner = Runner(lambda _args: ("", 1))
    adb = Adb(executable="adb", runner=runner)
    with pytest.raises(AdbError, match="device offline"):
        adb.shell("false")
