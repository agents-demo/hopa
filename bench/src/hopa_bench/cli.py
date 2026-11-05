"""``bench`` command line."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import UTC, datetime
from pathlib import Path

from hopa_pc_agent.device import Device
from hopa_pc_agent.errors import HopaError

from . import __version__
from .runner import Runner, TaskResult
from .task import TaskError, load_tasks


def _default_tasks_dir() -> Path:
    cwd_tasks = Path.cwd() / "tasks"
    if cwd_tasks.is_dir():
        return cwd_tasks
    return Path(__file__).resolve().parents[2] / "tasks"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="bench",
        description="HOPA-Bench: run HarmonyOS GUI-agent tasks on a device.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--tasks", type=Path, default=None, help="task directory")
    common.add_argument("--json", action="store_true", help="emit JSON")

    run = sub.add_parser("run", parents=[common], help="run tasks")
    run.add_argument("--task", action="append", default=[], help="only these task ids")
    run.add_argument("--out", type=Path, help="write results JSON here")
    run.add_argument("--fail-on-task-error", action="store_true")
    run.add_argument("--target", help="hdc target/address")
    run.add_argument("--hdc", dest="hdc_path", help="path to the hdc executable")
    run.add_argument("--timeout", type=float, default=60.0)

    sub.add_parser("list", parents=[common], help="list tasks")
    sub.add_parser("validate", parents=[common], help="validate task files")

    return parser


def _load(args: argparse.Namespace):
    directory = args.tasks or _default_tasks_dir()
    if not directory.is_dir():
        raise TaskError(f"task directory not found: {directory}")
    return load_tasks(directory)


def _cmd_list(tasks) -> int:
    for task in tasks:
        print(f"{task.id}\t{task.app}\t{task.goal}")
    return 0


def _cmd_validate(tasks) -> int:
    for task in tasks:
        print(f"ok {task.id} ({task.success.type})")
    print(f"{len(tasks)} task(s) valid")
    return 0


def _cmd_run(args, tasks) -> int:
    if args.task:
        wanted = set(args.task)
        tasks = [task for task in tasks if task.id in wanted]
        missing = wanted - {task.id for task in tasks}
        if missing:
            print(f"bench: unknown task id(s): {', '.join(sorted(missing))}", file=sys.stderr)
            return 2

    device = Device(target=args.target, hdc_path=args.hdc_path, timeout=args.timeout)
    runner = Runner(device)
    results: list[TaskResult] = [runner.run_task(task) for task in tasks]

    payload = {
        "started_at": datetime.now(UTC).isoformat(),
        "total": len(results),
        "results": [result.as_dict() for result in results],
    }
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        _print_human(results)

    if args.fail_on_task_error and any(
        result.error is not None or result.success is False for result in results
    ):
        return 2
    return 0


def _print_human(results: list[TaskResult]) -> None:
    symbols = {True: "PASS", False: "FAIL", None: "UNKNOWN"}
    for result in results:
        label = symbols[result.success]
        detail = f" error={result.error}" if result.error else ""
        print(f"[{label}] {result.task_id} ({result.duration_s:.1f}s){detail}")
    passed = sum(1 for result in results if result.success is True)
    failed = sum(1 for result in results if result.success is False)
    unknown = sum(1 for result in results if result.success is None)
    errors = sum(1 for result in results if result.error is not None)
    print(
        f"Summary: {len(results)} task(s), {passed} pass, {failed} fail, "
        f"{unknown} unknown, {errors} error(s)"
    )


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        tasks = _load(args)
        if args.command == "list":
            return _cmd_list(tasks)
        if args.command == "validate":
            return _cmd_validate(tasks)
        if args.command == "run":
            return _cmd_run(args, tasks)
        parser.error(f"unknown command: {args.command}")
    except (TaskError, HopaError) as exc:
        print(f"bench: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
