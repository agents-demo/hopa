#!/usr/bin/env bash
# Compile and test the Kotlin brain. Pinned to Kotlin 2.1.0 and JDK 17.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=2.1.0
TOOLS="$ROOT/.tools"
KOTLINC="$TOOLS/kotlinc"

if [ ! -x "$KOTLINC/bin/kotlinc" ]; then
  mkdir -p "$TOOLS"
  curl -fL "https://github.com/JetBrains/kotlin/releases/download/v$VERSION/kotlin-compiler-$VERSION.zip" \
    -o "$TOOLS/kotlin-compiler-$VERSION.zip"
  unzip -q "$TOOLS/kotlin-compiler-$VERSION.zip" -d "$TOOLS"
fi

OUT="$ROOT/brain/build/brain.jar"
mkdir -p "$(dirname "$OUT")"
find "$ROOT/brain/src" -name '*.kt' -print0 |
  xargs -0 "$KOTLINC/bin/kotlinc" -include-runtime -d "$OUT"

java -cp "$OUT" hopa.brain.RouterTestKt
