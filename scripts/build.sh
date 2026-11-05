#!/usr/bin/env bash
# Build the HOPA HAP from the command line (macOS/Linux, CI).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="$root/app"

hvigorw="${HVIGORW:-}"
if [[ -z "$hvigorw" && -n "${HOPA_CLT_HOME:-}" && -x "$HOPA_CLT_HOME/bin/hvigorw" ]]; then
  hvigorw="$HOPA_CLT_HOME/bin/hvigorw"
fi
if [[ -z "$hvigorw" ]]; then
  hvigorw="$(command -v hvigorw || true)"
fi
if [[ -z "$hvigorw" ]]; then
  echo "hvigorw not found. Set HOPA_CLT_HOME or add the Command Line Tools bin directory to PATH." >&2
  exit 1
fi

cd "$app"
"$hvigorw" assembleHap --no-daemon

out="$app/entry/build/default/outputs/default"
if [[ -d "$out" ]]; then
  find "$out" -maxdepth 1 -name '*.hap' -print
fi
