#!/usr/bin/env bash
# Mengambil rilis Hangover (Wine + FEX, .deb Debian 13 trixie arm64) lalu menyusun ulang ke ./out/usr
# (bin/ lib/ share/) supaya bisa dibungkus package-wcp.sh menjadi .wcp.
set -euo pipefail
ROOT="$(pwd)"; WORK="$ROOT/hangover"; OUT="$ROOT/out/usr"
rm -rf "$WORK" "$ROOT/out"; mkdir -p "$WORK/debs" "$WORK/x" "$OUT"

if [ -n "${HANGOVER_TAR:-}" ]; then
  cp "$HANGOVER_TAR" "$WORK/h.tar"; tag="${HANGOVER_TAG:-local}"
else
  repo="AndreRH/hangover"; tag="${HANGOVER_TAG:-}"
  [ -n "$tag" ] || tag=$(gh release view -R "$repo" --json tagName -q .tagName)
  assets=$(gh release view "$tag" -R "$repo" --json assets -q '.assets[].name')
  echo "== aset rilis $tag =="; echo "$assets"
  asset=$(echo "$assets" | grep -E 'debian13_trixie_arm64\.tar$' | head -n1 || true)
  [ -n "$asset" ] || { echo "::error::aset debian13_trixie_arm64 tidak ada di $repo@$tag"; exit 1; }
  gh release download "$tag" -R "$repo" -p "$asset" -O "$WORK/h.tar"
fi

tar -xf "$WORK/h.tar" -C "$WORK/debs"
echo "== isi paket =="
find "$WORK/debs" -name '*.deb' | sort | while read -r d; do
  echo "$(basename "$d")"; dpkg-deb -x "$d" "$WORK/x"
done

ntdll=$(find "$WORK/x" -path '*/lib/wine/aarch64-unix/ntdll.so' | head -n1 || true)
if [ -z "$ntdll" ]; then
  echo "::error::lib/wine/aarch64-unix/ntdll.so tidak ditemukan. Isi hasil ekstrak:"; find "$WORK/x" -maxdepth 4 | head -60; exit 1
fi
wineroot=$(dirname "$(dirname "$(dirname "$(dirname "$ntdll")")")")
echo "akar Wine: ${wineroot#"$WORK"/x}"

for d in bin lib share; do
  if [ -d "$wineroot/$d" ]; then cp -a "$wineroot/$d" "$OUT/$d"; fi
done

echo "== berkas FEX di paket =="
find "$WORK/x" \( -name 'libwow64fex.*' -o -name 'libarm64ecfex.*' \) | sed "s#$WORK/x##"
echo "$tag" > "$ROOT/.hangover-tag"
du -sh "$OUT"
