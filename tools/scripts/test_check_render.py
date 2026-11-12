import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tools" / "checks" / "check-render.py"


def _load():
    spec = importlib.util.spec_from_file_location("check_render", CHECKER)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def _blueprint(tmp_path: pathlib.Path, build: str, start: str) -> pathlib.Path:
    path = tmp_path / "render.yaml"
    path.write_text(
        "services:\n"
        "  - type: web\n"
        "    name: test-relay\n"
        f"    buildCommand: {build}\n"
        f"    startCommand: {start}\n"
        "    healthCheckPath: /health\n",
        encoding="utf-8",
    )
    return path


def test_the_repository_blueprint_is_consistent():
    checker = _load()
    assert checker.check() == []


def test_a_missing_build_path_is_reported(tmp_path):
    checker = _load()
    blueprint = _blueprint(
        tmp_path, "pip install --no-deps ./packages/wire", "python -m json.tool"
    )
    problems = checker.check(blueprint, tmp_path)
    assert any("missing path" in problem for problem in problems)


def test_an_existing_path_and_module_pass(tmp_path):
    checker = _load()
    (tmp_path / "packages" / "wire" / "src" / "hopa_wire").mkdir(parents=True)
    (tmp_path / "packages" / "wire" / "src" / "hopa_wire" / "__init__.py").write_text(
        ""
    )
    blueprint = _blueprint(
        tmp_path, "pip install ./packages/wire", "python -m hopa_wire"
    )
    assert checker.check(blueprint, tmp_path) == []


def test_an_unknown_start_module_is_reported(tmp_path):
    checker = _load()
    blueprint = _blueprint(tmp_path, "pip install .", "python -m hopa_missing")
    problems = checker.check(blueprint, tmp_path)
    assert any("unknown module" in problem for problem in problems)


def test_a_relative_health_path_is_reported(tmp_path):
    checker = _load()
    blueprint = _blueprint(tmp_path, "pip install .", "python -m json.tool")
    text = blueprint.read_text(encoding="utf-8").replace(
        "healthCheckPath: /health", "healthCheckPath: health"
    )
    blueprint.write_text(text, encoding="utf-8")
    problems = checker.check(blueprint, tmp_path)
    assert any("healthCheckPath" in problem for problem in problems)
