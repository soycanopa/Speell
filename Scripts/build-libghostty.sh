#!/usr/bin/env bash
#
# Genera Vendor/GhosttyKit.xcframework desde el pin de Vendor/ghostty.pin.
#
# Fase 0 — docs/IMPLEMENTACION.md. El comando de build es el de docs/TRD.md
# ("Qué es de libghostty"). El artefacto no se commitea por peso: se commitean
# el pin y Vendor/GhosttyKit.xcframework.sha256.
#
# Uso:
#   Scripts/build-libghostty.sh            # zig si falta, clona el pin, compila
#   Scripts/build-libghostty.sh --verify   # compara el artefacto con el hash commiteado
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$ROOT/Vendor"
BUILD_DIR="$VENDOR/build"
TOOLCHAIN_DIR="$VENDOR/toolchain"
SRC_DIR="$BUILD_DIR/ghostty"
OUT="$VENDOR/GhosttyKit.xcframework"
HASH_FILE="$VENDOR/GhosttyKit.xcframework.sha256"

# shellcheck source=../Vendor/ghostty.pin
. "$VENDOR/ghostty.pin"

# Hash estable del árbol: rutas relativas + sha256 de cada archivo, hasheados.
artifact_hash() {
  (
    cd "$1" &&
      find . -type f | LC_ALL=C sort | while IFS= read -r f; do
        printf '%s  ' "$f"
        shasum -a 256 "$f" | awk '{print $1}'
      done | shasum -a 256 | awk '{print $1}'
  )
}

if [ "${1:-}" = "--verify" ]; then
  [ -d "$OUT" ] || { echo "falta $OUT: corre el script sin --verify" >&2; exit 1; }
  actual="$(artifact_hash "$OUT")"
  expected="$(tr -d '[:space:]' < "$HASH_FILE")"
  if [ "$actual" = "$expected" ]; then
    echo "ok: $OUT coincide con el pin ($actual)"
  else
    echo "drift: artefacto $actual != hash commiteado $expected" >&2
    exit 1
  fi
  exit 0
fi

# xcodebuild -create-xcframework vive en Xcode, no en CommandLineTools.
if ! xcodebuild -version >/dev/null 2>&1; then
  if [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi
fi
xcodebuild -version >/dev/null 2>&1 || {
  echo "error: xcodebuild no usable; instala Xcode o exporta DEVELOPER_DIR" >&2
  exit 1
}

case "$(uname -m)" in
  arm64)  zig_arch=aarch64-macos; zig_sha="$zig_sha256_aarch64_macos" ;;
  x86_64) zig_arch=x86_64-macos;  zig_sha="$zig_sha256_x86_64_macos" ;;
  *) echo "arquitectura no soportada: $(uname -m)" >&2; exit 1 ;;
esac

ZIG_DIR="$TOOLCHAIN_DIR/zig-$zig_arch-$zig_version"
ZIG="$ZIG_DIR/zig"
export ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$TOOLCHAIN_DIR/cache-$zig_version}"

if [ ! -x "$ZIG" ]; then
  echo "==> zig $zig_version ($zig_arch)"
  mkdir -p "$TOOLCHAIN_DIR"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -sfL "https://ziglang.org/download/$zig_version/zig-$zig_arch-$zig_version.tar.xz" \
    -o "$tmp/zig.tar.xz"
  echo "$zig_sha  $tmp/zig.tar.xz" | shasum -a 256 -c -
  tar -xf "$tmp/zig.tar.xz" -C "$TOOLCHAIN_DIR"
fi

if [ ! -d "$SRC_DIR/.git" ]; then
  echo "==> clonando ghostty (historial sin blobs)"
  mkdir -p "$BUILD_DIR"
  git clone --filter=blob:none \
    https://github.com/ghostty-org/ghostty.git "$SRC_DIR"
fi

echo "==> checkout $ghostty_commit"
if ! git -C "$SRC_DIR" checkout -q --detach "$ghostty_commit" 2>/dev/null; then
  git -C "$SRC_DIR" fetch -q --depth 1 origin "$ghostty_commit"
  git -C "$SRC_DIR" checkout -q --detach FETCH_HEAD
fi

head="$(git -C "$SRC_DIR" rev-parse HEAD)"
if [ "$head" != "$ghostty_commit" ]; then
  echo "error: $SRC_DIR está en $head, el pin es $ghostty_commit" >&2
  exit 1
fi

echo "==> compilando GhosttyKit.xcframework (ReleaseFast, native)"
# -Di18n=false: Speell no embarca las traducciones de Ghostty y así el build no
# exige gettext (msgfmt). Ver docs/decisions/0001-pin-libghostty.md.
(cd "$SRC_DIR" && "$ZIG" build \
  -Demit-xcframework=true \
  -Dxcframework-target=native \
  -Demit-macos-app=false \
  -Di18n=false \
  -Doptimize=ReleaseFast)

echo "==> copiando artefacto"
rm -rf "$OUT"
cp -R "$SRC_DIR/macos/GhosttyKit.xcframework" "$OUT"

artifact_hash "$OUT" > "$HASH_FILE"
echo "==> $OUT"
echo "==> hash: $(cat "$HASH_FILE")"
