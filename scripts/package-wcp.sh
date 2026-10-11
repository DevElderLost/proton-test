#!/usr/bin/env bash
# Membungkus ./out/usr menjadi .wcp (tar.xz berisi profile.json + bin/ lib/ share/), format Winlator ContentsManager.
set -euo pipefail
: "${VERSION_NAME:?}" "${VERSION_CODE:?}"
ROOT="$(pwd)"; STAGE="$ROOT/stage"; DIST="$ROOT/dist"
rm -rf "$STAGE" "$DIST"; mkdir -p "$STAGE" "$DIST"

for d in bin lib share; do
  if [ -d "$ROOT/out/usr/$d" ]; then cp -a "$ROOT/out/usr/$d" "$STAGE/$d"; fi
done
rm -rf "$STAGE/share/man" 2>/dev/null || true

commit="${COMMIT:-$(git -C "$ROOT/wine-src" rev-parse --short HEAD 2>/dev/null || echo unknown)}"
WCP_TYPE="${WCP_TYPE:-Proton}"
WCP_TYPE="$WCP_TYPE" VERSION_NAME="$VERSION_NAME" VERSION_CODE="$VERSION_CODE" COMMIT="$commit" python3 - <<'PY'
import json, os
profile = {
    "type": os.environ["WCP_TYPE"],
    "versionName": os.environ["VERSION_NAME"],
    "versionCode": int(os.environ["VERSION_CODE"]),
    "description": "%s %s arm64ec (glibc) @ %s" % (os.environ["WCP_TYPE"], os.environ["VERSION_NAME"], os.environ["COMMIT"]),
    "files": [],
    "wine": {"binPath": "bin", "libPath": "lib"},
}
json.dump(profile, open(os.path.join("stage", "profile.json"), "w"), indent=2)
PY

name="${WCP_TYPE}-${VERSION_NAME}.wcp"
XZ_OPT="-T0 -6" tar -C "$STAGE" -cJf "$DIST/$name" .
(cd "$DIST" && sha256sum "$name" > "$name.sha256")
ls -lh "$DIST"
