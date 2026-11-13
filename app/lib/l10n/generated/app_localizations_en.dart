// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navLive => 'Live TV';

  @override
  String get navSearch => 'Search';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeContinue => 'Continue watching';

  @override
  String get homeSeries => 'Popular series';

  @override
  String get homeMovies => 'Popular movies';

  @override
  String get homePlay => 'Play';

  @override
  String get homeOpen => 'Open';

  @override
  String get emptyTitle => 'Add your first playlist';

  @override
  String get emptyBody =>
      'An M3U address or an Xtream account is all you need to find your channels, movies and series.';

  @override
  String get emptyCatalogTitle => 'This playlist is still empty';

  @override
  String get emptyCatalogBody =>
      'Refresh it from Settings to load its content.';

  @override
  String get actionAddPlaylist => 'Add a playlist';

  @override
  String get actionOpenSettings => 'Open Settings';

  @override
  String get loading => 'Loading';

  @override
  String get loadErrorTitle => 'The content couldn\'t be loaded';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionBack => 'Back';

  @override
  String get liveChooseCountry => 'Choose a country';

  @override
  String get liveUnknownCountry => 'Other';

  @override
  String get liveAllChannels => 'All channels';

  @override
  String get liveNoChannels => 'No channels in this group';

  @override
  String get liveChooseStream => 'Choose a stream';

  @override
  String liveStreamDefault(int number) {
    return 'Stream $number';
  }

  @override
  String get searchPrompt => 'Search for a movie or series';

  @override
  String get searchTrending => 'Trending';

  @override
  String get searchResults => 'Results';

  @override
  String searchNoResult(String query) {
    return 'No results for “$query”';
  }

  @override
  String get detailChooseVersion => 'Choose a version';

  @override
  String detailSeason(int number) {
    return 'Season $number';
  }

  @override
  String detailEpisode(int number) {
    return 'Episode $number';
  }

  @override
  String get detailNoEpisodes => 'No episodes available for this version';

  @override
  String detailResumeEpisode(int season, int episode) {
    return 'Season $season, episode $episode';
  }

  @override
  String get detailResume => 'Resume';

  @override
  String get detailPlay => 'Play';

  @override
  String get detailPlayFromStart => 'Play from the start';

  @override
  String get playerFailedTitle => 'This stream can\'t be played';

  @override
  String get playerFailedBody =>
      'It may be offline. Try again or choose another stream.';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Subtitles';

  @override
  String get playerSubtitlesOff => 'Turn off';

  @override
  String playerTrack(int number) {
    return 'Track $number';
  }

  @override
  String get playerLive => 'Live';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGroupSeries => 'Group series versions';

  @override
  String get settingsGroupChannels => 'Group channel qualities';

  @override
  String get settingsGroupMovies => 'Group movie versions';

  @override
  String get settingsPerformance => 'Performance mode';

  @override
  String settingsPerformanceAuto(String state) {
    return 'Automatic ($state)';
  }

  @override
  String get settingsDelay => 'Live channel delay';

  @override
  String settingsDelayValue(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds s',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String get settingsLanguage => 'App language';

  @override
  String get settingsPlaylists => 'Playlists';

  @override
  String settingsPlaylistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String get settingsOn => 'On';

  @override
  String get settingsOff => 'Off';

  @override
  String get settingsAttribution =>
      'This product uses the TMDB API but is not endorsed or certified by TMDB.';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistNew => 'New playlist';

  @override
  String get playlistEdit => 'Edit playlist';

  @override
  String get playlistName => 'Name';

  @override
  String get playlistType => 'Type';

  @override
  String get playlistUrl => 'Playlist address';

  @override
  String get playlistEpgUrl => 'XMLTV guide address (optional)';

  @override
  String get playlistServer => 'Server address';

  @override
  String get playlistUsername => 'Username';

  @override
  String get playlistPassword => 'Password';

  @override
  String get playlistCountry => 'Default country';

  @override
  String get playlistCountryNone => 'None';

  @override
  String get playlistEmptyField => 'Not set';

  @override
  String get playlistSave => 'Save';

  @override
  String get playlistRefresh => 'Refresh';

  @override
  String get playlistActivate => 'Use this playlist';

  @override
  String get playlistActive => 'In use';

  @override
  String get playlistDelete => 'Delete';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get playlistMissingFields =>
      'Enter the name and address before saving.';

  @override
  String get playlistSaveFailedTitle => 'Saving failed';

  @override
  String get playlistSynced => 'Refreshed';

  @override
  String get playlistNotSynced => 'Never refreshed';

  @override
  String importRunning(int count) {
    return 'Refreshing: $count items';
  }

  @override
  String get importDone => 'Refresh complete';

  @override
  String get importEpgFailed => 'Refresh complete, without the program guide';

  @override
  String get importAuthFailed =>
      'Credentials refused. Check them and try again.';

  @override
  String importAuthRejected(int code) {
    return 'Access refused by the server (code $code). Check the username, password and address.';
  }

  @override
  String importServerFailed(int code) {
    return 'The server returned an error (code $code). Try again later or use another address.';
  }

  @override
  String get importNetworkFailed =>
      'Server unreachable. Check the address and try again.';

  @override
  String get importFormatFailed =>
      'The content received isn\'t a valid playlist.';

  @override
  String get importSecureFailed =>
      'The secure (https) connection to the server was refused. Check the device\'s date and time, then try again.';

  @override
  String importLastStep(String step) {
    return 'Last step: $step';
  }

  @override
  String importVaultFailed(String cause) {
    return 'The device\'s encrypted vault isn\'t working ($cause error): the playlist\'s credentials couldn\'t be saved or read back.';
  }

  @override
  String importErrorDetail(String detail) {
    return 'Details: $detail';
  }

  @override
  String importUnrefined(String steps) {
    return 'Refresh complete, without: $steps.';
  }

  @override
  String get importRefineHomonyms => 'telling apart series with the same title';

  @override
  String get importRefineVersions => 'grouping language versions';

  @override
  String get importRefineSearch => 'the search index';

  @override
  String get importStorageFull =>
      'The device has run out of space to save the catalog. Free up some storage space, then try again.';

  @override
  String importStorageFailed(int code) {
    return 'The device couldn\'t save the catalog (SQLite error $code). Try again. If the error comes back, report it with this code.';
  }

  @override
  String importUnexpected(String kind) {
    return 'The import stopped on an unexpected error ($kind). Try again. If the error comes back, report it with this name.';
  }

  @override
  String get importConnecting => 'Connecting to the server…';

  @override
  String importReceivingChannels(int count) {
    return 'Receiving channels: $count items received';
  }

  @override
  String importReceivingMovies(int count) {
    return 'Receiving movies: $count items received';
  }

  @override
  String importReceivingSeries(int count) {
    return 'Receiving series: $count items received';
  }

  @override
  String get importIndexing => 'Preparing the catalog…';

  @override
  String get importGuide => 'Catalog ready. Receiving the program guide…';

  @override
  String importPartial(String sections) {
    return 'Refresh incomplete. Not received: $sections.';
  }

  @override
  String get importSectionChannels => 'channels';

  @override
  String get importSectionMovies => 'movies';

  @override
  String get importSectionSeries => 'series';

  @override
  String get importFailedTitle => 'The refresh failed';

  @override
  String get entryConfirm => 'Confirm';

  @override
  String get entryShow => 'Show';

  @override
  String get entryHide => 'Hide';

  @override
  String get entryCancel => 'Cancel';

  @override
  String get confirmDelete => 'Delete';

  @override
  String get confirmKeep => 'Keep';

  @override
  String get homeResume => 'Resume';

  @override
  String get homeRestart => 'Start over';

  @override
  String get homeRemoveContinue => 'Remove from Continue watching';

  @override
  String get playerVersion => 'Version';

  @override
  String get playerExternal => 'External player';

  @override
  String get playerExternalMissing =>
      'No external player found. Install VLC or mpv.';

  @override
  String get playerNoOtherVersion => 'No other version available';

  @override
  String get playerVersionMissing => 'This episode is not in that version';

  @override
  String playerEndsAt(String time) {
    return 'Ends at $time';
  }

  @override
  String get playerFullscreen => 'Full screen';

  @override
  String get playerExitFullscreen => 'Exit full screen';

  @override
  String get playerMono => 'mono';

  @override
  String get playerStereo => 'stereo';

  @override
  String get playerSubtitlesTranslate => 'Translate subtitles';

  @override
  String get playerSubtitlesLoaded => 'Subtitles loaded';

  @override
  String get playerSubtitlesNotFound => 'This source has no subtitles';

  @override
  String get playerSubtitlesFailed => 'Couldn\'t translate the subtitles';

  @override
  String get settingsSubtitleAppearance => 'Subtitle appearance';

  @override
  String get subtitlePreview => 'Preview';

  @override
  String get subtitleSample => 'We\'re heading up before the storm.';

  @override
  String get subtitleSize => 'Size';

  @override
  String get subtitleFont => 'Font';

  @override
  String get subtitleColor => 'Text color';

  @override
  String get subtitleEdge => 'Edge';

  @override
  String get subtitleBackground => 'Background';

  @override
  String get subtitleBackgroundOpacity => 'Background opacity';

  @override
  String get subtitlePosition => 'Position';

  @override
  String get subtitleReset => 'Restore the original settings';

  @override
  String get subtitleSizeSmall => 'Small';

  @override
  String get subtitleSizeMedium => 'Medium';

  @override
  String get subtitleSizeLarge => 'Large';

  @override
  String get subtitleSizeExtraLarge => 'Extra large';

  @override
  String get subtitleFontStandard => 'Standard';

  @override
  String get subtitleFontBold => 'Bold';

  @override
  String get subtitleFontSerif => 'Serif';

  @override
  String get subtitleFontMonospace => 'Monospace';

  @override
  String get subtitleColorWhite => 'White';

  @override
  String get subtitleColorYellow => 'Yellow';

  @override
  String get subtitleColorCyan => 'Cyan';

  @override
  String get subtitleColorGreen => 'Green';

  @override
  String get subtitleEdgeNone => 'None';

  @override
  String get subtitleEdgeOutline => 'Black outline';

  @override
  String get subtitleEdgeShadow => 'Shadow';

  @override
  String get subtitleBackgroundNone => 'None';

  @override
  String get subtitleBackgroundBlack => 'Black';

  @override
  String get subtitleBackgroundGrey => 'Grey';

  @override
  String get subtitleBackgroundNavy => 'Navy';

  @override
  String subtitleOpacityValue(int percent) {
    return '$percent%';
  }

  @override
  String get subtitlePositionBottom => 'Bottom';

  @override
  String get subtitlePositionRaised => 'Slightly raised';

  @override
  String get subtitlePositionHigher => 'Higher';

  @override
  String get subtitlePositionTop => 'Top';

  @override
  String get settingsDeepL => 'DeepL key (translated subtitles)';

  @override
  String get settingsKeySet => 'Set';

  @override
  String get settingsKeyUnset => 'Not set';

  @override
  String get settingsKeyReplace => 'Replace the key';

  @override
  String get settingsKeyRemove => 'Remove the key';

  @override
  String get versionSubtitled => 'subtitled';

  @override
  String get versionDubbed => 'dubbed';

  @override
  String get homeInfo => 'Information';

  @override
  String get homeNoOverview => 'No description available.';

  @override
  String get settingsKeyGet => 'Get a key';

  @override
  String settingsKeyScan(String service) {
    return 'Scan this code with your phone to open the $service page, then enter your key here.';
  }

  @override
  String playerServerAnswer(String answer) {
    return 'Server response: $answer';
  }

  @override
  String get playerServerSilent =>
      'The server does not respond to this stream.';

  @override
  String get playerConnectionsFullTitle => 'All your connections are in use';

  @override
  String get playerConnectionsFullBody =>
      'Your subscription limits simultaneous streams. Stop playback on your other devices or apps, then try again.';

  @override
  String get playerConnecting => 'Connection in use, trying again...';

  @override
  String get playerClose => 'Exit playback';

  @override
  String get playerSkipIntro => 'Skip intro';

  @override
  String get playerNextEpisode => 'Next episode';

  @override
  String get playerSubtitlesLanguage => 'Translate subtitles into';

  @override
  String get playerSubtitlesImagesOnly =>
      'This source\'s subtitles are images and cannot be translated';
}
