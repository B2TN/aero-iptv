# Développement d'Aero IPTV

Ce guide s'adresse à celles et ceux qui veulent compiler ou modifier l'application. Pour simplement l'installer, voir le [README](../README.md).

## État du projet

| Module | Contenu | État |
|---|---|---|
| `packages/iptv_domain` | Entités, règles de nettoyage, contrats | Disponible |
| `packages/iptv_data` | Parseurs, adapters, SQLite | Disponible |
| `packages/iptv_player` | Moteur vidéo | Disponible |
| `app` | Interface, focus D-pad, thème Frutiger Aero | Android et Windows disponibles |

## Compilation et distribution

Prérequis : Flutter 3.47, JDK 17, SDK Android avec la plateforme 36 et le
NDK 28.2, Visual Studio avec le C++ de bureau. Les scripts cherchent ces outils
dans l'environnement, puis dans `C:\dev`, et déposent les paquets dans `dist/`.

Android TV et Fire OS :

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_android.ps1
```

| Paquet | Appareils |
|---|---|
| `aero_iptv-<version>-armeabi-v7a.apk` | Tous les Fire TV Stick, boîtiers 32 bits |
| `aero_iptv-<version>-arm64-v8a.apk` | Boîtiers et TV Android 64 bits |

Sans `app/android/key.properties`, les APK sont signés avec la clé de débogage :
ils s'installent, mais ne se publient pas et ne pourront pas être mis à jour par
une version signée. Avant toute diffusion, créez une seule fois la clé définitive
et sauvegardez-la hors du dépôt :

```powershell
powershell -ExecutionPolicy Bypass -File tool\create_keystore.ps1
```

Windows :

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
```

Le script produit `aero_iptv-<version>-windows-x64.zip`. Le `.exe` ne fonctionne
pas seul : il a besoin de ses DLL et du dossier `data`, tous présents dans
l'archive. Si Inno Setup 6 est installé, il produit aussi un installeur en un seul
fichier. Il retire les fichiers d'une exécution de débogage et refuse de livrer
un paquet qui en contiendrait.

Si le projet est rangé dans OneDrive, ces deux scripts compilent dans une copie à
part (`C:\dev\aero_iptv_atelier`, ou le dossier de `AERO_WORKSHOP`), et les paquets
reviennent dans `dist/`. OneDrive marque en effet ses dossiers en lecture seule, ce
que `flutter gen-l10n` refuse, et il enverrait dans le nuage des gigaoctets de
fichiers générés. Pour la même raison, lancez les commandes ci-dessous depuis cette
copie plutôt que depuis OneDrive.

## Commandes

Certains chemins de media_kit dépassent la limite de Windows. Pour une première
installation, activez les chemins longs dans la session PowerShell, sans toucher
à la configuration Git globale :

```powershell
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'core.longpaths'
$env:GIT_CONFIG_VALUE_0 = 'true'
```

Depuis la racine :

```bash
flutter pub get
```

Le code généré n'est pas versionné : après un premier clone, lancez la génération
Drift ci-dessous avant de compiler.

Génération du code Drift, depuis `packages/iptv_data`, à relancer après toute
modification d'un fichier `.drift` :

```bash
dart run build_runner build
```

Tests, à lancer depuis chaque package :

```bash
dart test
```

Test de charge de 300 000 entrées, depuis `packages/iptv_data` :

```bash
dart test --run-skipped -t load
```

Tests contre un vrai libmpv, depuis `packages/iptv_player`, après
`flutter build windows` :

```powershell
$env:LIBMPV_PATH = (Resolve-Path ..\..\app\build\windows\x64\runner\Release\libmpv-2.dll)
dart test -j 1 --run-skipped -t libmpv
```

Les tests de décodage Dolby s'ajoutent à la commande ci-dessus si `DOLBY_SAMPLES`
désigne un dossier contenant `csi_miami_5.1_256_spx_small.eac3` et
`monsters_inc_5.1_448_small.ac3`, issus de la suite de tests de FFmpeg
(`fate-suite.ffmpeg.org`). Ces fichiers ne sont pas versionnés.

Tests d'intégration sur la vraie application Windows, depuis `app` :

```bash
flutter test integration_test/video_surface_test.dart -d windows
```

```bash
flutter test integration_test/app_tour_test.dart -d windows
```

La visite parcourt tous les écrans au clavier. Si `AERO_SHOTS` désigne un
dossier, elle y enregistre une capture de chaque écran.

Le test vidéo tourne aussi sur l'émulateur Android TV `aero_tv`, créé dans
`C:\dev\android-avd` à partir de l'image `android-36;android-tv;x86_64`. Lancez
l'émulateur :

```powershell
$env:ANDROID_AVD_HOME = 'C:\dev\android-avd'
& C:\dev\android-sdk\emulator\emulator.exe -avd aero_tv -gpu swiftshader_indirect
```

Puis, depuis `app` :

```bash
flutter test integration_test/video_surface_test.dart -d emulator-5554
```

Sur cet émulateur, l'application affiche « Ce flux ne peut pas être lu » : sa
couche EGL refuse le contexte OpenGL ES de mpv, sauf avec `gpu-debug=yes`, que le
test active et que l'application n'active pas. Cela ne concerne que l'émulateur.

Régénération des textures Frutiger Aero, depuis `app` :

```bash
flutter test tool/render_aero_textures_test.dart
```

Les icônes de l'application et la bannière des TV ont leur propre outil :

```bash
dart run tool/generate_aero_assets.dart
```

## Diagnostic d'un compte Xtream

Si un panneau refuse un import ou une lecture, cet outil affiche l'état du compte,
essaie d'ouvrir un flux direct et un film en suivant chaque redirection, puis
cherche par quel chemin le serveur accepte de livrer son catalogue : `http`, `https`,
`POST`, cookie de session, `get.php`, `xmltv.php` et `panel_api.php`. Il mesure aussi
ce qui ralentit la lecture : débit d'un film, temps de libération d'une connexion,
accès à la fin du fichier, et réponse d'un direct à la demande de mpv et à celle du
relais. Il lit le compte dans le coffre de l'application et n'affiche ni nom
d'utilisateur ni mot de passe. `-Servers` ajoute d'autres adresses aux essais :

```powershell
powershell -ExecutionPolicy Bypass -File tool\diagnostic_xtream.ps1 -Servers adresse1,adresse2
```

Il repose sur `dist\xtream_probe.exe`, à compiler depuis `packages/iptv_data` :

```bash
dart compile exe tool/xtream_probe.dart -o ../../dist/xtream_probe.exe
```

## Abonnements limités à une connexion

Pour lire l'index d'un film ou s'y déplacer, FFmpeg ouvre une seconde connexion
avant de fermer la première, ce qu'un panneau limité à une connexion refuse en
HTTP 458. Et mpv saute plus qu'il n'y paraît : à l'ouverture d'un MKV, il va lire
l'index en fin de fichier puis revient au début, et à chaque piste choisie il vide
son tampon pour relire ce qu'il avait déjà.

Les flux passent donc par un relais local
(`packages/iptv_player/lib/src/stream_relay.dart`) qui coupe l'ancienne connexion
d'abord, et garde une fenêtre du film en mémoire, de taille fixe : un saut qui y
reste n'ouvre aucune connexion. L'essentiel de la mise en réserve y est, et mpv ne
garde qu'un quart de son tampon habituel. Si le serveur coupe en cours de film, le
relais reprend seul là où il en était.

Un direct y passe aussi, sans fenêtre : le serveur reçoit une demande sans position,
et le lecteur un flux sans taille. Les listes HLS et DASH restent ouvertes par mpv,
car elles renvoient vers d'autres adresses. Le lecteur ne voit qu'une adresse
locale, sans le mot de passe du compte.

L'ouverture d'un MKV garde deux changements de connexion, que mpv impose : le temps
d'attente dépend alors du panneau, et `tool\diagnostic_xtream.ps1` le mesure.

## Clés de services

Toutes les clés sont facultatives :

| Clé | Rôle | Sans clé |
|---|---|---|
| `TMDB_READ_TOKEN` | Tendances et grandes images de l'accueil | Classements publics d'Apple et affiches de la playlist |
| `OPENSUBTITLES_API_KEY` | Fichier de sous-titres complet, traduit d'un bloc à la sélection | Seules les pistes du flux sont disponibles, traduites à la volée |
| `DEEPL_API_KEY` | Option « Télécharger sous-titre » : traduction dans la langue choisie | L'option n'est pas proposée |

Les clés DeepL et OpenSubtitles se saisissent plus simplement dans **Paramètres** :
elles y sont chiffrées par le coffre du système, et priment sur celles de la
compilation. Les clés DeepL gratuites se terminent par `:fx`. Le bouton « Obtenir
une clé » ouvre la page du service dans le navigateur sous Windows, et l'affiche en
QR code sur TV.

Une piste du flux déjà dans la langue voulue passe d'abord. Sinon, un fichier trouvé
sur OpenSubtitles est traduit d'un bloc : toutes les répliques sont prêtes dès la
sélection, et le résultat est conservé. Ce fichier vient d'une autre source que la
vidéo, et peut donc être légèrement décalé. Sans clé OpenSubtitles ou sans fichier
trouvé, la piste du flux est traduite réplique par réplique, l'anglais de préférence,
car le texte complet d'une piste n'est connu qu'à la lecture du film. Les pistes
dessinées en images (PGS, VobSub, DVB) ne contiennent aucun texte à traduire.

Copiez `config/secrets.example.json` vers `config/secrets.json` et renseignez vos
clés : les scripts de `tool/` les intègrent à la compilation. Pour un lancement de
développement, depuis `app` :

```bash
flutter run -d windows --dart-define-from-file=../config/secrets.json
```
