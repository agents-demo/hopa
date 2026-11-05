#!/usr/bin/env pwsh
# Run HOPA-Bench against the connected device with the stub model (Windows).
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BenchArgs
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Resolve-Python {
    $venv = Join-Path $root '.venv\Scripts\python.exe'
    if (Test-Path $venv) { return $venv }
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'Python 3.11+ not found.'
}

$py = Resolve-Python
$results = Join-Path $root 'bench\results\latest.json'

& $py -c "import hopa_pc_agent, hopa_bench" 2>$null
if ($LASTEXITCODE -ne 0) {
    & $py -m pip install -e (Join-Path $root 'pc-agent') -e (Join-Path $root 'bench')
    if ($LASTEXITCODE -ne 0) { throw 'pip install failed' }
}

& $py -m hopa_bench run --tasks (Join-Path $root 'bench\tasks') --out $results @BenchArgs
exit $LASTEXITCODE
