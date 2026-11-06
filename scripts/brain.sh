#!/usr/bin/env bash
# Compile and test the Kotlin brain. Pinned to Kotlin 2.1.0, Gson 2.11.0 and JDK 17.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=2.1.0
GSON_VERSION=2.11.0
TOOLS="$ROOT/.tools"
KOTLINC="$TOOLS/kotlinc"
GSON="$TOOLS/gson-$GSON_VERSION.jar"

if [ ! -x "$KOTLINC/bin/kotlinc" ]; then
  mkdir -p "$TOOLS"
  curl -fL "https://github.com/JetBrains/kotlin/releases/download/v$VERSION/kotlin-compiler-$VERSION.zip" \
    -o "$TOOLS/kotlin-compiler-$VERSION.zip"
  unzip -q "$TOOLS/kotlin-compiler-$VERSION.zip" -d "$TOOLS"
fi

if [ ! -f "$GSON" ]; then
  mkdir -p "$TOOLS"
  curl -fL "https://repo1.maven.org/maven2/com/google/code/gson/gson/$GSON_VERSION/gson-$GSON_VERSION.jar" \
    -o "$GSON"
fi

OUT="$ROOT/brain/build/brain.jar"
mkdir -p "$(dirname "$OUT")"
find "$ROOT/brain/src" -name '*.kt' -print0 |
  xargs -0 "$KOTLINC/bin/kotlinc" -classpath "$GSON" -include-runtime -d "$OUT"

java -cp "$OUT:$GSON" hopa.brain.RouterTestKt
java -cp "$OUT:$GSON" hopa.brain.ServerTestKt
java -cp "$OUT:$GSON" hopa.brain.KnowledgeLoaderTestKt "$ROOT/brain/knowledge/apps"
java -cp "$OUT:$GSON" hopa.brain.PromptBookTestKt
java -cp "$OUT:$GSON" hopa.brain.SkillLoaderTestKt "$ROOT/brain/knowledge/skills"
