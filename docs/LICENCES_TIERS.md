# Licences des composants tiers

Aero IPTV s'appuie sur ces composants. Leur licence complète est aussi affichée par les paquets concernés.

| Composant | Rôle | Licence |
|---|---|---|
| [Flutter](https://flutter.dev) | Interface | BSD 3 clauses |
| [media_kit](https://github.com/media-kit/media-kit) | Lecteur vidéo | MIT |
| [libmpv](https://mpv.io) | Moteur de lecture | LGPL v2.1 ou ultérieure |
| [FFmpeg](https://ffmpeg.org) | Décodage audio et vidéo | LGPL v3 ou ultérieure |
| [Riverpod](https://riverpod.dev) | État de l'application | MIT |
| [Drift](https://drift.simonbinder.eu) | Base de données locale | MIT |
| [SQLite](https://sqlite.org) | Base de données locale | Domaine public |
| [ANGLE](https://chromium.googlesource.com/angle/angle) | Affichage de la vidéo sous Windows | BSD 3 clauses |
| [qr](https://pub.dev/packages/qr) | QR code des clés | BSD 3 clauses |

## libmpv et FFmpeg

Ces bibliothèques sont distribuées telles que fournies par media_kit, sous forme de fichiers séparés : `libmpv-2.dll` sous Windows et `libmpv.so` dans les APK. Elles sont compilées sans le code sous GPL (`-Dgpl=false`, `--disable-gpl`) et sans le code non libre (`--disable-nonfree`). Vous pouvez les remplacer par une version compatible que vous aurez compilée.

Les sources et les recettes de compilation sont disponibles ici :

- [mpv](https://github.com/mpv-player/mpv) et [FFmpeg](https://github.com/FFmpeg/FFmpeg)
- [compilation Windows de media_kit](https://github.com/media-kit/libmpv-win32-video-cmake)
- [compilation Android de media_kit](https://github.com/media-kit/libmpv-android-video-build)
