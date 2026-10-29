#!/usr/bin/env bash
# Shows that an incremental build compiles Svc.groovy differently than a full build although it did not change.
# Restores the source it edits. Pass Gradle options through, for example: ./demo.sh -PgroovyVersion=5.1.4-SNAPSHOT
set -euo pipefail
cd "$(dirname "$0")"

UTIL=src/main/groovy/example/Util.groovy
CLASS=build/classes/groovy/main/example/Svc.class
OUT=build/demo
show() {
    local out
    out=$(javap -c -l -p "$1" | awk '/ make\(java.lang.String\);/{f=1} f && /LineNumberTable/{g=1} g && /line /{print "  " $1 " " $2 " " $3} g && /LocalVariableTable/{exit}' || true)
    if [ -n "$out" ]; then echo "$out"; else echo "  (none)"; fi
}

echo "== 1. Full build: all classes are compiled together"
./gradlew --console=plain -q "$@" clean classes
mkdir -p "$OUT"
cp "$CLASS" "$OUT/full.class"

echo
echo "== 2. Change a method body in Util, which Svc uses only inside a method body"
sed -i.bak "s/'loading'/'loading...'/" "$UTIL"
trap 'mv "$UTIL.bak" "$UTIL"' EXIT

echo
echo "== 3. Incremental build: Svc is recompiled against the other classes compiled"
./gradlew --console=plain --info "$@" classes | grep -E "Incremental compilation of|Full recompilation is required" || true
cp "$CLASS" "$OUT/incremental.class"

echo
echo "== 4. line number table of Svc.make, full build:"
show "$OUT/full.class"
echo "== line number table of Svc.make, incremental build:"
show "$OUT/incremental.class"
