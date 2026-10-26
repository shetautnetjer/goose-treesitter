#!/usr/bin/env bash
# Builds this package's native part ahead of time, one static archive per
# piece, for the machine it runs on: egg/<target>/libts_runtime.a (the shim
# and tree-sitter) and egg/<target>/libts_<language>.a, and prints their
# SHA-256 for egg.toml. The archives go to a GitHub release; CMakeLists.txt
# fetches and checks them instead of compiling ~100 MB of C.
#   scripts/build-egg.sh        (CC: the C compiler, default cc)
set -euo pipefail
cd "$(dirname "$0")/.."
os=$(uname -s | tr '[:upper:]' '[:lower:]'); cpu=$(uname -m)
case "$cpu" in x86_64|amd64) cpu=x64 ;; aarch64|arm64) cpu=arm64 ;; esac
target="$os-$cpu"
out="egg/$target"; obj="egg/obj-$target"
rm -rf "$out" "$obj"; mkdir -p "$out" "$obj"
inc="-Ivendor/tree-sitter/lib/include -Ivendor/tree-sitter/lib/src -Ivendor/tree-sitter-typescript/typescript/src"
compile() { "${CC:-cc}" -O2 -fPIC $inc -c "$1" -o "$2"; }
compile ts_shim.c "$obj/ts_shim.o" &
compile grammars/runtime.c "$obj/runtime.o" &
for f in grammars/*_parser.c grammars/*_scanner.c; do compile "$f" "$obj/$(basename "$f" .c).o" & done
wait
ar rcs "$out/libts_runtime.a" "$obj/ts_shim.o" "$obj/runtime.o"
for p in grammars/*_parser.c; do
    lang=$(basename "$p" _parser.c)
    objs="$obj/${lang}_parser.o"
    [ -f "$obj/${lang}_scanner.o" ] && objs="$objs $obj/${lang}_scanner.o"
    ar rcs "$out/libts_$lang.a" $objs
done
rm -rf "$obj"
echo "[targets.$target]"
for a in "$out"/*.a; do echo "$(basename "$a" .a) = \"$(sha256sum "$a" | cut -d' ' -f1)\""; done
