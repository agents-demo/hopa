# Compile and test the Kotlin brain. Pinned to Kotlin 2.1.0 and JDK 17.
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$version = "2.1.0"
$tools = Join-Path $root ".tools"
$kotlinc = Join-Path $tools "kotlinc"

if (-not (Test-Path (Join-Path $kotlinc "bin/kotlinc.bat"))) {
    New-Item -ItemType Directory -Force $tools | Out-Null
    $zip = Join-Path $tools "kotlin-compiler-$version.zip"
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri "https://github.com/JetBrains/kotlin/releases/download/v$version/kotlin-compiler-$version.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tools -Force
}

$sources = Get-ChildItem (Join-Path $root "brain/src") -Recurse -Filter *.kt |
    ForEach-Object { $_.FullName }
$out = Join-Path $root "brain/build/brain.jar"
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null

& (Join-Path $kotlinc "bin/kotlinc.bat") $sources -include-runtime -d $out
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& java -cp $out hopa.brain.RouterTestKt
exit $LASTEXITCODE
