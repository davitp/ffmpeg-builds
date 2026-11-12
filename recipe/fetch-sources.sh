#!/usr/bin/env bash
# Downloads every pinned source tarball into cache/ and verifies its SHA256: the libraries this repo builds
# (versions.env) and the upstream source of the re-hosted binaries (rehost.env).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"
# shellcheck source=rehost.env
source "$HERE/rehost.env"

mkdir -p "$ROOT/cache"

pinned() {
  local label="$1" url="$2" file="$3" sha="$4" path="$ROOT/cache/$3"
  if [ -z "$url" ]; then
    return 0
  fi
  if [ ! -f "$path" ]; then
    curl -fsSL -o "$path" "$url"
  fi
  if ! echo "$sha  $path" | shasum -a 256 -c - >/dev/null 2>&1; then
    rm -f "$path"
    echo "hash mismatch for $label" >&2
    exit 1
  fi
}

pinned ffmpeg "$FFMPEG_URL" "$FFMPEG_FILE" "$FFMPEG_SHA256"
pinned dav1d "$DAV1D_URL" "$DAV1D_FILE" "$DAV1D_SHA256"
pinned libvpx "$LIBVPX_URL" "$LIBVPX_FILE" "$LIBVPX_SHA256"
pinned opus "$OPUS_URL" "$OPUS_FILE" "$OPUS_SHA256"
pinned upstream-ffmpeg "$UPSTREAM_FFMPEG_URL" "$UPSTREAM_FFMPEG_FILE" "$UPSTREAM_FFMPEG_SHA256"
pinned upstream-builder "$UPSTREAM_BUILDER_URL" "$UPSTREAM_BUILDER_FILE" "$UPSTREAM_BUILDER_SHA256"
