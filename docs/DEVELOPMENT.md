# Developing Aero IPTV

This guide is for anyone who wants to build or modify the app. To simply install it, see the [README](../README.md).

## Project layout

| Module | Contents |
|---|---|
| `packages/iptv_domain` | Entities, cleaning rules, contracts |
| `packages/iptv_data` | Parsers, adapters, SQLite |
| `packages/iptv_player` | Video engine |
| `app` | Interface, D-pad focus, Frutiger Aero theme, for Android and Windows |

## Building and packaging

Requirements: Flutter 3.47, JDK 17, the Android SDK with platform 36 and NDK 28.2, and Visual Studio with desktop C++. The scripts look for these tools in the environment, then in `%USERPROFILE%\aero_outils`, and put the packages in `dist/`.

Android TV and Fire OS:

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_android.ps1
```

| Package | Devices |
|---|---|
| `aero_iptv-<version>-armeabi-v7a.apk` | All Fire TV Sticks, 32-bit boxes |
| `aero_iptv-<version>-arm64-v8a.apk` | 64-bit Android boxes and TVs |

Without `app/android/key.properties`, the APKs are signed with the debug key: they install, but they can't be published or updated by a signed version. Before distributing anything, create the final key once and back it up outside the repository:

```powershell
powershell -ExecutionPolicy Bypass -File tool\create_keystore.ps1
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
```

The script produces `aero_iptv-<version>-windows-x64.zip`. The `.exe` doesn't work on its own: it needs its DLLs and the `data` folder, all included in the archive. If Inno Setup 6 is installed, it also produces a single-file installer. It removes files left by a debug run and refuses to ship a package that contains any.

If the project is stored in OneDrive, both scripts build in a separate copy (`%USERPROFILE%\aero_iptv_atelier`, or the folder in `AERO_WORKSHOP`), and the packages come back to `dist/`. OneDrive marks its folders read-only, which `flutter gen-l10n` refuses, and it would upload gigabytes of generated files to the cloud. For the same reason, run the commands below from that copy rather than from OneDrive.

## Commands

Some media_kit paths exceed the Windows limit. For a first install, enable long paths in your PowerShell session, without touching your global Git configuration:

```powershell
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'core.longpaths'
$env:GIT_CONFIG_VALUE_0 = 'true'
```

From the root:

```bash
flutter pub get
```

Generated code isn't versioned: after a first clone, run the Drift generation below before building.

Drift code generation, from `packages/iptv_data`, to run again after changing a `.drift` file:

```bash
dart run build_runner build
```

Tests, to run from each package:

```bash
dart test
```

Load test with 300,000 entries, from `packages/iptv_data`:

```bash
dart test --run-skipped -t load
```

Tests against a real libmpv, from `packages/iptv_player`, after `flutter build windows`:

```powershell
$env:LIBMPV_PATH = (Resolve-Path ..\..\app\build\windows\x64\runner\Release\libmpv-2.dll)
dart test -j 1 --run-skipped -t libmpv
```

The Dolby decoding tests join the command above if `DOLBY_SAMPLES` points to a folder containing `csi_miami_5.1_256_spx_small.eac3` and `monsters_inc_5.1_448_small.ac3`, from the FFmpeg test suite (`fate-suite.ffmpeg.org`). These files aren't versioned.

Integration tests on the real Windows app, from `app`:

```bash
flutter test integration_test/video_surface_test.dart -d windows
```

```bash
flutter test integration_test/app_tour_test.dart -d windows
```

The tour goes through every screen with the keyboard. If `AERO_SHOTS` points to a folder, it saves a screenshot of each screen there.

The video test also runs on an Android TV emulator named `aero_tv`, created from the `android-36;android-tv;x86_64` image. Start the emulator:

```powershell
& $env:ANDROID_HOME\emulator\emulator.exe -avd aero_tv -gpu swiftshader_indirect
```

Then, from `app`:

```bash
flutter test integration_test/video_surface_test.dart -d emulator-5554
```

On this emulator, the app shows "This stream can't be played": its EGL layer refuses mpv's OpenGL ES context unless `gpu-debug=yes` is set, which the test enables and the app doesn't. This only affects the emulator.

Regenerating the Frutiger Aero textures, from `app`:

```bash
flutter test tool/render_aero_textures_test.dart
```

The app icons and the TV banner have their own tool:

```bash
dart run tool/generate_aero_assets.dart
```

## Diagnosing an Xtream account

If a panel refuses an import or playback, this tool shows the account status, tries to open a live stream and a movie while following each redirect, then looks for the route the server accepts for delivering its catalog: `http`, `https`, `POST`, session cookie, `get.php`, `xmltv.php` and `panel_api.php`. It also measures what slows playback down: movie throughput, how long a connection takes to be released, access to the end of the file, and how a live stream answers mpv's request and the relay's. It reads the account from the app's vault and displays neither the username nor the password. `-Servers` adds other addresses to try:

```powershell
powershell -ExecutionPolicy Bypass -File tool\diagnostic_xtream.ps1 -Servers address1,address2
```

It relies on `dist\xtream_probe.exe`, to compile from `packages/iptv_data`:

```bash
dart compile exe tool/xtream_probe.dart -o ../../dist/xtream_probe.exe
```

## Single-connection subscriptions

To read a movie's index or jump around in it, FFmpeg opens a second connection before closing the first, which a panel limited to one connection refuses with HTTP 458. And mpv jumps more than you'd expect: when opening an MKV, it reads the index at the end of the file and comes back to the start, and every time a track is selected it flushes its buffer and reads again what it already had.

Streams therefore go through a local relay (`packages/iptv_player/lib/src/stream_relay.dart`) that cuts the old connection first and keeps a fixed-size window of the movie in memory: a jump that stays inside it opens no connection at all. Most of the buffering happens there, and mpv keeps only a quarter of its usual buffer. If the server drops the connection during a movie, the relay resumes on its own from where it was.

Live streams go through it too, without the window: the server receives a request with no position, and the player receives a stream with no size. HLS and DASH playlists are still opened by mpv, because they point to other addresses. The player only sees a local address, without the account password.

Opening an MKV still takes two connection changes, imposed by mpv: the wait then depends on the panel, and `tool\diagnostic_xtream.ps1` measures it.

## Service keys

All keys are optional:

| Key | Purpose | Without a key |
|---|---|---|
| `TMDB_READ_TOKEN` | Trends and large images on the home screen | Apple's public charts and the playlist's posters |
| `OPENSUBTITLES_API_KEY` | Complete subtitle file, translated in one go when selected | Only the stream's tracks are available, translated on the fly |
| `DEEPL_API_KEY` | "Download subtitles" option: translation into the chosen language | The option isn't offered |

The DeepL and OpenSubtitles keys are easier to enter in **Settings**: they're encrypted there by the system vault, and take priority over the ones set at build time. Free DeepL keys end in `:fx`. The "Get a key" button opens the service's page in the browser on Windows, and shows it as a QR code on TV.

A stream track already in the requested language comes first. Otherwise, a file found on OpenSubtitles is translated in one go: every line is ready as soon as it's selected, and the result is kept. That file comes from a different source than the video, so it may be slightly out of sync. Without an OpenSubtitles key or a matching file, the stream's track is translated line by line, preferably from English, because a track's full text is only known by playing the movie. Tracks drawn as images (PGS, VobSub, DVB) contain no text to translate.

Copy `config/secrets.example.json` to `config/secrets.json` and fill in your keys: the scripts in `tool/` include them at build time. For a development run, from `app`:

```bash
flutter run -d windows --dart-define-from-file=../config/secrets.json
```
