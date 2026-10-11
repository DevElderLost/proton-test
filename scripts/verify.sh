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
for d in aarch64-windows i386-windows; do
  if [ -d "$root/lib/wine/$d" ]; then echo "ok: lib/wine/$d"; else echo "::warning::lib/wine/$d tidak ada"; fi
done

# arm64ec: tergantung versi/build, buktinya bisa berbeda. Cukup SATU bukti berikut:
#  a) folder arm64ec-windows (Wine lama)
#  b) ntdll.dll hybrid ARM64X di aarch64-windows (section .a64xrm / .hexpthk)
#  c) ntdll.so memuat kode arm64ec (alloc_arm64ec_map, __wine_unix_call_dispatcher_arm64ec, ...)
#  d) libarm64ecfex.dll (FEX arm64ec) ada di aarch64-windows
ec=0
if [ -f "$root/lib/wine/arm64ec-windows/ntdll.dll" ]; then echo "bukti arm64ec: arm64ec-windows/ntdll.dll"; ec=1; fi

# Diagnostik ntdll.dll (selalu dicetak supaya mudah dianalisis bila gagal)
python3 - "$root/lib/wine/aarch64-windows/ntdll.dll" <<'PY' && ec=1
import struct, sys
try:
    d = open(sys.argv[1], 'rb').read(1 << 16)
    o = struct.unpack_from('<I', d, 0x3c)[0]
    m, ns = struct.unpack_from('<HH', d, o + 4)
    so, = struct.unpack_from('<H', d, o + 20)
    st = o + 24 + so
    secs = [d[st + i * 40: st + i * 40 + 8].rstrip(b'\0').decode('latin1') for i in range(ns)]
except Exception as e:
    print('ntdll.dll (aarch64-windows) tidak terbaca:', e); sys.exit(1)
print('ntdll.dll aarch64-windows: machine=%s sections=%s' % (hex(m), secs))
ok = '.a64xrm' in secs or '.hexpthk' in secs
if ok: print('bukti arm64ec: ntdll.dll hybrid ARM64X')
sys.exit(0 if ok else 1)
PY

if [ -f "$root/lib/wine/aarch64-unix/ntdll.so" ] && grep -aq 'arm64ec' "$root/lib/wine/aarch64-unix/ntdll.so"; then
  echo "bukti arm64ec: ntdll.so memuat kode arm64ec"; ec=1
fi
if [ -f "$root/lib/wine/aarch64-windows/libarm64ecfex.dll" ]; then
  echo "bukti arm64ec: libarm64ecfex.dll ada"; ec=1
fi
[ "$ec" = 1 ] || { echo "::error::tidak ada bukti arm64ec sama sekali: build ini bukan arm64ec"; fail=1; }

exit $fail
