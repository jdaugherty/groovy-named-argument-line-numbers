#!/usr/bin/env bash
# The difference with groovyc alone, no build tool involved: compiles all classes together, then compiles
# Svc against the other classes compiled. Uses groovyc from the PATH, or the command in
# the GROOVYC environment variable.
set -euo pipefail
cd "$(dirname "$0")"
GROOVYC=${GROOVYC:-groovyc}
command -v "${GROOVYC%% *}" > /dev/null || { echo "groovyc not found; put it on the PATH or set GROOVYC"; exit 1; }

SRC=src/main/groovy/example
OUT=build/groovyc
rm -rf "$OUT"
mkdir -p "$OUT/together" "$OUT/first" "$OUT/second"

show() {
    local out
    out=$(javap -c -l -p "$1" | awk '/ make\(java.lang.String\);/{f=1} f && /LineNumberTable/{g=1} g && /line /{print "  " $1 " " $2 " " $3} g && /LocalVariableTable/{exit}' || true)
    if [ -n "$out" ]; then echo "$out"; else echo "  (none)"; fi
}

echo "== all classes compiled together"
$GROOVYC -d "$OUT/together" "$SRC/Ctx.groovy" "$SRC/Util.groovy" "$SRC/Svc.groovy"
echo "== Svc compiled against the other classes compiled"
$GROOVYC -d "$OUT/first" "$SRC/Ctx.groovy" "$SRC/Util.groovy"
$GROOVYC -d "$OUT/second" -cp "$OUT/first" "$SRC/Svc.groovy"

echo
echo "== line number table of Svc.make, compiled together:"
show "$OUT/together/example/Svc.class"
echo "== line number table of Svc.make, compiled against the other classes:"
show "$OUT/second/example/Svc.class"
