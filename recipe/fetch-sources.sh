#!/usr/bin/env bash
# Downloads every pinned source tarball into cache/ and verifies its SHA256.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"

mkdir -p "$ROOT/cache"
for name in FFMPEG DAV1D LIBVPX OPUS; do
  url_var="${name}_URL"
  file_var="${name}_FILE"
  sha_var="${name}_SHA256"
  file="$ROOT/cache/${!file_var}"
  if [ ! -f "$file" ]; then
    curl -fsSL -o "$file" "${!url_var}"
  fi
  if ! echo "${!sha_var}  $file" | shasum -a 256 -c - >/dev/null 2>&1; then
    rm -f "$file"
    echo "hash mismatch for $name" >&2
    exit 1
  fi
done
