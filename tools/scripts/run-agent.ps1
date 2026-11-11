#!/usr/bin/env pwsh
# Start (or inspect) the PC side only: the local bridge and the cloud link.
# It never installs, launches or stops the phone app.
#
#   .\tools\scripts\run-agent.ps1
#   .\tools\scripts\run-agent.ps1 -Status
#   .\tools\scripts\run-agent.ps1 -Restart
#   .\tools\scripts\run-agent.ps1 -Stop
#
# In cloud mode (.env HOPA_BRIDGE_URL is public) the bridge listens on
# HOPA_LOCAL_BRIDGE_URL and cloud-link keeps an outbound long-poll to
# HOPA_RELAY_URL. That poll is also the Render keep-alive.
param(
    [switch]$Status,
    [switch]$Stop,
    [switch]$Restart,
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

$phoneUrl = $cfg['HOPA_BRIDGE_URL']
if (-not $phoneUrl) { throw "Set HOPA_BRIDGE_URL in $EnvFile." }
if (-not $cfg['HOPA_BRIDGE_TOKEN']) { throw "Set HOPA_BRIDGE_TOKEN in $EnvFile." }
$localUrl = $cfg['HOPA_LOCAL_BRIDGE_URL']
if (-not $localUrl) { $localUrl = $phoneUrl }
$localUri = [Uri]$localUrl
$port = if ($localUri.Port -gt 0) { $localUri.Port } else { 80 }
$isLoopback = $phoneUrl -match '^https?://(127\.0\.0\.1|localhost)(:|/|$)'
$relayUrl = $cfg['HOPA_RELAY_URL']
$cloudEnabled = (-not $isLoopback) -and [bool]$relayUrl -and [bool]$cfg['HOPA_LINK_TOKEN']
$pcAgent = Join-Path $root '.venv\Scripts\pc-agent.exe'

function Test-Port([int]$value) {
    return [bool](Get-NetTCPConnection -LocalPort $value -State Listen -ErrorAction SilentlyContinue)
}

function Get-CloudLinkProcess {
    param([string]$Relay)
    if (-not $Relay) { return @() }
    return @(Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -and $_.CommandLine -match 'cloud-link' -and
        $_.CommandLine -match [regex]::Escape($Relay)
    })
}

function Stop-Bridge([int]$value) {
    $listener = Get-NetTCPConnection -LocalPort $value -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        Stop-Process -Id $listener.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -and $_.CommandLine -match 'pc-agent' -and
        $_.CommandLine -match '\bbridge\b' -and
        $_.CommandLine -match "--port $value"
    } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Stop-CloudLink {
    foreach ($process in (Get-CloudLinkProcess -Relay $relayUrl)) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Show-Status {
    $bridgeState = if (Test-Port $port) { 'up' } else { 'down' }
    Write-Host "bridge:     $localUrl ($bridgeState)"
    if ($cloudEnabled) {
        $links = @(Get-CloudLinkProcess -Relay $relayUrl)
        $linkState = if ($links.Count -gt 0) { "running (pid $($links[0].ProcessId))" } else { 'not running' }
        Write-Host "cloud link: $relayUrl ($linkState)"
    } else {
        Write-Host 'cloud link: off (local mode)'
    }
    Write-Host "phone:      $phoneUrl"
    if ($cloudEnabled) {
        try {
            $health = Invoke-RestMethod -Uri "$relayUrl/health" -TimeoutSec 15
            $age = if ($null -eq $health.link_age_seconds) { 'never' } else { "$($health.link_age_seconds)s ago" }
            Write-Host "relay:      linked=$($health.linked) (last link $age)"
        } catch {
            Write-Host "relay:      unreachable ($($_.Exception.Message))"
        }
    }
}

if ($Status) {
    Show-Status
    exit 0
}

if ($Stop) {
    Stop-CloudLink
    Stop-Bridge $port
    Start-Sleep -Seconds 1
    Write-Host 'stopped the bridge and cloud link'
    exit 0
}

if ($Restart) {
    Stop-CloudLink
    Stop-Bridge $port
    Start-Sleep -Seconds 2
}

if (-not (Test-Path $pcAgent)) {
    throw "pc-agent not found at $pcAgent. Install services\pc-agent into .venv first."
}

if (-not (Test-Port $port)) {
    $bridgeArgs = @('bridge', '--host', '127.0.0.1', '--port', "$port", '--token', $cfg['HOPA_BRIDGE_TOKEN'])
    if ($cfg['HOPA_DEVICE']) {
        # --target is a global option, so it goes before the subcommand.
        $bridgeArgs = @('--target', $cfg['HOPA_DEVICE']) + $bridgeArgs
    }
    Write-Host "Starting bridge on $localUrl..."
    Start-Process -FilePath $pcAgent -WindowStyle Hidden -ArgumentList $bridgeArgs | Out-Null
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 250
        if (Test-Port $port) { break }
    }
    if (-not (Test-Port $port)) {
        throw 'The bridge did not start. Check that pc-agent is installed and the port is free.'
    }
}

if ($cloudEnabled) {
    if (@(Get-CloudLinkProcess -Relay $relayUrl).Count -eq 0) {
        Write-Host "Starting cloud link to $relayUrl..."
        Start-Process -FilePath $pcAgent -WindowStyle Hidden -ArgumentList @(
            'cloud-link',
            '--relay', $relayUrl,
            '--link-token', $cfg['HOPA_LINK_TOKEN'],
            '--local', $localUrl,
            '--local-token', $cfg['HOPA_BRIDGE_TOKEN']
        ) | Out-Null
        Start-Sleep -Seconds 3
    }
}

Show-Status
