# ffmpeg-builds

LGPL-only `ffmpeg` and `ffprobe` builds, made from pinned sources and published as immutable releases.

- `recipe/versions.env` pins FFmpeg and its libraries (dav1d, libvpx, opus) by URL and SHA256.
- `recipe/configure-flags.txt` is the FFmpeg configure line: `--disable-gpl --disable-nonfree`, VideoToolbox and AudioToolbox, dav1d, libvpx, libopus, static.
- `recipe/build-macos.sh <arm64|x64>` builds for macOS (needs `pkg-config meson ninja nasm` and the Xcode command line tools).
- `recipe/rehost.sh` re-hosts a pinned upstream LGPL archive for Windows and Linux (`recipe/rehost.env`: BtbN autobuild `autobuild-2026-11-12-15-40`, FFmpeg n9.0.2-57-gd838f9f9ae, LGPL version 3), with the matching source pinned beside it.
- `recipe/license-gate.sh` fails a build that is GPL or nonfree, or that links outside the system.
- `recipe/make-manifest.sh` writes `dist/manifest.json`: every archive and the source bundle, pinned by SHA256.

A release is tagged `ffmpeg-<ffmpeg version>-b<build number>` and never edited or deleted; a fix is a new build number. Each release carries the source bundle (`recipe/` and the pinned source tarballs), which is the LGPL source offer, and each archive carries `COPYING.LGPLv2.1` and the licenses of the linked libraries.

Enable "Immutable releases" in the repository settings. See `CLAUDE.md` for how to update and release.
