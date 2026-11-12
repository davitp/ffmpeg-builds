#!/usr/bin/env bash
# Usage: recipe/build-macos.sh <arm64|x64> [work-dir]
# Builds static LGPL ffmpeg and ffprobe for macOS. Needs: pkg-config meson ninja nasm, Xcode command line tools.
set -euo pipefail

ARCH="${1:?arch: arm64 or x64}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="${2:-$ROOT/work/macos-$ARCH}"
# shellcheck source=versions.env
source "$HERE/versions.env"

case "$ARCH" in
  arm64) CLANG_ARCH=arm64; HOST=aarch64-apple-darwin; FF_ARCH=arm64; VPX_TARGET=arm64-darwin20-gcc; MESON_CPU=aarch64; MESON_FAMILY=aarch64 ;;
  x64) CLANG_ARCH=x86_64; HOST=x86_64-apple-darwin; FF_ARCH=x86_64; VPX_TARGET=x86_64-darwin20-gcc; MESON_CPU=x86_64; MESON_FAMILY=x86_64 ;;
  *) echo "unknown arch $ARCH" >&2; exit 1 ;;
esac

for tool in pkg-config meson ninja nasm curl shasum make; do
  command -v "$tool" >/dev/null || { echo "missing build tool: $tool" >&2; exit 1; }
done

export MACOSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET"
export CFLAGS="-arch $CLANG_ARCH -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET -O2"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-arch $CLANG_ARCH -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
PREFIX="$WORK/prefix"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
JOBS="$(sysctl -n hw.ncpu)"

mkdir -p "$WORK/src" "$PREFIX" "$ROOT/dist"

"$HERE/fetch-sources.sh"

extract() {
  local name="$1" file="$ROOT/cache/$2"
  rm -rf "$WORK/src/$name"
  mkdir -p "$WORK/src/$name"
  tar -xf "$file" -C "$WORK/src/$name" --strip-components=1
}

extract dav1d "$DAV1D_FILE"
extract libvpx "$LIBVPX_FILE"
extract opus "$OPUS_FILE"
extract ffmpeg "$FFMPEG_FILE"

CROSS_FILE="$WORK/meson-cross.ini"
cat > "$CROSS_FILE" <<CROSS
[binaries]
c = ['clang', '-arch', '$CLANG_ARCH']
cpp = ['clang++', '-arch', '$CLANG_ARCH']
ar = 'ar'
strip = 'strip'
pkg-config = 'pkg-config'

[host_machine]
system = 'darwin'
subsystem = 'macos'
kernel = 'xnu'
cpu_family = '$MESON_FAMILY'
cpu = '$MESON_CPU'
endian = 'little'

[built-in options]
c_args = ['-mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET']
c_link_args = ['-mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET']
CROSS

(
  cd "$WORK/src/dav1d"
  meson setup build --cross-file "$CROSS_FILE" --prefix "$PREFIX" --libdir lib --buildtype release \
    --default-library static -Denable_tools=false -Denable_tests=false
  ninja -C build -j "$JOBS" install
)

(
  cd "$WORK/src/opus"
  ./configure --prefix="$PREFIX" --host="$HOST" --enable-static --disable-shared --disable-doc --disable-extra-programs
  make -j "$JOBS"
  make install
)

(
  cd "$WORK/src/libvpx"
  ./configure --prefix="$PREFIX" --target="$VPX_TARGET" --enable-static --disable-shared --enable-pic \
    --disable-examples --disable-tools --disable-docs --disable-unit-tests --enable-vp9-highbitdepth \
    --enable-vp8 --enable-vp9 --disable-install-bins
  make -j "$JOBS"
  make install
)

OUT="$WORK/ffmpeg-out"
rm -rf "$OUT"
mkdir -p "$OUT"
(
  cd "$WORK/src/ffmpeg"
  CROSS_ARGS=()
  if [ "$ARCH" = x64 ] && [ "$(uname -m)" != x86_64 ]; then
    CROSS_ARGS=(--enable-cross-compile --target-os=darwin)
  fi
  # shellcheck disable=SC2046
  ./configure --prefix="$OUT" --arch="$FF_ARCH" ${CROSS_ARGS[@]+"${CROSS_ARGS[@]}"} \
    --cc="clang -arch $CLANG_ARCH" \
    --extra-cflags="-I$PREFIX/include" --extra-ldflags="-L$PREFIX/lib" \
    $(tr '\n' ' ' < "$HERE/configure-flags.txt")
  make -j "$JOBS"
  make install
)

NAME="ffmpeg-$FFMPEG_VERSION-b$BUILD_NUMBER-darwin-$ARCH"
STAGE="$WORK/stage/$NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "$OUT/bin/ffmpeg" "$OUT/bin/ffprobe" "$STAGE/"
strip -x "$STAGE/ffmpeg" "$STAGE/ffprobe"
cp "$WORK/src/ffmpeg/COPYING.LGPLv2.1" "$STAGE/"
mkdir -p "$STAGE/licenses"
cp "$WORK/src/dav1d/COPYING" "$STAGE/licenses/dav1d-COPYING"
cp "$WORK/src/libvpx/LICENSE" "$STAGE/licenses/libvpx-LICENSE"
cp "$WORK/src/libvpx/PATENTS" "$STAGE/licenses/libvpx-PATENTS"
cp "$WORK/src/opus/COPYING" "$STAGE/licenses/opus-COPYING"
"$STAGE/ffmpeg" -hide_banner -buildconf > "$STAGE/buildconf.txt" 2>&1 || true

"$HERE/license-gate.sh" "$STAGE"

tar -C "$WORK/stage" -czf "$ROOT/dist/$NAME.tar.gz" "$NAME"
shasum -a 256 "$ROOT/dist/$NAME.tar.gz"
