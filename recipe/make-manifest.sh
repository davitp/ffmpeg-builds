#!/usr/bin/env bash
# Usage: recipe/make-manifest.sh <base-url>   (run after the archives are in dist/)
# Writes dist/manifest.json: every archive pinned by SHA256, plus the source bundle and the configure line.
set -euo pipefail

BASE="${1:?release base url}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"

TAG="ffmpeg-$FFMPEG_VERSION-b$BUILD_NUMBER"
SOURCE="$ROOT/dist/$TAG-source.tar.gz"

"$HERE/fetch-sources.sh"
tar -czf "$SOURCE" -C "$ROOT" recipe "cache/$FFMPEG_FILE" "cache/$DAV1D_FILE" "cache/$LIBVPX_FILE" "cache/$OPUS_FILE"

node --input-type=module - "$ROOT/dist" "$BASE" "$TAG" "$FFMPEG_VERSION" "$HERE/configure-flags.txt" "$SOURCE" <<'NODE'
import { createHash } from 'node:crypto'
import { readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { basename, join } from 'node:path'

const [dist, base, tag, version, flagsFile, source] = process.argv.slice(2)
const sha = (file) => createHash('sha256').update(readFileSync(file)).digest('hex')
const archives = {}
for (const file of readdirSync(dist)) {
  const match = file.match(/^(ffmpeg-[0-9.]+-b[0-9]+)-(darwin|win32|linux)-(arm64|x64)\.tar\.gz$/)
  if (match && match[1] === tag) {
    archives[`${match[2]}-${match[3]}`] = { url: `${base}/${file}`, sha256: sha(join(dist, file)) }
  }
}
if (Object.keys(archives).length === 0) {
  console.error(`no archives for ${tag} in ${dist}`)
  process.exit(1)
}
const manifest = {
  tag,
  ffmpegVersion: version,
  archives,
  source: { url: `${base}/${basename(source)}`, sha256: sha(source) },
  configure: readFileSync(flagsFile, 'utf8').split('\n').filter(Boolean),
  ci: process.env.GITHUB_RUN_ID ?? null
}
writeFileSync(join(dist, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n')
console.log(Object.keys(archives).join(', '))
NODE
