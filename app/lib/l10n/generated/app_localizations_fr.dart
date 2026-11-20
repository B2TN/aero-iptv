// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navHome => 'Accueil';

  @override
  String get navLive => 'Live TV';

  @override
  String get navSearch => 'Recherche';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get homeContinue => 'Continuer à regarder';

  @override
  String homeEpisodeNumber(int season, int number) {
    return 'S$season É$number';
  }

  @override
  String get homeUpNext => 'À suivre';

  @override
  String get homeSeries => 'Séries populaires';

  @override
  String get homeMovies => 'Films populaires';

  @override
  String get homePlay => 'Lire';

  @override
  String get homeOpen => 'Ouvrir';

  @override
  String get emptyTitle => 'Ajoutez votre première playlist';

  @override
  String get emptyBody =>
      'Une adresse M3U ou un compte Xtream suffit pour retrouver vos chaînes, films et séries.';

  @override
  String get emptyCatalogTitle => 'Cette playlist est encore vide';

  @override
  String get emptyCatalogBody =>
      'Actualisez-la depuis les paramètres pour charger son contenu.';

  @override
  String get actionAddPlaylist => 'Ajouter une playlist';

  @override
  String get actionOpenSettings => 'Ouvrir les paramètres';

  @override
  String get loading => 'Chargement';

  @override
  String get loadErrorTitle => 'Le contenu n\'a pas pu être chargé';

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get actionBack => 'Retour';

  @override
  String get liveChooseCountry => 'Choisissez un pays';

  @override
  String get liveUnknownCountry => 'Autres';

  @override
  String get liveAllChannels => 'Toutes les chaînes';

  @override
  String get liveGeneralChannels => 'Général';

  @override
  String get liveNoChannels => 'Aucune chaîne dans ce groupe';

  @override
  String get liveChooseStream => 'Choisissez un flux';

  @override
  String liveStreamDefault(int number) {
    return 'Flux $number';
  }

  @override
  String get searchPrompt => 'Cherchez un film ou une série';

  @override
  String get searchTrending => 'Tendances';

  @override
  String get searchResults => 'Résultats';

  @override
  String searchNoResult(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get detailChooseVersion => 'Choisissez une version';

  @override
  String detailSeason(int number) {
    return 'Saison $number';
  }

  @override
  String detailEpisode(int number) {
    return 'Épisode $number';
  }

  @override
  String get detailNoEpisodes => 'Aucun épisode disponible pour cette version';

  @override
  String get searchSearching => 'Recherche en cours…';

  @override
  String get menuOpenPage => 'Voir la fiche';

  @override
  String get menuChooseVersion => 'Choisir la version';

  @override
  String get menuMarkWatched => 'Marquer comme vu';

  @override
  String get menuMarkUnwatched => 'Marquer comme non vu';

  @override
  String get menuMarkWatchedUpTo => 'Marquer vus jusqu\'ici';

  @override
  String get menuMarkSeasonWatched => 'Marquer la saison comme vue';

  @override
  String get menuMarkSeasonUnwatched => 'Marquer la saison comme non vue';

  @override
  String get menuAddFavorite => 'Ajouter aux favoris';

  @override
  String get menuRemoveFavorite => 'Retirer des favoris';

  @override
  String get homeFavorites => 'Favoris';

  @override
  String detailSeasonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saisons',
      one: '1 saison',
    );
    return '$_temp0';
  }

  @override
  String get detailRunning => 'En cours de diffusion';

  @override
  String get detailUpcoming => 'Prochains épisodes';

  @override
  String detailUpcomingEpisode(int season, int number, String title) {
    return 'S$season É$number, $title';
  }

  @override
  String get detailUntitled => 'Titre non annoncé';

  @override
  String get detailWatched => 'Vu';

  @override
  String get detailLate => 'Retard sur l\'IPTV';

  @override
  String get detailUpcomingNote =>
      'Dates de première diffusion dans le pays d\'origine, d\'après TVmaze. L\'épisode arrive chez votre fournisseur un peu plus tard.';

  @override
  String detailRuntimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String detailRuntimeHours(int hours, String minutes) {
    return '$hours h $minutes';
  }

  @override
  String detailResumeEpisode(int season, int episode) {
    return 'Saison $season, épisode $episode';
  }

  @override
  String get detailResume => 'Reprendre';

  @override
  String get detailPlay => 'Lecture';

  @override
  String get detailPlayFromStart => 'Lecture depuis le début';

  @override
  String get playerFailedTitle => 'Ce flux ne peut pas être lu';

  @override
  String get playerFailedBody =>
      'Il est peut-être hors ligne. Réessayez ou choisissez un autre flux.';

  @override
  String get playerPlay => 'Lecture';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Sous-titres';

  @override
  String get playerSubtitlesOff => 'Désactiver';

  @override
  String playerTrack(int number) {
    return 'Piste $number';
  }

  @override
  String get playerLive => 'En direct';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsGroupSeries => 'Regrouper les versions des séries';

  @override
  String get settingsGroupChannels => 'Regrouper les qualités des chaînes';

  @override
  String get settingsGroupMovies => 'Regrouper les versions des films';

  @override
  String get settingsPerformance => 'Mode Performance';

  @override
  String settingsPerformanceAuto(String state) {
    return 'Automatique ($state)';
  }

  @override
  String get settingsDelay => 'Retard des chaînes en direct';

  @override
  String settingsDelayValue(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds s',
      zero: 'Aucun',
    );
    return '$_temp0';
  }

  @override
  String get settingsTrendCountry => 'Pays des tendances';

  @override
  String settingsTrendCountryAuto(String country) {
    return 'Automatique ($country)';
  }

  @override
  String get settingsLanguage => 'Langue de l\'application';

  @override
  String get settingsPlaylists => 'Playlists';

  @override
  String get settingsDailySync => 'Synchroniser chaque jour';

  @override
  String updateAvailable(String version) {
    return 'Version $version disponible';
  }

  @override
  String get updateInstall => 'Mettre à jour';

  @override
  String get updateNotes => 'Notes de version';

  @override
  String get updateDismiss => 'Fermer';

  @override
  String updateDownloading(int percent) {
    return 'Téléchargement : $percent %';
  }

  @override
  String get updatePermission =>
      'Autorisez Aero IPTV à installer des applications, puis réessayez.';

  @override
  String get updateFailed => 'La mise à jour a échoué.';

  @override
  String updateNotesTitle(String version) {
    return 'Nouveautés de la version $version';
  }

  @override
  String get settingsBetaUpdates => 'Mises à jour bêta';

  @override
  String settingsPlaylistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
      zero: 'Aucune',
    );
    return '$_temp0';
  }

  @override
  String get settingsOn => 'Activé';

  @override
  String get settingsOff => 'Désactivé';

  @override
  String get settingsAttribution =>
      'Ce produit utilise l\'API TMDB, sans être approuvé ni certifié par TMDB.';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistNew => 'Nouvelle playlist';

  @override
  String get playlistEdit => 'Modifier la playlist';

  @override
  String get playlistName => 'Nom';

  @override
  String get playlistType => 'Type';

  @override
  String get playlistUrl => 'Adresse de la playlist';

  @override
  String get playlistEpgUrl => 'Adresse du guide XMLTV (facultatif)';

  @override
  String get playlistServer => 'Adresse du serveur';

  @override
  String get playlistUsername => 'Identifiant';

  @override
  String get playlistPassword => 'Mot de passe';

  @override
  String get playlistCountry => 'Pays par défaut';

  @override
  String get playlistCountryNone => 'Aucun';

  @override
  String get playlistEmptyField => 'Non renseigné';

  @override
  String get playlistSave => 'Enregistrer';

  @override
  String get playlistRefresh => 'Actualiser';

  @override
  String get playlistActivate => 'Utiliser cette playlist';

  @override
  String get playlistActive => 'En cours d\'utilisation';

  @override
  String get playlistDelete => 'Supprimer';

  @override
  String playlistDeleteConfirm(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get playlistMissingFields =>
      'Renseignez le nom et l\'adresse avant d\'enregistrer.';

  @override
  String get playlistSaveFailedTitle => 'L\'enregistrement a échoué';

  @override
  String get playlistSynced => 'Actualisée';

  @override
  String get playlistNotSynced => 'Jamais actualisée';

  @override
  String importRunning(int count) {
    return 'Actualisation : $count éléments';
  }

  @override
  String get importDone => 'Actualisation terminée';

  @override
  String get importEpgFailed =>
      'Actualisation terminée, sans le guide des programmes';

  @override
  String get importAuthFailed =>
      'Identifiants refusés. Vérifiez-les puis réessayez.';

  @override
  String importAuthRejected(int code) {
    return 'Accès refusé par le serveur (code $code). Vérifiez le nom d\'utilisateur, le mot de passe et l\'adresse.';
  }

  @override
  String importServerFailed(int code) {
    return 'Le serveur a renvoyé une erreur (code $code). Réessayez plus tard ou essayez une autre adresse.';
  }

  @override
  String get importNetworkFailed =>
      'Serveur injoignable. Vérifiez l\'adresse puis réessayez.';

  @override
  String get importFormatFailed =>
      'Le contenu reçu n\'est pas une playlist valide.';

  @override
  String get importSecureFailed =>
      'La connexion sécurisée (https) au serveur a été refusée. Vérifiez la date et l\'heure de l\'appareil, puis réessayez.';

  @override
  String importLastStep(String step) {
    return 'Dernière étape : $step';
  }

  @override
  String importVaultFailed(String cause) {
    return 'Le coffre chiffré de l\'appareil ne fonctionne pas (erreur $cause) : les identifiants de la playlist n\'ont pas pu être enregistrés ou relus.';
  }

  @override
  String importErrorDetail(String detail) {
    return 'Détail : $detail';
  }

  @override
  String importUnrefined(String steps) {
    return 'Actualisation terminée, sans : $steps.';
  }

  @override
  String get importRefineHomonyms => 'la séparation des séries homonymes';

  @override
  String get importRefineVersions => 'le regroupement des versions';

  @override
  String get importRefineSearch => 'l\'index de recherche';

  @override
  String get importStorageFull =>
      'L\'appareil n\'a plus assez de place pour enregistrer le catalogue. Libérez de l\'espace de stockage, puis réessayez.';

  @override
  String importStorageFailed(int code) {
    return 'L\'appareil n\'a pas pu enregistrer le catalogue (erreur SQLite $code). Réessayez. Si l\'erreur revient, signalez-la avec ce code.';
  }

  @override
  String importUnexpected(String kind) {
    return 'L\'import s\'est arrêté sur une erreur inattendue ($kind). Réessayez. Si l\'erreur revient, signalez-la avec ce nom.';
  }

  @override
  String get importConnecting => 'Connexion au serveur…';

  @override
  String importReceivingChannels(int count) {
    return 'Réception des chaînes : $count éléments reçus';
  }

  @override
  String importReceivingMovies(int count) {
    return 'Réception des films : $count éléments reçus';
  }

  @override
  String importReceivingSeries(int count) {
    return 'Réception des séries : $count éléments reçus';
  }

  @override
  String get importIndexing => 'Préparation du catalogue…';

  @override
  String get importGuide =>
      'Catalogue prêt. Réception du guide des programmes…';

  @override
  String importPartial(String sections) {
    return 'Actualisation incomplète. Non reçu : $sections.';
  }

  @override
  String get importSectionChannels => 'chaînes';

  @override
  String get importSectionMovies => 'films';

  @override
  String get importSectionSeries => 'séries';

  @override
  String get importFailedTitle => 'L\'actualisation a échoué';

  @override
  String get entryConfirm => 'Valider';

  @override
  String get entryShow => 'Afficher';

  @override
  String get entryHide => 'Masquer';

  @override
  String get entryCancel => 'Annuler';

  @override
  String get confirmDelete => 'Supprimer';

  @override
  String get confirmKeep => 'Conserver';

  @override
  String get homeResume => 'Reprendre';

  @override
  String get homeRestart => 'Recommencer';

  @override
  String get homeRemoveContinue => 'Supprimer de Continuer à regarder';

  @override
  String get playerVersion => 'Version';

  @override
  String get playerEpisodes => 'Épisodes';

  @override
  String get playerNowPlaying => 'En cours de lecture';

  @override
  String get playerExternal => 'Lecteur externe';

  @override
  String get playerExternalMissing =>
      'Aucun lecteur externe trouvé. Installez VLC ou mpv.';

  @override
  String get playerNoOtherVersion => 'Aucune autre version disponible';

  @override
  String get playerVersionMissing =>
      'Cet épisode n\'existe pas dans cette version';

  @override
  String playerEndsAt(String time) {
    return 'Fin à $time';
  }

  @override
  String get playerFullscreen => 'Plein écran';

  @override
  String get playerExitFullscreen => 'Quitter le plein écran';

  @override
  String get playerMono => 'mono';

  @override
  String get playerStereo => 'stéréo';

  @override
  String get playerSubtitlesTranslate => 'Traduire les sous-titres';

  @override
  String get playerSubtitlesLoaded => 'Sous-titres chargés';

  @override
  String get playerSubtitlesNotFound =>
      'Cette source ne contient aucun sous-titre';

  @override
  String get playerSubtitlesFailed => 'Traduction des sous-titres impossible';

  @override
  String get settingsSubtitleAppearance => 'Apparence des sous-titres';

  @override
  String get subtitlePreview => 'Aperçu';

  @override
  String get subtitleSample => 'On remonte avant la tempête.';

  @override
  String get subtitleSize => 'Taille';

  @override
  String get subtitleFont => 'Police';

  @override
  String get subtitleColor => 'Couleur du texte';

  @override
  String get subtitleEdge => 'Contour';

  @override
  String get subtitleBackground => 'Fond';

  @override
  String get subtitleBackgroundOpacity => 'Opacité du fond';

  @override
  String get subtitlePosition => 'Position';

  @override
  String get subtitleReset => 'Rétablir les réglages d\'origine';

  @override
  String get subtitleSizeSmall => 'Petite';

  @override
  String get subtitleSizeMedium => 'Moyenne';

  @override
  String get subtitleSizeLarge => 'Grande';

  @override
  String get subtitleSizeExtraLarge => 'Très grande';

  @override
  String get subtitleFontStandard => 'Standard';

  @override
  String get subtitleFontBold => 'Grasse';

  @override
  String get subtitleFontSerif => 'À empattements';

  @override
  String get subtitleFontMonospace => 'Chasse fixe';

  @override
  String get subtitleColorWhite => 'Blanc';

  @override
  String get subtitleColorYellow => 'Jaune';

  @override
  String get subtitleColorCyan => 'Cyan';

  @override
  String get subtitleColorGreen => 'Vert';

  @override
  String get subtitleEdgeNone => 'Aucun';

  @override
  String get subtitleEdgeOutline => 'Contour noir';

  @override
  String get subtitleEdgeShadow => 'Ombre';

  @override
  String get subtitleBackgroundNone => 'Aucun';

  @override
  String get subtitleBackgroundBlack => 'Noir';

  @override
  String get subtitleBackgroundGrey => 'Gris';

  @override
  String get subtitleBackgroundNavy => 'Bleu nuit';

  @override
  String subtitleOpacityValue(int percent) {
    return '$percent %';
  }

  @override
  String get subtitlePositionBottom => 'En bas';

  @override
  String get subtitlePositionRaised => 'Un peu relevée';

  @override
  String get subtitlePositionHigher => 'Plus haut';

  @override
  String get subtitlePositionTop => 'En haut';

  @override
  String get settingsDeepL => 'Clé DeepL (sous-titres traduits)';

  @override
  String get settingsKeySet => 'Configurée';

  @override
  String get settingsKeyUnset => 'Non configurée';

  @override
  String get settingsKeyReplace => 'Remplacer la clé';

  @override
  String get settingsKeyRemove => 'Supprimer la clé';

  @override
  String get versionSubtitled => 'sous-titré';

  @override
  String get versionDubbed => 'doublé';

  @override
  String get homeInfo => 'Informations';

  @override
  String get homeNoOverview => 'Aucune description disponible.';

  @override
  String get settingsKeyGet => 'Obtenir une clé';

  @override
  String settingsKeyScan(String service) {
    return 'Scannez ce code avec votre téléphone pour ouvrir la page $service, puis saisissez votre clé ici.';
  }

  @override
  String playerServerAnswer(String answer) {
    return 'Réponse du serveur : $answer';
  }

  @override
  String get playerServerSilent => 'Le serveur ne répond pas à ce flux.';

  @override
  String get playerConnectionsFullTitle =>
      'Toutes vos connexions sont utilisées';

  @override
  String get playerConnectionsFullBody =>
      'Votre abonnement limite le nombre de lectures simultanées. Arrêtez la lecture sur vos autres appareils ou applications, puis réessayez.';

  @override
  String get playerConnecting => 'Connexion occupée, nouvel essai...';

  @override
  String get playerClose => 'Quitter la lecture';

  @override
  String get playerSkipIntro => 'Passer l\'intro';

  @override
  String get playerNextEpisode => 'Épisode suivant';

  @override
  String get playerSubtitlesLanguage => 'Traduire les sous-titres en';

  @override
  String get playerSubtitlesImagesOnly =>
      'Les sous-titres de cette source sont des images : ils ne peuvent pas être traduits';

  @override
  String tutorialStep(int step, int count) {
    return 'Étape $step sur $count';
  }

  @override
  String get tutorialSkip => 'Passer';

  @override
  String get tutorialPrevious => 'Précédent';

  @override
  String get tutorialNext => 'Suivant';

  @override
  String get tutorialFinish => 'Terminer';

  @override
  String get tutorialWelcomeTitle => 'Bienvenue dans Aero IPTV';

  @override
  String get tutorialWelcomeBody =>
      'Quelques étapes pour tout préparer et faire le tour de l\'application. Vous pouvez passer ce tutoriel à tout moment, et le revoir depuis les Paramètres.';

  @override
  String get tutorialChangeLanguage => 'Changer la langue';

  @override
  String get tutorialPlaylistTitle => 'Ajoutez votre playlist';

  @override
  String get tutorialPlaylistBody =>
      'Aero IPTV lit votre abonnement : une adresse M3U, ou les identifiants Xtream Codes donnés par votre fournisseur. Ils restent chiffrés sur cet appareil et ne sont envoyés qu\'à votre fournisseur.';

  @override
  String get tutorialPerformanceTitle => 'Mode Performance';

  @override
  String get tutorialPerformanceBody =>
      'Il retire les effets de verre et de reflets pour garder une navigation fluide sur un petit appareil, comme un Fire TV Stick.';

  @override
  String get tutorialPerformanceSmall =>
      'Cet appareil a peu de mémoire : le mode Performance est conseillé.';

  @override
  String get tutorialPerformanceLarge =>
      'Cet appareil a assez de mémoire pour garder les effets.';

  @override
  String get tutorialPerformanceOn => 'Activer le mode Performance';

  @override
  String get tutorialPerformanceOff => 'Désactiver le mode Performance';

  @override
  String get tutorialControlsTitle => 'Télécommande, souris ou clavier';

  @override
  String get tutorialControlsBody =>
      'Flèches pour se déplacer, OK pour ouvrir ou lire, Retour pour revenir.\nUn appui long sur OK, ou la touche Menu, ouvre le menu d\'un film, d\'une série ou d\'un épisode.\nÀ la souris : un clic ouvre, un clic droit ouvre le menu. Au clavier : flèches, Entrée et Échap.';

  @override
  String get tutorialHomeTitle => 'L\'accueil';

  @override
  String get tutorialHomeBody =>
      '« Continuer à regarder » reprend là où vous vous êtes arrêté, dans n\'importe quelle version.\nVos favoris ont leur rangée : ajoutez-les depuis le menu d\'un titre.\nLes séries et films populaires suivent les tendances de votre pays.';

  @override
  String get tutorialDetailsTitle => 'Fiches et versions';

  @override
  String get tutorialDetailsBody =>
      'Un film ou une série existe souvent en plusieurs langues et qualités : sa fiche les réunit, et le bouton Version passe de l\'une à l\'autre. Votre progression vaut pour toutes.\nLa fiche d\'une série montre ses saisons, les épisodes vus et les prochains à venir.';

  @override
  String get tutorialLiveTitle => 'Chaînes en direct';

  @override
  String get tutorialLiveBody =>
      'Les chaînes sont rangées par pays, avec le programme en cours. Une chaîne proposée en plusieurs qualités n\'apparaît qu\'une fois.\nSi une chaîne saccade, ajoutez un retard dans les Paramètres.';

  @override
  String get tutorialPlayerTitle => 'Lecteur et sous-titres';

  @override
  String get tutorialPlayerBody =>
      'OK affiche les commandes : audio, sous-titres, version et épisodes.\nLes sous-titres viennent de la vidéo. Avec une clé DeepL gratuite, facultative, ils sont traduits dans votre langue pendant la lecture.';

  @override
  String get tutorialAddKey => 'Ajouter une clé DeepL';

  @override
  String get tutorialSyncTitle => 'Synchronisation et mises à jour';

  @override
  String get tutorialSyncBody =>
      'Votre playlist se met à jour chaque jour, jamais pendant une lecture.\nQuand une nouvelle version d\'Aero IPTV sort, un bandeau le signale.\nTous ces réglages, et ce tutoriel, se retrouvent dans les Paramètres.';

  @override
  String get settingsTutorial => 'Revoir le tutoriel';

  @override
  String homeNextEpisodeIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Prochain épisode dans $days jours',
      one: 'Prochain épisode demain',
      zero: 'Prochain épisode aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String homeNextEpisodeOn(String date) {
    return 'Prochain épisode le $date';
  }

  @override
  String get homeNextEpisodeAired =>
      'Épisode diffusé, bientôt dans la playlist';

  @override
  String get settingsCategoryPlaylist => 'Playlist';

  @override
  String get settingsCategoryCatalog => 'Catalogue';

  @override
  String get settingsCategoryPlayback => 'Lecture';

  @override
  String get settingsCategorySubtitles => 'Sous-titres';

  @override
  String get settingsCategoryAppearance => 'Apparence';

  @override
  String get settingsCategoryUpdates => 'Mises à jour';

  @override
  String get settingsCategoryAbout => 'À propos';

  @override
  String get settingsLastSync => 'Dernière synchronisation';

  @override
  String get settingsLastSyncNever => 'Jamais';

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
  String get syncReportFull => 'import complet';

  @override
  String get syncReportChanges => 'changements seulement';

  @override
  String get syncReportTotal => 'Total';

  @override
  String syncReportCounts(int received, int changed) {
    final intl.NumberFormat receivedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String receivedString = receivedNumberFormat.format(received);
    final intl.NumberFormat changedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String changedString = changedNumberFormat.format(changed);

    return '$receivedString reçus, $changedString modifiés';
  }

  @override
  String syncReportProgrammes(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString programmes';
  }

  @override
  String get syncPhaseConnection => 'Connexion';

  @override
  String get syncPhaseCatalog => 'Liste';

  @override
  String get syncPhaseLive => 'Chaînes';

  @override
  String get syncPhaseMovies => 'Films';

  @override
  String get syncPhaseSeries => 'Séries';

  @override
  String get syncPhaseRefinement => 'Finitions';

  @override
  String get syncPhaseUpdate => 'Mise à jour du catalogue';

  @override
  String get syncPhaseGuide => 'Guide des programmes';

  @override
  String get settingsVersion => 'Version installée';

  @override
  String get settingsVersionDev => 'Version de développement';

  @override
  String get settingsUpToDate => 'Aero IPTV est à jour.';

  @override
  String get settingsUpdateCheckFailed =>
      'La vérification n\'a pas abouti. Réessayez plus tard.';

  @override
  String get settingsReportProblem => 'Signaler un problème';

  @override
  String get settingsReportScan =>
      'Scannez ce code pour signaler un problème depuis votre téléphone.';

  @override
  String get settingsLicenses => 'Licences et sources';

  @override
  String get licensesFree =>
      'Aero IPTV est un logiciel libre, sous licence GPL-3.0.';

  @override
  String get licensesTvMaze => 'Prochains épisodes : TVmaze (CC BY-SA 4.0).';

  @override
  String get licensesSegments =>
      'Intros et génériques : TheIntroDB et IntroDB (ODbL).';

  @override
  String get licensesCharts =>
      'Tendances sans clé TMDB : classements publics d\'Apple.';

  @override
  String get actionClose => 'Fermer';
}
