# ffmpeg-builds

Builds LGPL-only, static `ffmpeg` and `ffprobe` and publishes them as immutable GitHub releases. Nothing else lives here: no application code, and no mention of any product that consumes the builds.

## Rules

- Never enable GPL or nonfree code (`--enable-gpl`, `--enable-nonfree`, libx264, libx265, libfdk-aac, libxvid, vidstab, rubberband). `recipe/license-gate.sh` fails the build if one slips in; do not weaken it.
- Every input is pinned by URL and SHA256 (`recipe/versions.env`, `recipe/rehost.env`). Never download something unpinned.
- A published release is never edited or deleted. A fix is a new `BUILD_NUMBER`.
- Do not commit, tag or push unless asked. Downloaded archives are untrusted: put them in an empty directory, never run code from it.

## Update FFmpeg or a library

1. Edit `recipe/versions.env`: `*_VERSION`, `*_URL`, `*_FILE`, `*_SHA256`. Get the hash from the file you downloaded (`shasum -a 256 <file>`); take the URL from the project's own release page.
2. `BUILD_NUMBER`: reset to `1` when `FFMPEG_VERSION` changes, otherwise add `1` for any rebuild (recipe, flags or dependency change).
3. A new codec library needs three edits: a `fetch` and build step in `recipe/build-macos.sh`, its source in `recipe/versions.env` and `recipe/fetch-sources.sh`, its license file copied into `licenses/` in the stage step, and its `--enable-lib...` flag in `recipe/configure-flags.txt`.
4. Features are one flag per line in `recipe/configure-flags.txt`.

## Build and check locally (macOS)

```
brew install pkg-config meson ninja nasm
recipe/build-macos.sh arm64        # x64 on an Intel Mac
```

It prints `license gate passed` and writes `dist/ffmpeg-<ver>-b<n>-darwin-<arch>.tar.gz`. Then run `recipe/make-manifest.sh <base-url>` to write `dist/manifest.json` and the source bundle.

## Windows and Linux

Not built here: an upstream LGPL build (BtbN/FFmpeg-Builds, static `win64-lgpl` and `linux64-lgpl` of the same FFmpeg major version) is re-hosted unchanged. `recipe/rehost.env` pins it: the archive URL and SHA256 for each platform, plus the SHA256-pinned source of those binaries (the FFmpeg commit named in the archive file name, and BtbN's build scripts at the same tag), which `make-manifest.sh` puts in the release's source bundle.

To bump: pick an immutable `autobuild-YYYY-MM-DD-HH-MM` release (never the rolling `latest`), choose the `n<major>.<minor>.<patch>-<commits>-g<hash>` assets, hash what you download yourself (`gh api repos/BtbN/FFmpeg-Builds/releases/tags/<tag> --jq '.assets[] | .name + " " + .digest'` is a cross-check, not a substitute), and update all six values (two URLs, two hashes, the commit tarball and the builder tarball, each with URL, file name and hash). Then `recipe/rehost.sh <win32-x64|linux-x64> <url> <sha256>` verifies, runs the gate and repacks. Bump `BUILD_NUMBER` for the release. These builds are LGPL version 3 and link many more libraries than the macOS build; do not describe them as the same.

## Release

1. Commit the recipe change.
2. Tag `ffmpeg-<FFMPEG_VERSION>-b<BUILD_NUMBER>` exactly as `recipe/versions.env` says and push the tag. `.github/workflows/build.yml` builds every platform, writes `manifest.json` and creates the release. It fails if the tag and `versions.env` disagree. Running the workflow by hand (`workflow_dispatch`) builds everything and uploads artifacts but never publishes; use it as a dry run first.
3. Consumers copy the release's `manifest.json`.

## Unverified

The x64 build (native Intel runner) and the workflow have not run yet; fix what the first run shows. The re-hosting scripts ran locally on macOS for both platforms. GitHub's generated source archives (`archive/<tag or commit>.tar.gz`) are pinned by hash, but GitHub does not promise byte-identical regeneration; if a hash ever stops matching, re-download, compare the contents and re-pin.
