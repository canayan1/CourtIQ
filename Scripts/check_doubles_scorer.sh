#!/bin/bash
# Validates the pure doubles scoring logic without an Xcode test target.
# Compiles the 3 pure source files + the harness with swiftc and runs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/CourtIQ/Features/Doubles"
TMP="$(mktemp -d)"
cp "$SRC/DoublesProfile.swift" "$SRC/DoublesResult.swift" "$SRC/DoublesCompatibility.swift" "$TMP/"
cp "$ROOT/Scripts/doubles_scorer_check.swift" "$TMP/main.swift"
( cd "$TMP" && swiftc -O *.swift -o doublestest && ./doublestest )
