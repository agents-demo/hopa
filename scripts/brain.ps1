# Compile and test the Kotlin brain. Pinned to Kotlin 2.1.0, Gson 2.11.0 and JDK 17.
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$version = "2.1.0"
$gsonVersion = "2.11.0"
$tools = Join-Path $root ".tools"
$kotlinc = Join-Path $tools "kotlinc"
$gson = Join-Path $tools "gson-$gsonVersion.jar"
$ProgressPreference = "SilentlyContinue"

if (-not (Test-Path (Join-Path $kotlinc "bin/kotlinc.bat"))) {
    New-Item -ItemType Directory -Force $tools | Out-Null
    $zip = Join-Path $tools "kotlin-compiler-$version.zip"
    Invoke-WebRequest -Uri "https://github.com/JetBrains/kotlin/releases/download/v$version/kotlin-compiler-$version.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tools -Force
}

if (-not (Test-Path $gson)) {
    New-Item -ItemType Directory -Force $tools | Out-Null
    Invoke-WebRequest -Uri "https://repo1.maven.org/maven2/com/google/code/gson/gson/$gsonVersion/gson-$gsonVersion.jar" -OutFile $gson
}

$sources = Get-ChildItem (Join-Path $root "brain/src") -Recurse -Filter *.kt |
    ForEach-Object { $_.FullName }
$out = Join-Path $root "brain/build/brain.jar"
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null

& (Join-Path $kotlinc "bin/kotlinc.bat") $sources -classpath $gson -include-runtime -d $out
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$classpath = "$out;$gson"
& java -cp $classpath hopa.brain.RouterTestKt
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& java -cp $classpath hopa.brain.ServerTestKt
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& java -cp $classpath hopa.brain.KnowledgeLoaderTestKt (Join-Path $root "brain/knowledge/apps")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& java -cp $classpath hopa.brain.PromptBookTestKt
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& java -cp $classpath hopa.brain.SkillLoaderTestKt (Join-Path $root "brain/knowledge/skills")
exit $LASTEXITCODE
