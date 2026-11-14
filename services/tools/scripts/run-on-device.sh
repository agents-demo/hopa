#!/usr/bin/env bash
# Build, sign, install and launch HOPA on the connected emulator/device (macOS/Linux).
#
#   ./services/tools/scripts/run-on-device.sh                       # full cycle
#   ./services/tools/scripts/run-on-device.sh --skip-build          # reuse the last build
#   ./services/tools/scripts/run-on-device.sh --target 127.0.0.1:5555
#   ./services/tools/scripts/run-on-device.sh --skip-sign           # reuse the signed HAP
#
# The debug profile embeds the target's UDID, so the script reads it from the
# selected device before signing. Nothing leaves the machine.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT="$ROOT/apps/harmony/entry/build/default/outputs/default"
SIGNED="$OUT/entry-default-signed.hap"
UNSIGNED="$OUT/entry-default-unsigned.hap"

SKIP_BUILD=0
SKIP_SIGN=0
TARGET=${HOPA_TARGET:-}
BUNDLE=${HOPA_BUNDLE:-com.hopa.agent}
ABILITY=${HOPA_ABILITY:-EntryAbility}

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --skip-sign) SKIP_SIGN=1 ;;
    --target) shift; TARGET=${1:-} ;;
    --bundle) shift; BUNDLE=${1:-} ;;
    --ability) shift; ABILITY=${1:-} ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

find_hdc() {
  for candidate in \
    "${HOPA_CLT_HOME:-}/sdk/default/openharmony/toolchains/hdc" \
    "${HOPA_CLT_HOME:-}/sdk/default/openharmony/toolchains/hdc.exe" \
    "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc" \
    "/opt/huawei/sdk/default/openharmony/toolchains/hdc"; do
    if [ -x "$candidate" ] || [ -f "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  command -v hdc
}

HDC=$(find_hdc)
if [ -z "$HDC" ]; then
  echo "hdc not found. Set HOPA_CLT_HOME or add the toolchains directory to PATH." >&2
  exit 1
fi

# --- pick a target ---------------------------------------------------------
if [ -z "$TARGET" ]; then
  targets=$("$HDC" list targets | tr -d '\r' | grep -v '^\[Empty\]$' | grep -v '^$' || true)
  count=$(printf '%s\n' "$targets" | grep -c . || true)
  if [ "$count" -eq 0 ]; then
    echo "No device/emulator connected. Start the emulator or connect USB, then check 'hdc list targets'." >&2
    exit 1
  fi
  if [ "$count" -gt 1 ]; then
    echo "More than one target connected ($(echo "$targets" | tr '\n' ' ')). Pass --target <id>." >&2
    exit 1
  fi
  TARGET=$targets
fi
echo "Target: $TARGET"

# --- build ----------------------------------------------------------------
if [ "$SKIP_BUILD" -eq 0 ]; then
  echo "=== build ==="
  "$ROOT/tools/scripts/build.sh"
fi
if [ ! -f "$UNSIGNED" ]; then
  echo "Unsigned HAP not found: $UNSIGNED. Run without --skip-build first." >&2
  exit 1
fi

# --- sign -----------------------------------------------------------------
if [ "$SKIP_SIGN" -eq 0 ]; then
  echo "=== sign ==="
  UDID=$("$HDC" -t "$TARGET" shell bm get --udid | grep -oE '[0-9A-Fa-f]{64}' | head -n 1 || true)
  if [ -z "$UDID" ]; then
    echo "Could not read the device UDID from '$TARGET'." >&2
    exit 1
  fi
  "$ROOT/tools/scripts/sign-app.sh" --udid "$UDID" --bundle "$BUNDLE"
fi
if [ ! -f "$SIGNED" ]; then
  echo "Signed HAP not found: $SIGNED. Run without --skip-sign first." >&2
  exit 1
fi

# --- install --------------------------------------------------------------
echo "=== install ==="
"$HDC" -t "$TARGET" install -r "$SIGNED"

# --- launch ---------------------------------------------------------------
echo "=== launch $BUNDLE/$ABILITY ==="
"$HDC" -t "$TARGET" shell aa start -a "$ABILITY" -b "$BUNDLE"

echo
echo "HOPA is running on $TARGET."
