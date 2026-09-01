#!/usr/bin/env bash
# Build the uploadable .plasmoid archive for store.kde.org.
#
#   ./build.sh
#
# A .plasmoid is a plain zip whose *root* holds metadata.json -- the package
# directory itself must not appear as a leading path component, or Plasma
# refuses the archive.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/package"
ID="$(sed -n 's/.*"Id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SRC/metadata.json")"
VERSION="$(sed -n 's/.*"Version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SRC/metadata.json")"
OUT="$ROOT/dist/${ID}-${VERSION}.plasmoid"

[[ -n "$ID" && -n "$VERSION" ]] || { echo "error: cannot read Id/Version from metadata.json" >&2; exit 1; }

mkdir -p "$ROOT/dist"
rm -f "$OUT"

# -x drops editor leftovers and VCS noise that would otherwise ship to the store.
( cd "$SRC" && zip -r -q -X "$OUT" . \
    -x '*.orig' '*.rej' '*~' '*.swp' '.directory' '*/.git/*' '.git/*' '*/.DS_Store' )

unzip -l "$OUT" | grep -q ' metadata.json$' || {
    echo "error: metadata.json is not at the archive root" >&2; exit 1; }

echo "Built $OUT"
unzip -l "$OUT"
