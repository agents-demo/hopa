import importlib.util
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tools" / "checks" / "check-openapi.py"


def _load():
    spec = importlib.util.spec_from_file_location("check_openapi", CHECKER)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_prefix_route_covers_the_spec_path():
    checker = _load()
    missing_spec, missing_code = checker.compare(
        literal={"/tap"},
        prefix={"/images/"},
        spec={"/tap", "/images/{id}"},
        declared_prefix=set(),
    )
    assert missing_spec == []
    assert missing_code == []


def test_route_in_code_and_missing_from_spec_is_reported():
    checker = _load()
    missing_spec, missing_code = checker.compare(
        literal={"/tap", "/shortcut"},
        prefix=set(),
        spec={"/tap"},
        declared_prefix=set(),
    )
    assert missing_spec == ["/shortcut"]
    assert missing_code == []


def test_spec_path_without_handler_is_reported():
    checker = _load()
    missing_spec, missing_code = checker.compare(
        literal={"/tap"}, prefix=set(), spec={"/tap", "/ghost"}, declared_prefix=set()
    )
    assert missing_spec == []
    assert missing_code == ["/ghost"]


def test_declared_prefix_is_allowed_on_both_sides():
    checker = _load()
    missing_spec, missing_code = checker.compare(
        literal=set(),
        prefix=set(),
        spec={"/d/{serial}/observe"},
        declared_prefix={"/d/{serial}"},
    )
    assert missing_spec == []
    assert missing_code == []


def test_the_repository_is_consistent():
    result = subprocess.run(
        [sys.executable, str(CHECKER)], capture_output=True, text=True, check=False
    )
    assert result.returncode == 0, result.stdout + result.stderr
