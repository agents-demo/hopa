#!/usr/bin/env bash
# Run HOPA-Bench against the connected device with the stub model (macOS/Linux).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

py="${PYTHON:-}"
if [[ -z "$py" && -x "$root/.venv/bin/python" ]]; then py="$root/.venv/bin/python"; fi
if [[ -z "$py" ]]; then py="$(command -v python3 || command -v python || true)"; fi
if [[ -z "$py" ]]; then
  echo "Python 3.11+ not found." >&2
  exit 1
fi

if ! "$py" -c "import hopa_pc_agent, hopa_bench" >/dev/null 2>&1; then
  "$py" -m pip install -e "$root/pc-agent" -e "$root/bench"
fi

mkdir -p "$root/bench/results"
exec "$py" -m hopa_bench run \
  --tasks "$root/bench/tasks" \
  --out "$root/bench/results/latest.json" \
  "$@"
