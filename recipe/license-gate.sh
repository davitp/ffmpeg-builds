#!/usr/bin/env bash
# Usage: recipe/license-gate.sh <folder with ffmpeg and ffprobe (.exe on Windows)>
# Fails when a build is GPL or nonfree. The configuration string is read from the binary file itself, so a
# Windows build can be checked on Linux; where the binary runs, its own report and its linked libraries are
# checked too.
set -euo pipefail

DIR="${1:?folder}"
BAD='--enable-gpl|--enable-nonfree|--enable-libx264|--enable-libx265|--enable-libfdk-aac|--enable-libxvid|--enable-libvidstab|--enable-librubberband'
status=0
checked=0

for name in ffmpeg ffprobe; do
  bin=""
  for candidate in "$DIR/$name" "$DIR/$name.exe"; do
    if [ -f "$candidate" ]; then
      bin="$candidate"
    fi
  done
  if [ -z "$bin" ]; then
    echo "GATE FAIL: $name not found in $DIR" >&2
    status=1
    continue
  fi
  checked=$((checked + 1))

  if ! grep -a -q -e '--prefix=' "$bin"; then
    echo "GATE FAIL: $name has no readable configuration string" >&2
    status=1
  fi
  if grep -a -E -q -e "$BAD" "$bin"; then
    echo "GATE FAIL: $name configuration is GPL or nonfree" >&2
    status=1
  fi

  if "$bin" -hide_banner -version >/dev/null 2>&1; then
    if "$bin" -hide_banner -buildconf 2>&1 | grep -E -q -e "$BAD"; then
      echo "GATE FAIL: $name reports a GPL or nonfree configuration" >&2
      status=1
    fi
    if "$bin" -hide_banner -L 2>&1 | head -3 | grep -Ei -q 'GNU General Public|nonfree'; then
      echo "GATE FAIL: $name reports a GPL license" >&2
      status=1
    fi
    if [ "$(uname)" = Darwin ]; then
      outside="$(otool -L "$bin" | tail -n +2 | awk '{print $1}' | grep -Ev '^(/usr/lib/|/System/Library/)' || true)"
      if [ -n "$outside" ]; then
        echo "GATE FAIL: $name links outside the system: $outside" >&2
        status=1
      fi
    fi
  fi
done

if [ "$status" -eq 0 ] && [ "$checked" -eq 2 ]; then
  echo "license gate passed"
  exit 0
fi
exit 1
