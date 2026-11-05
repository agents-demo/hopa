#!/usr/bin/env pwsh
# Build the HOPA HAP from the command line (Windows).
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'app'

function Resolve-Hvigorw {
    if ($env:HOPA_CLT_HOME) {
        $candidate = Join-Path $env:HOPA_CLT_HOME 'bin\hvigorw.bat'
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command hvigorw -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'hvigorw not found. Set HOPA_CLT_HOME or add the Command Line Tools bin directory to PATH.'
}

Push-Location $app
try {
    $hvigorw = Resolve-Hvigorw
    & $hvigorw assembleHap --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "hvigorw failed with exit code $LASTEXITCODE" }

    $out = Join-Path $app 'entry\build\default\outputs\default'
    if (Test-Path $out) {
        Get-ChildItem $out -Filter '*.hap' | ForEach-Object { Write-Host "Built: $($_.FullName)" }
    }
}
finally {
    Pop-Location
}
