#!/usr/bin/env bash
# Standalone package checks; no Swan, SCIP indexer or language server needed.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
GOOSE="${GOOSE:-goose}"
export GOOSE_HOME="${GOOSE_HOME:-$root/.test-cache}"
build="${TEST_BUILD_DIR:-$root/.test-build}"
mkdir -p "$build"
build="$(cd "$build" && pwd)"
"$GOOSE" build --offline tests/api.goose -o "$build/api"
scratch="$(mktemp -d "$build/run.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
"$build/api" "$scratch"
