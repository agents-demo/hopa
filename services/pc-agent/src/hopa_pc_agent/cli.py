"""``pc-agent`` command line interface."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

from . import __version__
from .device import Device
from .errors import HopaError
from .layout import Layout

# Preinstalled-app bundle ids common on HarmonyOS NEXT. Region/device builds can
# differ; pass an explicit bundle to `launch` when they do.
KNOWN_APPS = {
    "settings": "com.huawei.hmos.settings",
    "clock": "com.huawei.hmos.clock",
    "calendar": "com.huawei.hmos.calendar",
    "browser": "com.huawei.hmos.browser",
    "notes": "com.huawei.hmos.notepad",
}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="pc-agent",
        description="Control a HarmonyOS device over hdc + uitest.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    parser.add_argument("--target", help="hdc target/address (default: the only one)")
    parser.add_argument("--hdc", dest="hdc_path", help="path to the hdc executable")
    parser.add_argument("--timeout", type=float, default=60.0, help="command timeout (s)")
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")

    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("devices", help="list connected hdc targets")

    apps = sub.add_parser("apps", help="list installed app bundles")
    apps.add_argument("--query", help="filter bundles by substring")

    dump = sub.add_parser("dump", help="dump the current UI layout")
    dump.add_argument("--out", type=Path, help="write the raw layout JSON here")
    dump.add_argument("--find", metavar="TEXT", help="show nodes whose text contains TEXT")
    dump.add_argument("--find-id", metavar="ID", help="show nodes whose id contains ID")
    dump.add_argument("--include-attrs", action="store_true", help="dump extra attributes (-a)")

    tap = sub.add_parser("tap", help="tap at a coordinate")
    tap.add_argument("x", type=int)
    tap.add_argument("y", type=int)

    double = sub.add_parser("double-tap", help="double tap at a coordinate")
    double.add_argument("x", type=int)
    double.add_argument("y", type=int)

    long_press = sub.add_parser("long-press", help="long press at a coordinate")
    long_press.add_argument("x", type=int)
    long_press.add_argument("y", type=int)

    type_cmd = sub.add_parser("type", help="type text (optionally at a coordinate)")
    type_cmd.add_argument("text")
    type_cmd.add_argument("--x", type=int, help="x of the target text box")
    type_cmd.add_argument("--y", type=int, help="y of the target text box")

    swipe = sub.add_parser("swipe", help="swipe from one point to another")
    swipe.add_argument("from_x", type=int)
    swipe.add_argument("from_y", type=int)
    swipe.add_argument("to_x", type=int)
    swipe.add_argument("to_y", type=int)
    swipe.add_argument("--velocity", type=int, default=600, help="px/s (200-40000)")

    shot = sub.add_parser("screenshot", help="capture a screenshot")
    shot.add_argument("--out", type=Path, default=Path("screen.jpeg"))

    launch = sub.add_parser("launch", help="launch an app")
    launch.add_argument("bundle", help="bundle name or a known alias (settings, clock, ...)")
    launch.add_argument(
        "--ability", default="", help="ability name; default tries MainAbility then EntryAbility"
    )

    stop = sub.add_parser("stop", help="force-stop an app")
    stop.add_argument("bundle")

    key = sub.add_parser("key", help="send a key event (e.g. Back, Home)")
    key.add_argument("name")

    install = sub.add_parser("install", help="install a HAP")
    install.add_argument("hap", type=Path)

    uninstall = sub.add_parser("uninstall", help="uninstall a bundle")
    uninstall.add_argument("bundle")

    sub.add_parser("mcp", help="run as an MCP stdio server")

    bridge = sub.add_parser("bridge", help="serve the PC-tethered HTTP bridge")
    bridge.add_argument("--host", default="127.0.0.1")
    bridge.add_argument("--port", type=int, default=8765)
    bridge.add_argument("--token", default=os.environ.get("HOPA_BRIDGE_TOKEN", ""))
    bridge.add_argument("--pair-code", default=os.environ.get("HOPA_PAIR_CODE", ""))
    bridge.add_argument(
        "--sessions-key",
        default=os.environ.get("HOPA_SESSIONS_KEY", ""),
        help="read-only key another device can use to read /sessions",
    )
    bridge.add_argument(
        "--chats",
        default="",
        help="conversation store shared by every device (default ~/.hopa/chats.json)",
    )
    bridge.add_argument(
        "--devices",
        default="",
        help="JSON file listing several devices; one listener serves them all "
        "(entry: serial, token, pair, role, state, sessions_key)",
    )
    bridge.add_argument(
        "--state",
        default="",
        help="file that keeps the token pair across restarts (default ~/.hopa/bridge-<port>.json)",
    )
    bridge.add_argument(
        "--no-state",
        action="store_true",
        help="do not persist the pair: every restart needs a fresh pairing",
    )
    bridge.add_argument(
        "--token-ttl-hours",
        type=float,
        default=float(os.environ.get("HOPA_TOKEN_TTL_HOURS", "12")),
        help="hours an access token stays valid before the phone refreshes it",
    )

    return parser


def _make_device(args: argparse.Namespace) -> Device:
    return Device(target=args.target, hdc_path=args.hdc_path, timeout=args.timeout)


def _layout_summary(layout: Layout) -> dict[str, Any]:
    nodes = list(layout.walk())
    return {
        "nodes": len(nodes),
        "clickable": len(layout.clickable()),
        "texts": [text for text in layout.texts() if text.strip()][:200],
    }


def _emit(args: argparse.Namespace, payload: Any, human: str) -> None:
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(human)


def _cmd_bridge(args: argparse.Namespace, device: Device) -> int:
    import secrets
    import time

    from .bridge import BridgeError, BridgeServer

    ttl_hours = max(0.05, args.token_ttl_hours)

    if args.devices:
        from .bridge import BridgeError
        from .bridge_pool import BridgePool
        from .chat_store import ChatStore

        chats_path = args.chats or str(Path.home() / ".hopa" / "chats.json")
        chats = ChatStore(chats_path)
        try:
            entries = json.loads(Path(args.devices).read_text(encoding="utf-8-sig"))
        except (OSError, ValueError) as exc:
            print(f"pc-agent: cannot read {args.devices}: {exc}", file=sys.stderr)
            return 2
        if not isinstance(entries, list) or not entries:
            print("pc-agent: --devices needs a non-empty JSON list", file=sys.stderr)
            return 2
        try:
            pool = BridgePool(
                entries,
                host=args.host,
                port=args.port,
                token_ttl=ttl_hours * 3600,
                chats=chats,
            )
        except (BridgeError, ValueError, KeyError) as exc:
            print(f"pc-agent: {exc}", file=sys.stderr)
            return 2
        pool.start()
        print(f"bridge listening on http://{args.host}:{pool.port} (pool)", flush=True)
        print(f"conversations: {chats_path} (rev {chats.rev})", flush=True)
        for entry in entries:
            serial = str(entry["serial"])
            node = pool.node_for(serial)
            role = next((r for r, s in pool.roles.items() if s == serial), "")
            print(
                f"device {serial} role={role or '?'} token={entry['token']} "
                f"pair code={entry.get('pair', '')}",
                flush=True,
            )
            print(f"  sessions key (read-only): {node.sessions_key if node else ''}", flush=True)
        try:
            while True:
                time.sleep(3600)
        except KeyboardInterrupt:
            pass
        finally:
            pool.stop()
        return 0

    token = args.token or secrets.token_urlsafe(24)
    pair_code = args.pair_code or f"{secrets.randbelow(1_000_000):06d}"
    ttl_hours = max(0.05, args.token_ttl_hours)
    state_path = None
    if not args.no_state and args.port > 0:
        state_path = args.state or str(Path.home() / ".hopa" / f"bridge-{args.port}.json")
    try:
        server = BridgeServer(
            device,
            token,
            host=args.host,
            port=args.port,
            pair_code=pair_code,
            token_ttl=ttl_hours * 3600,
            sessions_key=args.sessions_key,
            state_path=state_path,
        )
    except BridgeError as exc:
        print(f"pc-agent: {exc}", file=sys.stderr)
        return 2
    server.start()
    print(f"bridge listening on http://{args.host}:{server.port}", flush=True)
    print(f"token: {token}", flush=True)
    print(f"pair code: {pair_code}", flush=True)
    print(f"token ttl: {ttl_hours:g} h", flush=True)
    if state_path is not None:
        kept = "kept a live pair" if server.restored else "new pair"
        print(f"state: {state_path} ({kept})", flush=True)
    print(f"sessions key (read-only): {server.sessions_key}", flush=True)
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        pass
    finally:
        server.stop()
    return 0


def _cmd_dump(args: argparse.Namespace, device: Device) -> int:
    layout = device.dump_layout(include_attrs=args.include_attrs)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(layout.raw, ensure_ascii=False, indent=2), encoding="utf-8")

    matches = []
    if args.find:
        matches = layout.find_by_text(args.find)
    elif args.find_id:
        matches = layout.find_by_id(args.find_id)

    if args.find or args.find_id:
        payload = [
            {
                "text": node.text,
                "description": node.description,
                "type": node.type,
                "id": node.id,
                "bounds": node.bounds,
                "center": node.center,
                "clickable": node.clickable,
            }
            for node in matches
        ]
        human = (
            "\n".join(
                f"{item['text'] or item['description'] or item['type']} "
                f"center={item['center']} bounds={item['bounds']} clickable={item['clickable']}"
                for item in payload
            )
            or "no matching nodes"
        )
        _emit(args, payload, human)
        return 0 if matches else 1

    summary = _layout_summary(layout)
    human = f"{summary['nodes']} nodes, {summary['clickable']} clickable\n" + "\n".join(
        f"- {text}" for text in summary["texts"][:40]
    )
    _emit(args, summary, human)
    return 0


def _cmd_launch(args: argparse.Namespace, device: Device) -> int:
    bundle = KNOWN_APPS.get(args.bundle.lower(), args.bundle)
    device.launch(bundle, ability=args.ability)
    _emit(args, {"bundle": bundle, "ability": args.ability}, f"launched {bundle}")
    return 0


def _dispatch(args: argparse.Namespace, device: Device) -> int:
    command = args.command

    if command == "bridge":
        return _cmd_bridge(args, device)

    if command == "devices":
        targets = device.devices()
        _emit(args, targets, "\n".join(targets) or "no devices")
        return 0 if targets else 1

    if command == "dump":
        return _cmd_dump(args, device)

    if command == "apps":
        installed = device.apps()
        if args.query:
            needle = args.query.lower()
            installed = [app for app in installed if needle in app["bundle"].lower()]
        _emit(
            args,
            installed,
            "\n".join(app["bundle"] for app in installed) or "no apps",
        )
        return 0 if installed else 1

    if command == "tap":
        device.tap(args.x, args.y)
        _emit(args, {"tap": [args.x, args.y]}, f"tapped {args.x},{args.y}")
        return 0

    if command == "double-tap":
        device.double_tap(args.x, args.y)
        _emit(args, {"double_tap": [args.x, args.y]}, f"double-tapped {args.x},{args.y}")
        return 0

    if command == "long-press":
        device.long_press(args.x, args.y)
        _emit(args, {"long_press": [args.x, args.y]}, f"long-pressed {args.x},{args.y}")
        return 0

    if command == "type":
        device.type_text(args.text, x=args.x, y=args.y)
        _emit(args, {"typed": args.text}, f"typed {args.text!r}")
        return 0

    if command == "swipe":
        device.swipe(
            args.from_x,
            args.from_y,
            args.to_x,
            args.to_y,
            velocity=args.velocity,
        )
        _emit(
            args,
            {"swipe": [args.from_x, args.from_y, args.to_x, args.to_y]},
            f"swiped {args.from_x},{args.from_y} -> {args.to_x},{args.to_y}",
        )
        return 0

    if command == "screenshot":
        path = device.screenshot(args.out)
        _emit(args, {"path": str(path)}, f"saved {path}")
        return 0

    if command == "launch":
        return _cmd_launch(args, device)

    if command == "stop":
        device.stop(args.bundle)
        _emit(args, {"stopped": args.bundle}, f"stopped {args.bundle}")
        return 0

    if command == "key":
        device.press_key(args.name)
        _emit(args, {"key": args.name}, f"pressed {args.name}")
        return 0

    if command == "install":
        output = device.install(args.hap)
        _emit(args, {"installed": str(args.hap), "output": output}, output.strip() or "installed")
        return 0

    if command == "uninstall":
        output = device.uninstall(args.bundle)
        _emit(args, {"uninstalled": args.bundle, "output": output}, output.strip() or "uninstalled")
        return 0

    if command == "mcp":
        from .mcp_server import serve_stdio

        serve_stdio(device)
        return 0

    raise HopaError(f"unknown command: {command}")


def main(argv: list[str] | None = None) -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        device = _make_device(args)
        return _dispatch(args, device)
    except HopaError as exc:
        print(f"pc-agent: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
