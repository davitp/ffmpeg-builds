#!/usr/bin/env bash
# Usage: recipe/rehost.sh <win32-x64|linux-x64> <upstream-archive-url> <upstream-sha256>
# Re-hosts a pinned upstream LGPL archive (BtbN lgpl variant) as our release asset after verifying its hash.
set -euo pipefail

PLATFORM="${1:?platform}"
URL="${2:?url}"
SHA="${3:?sha256}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"

WORK="$ROOT/work/rehost-$PLATFORM"
rm -rf "$WORK"
mkdir -p "$WORK/stage" "$ROOT/dist"

mkdir -p "$ROOT/cache"
ARCHIVE="$ROOT/cache/$(basename "$URL")"
if [ ! -f "$ARCHIVE" ]; then
  curl -fsSL -o "$ARCHIVE" "$URL"
fi
if ! echo "$SHA  $ARCHIVE" | shasum -a 256 -c - >/dev/null 2>&1; then
  rm -f "$ARCHIVE"
  echo "upstream hash mismatch" >&2
  exit 1
fi

NAME="ffmpeg-$FFMPEG_VERSION-b$BUILD_NUMBER-$PLATFORM"
STAGE="$WORK/stage/$NAME"
mkdir -p "$STAGE" "$WORK/unpack"
case "$ARCHIVE" in
  *.zip) unzip -q "$ARCHIVE" -d "$WORK/unpack" ;;
  *.tar.xz|*.tar.gz) tar -xf "$ARCHIVE" -C "$WORK/unpack" ;;
  *) echo "unknown archive type" >&2; exit 1 ;;
esac

find "$WORK/unpack" -type f \( -name 'ffmpeg' -o -name 'ffmpeg.exe' -o -name 'ffprobe' -o -name 'ffprobe.exe' \) -exec cp {} "$STAGE/" \;
find "$WORK/unpack" -type f -name 'LICENSE*' -exec cp {} "$STAGE/" \;
{
  echo "These binaries are an unmodified upstream LGPL build, re-hosted after checking its SHA256."
  echo "archive: $URL"
  echo "sha256: $SHA"
  echo "The corresponding source (the FFmpeg commit and the build scripts at the same tag) is in this release's source bundle."
} > "$STAGE/UPSTREAM.txt"

"$HERE/license-gate.sh" "$STAGE"

tar -C "$WORK/stage" -czf "$ROOT/dist/$NAME.tar.gz" "$NAME"
shasum -a 256 "$ROOT/dist/$NAME.tar.gz"
