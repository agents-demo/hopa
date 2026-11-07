#!/usr/bin/env bash
# Sign the HOPA HAP with the OpenHarmony debug kit shipped in the SDK (macOS/Linux).
#
#   ./scripts/sign-app.sh              # sign
#   ./scripts/sign-app.sh --install    # sign and install on the connected device
#   ./scripts/sign-app.sh --udid <id>  # override the embedded device id
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SIGNING="$ROOT/tools/signing"
KEYSTORE="$SIGNING/OpenHarmony.p12"
KEYSTORE_PWD=123456
KEY_ALIAS=hopa-app-debug
PROFILE_KEY_ALIAS="openharmony application profile debug"
APP_CHAIN="$SIGNING/app-chain.cer"
PROFILE_JSON="$SIGNING/profile.json"
PROFILE_P7B="$SIGNING/profile.p7b"
UNSIGNED="$ROOT/app/entry/build/default/outputs/default/entry-default-unsigned.hap"
SIGNED="$ROOT/app/entry/build/default/outputs/default/entry-default-signed.hap"

INSTALL=0
UDID=""
BUNDLE=${HOPA_BUNDLE:-com.hopa.agent}
while [ $# -gt 0 ]; do
  case "$1" in
    --install) INSTALL=1 ;;
    --udid) shift; UDID=${1:-} ;;
    --bundle) shift; BUNDLE=${1:-} ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

find_sdk_lib() {
  for candidate in \
    "${HOPA_CLT_HOME:-}/sdk/default/openharmony/toolchains/lib" \
    "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/lib" \
    "$HOME/Library/Huawei/Sdk/openharmony/toolchains/lib" \
    "/opt/huawei/sdk/default/openharmony/toolchains/lib"; do
    if [ -f "$candidate/hap-sign-tool.jar" ]; then
      echo "$candidate"
      return 0
    fi
  done
  echo "OpenHarmony signing kit not found. Set HOPA_CLT_HOME." >&2
  return 1
}

SDK_LIB=$(find_sdk_lib)
JAVA=${JAVA_HOME:+$JAVA_HOME/bin/java}
if [ -z "${JAVA:-}" ] || [ ! -x "$JAVA" ]; then
  if [ -x "/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home/bin/java" ]; then
    JAVA="/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home/bin/java"
  else
    JAVA=$(command -v java)
  fi
fi
KEYTOOL="$(dirname "$JAVA")/keytool"
[ -x "$KEYTOOL" ] || KEYTOOL=$(command -v keytool)
SIGN_TOOL="$SDK_LIB/hap-sign-tool.jar"

[ -f "$UNSIGNED" ] || { echo "Unsigned HAP not found: $UNSIGNED. Run scripts/build.sh first." >&2; exit 1; }
mkdir -p "$SIGNING"

if [ ! -f "$KEYSTORE" ]; then
  cp "$SDK_LIB/OpenHarmony.p12" "$KEYSTORE"
  echo "Copied the SDK debug keystore to signing/OpenHarmony.p12"
fi

if ! "$KEYTOOL" -list -keystore "$KEYSTORE" -storepass "$KEYSTORE_PWD" 2>/dev/null | grep -q "$KEY_ALIAS"; then
  echo "=== generate app keypair ==="
  "$JAVA" -jar "$SIGN_TOOL" generate-keypair \
    -keyAlias "$KEY_ALIAS" -keyPwd "$KEYSTORE_PWD" \
    -keyAlg ECC -keySize NIST-P-256 \
    -keystoreFile "$KEYSTORE" -keystorePwd "$KEYSTORE_PWD"
fi

"$KEYTOOL" -exportcert -rfc -alias "openharmony application root ca" \
  -keystore "$KEYSTORE" -storepass "$KEYSTORE_PWD" -file "$SIGNING/root.cer" >/dev/null 2>&1
"$KEYTOOL" -exportcert -rfc -alias "openharmony application ca" \
  -keystore "$KEYSTORE" -storepass "$KEYSTORE_PWD" -file "$SIGNING/ca.cer" >/dev/null 2>&1

# DN order must be C,O,OU,CN; the tool reverses it before comparing with the CA.
echo "=== generate app certificate chain ==="
"$JAVA" -jar "$SIGN_TOOL" generate-app-cert \
  -keyAlias "$KEY_ALIAS" -keyPwd "$KEYSTORE_PWD" \
  -issuer "C=CN, O=OpenHarmony, OU=OpenHarmony Team, CN=OpenHarmony Application CA" \
  -issuerKeyAlias "openharmony application ca" -issuerKeyPwd "$KEYSTORE_PWD" \
  -subject "C=CN, O=OpenHarmony, OU=OpenHarmony Team, CN=HOPA Debug" \
  -validity 365 -signAlg SHA256withECDSA \
  -rootCaCertFile "$SIGNING/root.cer" -subCaCertFile "$SIGNING/ca.cer" \
  -keystoreFile "$KEYSTORE" -keystorePwd "$KEYSTORE_PWD" \
  -outForm certChain -outFile "$APP_CHAIN"

if [ -z "$UDID" ]; then
  HDC=$(command -v hdc || true)
  if [ -n "$HDC" ]; then
    UDID=$("$HDC" shell "bm get --udid" 2>/dev/null | grep -oE '[0-9A-Fa-f]{64}' | head -n1 || true)
  fi
fi
[ -n "$UDID" ] || { echo "No device UDID. Connect a device or pass --udid <id>." >&2; exit 1; }
echo "Device id: $UDID"

echo "=== build debug profile ==="
HOPA_TEMPLATE="$SDK_LIB/UnsgnedDebugProfileTemplate.json" \
HOPA_CHAIN="$APP_CHAIN" HOPA_OUT="$PROFILE_JSON" \
HOPA_BUNDLE="$BUNDLE" HOPA_UDID="$UDID" \
python3 - <<'PY'
import json, os, time, uuid
tpl = json.load(open(os.environ["HOPA_TEMPLATE"], encoding="utf-8"))
chain = open(os.environ["HOPA_CHAIN"], encoding="utf-8").read()
start = chain.find("-----BEGIN CERTIFICATE-----")
end = chain.find("-----END CERTIFICATE-----")
leaf = chain[start:end + len("-----END CERTIFICATE-----")] + "\n"
now = int(time.time())
tpl["version-name"] = "2.0.0"
tpl["version-code"] = 2
tpl["uuid"] = str(uuid.uuid4())
tpl["validity"] = {"not-before": now - 86400, "not-after": now + 365 * 86400}
tpl["type"] = "debug"
tpl["bundle-info"]["bundle-name"] = os.environ["HOPA_BUNDLE"]
tpl["bundle-info"]["developer-id"] = "OpenHarmony"
tpl["bundle-info"]["development-certificate"] = leaf
tpl["bundle-info"]["apl"] = "normal"
tpl["bundle-info"]["app-feature"] = "hos_normal_app"
tpl["debug-info"] = {"device-ids": [os.environ["HOPA_UDID"]], "device-id-type": "udid"}
tpl["acls"] = {"allowed-acls": ["ohos.permission.ACCESSIBILITY_EXTENSION_ABILITY"]}
tpl["permissions"] = {"restricted-permissions": []}
open(os.environ["HOPA_OUT"], "w", encoding="utf-8").write(json.dumps(tpl, indent=2))
PY

"$JAVA" -jar "$SIGN_TOOL" sign-profile -mode localSign \
  -keyAlias "$PROFILE_KEY_ALIAS" -keyPwd "$KEYSTORE_PWD" \
  -profileCertFile "$SDK_LIB/OpenHarmonyProfileDebug.pem" \
  -inFile "$PROFILE_JSON" -signAlg SHA256withECDSA \
  -keystoreFile "$KEYSTORE" -keystorePwd "$KEYSTORE_PWD" \
  -outFile "$PROFILE_P7B"

echo "=== sign the HAP ==="
"$JAVA" -jar "$SIGN_TOOL" sign-app -mode localSign \
  -keyAlias "$KEY_ALIAS" -keyPwd "$KEYSTORE_PWD" \
  -appCertFile "$APP_CHAIN" -profileFile "$PROFILE_P7B" \
  -inFile "$UNSIGNED" -signAlg SHA256withECDSA \
  -keystoreFile "$KEYSTORE" -keystorePwd "$KEYSTORE_PWD" \
  -outFile "$SIGNED" -compatibleVersion 24 -signCode 1

echo "=== verify the HAP ==="
"$JAVA" -jar "$SIGN_TOOL" verify-app -inFile "$SIGNED" 2>&1 | grep -q "verify-app success" \
  || { echo "verify-app failed" >&2; exit 1; }
echo "Signed: $SIGNED"

if [ "$INSTALL" -eq 1 ]; then
  HDC=$(command -v hdc)
  "$HDC" install -r "$SIGNED"
  echo "Installed on the connected device."
fi
