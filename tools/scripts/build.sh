#!/usr/bin/env bash
# Build the HOPA HAP with DevEco Studio or the Command Line Tools.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
APP="$ROOT/app"

if [ -n "${HOPA_CLT_HOME:-}" ] && [ -x "$HOPA_CLT_HOME/bin/hvigorw" ]; then
  export DEVECO_SDK_HOME="$HOPA_CLT_HOME/sdk"
  export PATH="$HOPA_CLT_HOME/bin:$HOPA_CLT_HOME/sdk/default/openharmony/toolchains:$PATH"
  HVIGORW="$HOPA_CLT_HOME/bin/hvigorw"
elif [ -x "/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw" ]; then
  DEV="/Applications/DevEco-Studio.app/Contents"
  export DEVECO_SDK_HOME="$DEV/sdk"
  export PATH="$DEV/tools/node:$DEV/tools/ohpm/bin:$DEV/sdk/default/openharmony/toolchains:$PATH"
  HVIGORW="$DEV/tools/hvigor/bin/hvigorw"
elif command -v hvigorw >/dev/null 2>&1; then
  HVIGORW=$(command -v hvigorw)
else
  echo "hvigorw not found. Set HOPA_CLT_HOME or add the toolchain bin directory to PATH." >&2
  exit 2
fi

cd "$APP"
if command -v ohpm >/dev/null 2>&1; then
  ohpm install
fi
"$HVIGORW" assembleHap --no-daemon

find "$APP/entry/build/default/outputs/default" -name '*.hap' -print 2>/dev/null || true
