package com.hopa.sidecar.cli

/** Printed by `--help`; one place, so the options and the text cannot drift. */
internal const val USAGE = """hopa-sidecar — the HOPA engine host for Windows

Usage:
  hopa-sidecar                              speak NDJSON on stdin/stdout (the window)
  hopa-sidecar --turn "say hello"           run one turn headless and print JSON
  hopa-sidecar --pair-backend <url>         admit this PC to the backend, then speak NDJSON
  hopa-sidecar --version

Options:
  --turn <goal>          run one turn, print the turn envelope on stdout, exit
  --data-dir <path>      conversations, records and attachments (default ~/.hopa/windows)
  --conversation <id>    continue that conversation instead of creating one
  --pair-backend <url>   admit synchronously before the stdio loop, printing the QR on stderr
  --help                 print this text

Headless is deterministic by construction: no model key is loaded, so the engine
uses the scripted proposer, and no host is attached, so approvals deny and
actions refuse. Nothing in headless mode can allow an action."""
