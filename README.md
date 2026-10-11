# proton-arm64ec-wcp

Build **Proton/Wine arm64ec (glibc)** lewat GitHub Actions, dibungkus jadi `.wcp`
(format Winlator ContentsManager) dan dibagikan sebagai artefak. Ditujukan untuk
Tiny Computer (Debian trixie arm64 + FEX), tetapi format `.wcp` standar.

## Cara pakai
1. Buat repo GitHub (publik, supaya runner arm64 gratis), unggah isi folder ini.
2. Tab **Actions** → **Build Proton arm64ec (glibc) WCP** → **Run workflow**.
3. Isi input bila perlu:
   - `wine_repo` / `wine_ref`: sumber Wine/Proton. **Harus mendukung arm64ec.**
   - `version_name`, `version_code`: nama dan versi di `profile.json`.
   - `create_release`: centang untuk juga mengunggah ke Releases.
4. Setelah selesai, unduh artefak `Proton-<versi>-wcp`, ekstrak zip-nya, lalu impor
   `Proton-<versi>.wcp` di Pengaturan → Konten Wine Tiny.

## Isi repo
- `.github/workflows/build-proton-arm64ec.yml` — workflow.
- `scripts/get-llvm-mingw.sh` — toolchain PE arm64ec/aarch64/i386 (llvm-mingw).
- `scripts/build.sh` — clone, terapkan `patches/*.patch`, configure `--enable-archs=arm64ec,aarch64,i386`, make, install, strip.
- `scripts/verify.sh` — gagal bila hasil build bionic atau bukan arm64ec.
- `scripts/package-wcp.sh` — membuat `profile.json` dan `.wcp` (tar.xz) + sha256.
- `patches/` — taruh patch tambahan (`*.patch`, diterapkan berurutan).

## Catatan penting
- Repo ini **belum pernah dijalankan**. Sumber bawaan (`ValveSoftware/wine` branch
  `proton_9.0`) adalah tebakan; Wine 9.0 hanya punya dukungan arm64ec awal. Bila
  build gagal atau Wine tidak bisa boot, ganti `wine_repo`/`wine_ref` ke fork
  Proton 9.0 arm64ec yang memang dipakai Winlator/WinNative, atau tambahkan patch ke `patches/`.
- FEXCore (`libwow64fex.dll`, `libarm64ecfex.dll`), DXVK, dan VKD3D **tidak** termasuk;
  pasang sebagai paket `.wcp` terpisah.
- Tiny membuat prefix sendiri lewat `wineboot -u`, jadi `prefixPack` tidak dibuat.
- Rootfs Debian perlu library runtime Wine, mis.:
  `sudo apt install libfreetype6 libfontconfig1 libxkbcommon0 libvulkan1 libpulse0 libsdl2-2.0-0 libunwind8 libusb-1.0-0`.
