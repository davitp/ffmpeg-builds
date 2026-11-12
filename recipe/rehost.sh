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
mkdir -p "$WORK/in" "$WORK/stage" "$ROOT/dist"

ARCHIVE="$WORK/in/$(basename "$URL")"
curl -fsSL -o "$ARCHIVE" "$URL"
echo "$SHA  $ARCHIVE" | shasum -a 256 -c - >/dev/null || { echo "upstream hash mismatch" >&2; exit 1; }

NAME="ffmpeg-$FFMPEG_VERSION-b$BUILD_NUMBER-$PLATFORM"
STAGE="$WORK/stage/$NAME"
mkdir -p "$STAGE" "$WORK/unpack"
case "$ARCHIVE" in
  *.zip) unzip -q "$ARCHIVE" -d "$WORK/unpack" ;;
  *.tar.xz|*.tar.gz) tar -xf "$ARCHIVE" -C "$WORK/unpack" ;;
  *) echo "unknown archive type" >&2; exit 1 ;;
esac

find "$WORK/unpack" -type f \( -name 'ffmpeg' -o -name 'ffmpeg.exe' -o -name 'ffprobe' -o -name 'ffprobe.exe' \) -exec cp {} "$STAGE/" \;
find "$WORK/unpack" -type f -name 'LICENSE*' -exec cp {} "$STAGE/" \; || true
echo "upstream: $URL" > "$STAGE/UPSTREAM.txt"
echo "sha256: $SHA" >> "$STAGE/UPSTREAM.txt"

"$HERE/license-gate.sh" "$STAGE"

tar -C "$WORK/stage" -czf "$ROOT/dist/$NAME.tar.gz" "$NAME"
shasum -a 256 "$ROOT/dist/$NAME.tar.gz"
