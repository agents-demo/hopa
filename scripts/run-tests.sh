#!/usr/bin/env bash
# Run Python, brain and ArkTS tests, plus lint and plan checks.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [ -x "$ROOT/.venv/bin/python" ]; then
  PY="$ROOT/.venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "Python 3.11+ not found." >&2
  exit 2
fi

echo "=== installing Python packages (editable) ==="
"$PY" -m pip install -U pip
"$PY" -m pip install -e "$ROOT/pc-agent" -e "$ROOT/bench[dev]" -e "$ROOT/agent[dev]"

echo "=== Python tests ==="
"$PY" -m pytest "$ROOT/pc-agent" "$ROOT/bench" "$ROOT/agent" "$ROOT/scripts" -q

echo "=== agent coverage ==="
"$PY" -m pytest "$ROOT/agent" --cov=hopa_agent --cov-report=term --cov-fail-under=80 -q

echo "=== ruff ==="
"$PY" -m ruff check "$ROOT/pc-agent" "$ROOT/bench" "$ROOT/agent"
"$PY" -m ruff format --check "$ROOT/pc-agent" "$ROOT/bench" "$ROOT/agent"

echo "=== plan lint ==="
"$PY" "$ROOT/scripts/plan-status.py" --lint

echo "=== brain tests ==="
if [ -x "$ROOT/.tools/kotlinc/bin/kotlinc" ] || command -v java >/dev/null 2>&1; then
  bash "$ROOT/scripts/brain.sh"
else
  echo "Java not found; skipping brain tests." >&2
fi

echo "=== ArkTS tests ==="
if [ -n "${HOPA_CLT_HOME:-}" ] && [ -x "$HOPA_CLT_HOME/bin/hvigorw" ]; then
  export DEVECO_SDK_HOME="$HOPA_CLT_HOME/sdk"
  HVIGORW="$HOPA_CLT_HOME/bin/hvigorw"
elif [ -x "/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw" ]; then
  DEV="/Applications/DevEco-Studio.app/Contents"
  export DEVECO_SDK_HOME="$DEV/sdk"
  export PATH="$DEV/tools/node:$DEV/tools/ohpm/bin:$DEV/sdk/default/openharmony/toolchains:$PATH"
  HVIGORW="$DEV/tools/hvigor/bin/hvigorw"
elif command -v hvigorw >/dev/null 2>&1; then
  HVIGORW=$(command -v hvigorw)
else
  echo "hvigorw not found; skipping ArkTS tests." >&2
  echo "All available tests passed."
  exit 0
fi

cd "$ROOT/app"
if command -v ohpm >/dev/null 2>&1; then
  ohpm install
fi
"$HVIGORW" test -p module=core@default --no-daemon -p coverage=false

echo "All tests passed."
