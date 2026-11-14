import subprocess
from pathlib import Path

import pytest

from hopa_bridge import bridge


def test_transcribe_wav_returns_engine_text(monkeypatch):
    seen: dict[str, list[str]] = {}

    def fake(script: Path, args: list[str], timeout: float = 30.0):
        seen["args"] = args
        return subprocess.CompletedProcess(args, 0, "open weibo", "")

    monkeypatch.setattr(bridge, "_powershell", fake)
    assert bridge.transcribe_wav(b"RIFFxxxx") == "open weibo"
    assert seen["args"][0] == "-Mode"
    assert seen["args"][1] == "transcribe"


def test_transcribe_wav_reports_engine_failure(monkeypatch):
    def fake(script: Path, args: list[str], timeout: float = 30.0):
        return subprocess.CompletedProcess(args, 1, "", "engine missing")

    monkeypatch.setattr(bridge, "_powershell", fake)
    with pytest.raises(bridge.BridgeError):
        bridge.transcribe_wav(b"RIFFxxxx")


def test_speak_wav_returns_rendered_file(monkeypatch, tmp_path):
    def fake(script: Path, args: list[str], timeout: float = 30.0):
        target = args[args.index("-Out") + 1]
        Path(target).write_bytes(b"RIFF-reply")
        return subprocess.CompletedProcess(args, 0, "", "")

    monkeypatch.setattr(bridge, "_powershell", fake)
    assert bridge.speak_wav("hello") == b"RIFF-reply"
