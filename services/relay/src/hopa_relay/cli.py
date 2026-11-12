"""hopa-relay: one command, one deployable."""

from __future__ import annotations

import argparse

from . import __version__
from .relay_server import serve_relay


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="hopa-relay",
        description="Run the HOPA cloud relay (the half a linked PC dials out to).",
    )
    parser.add_argument("--version", action="version", version=__version__)
    sub = parser.add_subparsers(dest="command", required=True)

    relay = sub.add_parser("relay", help="serve the relay")
    relay.add_argument("--host", default="0.0.0.0")
    relay.add_argument("--port", type=int, default=8790)
    relay.add_argument("--token", default="", help="phone token (env HOPA_BRIDGE_TOKEN)")
    relay.add_argument("--link-token", default="", help="PC link token (env HOPA_LINK_TOKEN)")
    relay.add_argument(
        "--pair-code", default="", help="short code that issues a pair (env HOPA_PAIR_CODE)"
    )
    relay.add_argument("--token-ttl-hours", type=float, default=12.0)
    relay.add_argument("--wait-seconds", type=float, default=45.0)
    relay.add_argument("--poll-seconds", type=float, default=25.0)
    return parser


def main(argv: list[str] | None = None) -> int:
    import os

    parser = build_parser()
    args = parser.parse_args(argv)
    if not getattr(args, "token", ""):
        args.token = os.environ.get("HOPA_BRIDGE_TOKEN", "")
    if not getattr(args, "link_token", ""):
        args.link_token = os.environ.get("HOPA_LINK_TOKEN", "")
    if not getattr(args, "pair_code", ""):
        args.pair_code = os.environ.get("HOPA_PAIR_CODE", "")
    if args.command == "relay":
        return serve_relay(args)
    parser.error("unknown command")
    return 2
