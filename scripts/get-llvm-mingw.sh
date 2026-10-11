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

B="$PWD/llvm-mingw/bin"
echo "== wrapper yang tersedia =="
ls "$B" | grep -E 'mingw32-(clang|clang\+\+|gcc|g\+\+)$' || true
echo "== sysroot target =="
ls -d "$PWD"/llvm-mingw/*-w64-mingw32 2>/dev/null || true

for t in aarch64 i686; do
  test -x "$B/$t-w64-mingw32-clang" || { echo "::error::$t-w64-mingw32-clang tidak ada"; exit 1; }
done

# Wrapper arm64ec: beberapa rilis tidak memasangnya di bin/ walau sysroot-nya ada.
try_arm64ec() {
  printf 'int main(void){return 0;}\n' > /tmp/t.c
  "$B/arm64ec-w64-mingw32-clang" /tmp/t.c -o /tmp/t.exe >/dev/null 2>&1
}

if [ ! -x "$B/arm64ec-w64-mingw32-clang" ]; then
  echo "::warning::arm64ec-w64-mingw32-clang tidak ada, mencoba membuatnya"
  if [ ! -d "$PWD/llvm-mingw/arm64ec-w64-mingw32" ]; then
    echo "::error::Rilis llvm-mingw $tag tidak punya sysroot arm64ec. Ganti input llvm_mingw_tag (mis. rilis yang lebih baru atau lebih lama)."
    exit 1
  fi
  # 1) pakai wrapper bawaan yang sama dengan aarch64 (target dibaca dari nama berkas)
  wrapper=$(readlink "$B/aarch64-w64-mingw32-clang" || true)
  if [ -n "$wrapper" ]; then
    for n in clang clang++ gcc g++ c++ cc; do
      [ -e "$B/aarch64-w64-mingw32-$n" ] && ln -sf "$wrapper" "$B/arm64ec-w64-mingw32-$n" || true
    done
  fi
  # 2) bila tidak bisa mengompilasi, pakai skrip pembungkus clang langsung
  if ! try_arm64ec; then
    echo "::warning::wrapper symlink gagal, memakai skrip --target"
    for n in clang clang++; do
      cat > "$B/arm64ec-w64-mingw32-$n" <<'SH'
#!/bin/sh
d=$(dirname "$(readlink -f "$0")")
case "$0" in *++) bin=clang++ ;; *) bin=clang ;; esac
exec "$d/$bin" --target=arm64ec-w64-windows-gnu -fuse-ld=lld -rtlib=compiler-rt -unwindlib=libunwind -Qunused-arguments "$@"
SH
      chmod +x "$B/arm64ec-w64-mingw32-$n"
    done
    for n in gcc cc; do ln -sf arm64ec-w64-mingw32-clang "$B/arm64ec-w64-mingw32-$n"; done
    for n in g++ c++; do ln -sf arm64ec-w64-mingw32-clang++ "$B/arm64ec-w64-mingw32-$n"; done
  fi
fi

try_arm64ec || { echo "::error::arm64ec-w64-mingw32-clang tidak bisa mengompilasi. Coba llvm_mingw_tag lain."; exit 1; }
echo "arm64ec-w64-mingw32-clang OK"
