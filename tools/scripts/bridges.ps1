#!/usr/bin/env pwsh
# Keep one bridge process per device alive.
#
#   powershell -ExecutionPolicy Bypass -File tools\scripts\bridges.ps1
#   ... -Status    only report what is listening
#   ... -Stop      stop the bridges this script started (by port)
#
# One bridge serves one device, so the phone gets 8766 and the 2in1 gets 8767.
# The bridge now persists its token pair under ~/.hopa, so a restart no longer
# forces the phone to pair again.
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
$seenPhone = $false
$seenLaptop = $false
foreach ($t in $targets) {
    $serial = ($t -split '\s+')[0]
    $kind = (& $hdc -t $serial shell 'param get const.product.devicetype' 2>$null) -join ''
    $isLaptop = $kind -match '2in1'
    $port = if ($isLaptop) { 8767 } else { 8766 }
    $token = if ($isLaptop) { 'hopalaptop' } else { 'hopaphone' }
    $code = if ($isLaptop) { '135790' } else { '246810' }
    # Fixed read-only keys: they are pasted into the other shell, so they must
    # never start with a dash (aa start would read that as an option).
    $sessionsKey = if ($isLaptop) { 'hopareadonly-8767' } else { 'hopareadonly-8766' }
    $label = if ($isLaptop) { 'laptop' } else { 'phone' }
    if ($isLaptop) { $seenLaptop = $true } else { $seenPhone = $true }

    if ($Stop) {
        if (Stop-Port $port) { Write-Host "  $label bridge stopped (was on $port)" }
        continue
    }

    $alive = Test-Port $port
    if ($Status) {
        $state = if ($alive) { 'up' } else { 'down' }
        Write-Host ("  {0} {1} bridge {2} on {3}" -f $label, $serial, $state, $port)
        continue
    }
    if ($alive) {
        Write-Host "  $label bridge already on $port"
        continue
    }

    $log = Join-Path $shots "bridge-$port.log"
    $arguments = @('-3', '-m', 'hopa_pc_agent', '--target', $serial, 'bridge',
        '--port', "$port", '--token', $token, '--pair-code', $code,
        '--sessions-key', $sessionsKey)
    Start-Process -FilePath 'py' -ArgumentList $arguments -WorkingDirectory $agentDir `
        -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    Start-Sleep -Milliseconds 1500
    if (Test-Port $port) {
        Write-Host "  $label bridge started on $port (log: $log)"
    } else {
        Write-Host "  $label bridge did not start; see $log.err"
    }
}

# A device that is not on hdc cannot have a reverse port, so its app will say
# "PC bridge offline" no matter what the bridge does. Say so out loud.
if (-not $Status) {
    if (-not $seenPhone) {
        Write-Host '  no phone on hdc: its app will read "PC bridge offline" until it is reconnected.'
    }
    if (-not $seenLaptop) {
        Write-Host '  no 2in1 on hdc: the laptop has no tunnel.'
    }
}
