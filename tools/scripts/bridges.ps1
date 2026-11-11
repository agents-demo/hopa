#!/usr/bin/env pwsh
# One bridge process, every device.
#
#   powershell -ExecutionPolicy Bypass -File tools\scripts\bridges.ps1
#   ... -Status    report the listener and the devices it serves
#   ... -Stop      stop the bridge on 8766
#
# The bridge is a pool: one listener on 8766, and each request says which
# device it means (`X-Hopa-Role`, or /d/<serial>/...). hdc only lets one device
# own a given device-side port, so the phone forwards 8768 -> 8766 and the
# laptop forwards 8766 -> 8766.
param(
    [switch]$Status,
    [switch]$Stop
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
if (-not (Test-Path $hdc)) {
    $cmd = Get-Command hdc -ErrorAction SilentlyContinue
    if (-not $cmd) { throw 'hdc not found.' }
    $hdc = $cmd.Source
}
$agentDir = Join-Path $root 'services\pc-agent'
$shots = Join-Path $env:TEMP 'hopa-shots'
$bridgePort = 8766
$phoneDevicePort = 8768
New-Item -ItemType Directory -Force $shots | Out-Null

function Test-Port([int]$port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect('127.0.0.1', $port)
        return $true
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

function Stop-Port([int]$port) {
    $connection = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($null -eq $connection) { return $false }
    Stop-Process -Id $connection.OwningProcess -Force -ErrorAction SilentlyContinue
    return $true
}

$targets = @(& $hdc list targets 2>$null | Where-Object { $_ -match '^\S+' -and $_ -notmatch '\[Empty\]' })
$entries = @()
$seenPhone = $false
$seenLaptop = $false
foreach ($t in $targets) {
    $serial = ($t -split '\s+')[0]
    $kind = (& $hdc -t $serial shell 'param get const.product.devicetype' 2>$null) -join ''
    $isLaptop = $kind -match '2in1'
    if ($isLaptop) { $seenLaptop = $true } else { $seenPhone = $true }
    $role = if ($isLaptop) { '2in1' } else { 'phone' }
    $token = if ($isLaptop) { 'hopalaptop' } else { 'hopaphone' }
    $code = if ($isLaptop) { '135790' } else { '246810' }
    # Fixed read-only keys: they are pasted into the other shell, so they must
    # never start with a dash (aa start would read that as an option).
    $sessionsKey = if ($isLaptop) { 'hopareadonly-laptop' } else { 'hopareadonly-phone' }
    $state = Join-Path $env:USERPROFILE ".hopa\bridge-$bridgePort-$serial.json"
    $entries += [ordered]@{
        serial = $serial
        token = $token
        pair = $code
        role = $role
        sessions_key = $sessionsKey
        state = $state
    }
    # The reverse tunnel: device-side port -> this PC's bridge port.
    $devicePort = if ($isLaptop) { $bridgePort } else { $phoneDevicePort }
    & $hdc -t $serial rport "tcp:$devicePort" "tcp:$bridgePort" 2>&1 | Out-Null
}

$config = Join-Path $shots 'bridge-devices.json'
# Always a JSON array: ConvertTo-Json turns a single entry into an object.
$json = '[' + (($entries | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 5 }) -join ',') + ']'
# No BOM: the Python reader treats it as a JSON error.
[System.IO.File]::WriteAllText($config, $json, (New-Object System.Text.UTF8Encoding($false)))

if ($Stop) {
    if (Stop-Port $bridgePort) {
        Write-Host "  bridge stopped (was on $bridgePort)"
    } else {
        Write-Host "  bridge was not running"
    }
    if (-not $Status) { exit 0 }
}

if ($Status) {
    $state = if (Test-Port $bridgePort) { 'up' } else { 'down' }
    Write-Host "  bridge $state on $bridgePort"
    foreach ($entry in $entries) {
        Write-Host ("  {0} {1} (role {2})" -f $entry.role, $entry.serial, $entry.role)
    }
    if (-not $seenPhone) { Write-Host '  no phone on hdc: its app will read "PC bridge offline" until it is reconnected.' }
    if (-not $seenLaptop) { Write-Host '  no 2in1 on hdc: the laptop has no tunnel.' }
    exit 0
}

if ($entries.Count -eq 0) {
    Write-Host '  no devices on hdc: nothing to serve'
    exit 1
}

if (Test-Port $bridgePort) {
    Write-Host "  bridge already on $bridgePort; devices in $config"
} else {
    $log = Join-Path $shots 'bridge.log'
    $arguments = @('-3', '-m', 'hopa_pc_agent', 'bridge', '--port', "$bridgePort", '--devices', $config)
    Start-Process -FilePath 'py' -ArgumentList $arguments -WorkingDirectory $agentDir `
        -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    Start-Sleep -Milliseconds 2000
    if (Test-Port $bridgePort) {
        Write-Host "  bridge started on $bridgePort with $($entries.Count) device(s) (log: $log)"
    } else {
        Write-Host "  bridge did not start; see $log.err"
    }
}

if (-not $seenPhone) {
    Write-Host '  no phone on hdc: its app will read "PC bridge offline" until it is reconnected.'
}
if (-not $seenLaptop) {
    Write-Host '  no 2in1 on hdc: the laptop has no tunnel.'
}
