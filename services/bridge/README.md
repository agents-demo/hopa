# hopa-bridge

Controls a HarmonyOS device or emulator over `hdc` + `uitest`. It works as a
**CLI** and as an **MCP stdio server**, and is the engine behind `bench/`.

Stdlib only — no runtime dependencies.

## Install

```bash
cd hopa-bridge
python -m venv .venv
# Windows: .\.venv\Scripts\Activate.ps1
# macOS/Linux: source .venv/bin/activate
python -m pip install -U pip
pip install -e ".[dev]"
```

`hdc` is discovered from (in order): `HOPA_HDC`, the toolchain under
`HOPA_CLT_HOME`, common install paths, then `PATH`.

## CLI

```bash
hopa-bridge devices
hopa-bridge dump --out layout.json
hopa-bridge dump --find "Wi-Fi"          # print matching nodes + centers
hopa-bridge tap 540 1200
hopa-bridge double-tap 540 1200
hopa-bridge long-press 540 1200
hopa-bridge type "hello world" --x 540 --y 900
hopa-bridge swipe 540 1800 540 600 --velocity 800
hopa-bridge screenshot --out screen.jpeg
hopa-bridge launch settings               # alias -> com.huawei.hmos.settings
hopa-bridge launch com.example.app --ability MainAbility
hopa-bridge stop com.example.app
hopa-bridge key Back
hopa-bridge install entry-default-signed.hap
hopa-bridge uninstall com.hopa.agent
```

Add `--json` before the subcommand for machine-readable output:

```bash
hopa-bridge --json dump --find "Settings"
```

## MCP server

```bash
hopa-bridge mcp
```

It speaks newline-delimited JSON-RPC over stdio and implements `initialize`,
`ping`, `tools/list`, and `tools/call`. Example client config:

```json
{
  "mcpServers": {
    "hopa": {
      "command": "hopa-bridge",
      "args": ["mcp", "--target", "127.0.0.1:5555"]
    }
  }
}
```

Tools exposed: `hopa_list_devices`, `hopa_dump_layout`, `hopa_tap`,
`hopa_swipe`, `hopa_type_text`, `hopa_screenshot`, `hopa_launch_app`,
`hopa_press_key`.

## Notes on commands (verified against Huawei docs)

| Need | Command |
| --- | --- |
| list devices | `hdc list targets` |
| dump layout | `hdc shell uitest dumpLayout -p /data/local/tmp/x.json` |
| tap | `hdc shell uitest uiInput click X Y` |
| type at point | `hdc shell uitest uiInput inputText X Y TEXT` |
| type at focus | `hdc shell uitest uiInput text TEXT` (API 18+) |
| swipe | `hdc shell uitest uiInput swipe X1 Y1 X2 Y2 VELOCITY` |
| key | `hdc shell uitest uiInput keyEvent Back` |
| screenshot | `hdc shell snapshot_display -f /data/local/tmp/x.jpeg` |
| launch | `hdc shell aa start -a EntryAbility -b BUNDLE` |

`uitest` must be available on the target (it is part of the standard HarmonyOS
image). The screen must be on and unlocked.
