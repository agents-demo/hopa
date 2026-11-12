import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
CHECKER = ROOT / "tools" / "checks" / "check-tree.py"


def _load():
    spec = importlib.util.spec_from_file_location("check_tree", CHECKER)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def _tree(base: pathlib.Path, *names: str) -> None:
    for name in names:
        (base / name).mkdir(parents=True, exist_ok=True)


def test_the_repository_is_allowed():
    checker = _load()
    assert checker.check() == []


def test_unknown_top_level_folder_is_reported(tmp_path):
    checker = _load()
    _tree(tmp_path, "apps", "services", "surprise")
    problems = checker.check(tmp_path)
    assert any("surprise" in problem for problem in problems)


def test_harness_is_rejected_even_if_allow_listed(tmp_path):
    checker = _load()
    _tree(tmp_path, "apps", "harness")
    problems = checker.check(tmp_path)
    assert any("harness" in problem for problem in problems)


def test_junk_drawer_is_rejected_at_any_depth(tmp_path):
    checker = _load()
    _tree(tmp_path, "apps", "apps/harmony/utils")
    problems = checker.check(tmp_path)
    assert any("utils" in problem for problem in problems)


def test_dot_folders_and_build_output_are_ignored(tmp_path):
    checker = _load()
    _tree(tmp_path, "apps", ".venv", "apps/harmony/build", "apps/harmony/oh_modules")
    assert checker.check(tmp_path) == []
