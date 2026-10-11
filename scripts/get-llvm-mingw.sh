#!/usr/bin/env bash
# Mengunduh llvm-mingw (host aarch64) ke ./llvm-mingw. Dipakai untuk PE arm64ec/aarch64/i386.
set -euo pipefail
tag="${LLVM_MINGW_TAG:?}"
asset=$(gh release view "$tag" -R mstorsjo/llvm-mingw --json assets -q '.assets[].name' \
  | grep -E 'ucrt-ubuntu-[0-9.]+-aarch64\.tar\.xz$' | head -n1)
[ -n "$asset" ] || { echo "::error::Aset aarch64 llvm-mingw $tag tidak ditemukan"; exit 1; }
echo "llvm-mingw: $asset"
gh release download "$tag" -R mstorsjo/llvm-mingw -p "$asset" -O llvm-mingw.tar.xz
mkdir -p llvm-mingw
tar -xJf llvm-mingw.tar.xz -C llvm-mingw --strip-components=1
rm -f llvm-mingw.tar.xz
for t in arm64ec aarch64 i686; do
  test -x "llvm-mingw/bin/$t-w64-mingw32-clang" || { echo "::error::$t-w64-mingw32-clang tidak ada"; exit 1; }
done
