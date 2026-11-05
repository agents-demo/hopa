#!/usr/bin/env bash
# Run core unit tests (host) plus pc-agent/bench pytest and ruff (macOS/Linux).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

py="${PYTHON:-}"
if [[ -z "$py" && -x "$root/.venv/bin/python" ]]; then py="$root/.venv/bin/python"; fi
if [[ -z "$py" ]]; then py="$(command -v python3 || command -v python || true)"; fi
if [[ -z "$py" ]]; then
  echo "Python 3.11+ not found. Install it and/or create .venv at the repo root." >&2
  exit 1
fi

# Ensure the Python packages are installed in editable mode.
if ! "$py" -c "import hopa_pc_agent, hopa_bench" >/dev/null 2>&1; then
  echo '--- installing pc-agent and bench (editable) ---'
  "$py" -m pip install -e "$root/pc-agent" -e "$root/bench"
fi

if [[ "$(uname -s)" == "Linux" ]]; then
  echo 'Skipping core local unit tests: hvigorw Local Test is not supported on Linux.'
  echo 'Run them on Windows/macOS (see docs/setup.md §8).'
else
  hvigorw="${HVIGORW:-}"
  if [[ -z "$hvigorw" && -n "${HOPA_CLT_HOME:-}" && -x "$HOPA_CLT_HOME/bin/hvigorw" ]]; then
    hvigorw="$HOPA_CLT_HOME/bin/hvigorw"
  fi
  if [[ -z "$hvigorw" ]]; then hvigorw="$(command -v hvigorw || true)"; fi
  if [[ -n "$hvigorw" ]]; then
    echo '--- core local unit tests ---'
    ( cd "$root/app" && "$hvigorw" test -p module=core@default --no-daemon -p coverage=false )
  else
    echo 'WARNING: hvigorw not found; skipping core local unit tests.' >&2
  fi
fi

echo '--- pc-agent pytest ---'
"$py" -m pytest "$root/pc-agent"
echo '--- bench pytest ---'
"$py" -m pytest "$root/bench"
echo '--- ruff ---'
"$py" -m ruff check "$root/pc-agent" "$root/bench"

echo 'All tests passed.'
