#!/usr/bin/env pwsh
# Sign the HOPA HAP with the OpenHarmony debug kit that ships inside the SDK.
#
# This is a *local* debug signature: it needs no Huawei account. It is only
# valid for development devices whose UDID is embedded in the profile.
#
#   .\scripts\sign-app.ps1                 # sign
#   .\scripts\sign-app.ps1 -Install        # sign and install on the connected device
#   .\scripts\sign-app.ps1 -Udids <udid>   # override the embedded device ids
#
# Everything it generates lives in signing/ (gitignored).
param(
    [switch]$Install,
    [string[]]$Udids = @(),
    [string]$BundleName = 'com.hopa.agent'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$signing = Join-Path $root 'tools\signing'
$keystore = Join-Path $signing 'OpenHarmony.p12'
$keystorePwd = '123456'
$keyAlias = 'hopa-app-debug'
$profileKeyAlias = 'openharmony application profile debug'
$appChain = Join-Path $signing 'app-chain.cer'
$profileJson = Join-Path $signing 'profile.json'
$profileP7b = Join-Path $signing 'profile.p7b'
$unsigned = Join-Path $root 'apps\harmony\entry\build\default\outputs\default\entry-default-unsigned.hap'
$signed = Join-Path $root 'apps\harmony\entry\build\default\outputs\default\entry-default-signed.hap'

# The Java tools log INFO to stderr. With $ErrorActionPreference = 'Stop' that
# would abort the run, so native calls go through this wrapper.
function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$Quiet
    )
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $FilePath @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if (-not $Quiet -and $output.Trim().Length -gt 0) { Write-Host $output.Trim() }
    return $code
}

function Resolve-SdkLib {
    $candidates = @()
    if ($env:HOPA_CLT_HOME) {
        $candidates += Join-Path $env:HOPA_CLT_HOME 'sdk\default\openharmony\toolchains\lib'
    }
    $candidates += 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\lib'
    $candidates += '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/lib'
    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate 'hap-sign-tool.jar')) { return $candidate }
    }
    throw 'OpenHarmony signing kit not found. Set HOPA_CLT_HOME or install DevEco Studio.'
}

function Resolve-Java {
    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += (Join-Path $env:JAVA_HOME 'bin\java.exe') }
    $candidates += 'C:\Program Files\Huawei\DevEco Studio\jbr\bin\java.exe'
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command java -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'java not found. Install a JDK or DevEco Studio.'
}

function Resolve-Keytool {
    $java = Resolve-Java
    $candidate = Join-Path (Split-Path -Parent $java) 'keytool.exe'
    if (Test-Path $candidate) { return $candidate }
    $unix = Join-Path (Split-Path -Parent $java) 'keytool'
    if (Test-Path $unix) { return $unix }
    $cmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'keytool not found. Install a JDK or DevEco Studio.'
}

function Resolve-Hdc {
    # The Command Line Tools hdc 3.2.0d crashes on `install` (missing DLL), so
    # prefer DevEco's bundled copy when it exists.
    $candidates = @()
    $candidates += 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
    if ($env:HOPA_CLT_HOME) {
        $candidates += Join-Path $env:HOPA_CLT_HOME 'sdk\default\openharmony\toolchains\hdc.exe'
    }
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command hdc -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$sdkLib = Resolve-SdkLib
$java = Resolve-Java
$keytool = Resolve-Keytool
$signTool = Join-Path $sdkLib 'hap-sign-tool.jar'

New-Item -ItemType Directory -Force $signing | Out-Null

if (-not (Test-Path $unsigned)) {
    throw "Unsigned HAP not found: $unsigned. Run .\scripts\build.ps1 first."
}

# 1. Local keystore: a copy of the SDK debug keystore plus our own app key.
if (-not (Test-Path $keystore)) {
    Copy-Item (Join-Path $sdkLib 'OpenHarmony.p12') $keystore
    Write-Host "Copied the SDK debug keystore to signing\OpenHarmony.p12"
}

$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $list = & $keytool -list -keystore $keystore -storepass $keystorePwd 2>&1 | Out-String
} finally {
    $ErrorActionPreference = $previous
}
if ($list -notmatch [regex]::Escape($keyAlias)) {
    Write-Host '=== generate app keypair ==='
    $code = Invoke-Native -FilePath $java -Arguments @(
        '-jar', $signTool, 'generate-keypair',
        '-keyAlias', $keyAlias, '-keyPwd', $keystorePwd,
        '-keyAlg', 'ECC', '-keySize', 'NIST-P-256',
        '-keystoreFile', $keystore, '-keystorePwd', $keystorePwd)
    if ($code -ne 0) { throw 'generate-keypair failed' }
}

# 2. Root and CA certificates from the SDK keystore.
$rootCer = Join-Path $signing 'root.cer'
$caCer = Join-Path $signing 'ca.cer'
$code = Invoke-Native -FilePath $keytool -Arguments @(
    '-exportcert', '-rfc', '-alias', 'openharmony application root ca',
    '-keystore', $keystore, '-storepass', $keystorePwd, '-file', $rootCer) -Quiet
if ($code -ne 0) { throw 'failed to export the root CA certificate' }
$code = Invoke-Native -FilePath $keytool -Arguments @(
    '-exportcert', '-rfc', '-alias', 'openharmony application ca',
    '-keystore', $keystore, '-storepass', $keystorePwd, '-file', $caCer) -Quiet
if ($code -ne 0) { throw 'failed to export the application CA certificate' }

# 3. App certificate chain. The DN order must be C,O,OU,CN: the tool reverses it
#    before comparing the issuer with the CA subject.
Write-Host '=== generate app certificate chain ==='
$code = Invoke-Native -FilePath $java -Arguments @(
    '-jar', $signTool, 'generate-app-cert',
    '-keyAlias', $keyAlias, '-keyPwd', $keystorePwd,
    '-issuer', 'C=CN, O=OpenHarmony, OU=OpenHarmony Team, CN=OpenHarmony Application CA',
    '-issuerKeyAlias', 'openharmony application ca', '-issuerKeyPwd', $keystorePwd,
    '-subject', 'C=CN, O=OpenHarmony, OU=OpenHarmony Team, CN=HOPA Debug',
    '-validity', '365', '-signAlg', 'SHA256withECDSA',
    '-rootCaCertFile', $rootCer, '-subCaCertFile', $caCer,
    '-keystoreFile', $keystore, '-keystorePwd', $keystorePwd,
    '-outForm', 'certChain', '-outFile', $appChain)
if ($code -ne 0) { throw 'generate-app-cert failed' }

# 4. Provision profile with the leaf certificate and the device ids.
Write-Host '=== build debug profile ==='
$template = Get-Content (Join-Path $sdkLib 'UnsgnedDebugProfileTemplate.json') -Raw | ConvertFrom-Json

$chainText = Get-Content $appChain -Raw
$leaf = [regex]::Match(
    $chainText,
    '-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----'
).Value
if ([string]::IsNullOrEmpty($leaf)) { throw 'No leaf certificate found in the app chain' }
$leaf = $leaf + "`n"

if ($Udids.Count -eq 0) {
    $hdc = Resolve-Hdc
    if ($hdc) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = & $hdc shell 'bm get --udid' 2>&1 | Out-String
        } finally {
            $ErrorActionPreference = $previous
        }
        $match = [regex]::Match($output, '[0-9A-Fa-f]{64}')
        if ($match.Success) { $Udids = @($match.Value) }
    }
}
if ($Udids.Count -eq 0) {
    throw 'No device UDID. Connect a device, or pass -Udids <udid>.'
}
Write-Host "Device ids: $($Udids -join ', ')"

$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$template.'version-name' = '2.0.0'
$template.'version-code' = 2
$template.uuid = [guid]::NewGuid().ToString()
$template.validity.'not-before' = $now - 86400
$template.validity.'not-after' = $now + 365 * 86400
$template.type = 'debug'
$template.'bundle-info'.'bundle-name' = $BundleName
$template.'bundle-info'.'developer-id' = 'OpenHarmony'
$template.'bundle-info'.'development-certificate' = $leaf
$template.'bundle-info'.apl = 'normal'
$template.'bundle-info'.'app-feature' = 'hos_normal_app'
$template.'debug-info'.'device-ids' = $Udids
$template.'debug-info'.'device-id-type' = 'udid'
$template.acls.'allowed-acls' = @('ohos.permission.ACCESSIBILITY_EXTENSION_ABILITY')
$template.permissions.'restricted-permissions' = @()

$template | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $profileJson

$code = Invoke-Native -FilePath $java -Arguments @(
    '-jar', $signTool, 'sign-profile', '-mode', 'localSign',
    '-keyAlias', $profileKeyAlias, '-keyPwd', $keystorePwd,
    '-profileCertFile', (Join-Path $sdkLib 'OpenHarmonyProfileDebug.pem'),
    '-inFile', $profileJson, '-signAlg', 'SHA256withECDSA',
    '-keystoreFile', $keystore, '-keystorePwd', $keystorePwd,
    '-outFile', $profileP7b)
if ($code -ne 0) { throw 'sign-profile failed' }

# 5. Sign and verify the HAP.
Write-Host '=== sign the HAP ==='
$code = Invoke-Native -FilePath $java -Arguments @(
    '-jar', $signTool, 'sign-app', '-mode', 'localSign',
    '-keyAlias', $keyAlias, '-keyPwd', $keystorePwd,
    '-appCertFile', $appChain, '-profileFile', $profileP7b,
    '-inFile', $unsigned, '-signAlg', 'SHA256withECDSA',
    '-keystoreFile', $keystore, '-keystorePwd', $keystorePwd,
    '-outFile', $signed, '-compatibleVersion', '24', '-signCode', '1')
if ($code -ne 0) { throw 'sign-app failed' }

Write-Host '=== verify the HAP ==='
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $verify = & $java -jar $signTool verify-app -inFile $signed `
        -outCertChain (Join-Path $signing 'verify-chain.cer') `
        -outProfile (Join-Path $signing 'verify-profile.p7b') 2>&1 | Out-String
} finally {
    $ErrorActionPreference = $previous
}
if ($verify -notmatch 'Verify success') {
    Write-Host $verify
    throw 'verify-app failed'
}
Write-Host "Signed: $signed"

if ($Install) {
    $hdc = Resolve-Hdc
    if (-not $hdc) { throw 'hdc not found; cannot install.' }
    $code = Invoke-Native -FilePath $hdc -Arguments @('install', '-r', $signed)
    if ($code -ne 0) { throw 'install failed' }
    Write-Host 'Installed on the connected device.'
}
