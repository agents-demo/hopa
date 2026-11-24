param(
    [int]$Runs = 20,
    [string]$Framework = "net8.0-windows",
    [string]$Output = "docs/project/evidence/M0-baseline.md"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$out = Join-Path $root $Output
$evidenceDir = Split-Path -Parent $out
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null

function Percentile {
    param([double[]]$Values, [double]$Percent)
    if ($Values.Count -eq 0) { return 0 }
    $sorted = $Values | Sort-Object
    $index = [Math]::Min($sorted.Count - 1, [Math]::Ceiling(($Percent / 100) * $sorted.Count) - 1)
    return $sorted[$index]
}

function Median {
    param([double[]]$Values)
    return Percentile $Values 50
}

Write-Host "building the client for $Framework"
dotnet build apps/windows/Hopa.Windows/Hopa.Windows.csproj -c Debug --nologo | Out-Null
if ($LASTEXITCODE -ne 0) { throw "client build failed" }

$exe = Join-Path $root "apps/windows/Hopa.Windows/bin/Debug/$Framework/Hopa.Windows.exe"
if (-not (Test-Path $exe)) { throw "client exe not found at $exe" }

# A cold start is process start to the first main window handle. Close the
# window after each run so the sidecar disposes through the normal path.
Get-Process Hopa.Windows -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$starts = @()
for ($i = 1; $i -le $Runs; $i++) {
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $exe -PassThru
    while ($watch.Elapsed.TotalSeconds -lt 30) {
        Start-Sleep -Milliseconds 50
        $process.Refresh()
        if ($process.MainWindowHandle -ne [IntPtr]::Zero) { break }
    }
    $starts += $watch.Elapsed.TotalMilliseconds
    if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
        [void]$process.CloseMainWindow()
        [void]$process.WaitForExit(5000)
    }
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Host ("cold start {0}/{1}: {2:0} ms" -f $i, $Runs, $starts[-1])
}

# Test durations are a separate signal: they move when analyzers or generators
# change, without a UI run.
$testWatch = [System.Diagnostics.Stopwatch]::StartNew()
dotnet test apps/windows/Hopa.Windows.Tests -c Debug --no-build --nologo | Out-Null
$unitMs = $testWatch.Elapsed.TotalMilliseconds
$testWatch.Restart()
dotnet test apps/windows/Hopa.Windows.IntegrationTests -c Debug --no-build --nologo | Out-Null
$integrationMs = $testWatch.Elapsed.TotalMilliseconds

# Headless turns use the scripted model, so the number is deterministic and
# free. The product's real-model p95 belongs to a separate budget run.
$sidecarLib = Join-Path $root "apps/windows/sidecar/build/install/hopa-windows-sidecar/lib"
$turnTimes = @()
if (Test-Path $sidecarLib) {
    $data = Join-Path $env:TEMP "hopa-baseline-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $data -Force | Out-Null
    $java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin/java.exe" } else { "java" }
    for ($i = 1; $i -le 5; $i++) {
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        $ErrorActionPreference = "Continue"
        & $java -cp "$sidecarLib/*" com.hopa.sidecar.MainKt --turn "say hello" --data-dir $data 2>$null | Out-Null
        $ErrorActionPreference = "Stop"
        $turnTimes += $watch.Elapsed.TotalMilliseconds
    }
    Remove-Item $data -Recurse -Force -ErrorAction SilentlyContinue
}

$zip = Join-Path $root "out/windows/hopa-windows-0.1.0.zip"
$msi = Join-Path $root "out/windows/hopa-windows-0.1.0.msi"
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$dotnet = (& dotnet --version).Trim()
$javaVersion = if ($env:JAVA_HOME) {
    $ErrorActionPreference = "Continue"
    $versionLine = (& (Join-Path $env:JAVA_HOME "bin/java.exe") -version 2>&1 | Select-Object -First 1)
    $ErrorActionPreference = "Stop"
    $versionLine
} else {
    "java not on JAVA_HOME"
}

$lines = @(
    "# M0 baseline",
    "",
    "Measured on the machine below. Re-run with:",
    "",
    '```powershell',
    "powershell -NoProfile -ExecutionPolicy Bypass -File tools/scripts/windows-baseline.ps1",
    '```',
    "",
    "| Field | Value |",
    "|---|---|",
    "| OS | $($os.Caption) $($os.Version) |",
    "| CPU | $($cpu.Name.Trim()) |",
    "| .NET SDK | $dotnet |",
    "| Java | $javaVersion |",
    "| Client TFM | $Framework |",
    "| Samples | $Runs cold starts; 5 headless turns |",
    "",
    "| Metric | Median | p95 |",
    "|---|---:|---:|",
    ("| Cold start (ms) | {0:0} | {1:0} |" -f (Median $starts), (Percentile $starts 95)),
    ("| Unit tests (ms) | {0:0} | - |" -f $unitMs),
    ("| Integration tests (ms) | {0:0} | - |" -f $integrationMs)
)

if ($turnTimes.Count -gt 0) {
    $lines += ("| Headless turn (ms) | {0:0} | {1:0} |" -f (Median $turnTimes), (Percentile $turnTimes 95))
}

$lines += @(
    "",
    "| Package | Bytes |",
    "|---|---:|",
    "| zip | $(if (Test-Path $zip) { (Get-Item $zip).Length } else { 'not built' }) |",
    "| MSI | $(if (Test-Path $msi) { (Get-Item $msi).Length } else { 'not built' }) |",
    "",
    "The cold-start loop closes the main window after the first handle; it does not",
    "measure a full turn. Headless turns use the scripted model, so they are a",
    "toolchain regression signal, not a model-latency budget."
)

Set-Content -Path $out -Value $lines -Encoding utf8
Write-Host "wrote $out"
