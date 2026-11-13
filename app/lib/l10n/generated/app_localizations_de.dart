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
  String get settingsLanguage => 'App-Sprache';

  @override
  String get settingsPlaylists => 'Playlists';

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
}
