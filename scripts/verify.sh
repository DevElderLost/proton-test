#!/usr/bin/env bash
# Memastikan hasil build glibc (interpreter ld-linux-aarch64) dan struktur arm64ec lengkap.
set -uo pipefail
root="${1:?usage: verify.sh <dir berisi bin/ lib/>}"
fail=0

for f in wine wineserver; do
  p="$root/bin/$f"
  if [ ! -e "$p" ]; then echo "::error::bin/$f tidak ada"; fail=1; continue; fi
  interp=$(readelf -l "$p" 2>/dev/null | sed -n 's/.*Requesting program interpreter: \(.*\)\]/\1/p')
  echo "bin/$f interpreter: ${interp:-<tidak ada>}"
  case "$interp" in
    *ld-linux-aarch64.so.1) ;;
    *linker64*) echo "::error::bin/$f build BIONIC, bukan glibc"; fail=1 ;;
    *) echo "::error::bin/$f interpreter tidak dikenal"; fail=1 ;;
  esac
done

[ -f "$root/lib/wine/aarch64-unix/ntdll.so" ] || { echo "::error::lib/wine/aarch64-unix/ntdll.so tidak ada"; fail=1; }
for d in arm64ec-windows aarch64-windows i386-windows; do
  if [ -d "$root/lib/wine/$d" ]; then echo "ok: lib/wine/$d"; else echo "::warning::lib/wine/$d tidak ada"; fi
done
[ -f "$root/lib/wine/arm64ec-windows/ntdll.dll" ] || { echo "::error::ntdll.dll arm64ec tidak ada: build ini bukan arm64ec"; fail=1; }

exit $fail
