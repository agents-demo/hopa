#!/usr/bin/env pwsh
# Run core unit tests (host) plus pc-agent/bench pytest and ruff (Windows).
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

function Resolve-Python {
    $venv = Join-Path $root '.venv\Scripts\python.exe'
    if (Test-Path $venv) { return $venv }
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'Python 3.11+ not found. Install it and/or create .venv at the repo root.'
}

function Resolve-Hvigorw {
    if ($env:HOPA_CLT_HOME) {
        $candidate = Join-Path $env:HOPA_CLT_HOME 'bin\hvigorw.bat'
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command hvigorw -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$py = Resolve-Python

# Ensure the Python packages are installed in editable mode.
& $py -c "import hopa_pc_agent, hopa_bench" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host '--- installing pc-agent and bench (editable) ---'
    & $py -m pip install -e (Join-Path $root 'pc-agent') -e (Join-Path $root 'bench')
    if ($LASTEXITCODE -ne 0) { throw 'pip install failed' }
}

$hvigorw = Resolve-Hvigorw
if ($hvigorw) {
    Write-Host '--- core local unit tests ---'
    Push-Location (Join-Path $root 'app')
    try {
        & $hvigorw test -p module=core@default --no-daemon -p coverage=false
        if ($LASTEXITCODE -ne 0) { throw "core tests failed with exit code $LASTEXITCODE" }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Warning 'hvigorw not found; skipping core local unit tests.'
}

Write-Host '--- pc-agent pytest ---'
& $py -m pytest (Join-Path $root 'pc-agent')
if ($LASTEXITCODE -ne 0) { throw 'pc-agent tests failed' }

Write-Host '--- bench pytest ---'
& $py -m pytest (Join-Path $root 'bench')
if ($LASTEXITCODE -ne 0) { throw 'bench tests failed' }

Write-Host '--- ruff ---'
& $py -m ruff check (Join-Path $root 'pc-agent') (Join-Path $root 'bench')
if ($LASTEXITCODE -ne 0) { throw 'ruff failed' }

Write-Host 'All tests passed.'
