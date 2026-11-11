#!/usr/bin/env pwsh
# Run the HOPA laptop shell: the local bridge, the USB reverse port and the app.
#
#   .\tools\scripts\run-laptop.ps1
#   .\tools\scripts\run-laptop.ps1 -Status
#   .\tools\scripts\run-laptop.ps1 -Restart
#   .\tools\scripts\run-laptop.ps1 -Stop
#   .\tools\scripts\run-laptop.ps1 -NoLaunch
#   .\tools\scripts\run-laptop.ps1 -ResetForward
#
# The phone uses run-agent.ps1 on 8765. This is a separate bridge on 8767 for
# the 2-in-1; the laptop reaches it through `hdc rport`. It never touches the
# phone bridge or the cloud relay.
param(
    [switch]$Status,
    [switch]$Stop,
    [switch]$Restart,
    [switch]$NoLaunch,
    [switch]$ResetForward,
    [string]$EnvFile = '.env'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$envPath = Join-Path $root $EnvFile
if (-not (Test-Path $envPath)) { throw "Config file not found: $envPath" }

$cfg = @{}
Get-Content $envPath | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith('#') -or -not $line.Contains('=')) { return }
    $index = $line.IndexOf('=')
    $key = $line.Substring(0, $index).Trim()
    $value = $line.Substring($index + 1).Trim()
    if ($value.Length -ge 2) {
        $first = $value.Substring(0, 1)
        $last = $value.Substring($value.Length - 1, 1)
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            $value = $value.Substring(1, $value.Length - 2)
        }
    }
    $cfg[$key] = $value
}

$device = $cfg['HOPA_LAPTOP_DEVICE']
if (-not $device) { $device = '3QC0225821000268' }
$portText = $cfg['HOPA_LAPTOP_BRIDGE_PORT']
if (-not $portText) { $portText = '8767' }
$port = [int]$portText
$token = $cfg['HOPA_LAPTOP_BRIDGE_TOKEN']
if (-not $token) { $token = 'hopalaptop' }
$appUrl = $cfg['HOPA_LAPTOP_BRIDGE_URL']
if (-not $appUrl) { $appUrl = "http://127.0.0.1:$port" }
$bundle = 'com.hopa.agent'
$ability = 'LaptopAbility'
$pcAgent = Join-Path $root '.venv\Scripts\pc-agent.exe'
$healthUrl = "http://127.0.0.1:$port"

function Resolve-Hdc {
    if ($env:HOPA_HDC -and (Test-Path $env:HOPA_HDC)) { return $env:HOPA_HDC }
    $candidates = @()
    if ($env:HOPA_CLT_HOME) {
        $candidates += Join-Path $env:HOPA_CLT_HOME 'sdk\default\openharmony\toolchains\hdc.exe'
    }
    $candidates += 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    $command = Get-Command hdc -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw 'hdc not found. Set HOPA_HDC or add the toolchains directory to PATH.'
}

function Test-Port([int]$value) {
    return [bool](Get-NetTCPConnection -LocalPort $value -State Listen -ErrorAction SilentlyContinue)
}

function Get-Targets {
    $text = (& $hdc list targets 2>&1 | Out-String)
    return @($text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object {
        $_ -and $_ -notmatch '^\[Empty\]$'
    })
}

function Get-BridgeProcesses {
    $portPattern = "--port $port(?:\s|$)"
    return @(Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -and
        ($_.Name -eq 'pc-agent.exe' -or $_.Name -eq 'python.exe') -and
        $_.CommandLine -match '\bbridge\b' -and
        $_.CommandLine -match $portPattern
    })
}

function Stop-LaptopBridge {
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        Stop-Process -Id $listener.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    foreach ($process in (Get-BridgeProcesses)) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        if (-not (Test-Port $port)) { return }
        Start-Sleep -Milliseconds 250
    }
}

function Start-LaptopBridge {
    if (Test-Port $port) { return }
    if (-not (Test-Path $pcAgent)) {
        throw "pc-agent not found at $pcAgent. Install services\pc-agent into .venv first."
    }
    $arguments = @(
        '--target', $device,
        'bridge', '--host', '127.0.0.1', '--port', "$port", '--token', $token
    )
    Start-Process -FilePath $pcAgent -WindowStyle Hidden -ArgumentList $arguments | Out-Null
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Milliseconds 250
        if (Test-Port $port) { return }
    }
    throw "The laptop bridge did not start on port $port."
}

function Add-ReversePort {
    if ($ResetForward) {
        Write-Host 'Resetting hdc forwards (this briefly drops other hdc targets)...'
        & $hdc kill 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        & $hdc start 2>&1 | Out-Null
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            Start-Sleep -Milliseconds 500
            if (@(Get-Targets) -contains $device) { break }
        }
    }
    $output = (& $hdc -t $device rport "tcp:$port" "tcp:$port" 2>&1 | Out-String)
    if ($output -notmatch 'OK') {
        # The laptop may already hold this forward from a previous run.
        $hex = '{0:X4}' -f $port
        $listener = (& $hdc -t $device shell "cat /proc/net/tcp 2>/dev/null | grep -i ':$hex '" 2>&1 | Out-String)
        if (-not $listener) {
            Write-Host "reverse: $($output.Trim())"
            Write-Host 'hint: rerun with -ResetForward if the forward is stale.'
        }
    }
}

function Start-LaptopApp {
    $targets = @(Get-Targets)
    if (-not ($targets -contains $device)) {
        throw "The laptop $device is not connected by USB."
    }
    $parameters = [ordered]@{
        'hopa.bridge_url'      = $appUrl
        'hopa.bridge_key'      = $token
        'hopa.laptop_key'      = $cfg['HOPA_MODEL_API_KEY']
        'hopa.laptop_endpoint' = $cfg['HOPA_MODEL_BASE_URL']
        'hopa.laptop_model'    = $cfg['HOPA_MODEL_NAME']
    }
    & $hdc -t $device shell "aa force-stop $bundle" 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    $shellArgs = @('shell', 'aa', 'start', '-a', $ability, '-b', $bundle)
    foreach ($key in $parameters.Keys) {
        $value = $parameters[$key]
        if ($value) {
            $shellArgs += '--ps'
            $shellArgs += $key
            $shellArgs += ("'" + $value.Replace("'", "'\''") + "'")
        }
    }
    $output = (& $hdc -t $device @shellArgs 2>&1 | Out-String)
    if ($output -notmatch 'success') {
        Write-Host $output.Trim()
        throw "Failed to launch $bundle/$ability."
    }
    Write-Host "launched $bundle/$ability against $appUrl"
}

function Show-Status {
    $bridgeUp = Test-Port $port
    $targets = @(Get-Targets)
    $connected = $targets -contains $device
    $appText = ''
    $reverseText = ''
    if ($connected) {
        $appText = (& $hdc -t $device shell "ps -A | grep com.hopa.agent" 2>&1 | Out-String).Trim()
        $hex = '{0:X4}' -f $port
        $reverseText = (& $hdc -t $device shell "cat /proc/net/tcp 2>/dev/null | grep -i ':$hex '" 2>&1 | Out-String).Trim()
    }
    $bridgeState = if ($bridgeUp) { 'up' } else { 'down' }
    $laptopState = if ($connected) { 'connected' } else { 'not connected' }
    $appState = if ($appText) { 'running' } else { 'not running' }
    $reverseState = if ($reverseText) { "tcp:$port forward present" } else { "tcp:$port forward missing" }
    Write-Host "bridge:  $healthUrl ($bridgeState)"
    Write-Host "laptop:  $device ($laptopState)"
    Write-Host "app:     $appState"
    Write-Host "reverse: $reverseState"
    Write-Host "app url: $appUrl"
    if ($bridgeUp) {
        try {
            Invoke-RestMethod -Uri "$healthUrl/health" -TimeoutSec 5 | Out-Null
            Write-Host 'health:  ok'
        } catch {
            Write-Host "health:  $($_.Exception.Message)"
        }
        try {
            Invoke-RestMethod -Uri "$healthUrl/whoami" `
                -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 5 | Out-Null
            Write-Host 'whoami:  ok'
        } catch {
            Write-Host 'whoami:  rejected or unavailable'
        }
    }
}

$hdc = Resolve-Hdc

if ($Status) {
    Show-Status
    exit 0
}

if ($Stop) {
    Stop-LaptopBridge
    Write-Host "stopped the laptop bridge on port $port"
    exit 0
}

if ($Restart) {
    Stop-LaptopBridge
    Start-Sleep -Seconds 1
}

Start-LaptopBridge
Add-ReversePort
if (-not $NoLaunch) {
    Start-LaptopApp
}
Show-Status
