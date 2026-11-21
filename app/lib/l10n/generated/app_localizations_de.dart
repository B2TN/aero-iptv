// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get navHome => 'Startseite';

  @override
  String get navLive => 'Live-TV';

  @override
  String get navSearch => 'Suche';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get homeContinue => 'Weiterschauen';

  @override
  String homeEpisodeNumber(int season, int number) {
    return 'S$season F$number';
  }

  @override
  String get homeUpNext => 'Als Nächstes';

  @override
  String get homeSeries => 'Beliebte Serien';

  @override
  String get homeMovies => 'Beliebte Filme';

  @override
  String get homePlay => 'Abspielen';

  @override
  String get homeOpen => 'Öffnen';

  @override
  String get emptyTitle => 'Fügen Sie Ihre erste Playlist hinzu';

  @override
  String get emptyBody =>
      'Eine M3U-Adresse oder ein Xtream-Konto genügt, um Ihre Sender, Filme und Serien zu finden.';

  @override
  String get emptyCatalogTitle => 'Diese Playlist ist noch leer';

  @override
  String get emptyCatalogBody =>
      'Aktualisieren Sie sie in den Einstellungen, um den Inhalt zu laden.';

  @override
  String get actionAddPlaylist => 'Playlist hinzufügen';

  @override
  String get actionOpenSettings => 'Einstellungen öffnen';

  @override
  String get loading => 'Wird geladen';

  @override
  String get loadErrorTitle => 'Der Inhalt konnte nicht geladen werden';

  @override
  String get actionRetry => 'Erneut versuchen';

  @override
  String get actionBack => 'Zurück';

  @override
  String get liveChooseCountry => 'Wählen Sie ein Land';

  @override
  String get liveUnknownCountry => 'Andere';

  @override
  String get liveAllChannels => 'Alle Sender';

  @override
  String get liveGeneralChannels => 'Allgemein';

  @override
  String get liveNoChannels => 'Keine Sender in dieser Gruppe';

  @override
  String get liveChooseStream => 'Wählen Sie einen Stream';

  @override
  String liveStreamDefault(int number) {
    return 'Stream $number';
  }

  @override
  String get searchPrompt => 'Suchen Sie einen Film oder eine Serie';

  @override
  String get searchTrending => 'Im Trend';

  @override
  String get searchResults => 'Ergebnisse';

  @override
  String searchNoResult(String query) {
    return 'Keine Ergebnisse für „$query“';
  }

  @override
  String get detailChooseVersion => 'Wählen Sie eine Version';

  @override
  String detailSeason(int number) {
    return 'Staffel $number';
  }

  @override
  String detailEpisode(int number) {
    return 'Folge $number';
  }

  @override
  String get detailNoEpisodes =>
      'Für diese Version sind keine Folgen verfügbar';

  @override
  String get detailNoDescription => 'Keine Beschreibung verfügbar';

  @override
  String get searchSearching => 'Suche läuft…';

  @override
  String get menuOpenPage => 'Seite öffnen';

  @override
  String get menuChooseVersion => 'Version wählen';

  @override
  String get menuMarkWatched => 'Als gesehen markieren';

  @override
  String get menuMarkUnwatched => 'Als ungesehen markieren';

  @override
  String get menuMarkWatchedUpTo => 'Bis hier als gesehen markieren';

  @override
  String get menuMarkSeasonWatched => 'Staffel als gesehen markieren';

  @override
  String get menuMarkSeasonUnwatched => 'Staffel als ungesehen markieren';

  @override
  String get menuAddFavorite => 'Zu Favoriten hinzufügen';

  @override
  String get menuRemoveFavorite => 'Aus Favoriten entfernen';

  @override
  String get homeFavorites => 'Favoriten';

  @override
  String detailSeasonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Staffeln',
      one: '1 Staffel',
    );
    return '$_temp0';
  }

  @override
  String get detailRunning => 'Läuft noch';

  @override
  String get detailUpcoming => 'Nächste Folgen';

  @override
  String detailUpcomingEpisode(int season, int number, String title) {
    return 'S$season F$number, $title';
  }

  @override
  String get detailUntitled => 'Titel noch nicht bekannt';

  @override
  String get detailWatched => 'Gesehen';

  @override
  String get detailLate => 'Verspätet im IPTV';

  @override
  String get detailUpcomingNote =>
      'Erstausstrahlung im Herkunftsland, laut TVmaze. Bei Ihrem Anbieter erscheint die Folge etwas später.';

  @override
  String detailRuntimeMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String detailRuntimeHours(int hours, String minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String detailResumeEpisode(int season, int episode) {
    return 'Staffel $season, Folge $episode';
  }

  @override
  String get detailResume => 'Fortsetzen';

  @override
  String get detailPlay => 'Abspielen';

  @override
  String get detailPlayFromStart => 'Von vorne abspielen';

  @override
  String get playerFailedTitle => 'Dieser Stream kann nicht abgespielt werden';

  @override
  String get playerFailedBody =>
      'Er ist möglicherweise offline. Versuchen Sie es erneut oder wählen Sie einen anderen Stream.';

  @override
  String get playerPlay => 'Abspielen';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Untertitel';

  @override
  String get playerSubtitlesOff => 'Deaktivieren';

  @override
  String playerTrack(int number) {
    return 'Spur $number';
  }

  @override
  String get playerLive => 'Live';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsGroupSeries => 'Serienversionen gruppieren';

  @override
  String get settingsGroupChannels => 'Senderqualitäten gruppieren';

  @override
  String get settingsGroupMovies => 'Filmversionen zusammenfassen';

  @override
  String get settingsPerformance => 'Leistungsmodus';

  @override
  String settingsPerformanceAuto(String state) {
    return 'Automatisch ($state)';
  }

  @override
  String get settingsDelay => 'Verzögerung bei Live-Sendern';

  @override
  String settingsDelayValue(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds s',
      zero: 'Keine',
    );
    return '$_temp0';
  }

  @override
  String get settingsTrendCountry => 'Land der Trends';

  @override
  String settingsTrendCountryAuto(String country) {
    return 'Automatisch ($country)';
  }

  @override
  String get settingsLanguage => 'App-Sprache';

  @override
  String get settingsPlaylists => 'Playlists';

  @override
  String get settingsDailySync => 'Täglich synchronisieren';

  @override
  String updateAvailable(String version) {
    return 'Version $version verfügbar';
  }

  @override
  String get updateInstall => 'Aktualisieren';

  @override
  String get updateNotes => 'Versionshinweise';

  @override
  String get updateDismiss => 'Schließen';

  @override
  String updateDownloading(int percent) {
    return 'Download: $percent %';
  }

  @override
  String get updatePermission =>
      'Erlauben Sie Aero IPTV, Apps zu installieren, und versuchen Sie es erneut.';

  @override
  String get updateFailed => 'Die Aktualisierung ist fehlgeschlagen.';

  @override
  String updateNotesTitle(String version) {
    return 'Neu in Version $version';
  }

  @override
  String get settingsBetaUpdates => 'Beta-Updates';

  @override
  String settingsPlaylistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Playlists',
      one: '1 Playlist',
      zero: 'Keine',
    );
    return '$_temp0';
  }

  @override
  String get settingsOn => 'An';

  @override
  String get settingsOff => 'Aus';

  @override
  String get settingsAttribution =>
      'Dieses Produkt verwendet die TMDB-API, ist aber nicht von TMDB unterstützt oder zertifiziert.';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistNew => 'Neue Playlist';

  @override
  String get playlistEdit => 'Playlist bearbeiten';

  @override
  String get playlistName => 'Name';

  @override
  String get playlistType => 'Typ';

  @override
  String get playlistUrl => 'Playlist-Adresse';

  @override
  String get playlistEpgUrl => 'XMLTV-Guide-Adresse (optional)';

  @override
  String get playlistServer => 'Serveradresse';

  @override
  String get playlistUsername => 'Benutzername';

  @override
  String get playlistPassword => 'Passwort';

  @override
  String get playlistCountry => 'Standardland';

  @override
  String get playlistCountryNone => 'Keines';

  @override
  String get playlistEmptyField => 'Nicht festgelegt';

  @override
  String get playlistSave => 'Speichern';

  @override
  String get playlistRefresh => 'Aktualisieren';

  @override
  String get playlistActivate => 'Diese Playlist verwenden';

  @override
  String get playlistActive => 'In Verwendung';

  @override
  String get playlistDelete => 'Löschen';

  @override
  String playlistDeleteConfirm(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get playlistMissingFields =>
      'Geben Sie vor dem Speichern Name und Adresse ein.';

  @override
  String get playlistSaveFailedTitle => 'Speichern fehlgeschlagen';

  @override
  String get playlistSynced => 'Aktualisiert';

  @override
  String get playlistNotSynced => 'Nie aktualisiert';

  @override
  String importRunning(int count) {
    return 'Aktualisierung: $count Einträge';
  }

  @override
  String get importDone => 'Aktualisierung abgeschlossen';

  @override
  String get importEpgFailed =>
      'Aktualisierung abgeschlossen, ohne Programmführer';

  @override
  String get importAuthFailed =>
      'Zugangsdaten abgelehnt. Prüfen Sie sie und versuchen Sie es erneut.';

  @override
  String importAuthRejected(int code) {
    return 'Zugriff vom Server verweigert (Code $code). Prüfen Sie Benutzername, Passwort und Adresse.';
  }

  @override
  String importServerFailed(int code) {
    return 'Der Server hat einen Fehler gemeldet (Code $code). Versuchen Sie es später erneut oder nutzen Sie eine andere Adresse.';
  }

  @override
  String get importNetworkFailed =>
      'Server nicht erreichbar. Prüfen Sie die Adresse und versuchen Sie es erneut.';

  @override
  String get importFormatFailed =>
      'Der empfangene Inhalt ist keine gültige Playlist.';

  @override
  String get importSecureFailed =>
      'Die sichere Verbindung (https) zum Server wurde abgelehnt. Prüfen Sie Datum und Uhrzeit des Geräts und versuchen Sie es erneut.';

  @override
  String importLastStep(String step) {
    return 'Letzter Schritt: $step';
  }

  @override
  String importVaultFailed(String cause) {
    return 'Der verschlüsselte Tresor des Geräts funktioniert nicht (Fehler $cause): Die Zugangsdaten der Playlist konnten nicht gespeichert oder gelesen werden.';
  }

  @override
  String importErrorDetail(String detail) {
    return 'Details: $detail';
  }

  @override
  String importUnrefined(String steps) {
    return 'Aktualisierung abgeschlossen, ohne: $steps.';
  }

  @override
  String get importRefineHomonyms => 'die Trennung gleichnamiger Serien';

  @override
  String get importRefineVersions => 'die Zusammenführung der Sprachversionen';

  @override
  String get importRefineSearch => 'den Suchindex';

  @override
  String get importStorageFull =>
      'Auf dem Gerät ist nicht mehr genug Platz, um den Katalog zu speichern. Geben Sie Speicherplatz frei und versuchen Sie es erneut.';

  @override
  String importStorageFailed(int code) {
    return 'Das Gerät konnte den Katalog nicht speichern (SQLite-Fehler $code). Versuchen Sie es erneut. Tritt der Fehler wieder auf, melden Sie ihn mit diesem Code.';
  }

  @override
  String importUnexpected(String kind) {
    return 'Der Import wurde durch einen unerwarteten Fehler abgebrochen ($kind). Versuchen Sie es erneut. Tritt der Fehler wieder auf, melden Sie ihn mit diesem Namen.';
  }

  @override
  String get importConnecting => 'Verbindung zum Server…';

  @override
  String importReceivingChannels(int count) {
    return 'Sender werden empfangen: $count Einträge empfangen';
  }

  @override
  String importReceivingMovies(int count) {
    return 'Filme werden empfangen: $count Einträge empfangen';
  }

  @override
  String importReceivingSeries(int count) {
    return 'Serien werden empfangen: $count Einträge empfangen';
  }

  @override
  String get importIndexing => 'Katalog wird vorbereitet…';

  @override
  String get importGuide => 'Katalog bereit. Programmführer wird empfangen…';

  @override
  String importPartial(String sections) {
    return 'Aktualisierung unvollständig. Nicht empfangen: $sections.';
  }

  @override
  String get importSectionChannels => 'Sender';

  @override
  String get importSectionMovies => 'Filme';

  @override
  String get importSectionSeries => 'Serien';

  @override
  String get importFailedTitle => 'Die Aktualisierung ist fehlgeschlagen';

  @override
  String get entryConfirm => 'Bestätigen';

  @override
  String get entryShow => 'Anzeigen';

  @override
  String get entryHide => 'Verbergen';

  @override
  String get entryCancel => 'Abbrechen';

  @override
  String get confirmDelete => 'Löschen';

  @override
  String get confirmKeep => 'Behalten';

  @override
  String get homeResume => 'Fortsetzen';

  @override
  String get homeRestart => 'Von vorne beginnen';

  @override
  String get homeRemoveContinue => 'Aus Weiterschauen entfernen';

  @override
  String get playerVersion => 'Version';

  @override
  String get playerEpisodes => 'Folgen';

  @override
  String get playerNowPlaying => 'Läuft gerade';

  @override
  String get playerExternal => 'Externer Player';

  @override
  String get playerExternalMissing =>
      'Kein externer Player gefunden. Installieren Sie VLC oder mpv.';

  @override
  String get playerNoOtherVersion => 'Keine andere Version verfügbar';

  @override
  String get playerVersionMissing => 'Diese Folge fehlt in dieser Version';

  @override
  String playerEndsAt(String time) {
    return 'Ende um $time';
  }

  @override
  String get playerFullscreen => 'Vollbild';

  @override
  String get playerExitFullscreen => 'Vollbild beenden';

  @override
  String get playerMono => 'Mono';

  @override
  String get playerStereo => 'Stereo';

  @override
  String get playerSubtitlesTranslate => 'Untertitel übersetzen';

  @override
  String get playerSubtitlesLoaded => 'Untertitel geladen';

  @override
  String get playerSubtitlesNotFound => 'Diese Quelle enthält keine Untertitel';

  @override
  String get playerSubtitlesFailed =>
      'Untertitel konnten nicht übersetzt werden';

  @override
  String get settingsSubtitleAppearance => 'Darstellung der Untertitel';

  @override
  String get subtitlePreview => 'Vorschau';

  @override
  String get subtitleSample => 'Wir tauchen vor dem Sturm auf.';

  @override
  String get subtitleSize => 'Größe';

  @override
  String get subtitleFont => 'Schriftart';

  @override
  String get subtitleColor => 'Textfarbe';

  @override
  String get subtitleEdge => 'Rand';

  @override
  String get subtitleBackground => 'Hintergrund';

  @override
  String get subtitleBackgroundOpacity => 'Deckkraft des Hintergrunds';

  @override
  String get subtitlePosition => 'Position';

  @override
  String get subtitleReset => 'Ursprüngliche Einstellungen wiederherstellen';

  @override
  String get subtitleSizeSmall => 'Klein';

  @override
  String get subtitleSizeMedium => 'Mittel';

  @override
  String get subtitleSizeLarge => 'Groß';

  @override
  String get subtitleSizeExtraLarge => 'Sehr groß';

  @override
  String get subtitleFontStandard => 'Standard';

  @override
  String get subtitleFontBold => 'Fett';

  @override
  String get subtitleFontSerif => 'Mit Serifen';

  @override
  String get subtitleFontMonospace => 'Festbreite';

  @override
  String get subtitleColorWhite => 'Weiß';

  @override
  String get subtitleColorYellow => 'Gelb';

  @override
  String get subtitleColorCyan => 'Cyan';

  @override
  String get subtitleColorGreen => 'Grün';

  @override
  String get subtitleEdgeNone => 'Keiner';

  @override
  String get subtitleEdgeOutline => 'Schwarzer Rand';

  @override
  String get subtitleEdgeShadow => 'Schatten';

  @override
  String get subtitleBackgroundNone => 'Keiner';

  @override
  String get subtitleBackgroundBlack => 'Schwarz';

  @override
  String get subtitleBackgroundGrey => 'Grau';

  @override
  String get subtitleBackgroundNavy => 'Nachtblau';

  @override
  String subtitleOpacityValue(int percent) {
    return '$percent %';
  }

  @override
  String get subtitlePositionBottom => 'Unten';

  @override
  String get subtitlePositionRaised => 'Etwas höher';

  @override
  String get subtitlePositionHigher => 'Höher';

  @override
  String get subtitlePositionTop => 'Oben';

  @override
  String get settingsDeepL => 'DeepL-Schlüssel (übersetzte Untertitel)';

  @override
  String get settingsKeySet => 'Eingerichtet';

  @override
  String get settingsKeyUnset => 'Nicht eingerichtet';

  @override
  String get settingsKeyReplace => 'Schlüssel ersetzen';

  @override
  String get settingsKeyRemove => 'Schlüssel entfernen';

  @override
  String get versionSubtitled => 'mit Untertiteln';

  @override
  String get versionDubbed => 'synchronisiert';

  @override
  String get homeInfo => 'Informationen';

  @override
  String get homeNoOverview => 'Keine Beschreibung verfügbar.';

  @override
  String get settingsKeyGet => 'Schlüssel holen';

  @override
  String settingsKeyScan(String service) {
    return 'Scannen Sie diesen Code mit Ihrem Telefon, um die $service-Seite zu öffnen, und geben Sie Ihren Schlüssel dann hier ein.';
  }

  @override
  String playerServerAnswer(String answer) {
    return 'Antwort des Servers: $answer';
  }

  @override
  String get playerServerSilent =>
      'Der Server antwortet nicht auf diesen Stream.';

  @override
  String get playerConnectionsFullTitle => 'Alle Ihre Verbindungen sind belegt';

  @override
  String get playerConnectionsFullBody =>
      'Ihr Abonnement begrenzt die gleichzeitige Wiedergabe. Beenden Sie die Wiedergabe auf Ihren anderen Geräten oder Apps und versuchen Sie es erneut.';

  @override
  String get playerConnecting => 'Verbindung belegt, neuer Versuch...';

  @override
  String get playerClose => 'Wiedergabe beenden';

  @override
  String get playerSkipIntro => 'Intro überspringen';

  @override
  String get playerNextEpisode => 'Nächste Folge';

  @override
  String get playerSubtitlesLanguage => 'Untertitel übersetzen in';

  @override
  String get playerSubtitlesImagesOnly =>
      'Die Untertitel dieser Quelle sind Bilder und können nicht übersetzt werden';

  @override
  String tutorialStep(int step, int count) {
    return 'Schritt $step von $count';
  }

  @override
  String get tutorialSkip => 'Überspringen';

  @override
  String get tutorialPrevious => 'Zurück';

  @override
  String get tutorialNext => 'Weiter';

  @override
  String get tutorialFinish => 'Fertig';

  @override
  String get tutorialWelcomeTitle => 'Willkommen bei Aero IPTV';

  @override
  String get tutorialWelcomeBody =>
      'Ein paar Schritte, um alles einzurichten und die App kennenzulernen. Sie können diese Anleitung jederzeit überspringen und in den Einstellungen erneut ansehen.';

  @override
  String get tutorialChangeLanguage => 'Sprache ändern';

  @override
  String get tutorialPlaylistTitle => 'Fügen Sie Ihre Playlist hinzu';

  @override
  String get tutorialPlaylistBody =>
      'Aero IPTV spielt Ihr Abonnement ab: eine M3U-Adresse oder die Xtream-Codes-Zugangsdaten Ihres Anbieters. Sie bleiben verschlüsselt auf diesem Gerät und werden nur an Ihren Anbieter gesendet.';

  @override
  String get tutorialPerformanceTitle => 'Leistungsmodus';

  @override
  String get tutorialPerformanceBody =>
      'Er entfernt die Glas- und Spiegeleffekte, damit die Bedienung auf einem kleinen Gerät wie einem Fire TV Stick flüssig bleibt.';

  @override
  String get tutorialPerformanceSmall =>
      'Dieses Gerät hat wenig Speicher: Der Leistungsmodus wird empfohlen.';

  @override
  String get tutorialPerformanceLarge =>
      'Dieses Gerät hat genug Speicher für die Effekte.';

  @override
  String get tutorialPerformanceOn => 'Leistungsmodus einschalten';

  @override
  String get tutorialPerformanceOff => 'Leistungsmodus ausschalten';

  @override
  String get tutorialControlsTitle => 'Fernbedienung, Maus oder Tastatur';

  @override
  String get tutorialControlsBody =>
      'Pfeile zum Bewegen, OK zum Öffnen oder Abspielen, Zurück zum Zurückgehen.\nLanges Drücken auf OK oder die Menütaste öffnet das Menü eines Films, einer Serie oder einer Folge.\nMit der Maus: Klick zum Öffnen, Rechtsklick für das Menü. Mit der Tastatur: Pfeile, Eingabe und Esc.';

  @override
  String get tutorialHomeTitle => 'Der Startbildschirm';

  @override
  String get tutorialHomeBody =>
      '„Weiterschauen“ setzt dort fort, wo Sie aufgehört haben, in jeder Version.\nIhre Favoriten haben eine eigene Reihe: Fügen Sie sie über das Menü eines Titels hinzu.\nBeliebte Serien und Filme folgen den Trends in Ihrem Land.';

  @override
  String get tutorialDetailsTitle => 'Seiten und Versionen';

  @override
  String get tutorialDetailsBody =>
      'Filme und Serien gibt es oft in mehreren Sprachen und Qualitäten: Ihre Seite fasst sie zusammen, und die Schaltfläche Version wechselt zwischen ihnen. Ihr Fortschritt gilt für alle.\nDie Seite einer Serie zeigt ihre Staffeln, die gesehenen und die kommenden Folgen.';

  @override
  String get tutorialLiveTitle => 'Live-Sender';

  @override
  String get tutorialLiveBody =>
      'Die Sender sind nach Land sortiert, mit dem laufenden Programm. Ein Sender in mehreren Qualitäten erscheint nur einmal.\nWenn ein Sender ruckelt, fügen Sie in den Einstellungen eine Verzögerung hinzu.';

  @override
  String get tutorialPlayerTitle => 'Player und Untertitel';

  @override
  String get tutorialPlayerBody =>
      'OK zeigt die Steuerung: Audio, Untertitel, Version und Folgen.\nUntertitel stammen aus dem Video. Mit einem optionalen, kostenlosen DeepL-Schlüssel werden sie beim Ansehen in Ihre Sprache übersetzt.';

  @override
  String get tutorialAddKey => 'DeepL-Schlüssel hinzufügen';

  @override
  String get tutorialSyncTitle => 'Synchronisierung und Updates';

  @override
  String get tutorialSyncBody =>
      'Ihre Playlist wird täglich aktualisiert, nie während der Wiedergabe.\nWenn eine neue Version von Aero IPTV erscheint, weist ein Banner darauf hin.\nAlle diese Einstellungen und diese Anleitung finden Sie in den Einstellungen.';

  @override
  String get settingsTutorial => 'Anleitung erneut ansehen';

  @override
  String homeNextEpisodeIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Nächste Folge in $days Tagen',
      one: 'Nächste Folge morgen',
      zero: 'Nächste Folge heute',
    );
    return '$_temp0';
  }

  @override
  String homeNextEpisodeOn(String date) {
    return 'Nächste Folge am $date';
  }

  @override
  String get homeNextEpisodeAired => 'Folge ausgestrahlt, bald in der Playlist';

  @override
  String get settingsCategoryPlaylist => 'Playlist';

  @override
  String get settingsCategoryCatalog => 'Katalog';

  @override
  String get settingsCategoryPlayback => 'Wiedergabe';

  @override
  String get settingsCategorySubtitles => 'Untertitel';

  @override
  String get settingsCategoryAppearance => 'Darstellung';

  @override
  String get settingsCategoryUpdates => 'Updates';

  @override
  String get settingsCategoryAbout => 'Über';

  @override
  String get settingsLastSync => 'Letzte Synchronisierung';

  @override
  String get settingsLastSyncNever => 'Nie';

  @override
  String settingsLastSyncValue(String date, String duration) {
    return '$date, $duration';
  }

  @override
  String syncDurationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String syncDurationMinutes(int minutes, int seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String get syncReportFull => 'vollständiger Import';

  @override
  String get syncReportChanges => 'nur Änderungen';

  @override
  String get syncReportTotal => 'Gesamt';

  @override
  String syncReportCounts(int received, int changed) {
    final intl.NumberFormat receivedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String receivedString = receivedNumberFormat.format(received);
    final intl.NumberFormat changedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String changedString = changedNumberFormat.format(changed);

    return '$receivedString empfangen, $changedString geändert';
  }

  @override
  String syncReportProgrammes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString Sendungen';
  }

  @override
  String get syncPhaseConnection => 'Verbindung';

  @override
  String get syncPhaseCatalog => 'Liste';

  @override
  String get syncPhaseLive => 'Sender';

  @override
  String get syncPhaseMovies => 'Filme';

  @override
  String get syncPhaseSeries => 'Serien';

  @override
  String get syncPhaseRefinement => 'Feinschliff';

  @override
  String get syncPhaseUpdate => 'Katalogaktualisierung';

  @override
  String get syncPhaseGuide => 'Programmführer';

  @override
  String get settingsVersion => 'Installierte Version';

  @override
  String get settingsVersionDev => 'Entwicklungsversion';

  @override
  String get settingsUpToDate => 'Aero IPTV ist auf dem neuesten Stand.';

  @override
  String get settingsUpdateCheckFailed =>
      'Die Prüfung ist fehlgeschlagen. Versuchen Sie es später erneut.';

  @override
  String get settingsReportProblem => 'Problem melden';

  @override
  String get settingsReportScan =>
      'Scannen Sie diesen Code, um ein Problem vom Telefon aus zu melden.';

  @override
  String get settingsLicenses => 'Lizenzen und Quellen';

  @override
  String get licensesFree =>
      'Aero IPTV ist freie Software unter der Lizenz GPL-3.0.';

  @override
  String get licensesTvMaze => 'Kommende Folgen: TVmaze (CC BY-SA 4.0).';

  @override
  String get licensesSegments =>
      'Intros und Abspann: TheIntroDB und IntroDB (ODbL).';

  @override
  String get licensesCharts =>
      'Trends ohne TMDB-Schlüssel: öffentliche Apple-Charts.';

  @override
  String get actionClose => 'Schließen';

  @override
  String detailEpisodeTitled(int number, String title) {
    return 'Folge $number: $title';
  }
}
