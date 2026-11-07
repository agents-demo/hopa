#!/usr/bin/env bash
# Install the built HAP on the connected emulator/device and launch it.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
app="$root/app"
out="$app/entry/build/default/outputs/default"
bundle='com.hopa.agent'
ability='EntryAbility'

hdc="${HDC:-}"
if [[ -z "$hdc" && -n "${HOPA_CLT_HOME:-}" ]]; then
  for candidate in "$HOPA_CLT_HOME/sdk/default/openharmony/toolchains/hdc" \
                   "$HOPA_CLT_HOME/sdk/default/openharmony/toolchains/hdc.exe"; do
    if [[ -x "$candidate" || -f "$candidate" ]]; then hdc="$candidate"; break; fi
  done
fi
if [[ -z "$hdc" ]]; then hdc="$(command -v hdc || true)"; fi
if [[ -z "$hdc" ]]; then
  echo "hdc not found. Set HOPA_CLT_HOME or add the toolchains directory to PATH." >&2
  exit 1
fi

hap="$(find "$out" -maxdepth 1 -name '*-signed.hap' -print -quit 2>/dev/null || true)"
if [[ -z "$hap" ]]; then
  hap="$(find "$out" -maxdepth 1 -name '*.hap' -print -quit 2>/dev/null || true)"
fi
if [[ -z "$hap" ]]; then
  echo "No HAP found in $out. Run scripts/build.sh first." >&2
  exit 1
fi

echo "--- targets ---"
"$hdc" list targets
echo "--- installing $(basename "$hap") ---"
"$hdc" install -r "$hap"
echo "--- launching $bundle/$ability ---"
"$hdc" shell aa start -a "$ability" -b "$bundle"
