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
$bridgeTarget = $cfg['HOPA_BRIDGE_TARGET']
if (-not $bridgeTarget) { $bridgeTarget = $cfg['HOPA_DEVICE'] }
$tunnelListen = $cfg['HOPA_TUNNEL_LISTEN']
if (-not $tunnelListen) { $tunnelListen = '127.0.0.1:5556' }
$tunnelSession = $cfg['HOPA_TUNNEL_SESSION']
if (-not $tunnelSession) { $tunnelSession = 'default' }
$tunnelEnabled = $cloudEnabled -and ($bridgeTarget -eq $tunnelListen)
$poolEnabled = $cfg['HOPA_POOL'] -match '^(1|true|yes|on)$'
$devicesPath = $cfg['HOPA_DEVICES']
if (-not $devicesPath) { $devicesPath = Join-Path $env:USERPROFILE '.hopa\devices.json' }
$laptopDevice = $cfg['HOPA_LAPTOP_DEVICE']
$laptopTunnelEnabled = $cloudEnabled -and ($cfg['HOPA_LAPTOP_TUNNEL'] -match '^(1|true|yes|on)$')
$laptopTunnelListen = $cfg['HOPA_LAPTOP_TUNNEL_LISTEN']
if (-not $laptopTunnelListen) { $laptopTunnelListen = '127.0.0.1:5557' }
$laptopTunnelSession = $cfg['HOPA_LAPTOP_TUNNEL_SESSION']
if (-not $laptopTunnelSession) { $laptopTunnelSession = 'laptop' }
$laptopTarget = if ($laptopTunnelEnabled) { $laptopTunnelListen } else { $laptopDevice }
$pcAgent = Join-Path $root '.venv\Scripts\pc-agent.exe'

function Write-PoolFile {
    if (-not $poolEnabled) { return }
    $stateDir = Join-Path $env:USERPROFILE '.hopa'
    New-Item -ItemType Directory -Force $stateDir | Out-Null
    $entries = @()
    if ($bridgeTarget) {
        $entries += [ordered]@{
            serial = $bridgeTarget
            token  = $cfg['HOPA_BRIDGE_TOKEN']
            role   = 'phone'
            state  = (Join-Path $stateDir 'bridge-8765-phone.json')
        }
    }
    if ($laptopTarget) {
        $entries += [ordered]@{
            serial = $laptopTarget
            token  = $cfg['HOPA_BRIDGE_TOKEN']
            role   = '2in1'
            state  = (Join-Path $stateDir 'bridge-8765-2in1.json')
        }
    }
    if ($entries.Count -eq 0) {
        throw 'HOPA_POOL is on but neither HOPA_BRIDGE_TARGET nor HOPA_LAPTOP_DEVICE is set.'
    }
    $json = ConvertTo-Json -InputObject $entries -Depth 5
    if ($entries.Count -eq 1) {
        $json = "[$($json.Trim())]"
    }
    Set-Content -Path $devicesPath -Value $json -Encoding utf8
}

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

function Get-TunnelProcess {
    if (-not $tunnelEnabled) { return @() }
    return @(Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -and $_.CommandLine -match 'hdc-tunnel' -and
        $_.CommandLine -match [regex]::Escape($tunnelListen)
    })
}

function Stop-Tunnel {
    foreach ($process in (Get-TunnelProcess)) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Get-LaptopTunnelProcess {
    if (-not $laptopTunnelEnabled) { return @() }
    return @(Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -and $_.CommandLine -match 'hdc-tunnel' -and
        $_.CommandLine -match [regex]::Escape($laptopTunnelListen)
    })
}

function Stop-LaptopTunnel {
    foreach ($process in (Get-LaptopTunnelProcess)) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Show-Status {
    $bridgeState = if (Test-Port $port) { 'up' } else { 'down' }
    if ($poolEnabled) {
        $poolTargets = "phone=$bridgeTarget"
        if ($laptopTarget) { $poolTargets = "$poolTargets, 2in1=$laptopTarget" }
        Write-Host "bridge:     $localUrl ($bridgeState, pool: $poolTargets)"
    } else {
        Write-Host "bridge:     $localUrl ($bridgeState, target $bridgeTarget)"
    }
    if ($cloudEnabled) {
        $links = @(Get-CloudLinkProcess -Relay $relayUrl)
        $linkState = if ($links.Count -gt 0) { "running (pid $($links[0].ProcessId))" } else { 'not running' }
        Write-Host "cloud link: $relayUrl ($linkState)"
    } else {
        Write-Host 'cloud link: off (local mode)'
    }
    if ($tunnelEnabled) {
        $tunnels = @(Get-TunnelProcess)
        $tunnelState = if ($tunnels.Count -gt 0) { "running (pid $($tunnels[0].ProcessId))" } else { 'not running' }
        Write-Host "hd tunnel:  $tunnelListen ($tunnelState)"
    } else {
        Write-Host 'hd tunnel:  off (set HOPA_BRIDGE_TARGET to the tunnel address to enable)'
    }
    if ($laptopTunnelEnabled) {
        $laptopTunnels = @(Get-LaptopTunnelProcess)
        $laptopTunnelState = if ($laptopTunnels.Count -gt 0) { "running (pid $($laptopTunnels[0].ProcessId))" } else { 'not running' }
        Write-Host "hd tunnel 2: $laptopTunnelListen ($laptopTunnelState)"
    }
    Write-Host "phone:      $phoneUrl"
    if ($cloudEnabled) {
        try {
            $health = Invoke-RestMethod -Uri "$relayUrl/health" -TimeoutSec 15
            $age = if ($null -eq $health.link_age_seconds) { 'never' } else { "$($health.link_age_seconds)s ago" }
            Write-Host "relay:      linked=$($health.linked) (last link $age)"
            if ($null -ne $health.tunnel) {
                $tunnel = $health.tunnel
                $tunnelState = if ($tunnel.ready) { 'ready' } else { "host=$($tunnel.host) phone=$($tunnel.phone)" }
                Write-Host "tunnel:     $tunnelState"
            }
        } catch {
            Write-Host "relay:      unreachable ($($_.Exception.Message))"
        }
    }
}

Write-PoolFile

if ($Status) {
    Show-Status
    exit 0
}

if ($Stop) {
    Stop-CloudLink
    Stop-Tunnel
    Stop-LaptopTunnel
    Stop-Bridge $port
    Start-Sleep -Seconds 1
    Write-Host 'stopped the bridge, cloud link and hdc tunnels'
    exit 0
}

if ($Restart) {
    Stop-CloudLink
    Stop-Tunnel
    Stop-LaptopTunnel
    Stop-Bridge $port
    Start-Sleep -Seconds 2
}

if (-not (Test-Path $pcAgent)) {
    throw "pc-agent not found at $pcAgent. Install services\bridge into .venv first."
}

if (-not (Test-Port $port)) {
    if ($poolEnabled) {
        $bridgeArgs = @(
            'bridge', '--host', '127.0.0.1', '--port', "$port",
            '--devices', $devicesPath
        )
        Write-Host "Starting bridge pool on $localUrl..."
    } else {
        $bridgeArgs = @('bridge', '--host', '127.0.0.1', '--port', "$port", '--token', $cfg['HOPA_BRIDGE_TOKEN'])
        if ($bridgeTarget) {
            # --target is a global option, so it goes before the subcommand.
            $bridgeArgs = @('--target', $bridgeTarget) + $bridgeArgs
        }
        Write-Host "Starting bridge on $localUrl..."
    }
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

if ($tunnelEnabled -and @(Get-TunnelProcess).Count -eq 0) {
    Write-Host "Starting hdc tunnel on $tunnelListen..."
    Start-Process -FilePath $pcAgent -WindowStyle Hidden -ArgumentList @(
        'hdc-tunnel',
        '--relay', $relayUrl,
        '--link-token', $cfg['HOPA_LINK_TOKEN'],
        '--listen', $tunnelListen,
        '--session', $tunnelSession
    ) | Out-Null
    Start-Sleep -Seconds 2
}

if ($laptopTunnelEnabled -and @(Get-LaptopTunnelProcess).Count -eq 0) {
    Write-Host "Starting laptop hdc tunnel on $laptopTunnelListen..."
    Start-Process -FilePath $pcAgent -WindowStyle Hidden -ArgumentList @(
        'hdc-tunnel',
        '--relay', $relayUrl,
        '--link-token', $cfg['HOPA_LINK_TOKEN'],
        '--listen', $laptopTunnelListen,
        '--session', $laptopTunnelSession
    ) | Out-Null
    Start-Sleep -Seconds 2
}

Show-Status
