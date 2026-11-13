# Third-party licenses

Aero IPTV relies on these components. Their full licenses are also included in the packages concerned.

| Component | Purpose | License |
|---|---|---|
| [Flutter](https://flutter.dev) | Interface | BSD 3-Clause |
| [media_kit](https://github.com/media-kit/media-kit) | Video player | MIT |
| [libmpv](https://mpv.io) | Playback engine | LGPL v2.1 or later |
| [FFmpeg](https://ffmpeg.org) | Audio and video decoding | LGPL v3 or later |
| [Riverpod](https://riverpod.dev) | App state | MIT |
| [Drift](https://drift.simonbinder.eu) | Local database | MIT |
| [SQLite](https://sqlite.org) | Local database | Public domain |
| [ANGLE](https://chromium.googlesource.com/angle/angle) | Video display on Windows | BSD 3-Clause |
| [qr](https://pub.dev/packages/qr) | QR code for keys | BSD 3-Clause |

## Intro and credits data

The skip intro and next episode buttons use these community databases. The app only sends them the series title, its public IDs, and the season and episode numbers.

| Service | Purpose | Data license |
|---|---|---|
| [TheIntroDB](https://theintrodb.org) | Intro and end credits times | Not stated by the service |
| [IntroDB](https://introdb.app) | Intro and end credits times | [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/) |
| [TVmaze](https://www.tvmaze.com/api) | Finds the IDs of a series from its title | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |

Contains data from IntroDB (introdb.app), available under the ODbL. Series IDs are provided by TVmaze.

## libmpv and FFmpeg

These libraries are distributed as provided by media_kit, as separate files: `libmpv-2.dll` on Windows and `libmpv.so` in the APKs. They are built without GPL code (`-Dgpl=false`, `--disable-gpl`) and without non-free code (`--disable-nonfree`). You can replace them with a compatible version you have built yourself.

The sources and build recipes are available here:

- [mpv](https://github.com/mpv-player/mpv) and [FFmpeg](https://github.com/FFmpeg/FFmpeg)
- [media_kit Windows build](https://github.com/media-kit/libmpv-win32-video-cmake)
- [media_kit Android build](https://github.com/media-kit/libmpv-android-video-build)
