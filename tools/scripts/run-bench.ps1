#!/usr/bin/env pwsh
# Run HOPA-Bench against the connected device with the stub model (Windows).
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BenchArgs
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$venv = Join-Path $root '.venv\Scripts\python.exe'

if (Test-Path $venv) {
    $pythonExe = $venv
    $pythonPrefix = @()
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    $pythonExe = 'py'
    $pythonPrefix = @('-3')
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonExe = 'python'
    $pythonPrefix = @()
} else {
    throw 'Python 3.11+ not found.'
}

$results = Join-Path $root 'evals\bench\results\latest.json'
& $pythonExe @pythonPrefix -c "import hopa_bridge, hopa_bench" 2>$null
if ($LASTEXITCODE -ne 0) {
    & $pythonExe @pythonPrefix -m pip install -e (Join-Path $root 'services\wire', 'services\bridge') -e (Join-Path $root 'evals\bench')
    if ($LASTEXITCODE -ne 0) { throw 'pip install failed' }
}

& $pythonExe @pythonPrefix -m hopa_bench run --tasks (Join-Path $root 'evals\bench\tasks') --out $results @BenchArgs
exit $LASTEXITCODE
