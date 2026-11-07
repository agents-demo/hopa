#!/usr/bin/env pwsh
# Run Python, brain and ArkTS tests, plus lint and plan checks (Windows).
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
    throw 'Python 3.11+ not found. Install it and/or create .venv at the repo root.'
}

Write-Host '=== installing Python packages (editable) ==='
& $pythonExe @pythonPrefix -m pip install -U pip | Out-Host
& $pythonExe @pythonPrefix -m pip install `
    -e (Join-Path $root 'services\pc-agent') `
    -e (Join-Path $root 'harness\bench[dev]') `
    -e (Join-Path $root 'harness\agent[dev]') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'pip install failed' }

Write-Host '=== Python tests ==='
& $pythonExe @pythonPrefix -m pytest `
    (Join-Path $root 'services\pc-agent') `
    (Join-Path $root 'harness\bench') `
    (Join-Path $root 'harness\agent') `
    (Join-Path $root 'tools\scripts') -q
if ($LASTEXITCODE -ne 0) { throw 'Python tests failed' }

Write-Host '=== agent coverage ==='
& $pythonExe @pythonPrefix -m pytest (Join-Path $root 'harness\agent') `
    --cov=hopa_agent --cov-report=term --cov-fail-under=80 -q
if ($LASTEXITCODE -ne 0) { throw 'agent coverage gate failed' }

Write-Host '=== ruff ==='
& $pythonExe @pythonPrefix -m ruff check `
    (Join-Path $root 'services\pc-agent') (Join-Path $root 'harness\bench') (Join-Path $root 'harness\agent')
if ($LASTEXITCODE -ne 0) { throw 'ruff check failed' }
& $pythonExe @pythonPrefix -m ruff format --check `
    (Join-Path $root 'services\pc-agent') (Join-Path $root 'harness\bench') (Join-Path $root 'harness\agent')
if ($LASTEXITCODE -ne 0) { throw 'ruff format check failed' }

Write-Host '=== plan lint ==='
& $pythonExe @pythonPrefix (Join-Path $root 'tools\scripts\plan-status.py') --lint
if ($LASTEXITCODE -ne 0) { throw 'plan lint failed' }

Write-Host '=== app catalogue ==='
& $pythonExe @pythonPrefix (Join-Path $root 'tools\scripts\build-app-catalog.py') --check
if ($LASTEXITCODE -ne 0) { throw 'app catalogue is stale' }

Write-Host '=== brain tests ==='
if (Test-Path (Join-Path $root '.tools\kotlinc\bin\kotlinc.bat')) {
    & (Join-Path $PSScriptRoot 'brain.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'brain tests failed' }
} elseif (Get-Command java -ErrorAction SilentlyContinue) {
    Write-Host 'Kotlin compiler not downloaded yet; downloading it via brain.ps1.'
    & (Join-Path $PSScriptRoot 'brain.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'brain tests failed' }
} else {
    Write-Warning 'Java not found; skipping brain tests.'
}

Write-Host '=== ArkTS tests ==='
$dev = 'C:\Program Files\Huawei\DevEco Studio'
$hvigorw = $null
if ($env:HOPA_CLT_HOME) {
    $candidate = Join-Path $env:HOPA_CLT_HOME 'bin\hvigorw.bat'
    if (Test-Path $candidate) {
        $hvigorw = $candidate
        $env:DEVECO_SDK_HOME = Join-Path $env:HOPA_CLT_HOME 'sdk'
    }
}
if (-not $hvigorw) {
    $candidate = Join-Path $dev 'tools\hvigor\bin\hvigorw.bat'
    if (Test-Path $candidate) {
        $hvigorw = $candidate
        $env:DEVECO_SDK_HOME = Join-Path $dev 'sdk'
        $env:JAVA_HOME = Join-Path $dev 'jbr'
        $env:PATH = "$(Join-Path $dev 'tools\node');$(Join-Path $dev 'tools\ohpm\bin');$(Join-Path $dev 'sdk\default\openharmony\toolchains');$env:PATH"
    }
}
if (-not $hvigorw) {
    $cmd = Get-Command hvigorw -ErrorAction SilentlyContinue
    if ($cmd) { $hvigorw = $cmd.Source }
}
if ($hvigorw) {
    Push-Location (Join-Path $root 'apps\harmony')
    try {
        $ohpm = Get-Command ohpm -ErrorAction SilentlyContinue
        if ($ohpm) { & $ohpm.Source install }
        & $hvigorw test -p module=core@default --no-daemon -p coverage=false
        if ($LASTEXITCODE -ne 0) { throw 'ArkTS tests failed' }
    } finally {
        Pop-Location
    }
} else {
    Write-Warning 'hvigorw not found; skipping ArkTS tests.'
}

Write-Host 'All tests passed.'
