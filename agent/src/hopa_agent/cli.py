from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from hopa_pc_agent.device import Device
from hopa_pc_agent.errors import HopaError

from . import __version__
from .capture import capture
from .errors import AgentError, SchemaError
from .executor import DeviceExecutor
from .loop import AgentLoop
from .models import OpenAIClient, load_steps
from .policy import ApprovalRequest
from .records import RunStore


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="hopa-agent",
        description="HOPA reference loop: observe, decide, act, verify, record.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    observe = sub.add_parser("observe", help="capture and print one observation")
    observe.add_argument("--screenshot", action="store_true")
    observe.add_argument("--out", type=Path, default=None, help="screenshot directory")
    observe.add_argument("--app", default="")
    observe.add_argument("--json", action="store_true")
    _add_device_args(observe)

    run = sub.add_parser("run", help="run a goal")
    run.add_argument("goal")
    run.add_argument("--model", choices=["stub", "openai"], default="stub")
    run.add_argument("--steps", type=Path, help="JSON list of actions for the stub model")
    run.add_argument(
        "--base-url", default=os.environ.get("HOPA_BASE_URL", "https://api.openai.com/v1")
    )
    run.add_argument("--model-name", default=os.environ.get("HOPA_MODEL", "gpt-4o-mini"))
    run.add_argument("--api-key-env", default="HOPA_API_KEY")
    run.add_argument("--record", type=Path, default=Path(".hopa/runs.jsonl"))
    run.add_argument("--max-steps", type=int, default=12)
    run.add_argument("--max-seconds", type=float, default=300.0)
    run.add_argument("--screenshot", action="store_true")
    run.add_argument("--yes", action="store_true", help="approve sensitive actions, never payments")
    run.add_argument("--approve-payment", action="store_true", help="DANGEROUS: approve payments")
    run.add_argument("--json", action="store_true")
    _add_device_args(run)

    records = sub.add_parser("records", help="print recorded steps")
    records.add_argument("--path", type=Path, default=Path(".hopa/runs.jsonl"))
    records.add_argument("--run", dest="run_id", default=None)
    records.add_argument("--json", action="store_true")

    verify = sub.add_parser("verify-chain", help="verify the record hash chain")
    verify.add_argument("--path", type=Path, default=Path(".hopa/runs.jsonl"))

    return parser


def _add_device_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--target", help="hdc target/address")
    parser.add_argument("--hdc", dest="hdc_path", help="path to the hdc executable")
    parser.add_argument("--timeout", type=float, default=60.0)


def _make_device(args: argparse.Namespace) -> Device:
    return Device(target=args.target, hdc_path=args.hdc_path, timeout=args.timeout)


def _make_approver(*, yes: bool, approve_payment: bool):
    def approve(request: ApprovalRequest) -> bool:
        if request.classification == "payment" and not approve_payment:
            print(
                "hopa-agent: payment approval is disabled; pass --approve-payment to allow.",
                file=sys.stderr,
            )
            return False
        if yes:
            return True
        if not sys.stdin.isatty():
            print("hopa-agent: no interactive approver; denying.", file=sys.stderr)
            return False
        print("\nApproval required")
        print(f"  class:       {request.classification}")
        print(f"  reason:      {request.reason}")
        if request.amount:
            print(f"  amount:      {request.amount}")
        if request.merchant:
            print(f"  merchant:    {request.merchant}")
        print(f"  consequence: {request.consequence}")
        answer = input("Approve? [y/N] ").strip().lower()
        return answer in {"y", "yes"}

    return approve


def _cmd_observe(args: argparse.Namespace) -> int:
    device = _make_device(args)
    observation = capture(
        device,
        app=args.app,
        screenshot=args.screenshot,
        out_dir=args.out,
    )
    if args.json:
        print(json.dumps(observation.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(observation.summary())
        print(f"hash: {observation.hash}")
        if observation.text:
            print(observation.text[:500])
        for node in observation.clickable()[:40]:
            label = node.text or node.description or node.type
            print(f"  {node.ref} {label!r} {node.bounds}")
    return 0


def _cmd_run(args: argparse.Namespace) -> int:
    if args.model == "stub":
        if args.steps is None:
            print("hopa-agent: --steps is required for --model stub", file=sys.stderr)
            return 2
        model = load_steps(str(args.steps))
    else:
        api_key = os.environ.get(args.api_key_env, "")
        if not api_key:
            print(
                f"hopa-agent: environment variable {args.api_key_env} is empty",
                file=sys.stderr,
            )
            return 2
        model = OpenAIClient(
            api_key=api_key,
            model=args.model_name,
            base_url=args.base_url,
        )

    device = _make_device(args)
    store = RunStore(args.record)
    executor = DeviceExecutor(
        device,
        approver=_make_approver(yes=args.yes, approve_payment=args.approve_payment),
        store=store,
        screenshot=args.screenshot,
        out_dir=str(args.record.parent / "screens"),
    )
    loop = AgentLoop(
        executor, model, store=store, max_steps=args.max_steps, max_seconds=args.max_seconds
    )
    result = loop.run(args.goal)

    if args.json:
        print(json.dumps(result.as_dict(), ensure_ascii=False, indent=2))
    else:
        print(f"[{'PASS' if result.success else 'FAIL'}] {result.goal}")
        print(f"  run:    {result.run_id}")
        print(f"  reason: {result.reason}")
        print(f"  steps:  {result.steps}")
        if result.say:
            print(f"  say:    {result.say}")
        if result.error:
            print(f"  error:  {result.error}")
    return 0 if result.success else 1


def _cmd_records(args: argparse.Namespace) -> int:
    records = RunStore(args.path).read_all()
    if args.run_id:
        records = [record for record in records if record.run_id == args.run_id]
    if args.json:
        print(json.dumps([record.to_dict() for record in records], ensure_ascii=False, indent=2))
        return 0
    for record in records:
        kind = record.action.get("kind", "?")
        detail = f" error={record.error}" if record.error else ""
        print(
            f"{record.run_id} step={record.step} {kind} "
            f"class={record.classification} approved={record.approved} "
            f"executed={record.executed} verified={record.verified}{detail}"
        )
    print(f"{len(records)} record(s)")
    return 0


def _cmd_verify_chain(args: argparse.Namespace) -> int:
    errors = RunStore(args.path).verify_chain()
    if errors:
        for error in errors:
            print(f"FAIL {error}", file=sys.stderr)
        return 1
    print("ok: hash chain intact")
    return 0


def main(argv: list[str] | None = None) -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.command == "observe":
            return _cmd_observe(args)
        if args.command == "run":
            return _cmd_run(args)
        if args.command == "records":
            return _cmd_records(args)
        if args.command == "verify-chain":
            return _cmd_verify_chain(args)
        parser.error(f"unknown command: {args.command}")
    except (AgentError, SchemaError, HopaError) as exc:
        print(f"hopa-agent: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        return 130
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
