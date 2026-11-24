param(
    [string]$Output = "out/windows-desktop",
    [switch]$ReadyOnly,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$outDir = Join-Path $root $Output

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Test-DesktopReady {
    Assert-True ([Environment]::UserInteractive) "the process is not interactive; a service or session 0 cannot drive UI Automation"

    $session = (Get-Process -Id $PID).SessionId
    Assert-True ($session -ne 0) "session 0 is not an interactive desktop; run the runner from an interactive user session"

    $explorer = Get-Process explorer -ErrorAction SilentlyContinue
    Assert-True ($null -ne $explorer) "no Explorer shell is running; log in to the runner user and keep the session unlocked"

    if (-not ("HopaDesktopProbe" -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class HopaDesktopProbe
{
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern IntPtr GetDesktopWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
}
'@
    }

    $foreground = [HopaDesktopProbe]::GetForegroundWindow()
    Assert-True ($foreground -ne [IntPtr]::Zero) "there is no foreground window; a headless, locked or disconnected desktop cannot be observed"
    $desktop = [HopaDesktopProbe]::GetDesktopWindow()
    Assert-True ($desktop -ne [IntPtr]::Zero) "the desktop window is not available"

    $foregroundPid = [uint32]0
    [void][HopaDesktopProbe]::GetWindowThreadProcessId($foreground, [ref]$foregroundPid)
    $foregroundName = ""
    try {
        $foregroundName = (Get-Process -Id $foregroundPid -ErrorAction Stop).ProcessName
    }
    catch {
        # A process we cannot name is still a foreground window, but not the
        # lock screen. The name is only used for the refusal below.
    }

    $secure = @("LockApp", "LogonUI", "Winlogon")
    Assert-True ($secure -notcontains $foregroundName) "the foreground is '$foregroundName' (locked or secure); unlock the runner desktop"

    Write-Host "desktop ready: session=$session foreground=$foreground process=$foregroundName"
}

function Invoke-DevTool {
    param([string]$Name, [string[]]$Arguments)
    Write-Host "== $Name"
    & $dev @Arguments
    $code = $LASTEXITCODE
    Assert-True ($code -eq 0) "$Name exited with code $code"
}

function Read-Transcript {
    param([string]$Path, [string]$Name)
    Assert-True (Test-Path $Path) "$Name wrote no transcript at $Path"
    return Get-Content $Path -Raw
}

function Assert-NoFailure {
    param([string]$Text, [string]$Name)
    Assert-True ($Text -notmatch '(?im)^\s*(FAIL|error:)') "$Name reported a failure:`n$Text"
}

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Name)
    Assert-True ($Text -match $Pattern) "$Name did not report '$Pattern':`n$Text"
}

function Assert-Screenshot {
    param([string]$Path, [string]$Name)
    Assert-True (Test-Path $Path) "$Name wrote no screenshot at $Path"
    Assert-True ((Get-Item $Path).Length -gt 0) "$Name wrote an empty screenshot at $Path"
}

Test-DesktopReady

if ($ReadyOnly) {
    return
}

if (-not $SkipBuild) {
    Write-Host "== build DevTools"
    dotnet build apps/windows/Hopa.Windows.DevTools -c Release --nologo
    Assert-True ($LASTEXITCODE -eq 0) "DevTools did not build"
}

$dev = Join-Path $root "apps/windows/Hopa.Windows.DevTools/bin/Release/net10.0-windows/Hopa.Windows.DevTools.exe"
Assert-True (Test-Path $dev) "DevTools is not built at $dev"

$sidecar = Join-Path $root "apps/windows/sidecar/build/install/hopa-windows-sidecar/lib"
Assert-True (Test-Path $sidecar) "the sidecar is not installed; run gradlew -p apps/windows/sidecar installDist"

New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$shots = Join-Path $outDir "shots"
$w4 = Join-Path $outDir "w4"
$w6 = Join-Path $outDir "w6"
$web = Join-Path $outDir "web"
New-Item -ItemType Directory -Path $shots, $w4, $w6, $web -Force | Out-Null

# The checks launch real apps. Remember what was already running so cleanup
# only closes what this run started.
$watched = @("notepad", "calc", "CalculatorApp", "chrome", "msedge", "Code")
$before = @{}
foreach ($name in $watched) {
    $before[$name] = @(Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object Id)
}
$notepadWasOpen = $before["notepad"].Count -gt 0
if ($notepadWasOpen) {
    Write-Warning "Notepad is already open; the P2 readback assertion will be skipped so the person's document is not touched."
}

try {
    Invoke-DevTool "observation (W3)" @("--w3-check", (Join-Path $outDir "w3-check.txt"))
    $w3Text = Read-Transcript (Join-Path $outDir "w3-check.txt") "W3"
    Assert-NoFailure $w3Text "W3"
    Assert-Match $w3Text "blind type: refused" "W3"
    Assert-Match $w3Text "hash stable across two observations: True" "W3"

    Invoke-DevTool "device port (P2)" @("--p2-check", (Join-Path $outDir "p2-check.txt"))
    $p2Text = Read-Transcript (Join-Path $outDir "p2-check.txt") "P2"
    Assert-NoFailure $p2Text "P2"
    Assert-Match $p2Text "stale ref: refused" "P2"
    Assert-Match $p2Text "apps: [1-9][0-9]* from the Start menu" "P2"
    if (-not $notepadWasOpen) {
        Assert-Match $p2Text "readback matches: True" "P2"
    }

    Invoke-DevTool "app matrix" @("--matrix-check", (Join-Path $outDir "matrix-check.txt"))
    $matrixText = Read-Transcript (Join-Path $outDir "matrix-check.txt") "matrix"
    Assert-Match $matrixText "--- notepad" "matrix"
    Assert-Match $matrixText "observe: app=notepad" "matrix"

    Invoke-DevTool "window and tray (W4)" @("--w4-check", $w4)
    $w4Text = Read-Transcript (Join-Path $w4 "w4-check.txt") "W4"
    Assert-NoFailure $w4Text "W4"
    Assert-Match $w4Text "tray icon created: True" "W4"
    Assert-Match $w4Text "off-screen restore refused: True" "W4"
    Assert-Match $w4Text "automation names on controls: [1-9][0-9]*" "W4"
    Assert-Screenshot (Join-Path $w4 "windows-w4.png") "W4"

    Invoke-DevTool "keyboard order (W6)" @("--keyboard-check", $w6)
    $keyboardText = Read-Transcript (Join-Path $w6 "keyboard-check.txt") "keyboard"
    Assert-Match $keyboardText "focusable stops: [1-9][0-9]*" "keyboard"

    Invoke-DevTool "chat shot (W6)" @("--shot-chat", $shots)
    Assert-Screenshot (Join-Path $shots "windows-w6-chat.png") "chat shot"

    Invoke-DevTool "component shots (W6)" @("--shot-components", $shots)
    Assert-Screenshot (Join-Path $shots "windows-w6-approval.png") "component shot"
    Assert-Screenshot (Join-Path $shots "windows-w6-steps.png") "component shot"

    Invoke-DevTool "frame shot (W6)" @("--shot-frame", (Join-Path $shots "windows-frame.png"))
    Assert-Screenshot (Join-Path $shots "windows-frame.png") "frame shot"

    Invoke-DevTool "settings shot (W6)" @("--shot-settings", (Join-Path $shots "windows-settings.png"))
    Assert-Screenshot (Join-Path $shots "windows-settings.png") "settings shot"

    Invoke-DevTool "settings pages (W11)" @("--shot-settings-pages", $shots)
    Assert-Screenshot (Join-Path $shots "windows-settings-general.png") "settings pages"
    Assert-Screenshot (Join-Path $shots "windows-settings-run.png") "settings pages"
    Assert-Screenshot (Join-Path $shots "windows-settings-browser.png") "settings pages"

    Invoke-DevTool "web surface (W10f)" @("--web-check", $web)
    $webText = Read-Transcript (Join-Path $web "web-check.txt") "W10f"
    Assert-NoFailure $webText "W10f"
    Assert-Match $webText "has heading: True" "W10f"
    Assert-Match $webText "has refs: True" "W10f"
    Assert-Match $webText "signed visible: True" "W10f"
    Assert-Screenshot (Join-Path $web "windows-web-check.png") "W10f"
}
finally {
    foreach ($name in $watched) {
        Get-Process -Name $name -ErrorAction SilentlyContinue |
            Where-Object { $before[$name] -notcontains $_.Id } |
            ForEach-Object {
                try {
                    if ($_.CloseMainWindow()) {
                        $_.WaitForExit(3000)
                    }
                }
                catch {
                    # Already gone.
                }

                if (-not $_.HasExited) {
                    try {
                        $_.Kill($true)
                    }
                    catch {
                        # Already gone.
                    }
                }
            }
    }
}

Write-Host "desktop checks passed; artifacts: $outDir"
