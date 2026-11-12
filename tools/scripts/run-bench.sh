#!/usr/bin/env bash
# Run HOPA-Bench against the connected device with the stub model.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
RESULTS="$ROOT/evals/bench/results/latest.json"

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

"$PY" -c "import hopa_pc_agent, hopa_bench" 2>/dev/null || {
  "$PY" -m pip install -e "$ROOT/services/pc-agent" -e "$ROOT/evals/bench"
}

"$PY" -m hopa_bench run --tasks "$ROOT/evals/bench/tasks" --out "$RESULTS" "$@"
