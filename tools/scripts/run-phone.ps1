#!/usr/bin/env pwsh
# Launch HOPA on the connected phone with the model/bridge settings from .env.
#
# The app accepts these as `aa start --ps hopa.*` parameters. The API key is
# passed to the app process and kept in memory; it is never printed or written
# to the app's preferences.
#
#   .\tools\scripts\run-phone.ps1
#   .\tools\scripts\run-phone.ps1 -EnvFile .env.local
param(
    [string]$EnvFile = '.env'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$envPath = Join-Path $root $EnvFile
if (-not (Test-Path $envPath)) {
    throw "Config file not found: $envPath"
}

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

function Resolve-Hdc {
    $candidates = @(
        'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
    )
    if ($env:HOPA_CLT_HOME) {
        $candidates += Join-Path $env:HOPA_CLT_HOME 'sdk\default\openharmony\toolchains\hdc.exe'
    }
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command hdc -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'hdc not found. Set HOPA_CLT_HOME or add the toolchains directory to PATH.'
}

$hdc = Resolve-Hdc
$target = $cfg['HOPA_DEVICE']
if (-not $target) {
    $listed = @((& $hdc list targets 2>&1 | Out-String).Trim() -split "`r?`n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and $_ -notmatch '^\[Empty\]$' })
    if ($listed.Count -ne 1) {
        throw "Connect exactly one device or set HOPA_DEVICE in $EnvFile."
    }
    $target = $listed[0]
}

$required = @('HOPA_MODEL_BASE_URL', 'HOPA_MODEL_NAME', 'HOPA_MODEL_API_KEY', 'HOPA_BRIDGE_URL', 'HOPA_BRIDGE_TOKEN')
$missing = @($required | Where-Object { -not $cfg[$_] })
if ($missing.Count -gt 0) {
    throw "Fill these in $EnvFile first: $($missing -join ', ')"
}

# The phone talks to HOPA_BRIDGE_URL. Locally that is the bridge itself; in
# cloud mode it is the relay, and the bridge plus cloud-link run on this PC.
# HOPA_LOCAL_BRIDGE_URL is where cloud-link reaches the bridge.
$phoneUrl = $cfg['HOPA_BRIDGE_URL']
$localUrl = $cfg['HOPA_LOCAL_BRIDGE_URL']
if (-not $localUrl) { $localUrl = $phoneUrl }
$bridgeUri = [Uri]$localUrl
$port = if ($bridgeUri.Port -gt 0) { $bridgeUri.Port } else { 80 }
$isLoopback = $phoneUrl -match '^https?://(127\.0\.0\.1|localhost)(:|/|$)'

# Start the bridge if it is not already listening.
$listening = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if (-not $listening) {
    $pcAgent = Join-Path $root '.venv\Scripts\hopa-bridge.exe'
    if (-not (Test-Path $pcAgent)) {
        throw "hopa-bridge not found at $pcAgent. Install services\\hopa-bridge into .venv first."
    }
    Write-Host "Starting PC bridge on port $port..."
    Start-Process -FilePath $pcAgent -WindowStyle Hidden -ArgumentList @(
        '--target', $target,
        'bridge', '--host', '127.0.0.1', '--port', "$port",
        '--token', $cfg['HOPA_BRIDGE_TOKEN']
    )
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Start-Sleep -Milliseconds 250
        if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
            $listening = $true
            break
        }
    }
    if (-not $listening) { throw 'The PC bridge did not start.' }
}

if (-not $isLoopback -and $cfg['HOPA_RELAY_URL'] -and $cfg['HOPA_LINK_TOKEN']) {
    # Cloud mode: the phone reaches the public relay, and this PC dials out to
    # it. The long-poll is also what keeps a free Render instance awake.
    $running = Get-CimInstance Win32_Process | Where-Object {
        $_.CommandLine -and $_.CommandLine -match 'cloud-link' -and
        $_.CommandLine -match [regex]::Escape($cfg['HOPA_RELAY_URL'])
    }
    if (-not $running) {
        Write-Host "Starting cloud link to $($cfg['HOPA_RELAY_URL'])..."
        Start-Process -FilePath (Join-Path $root '.venv\Scripts\hopa-bridge.exe') -WindowStyle Hidden -ArgumentList @(
            'cloud-link',
            '--relay', $cfg['HOPA_RELAY_URL'],
            '--link-token', $cfg['HOPA_LINK_TOKEN'],
            '--local', $localUrl,
            '--local-token', $cfg['HOPA_BRIDGE_TOKEN']
        )
        Start-Sleep -Seconds 2
    }
} else {
    # Local mode: the phone reaches the PC over the USB reverse tunnel.
    $forwards = & $hdc -t $target fport ls 2>&1 | Out-String
    if ($forwards -notmatch "tcp:$port") {
        & $hdc -t $target rport "tcp:$port" "tcp:$port" 2>&1 | Out-Null
    }
}

$parameters = [ordered]@{
    'hopa.provider'     = $cfg['HOPA_MODEL_PROVIDER']
    'hopa.base_url'     = $cfg['HOPA_MODEL_BASE_URL']
    'hopa.model'        = $cfg['HOPA_MODEL_NAME']
    'hopa.api_key'      = $cfg['HOPA_MODEL_API_KEY']
    'hopa.bridge_url'   = $cfg['HOPA_BRIDGE_URL']
    'hopa.bridge_token' = $cfg['HOPA_BRIDGE_TOKEN']
}

$shellArgs = @('shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.hopa.agent')
foreach ($key in $parameters.Keys) {
    $value = $parameters[$key]
    if ($value) {
        $shellArgs += '--ps'
        $shellArgs += $key
        $shellArgs += ("'" + $value.Replace("'", "'\''") + "'")
    }
}

Write-Host "Target: $target"
Write-Host "Model:  $($cfg['HOPA_MODEL_PROVIDER']) / $($cfg['HOPA_MODEL_NAME']) @ $($cfg['HOPA_MODEL_BASE_URL'])"
Write-Host "Bridge: $($cfg['HOPA_BRIDGE_URL'])"
Write-Host "API key: set ($($cfg['HOPA_MODEL_API_KEY'].Length) chars, memory only)"

& $hdc -t $target shell aa force-stop com.hopa.agent 2>&1 | Out-Null
Start-Sleep -Milliseconds 500
$output = & $hdc -t $target @shellArgs 2>&1 | Out-String
if ($output -notmatch 'success') {
    Write-Host $output.Trim()
    throw 'Failed to launch HOPA with the .env settings.'
}
Write-Host 'HOPA is running with the .env settings.'
