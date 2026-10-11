#!/usr/bin/env bash
# Build Wine/Proton arm64ec (unix aarch64 glibc + PE arm64ec/aarch64/i386) lalu install ke ./out/usr
set -euo pipefail
: "${WINE_REPO:?}" "${WINE_REF:?}"
ROOT="$(pwd)"
SRC="$ROOT/wine-src"; BUILD="$ROOT/build"; OUT="$ROOT/out"
export PATH="$ROOT/llvm-mingw/bin:$PATH"

rm -rf "$SRC" "$BUILD" "$OUT"
mkdir -p "$SRC" "$BUILD" "$OUT"

echo "::group::Ambil sumber $WINE_REPO @ $WINE_REF"
git -C "$SRC" init -q
git -C "$SRC" remote add origin "$WINE_REPO"
git -C "$SRC" fetch --depth 1 origin "$WINE_REF"
git -C "$SRC" checkout -q FETCH_HEAD
git -C "$SRC" log -1 --oneline
echo "::endgroup::"

shopt -s nullglob
for p in "$ROOT"/patches/*.patch; do
  echo "Menerapkan $(basename "$p")"
  git -C "$SRC" apply --whitespace=nowarn "$p"
done
# Bila patch menyentuh configure.ac, regenerasi configure.
if git -C "$SRC" diff --name-only | grep -q '^configure\.ac$'; then
  (cd "$SRC" && autoreconf -f)
fi

cd "$BUILD"
echo "::group::configure"
CC="ccache gcc" CXX="ccache g++" \
CFLAGS="-O2 -pipe -g0" CXXFLAGS="-O2 -pipe -g0" CROSSCFLAGS="-O2 -pipe -g0" \
"$SRC/configure" \
  --prefix=/usr \
  --enable-archs=arm64ec,aarch64,i386 \
  --disable-tests \
  --without-oss
echo "::endgroup::"

grep -E '^(arm64ec|aarch64|i386)_CC' Makefile || echo "::warning::variabel cross-compiler tidak terbaca di Makefile"

echo "::group::make"
make -j"$(nproc)"
echo "::endgroup::"

make install DESTDIR="$OUT"

echo "::group::strip"
find "$OUT/usr" -type f \( -name '*.so' -o -name '*.so.*' \) -exec strip --strip-unneeded {} + 2>/dev/null || true
for b in "$OUT"/usr/bin/*; do
  file "$b" 2>/dev/null | grep -q ELF && strip --strip-unneeded "$b" 2>/dev/null || true
done
find "$OUT/usr/lib" -type f \( -name '*.dll' -o -name '*.exe' -o -name '*.sys' -o -name '*.drv' -o -name '*.ocx' -o -name '*.cpl' -o -name '*.acm' -o -name '*.ax' -o -name '*.tlb' \) \
  -exec llvm-strip --strip-unneeded {} + 2>/dev/null || true
echo "::endgroup::"
du -sh "$OUT/usr"
