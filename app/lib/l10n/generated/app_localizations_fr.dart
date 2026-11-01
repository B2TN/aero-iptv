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
  String get settingsLanguage => 'Langue de l\'application';

  @override
  String get settingsPlaylists => 'Playlists';

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
  String get playerSubtitlesDownload => 'Télécharger sous-titre';

  @override
  String get playerSubtitlesSearching => 'Recherche des sous-titres...';

  @override
  String get playerSubtitlesLoaded => 'Sous-titres chargés';

  @override
  String get playerSubtitlesUntranslated =>
      'Sous-titres chargés en anglais : traduction non configurée';

  @override
  String get playerSubtitlesNotFound =>
      'Cette source ne contient aucun sous-titre';

  @override
  String get playerSubtitlesFailed =>
      'Téléchargement des sous-titres impossible';

  @override
  String get settingsDeepL => 'Clé DeepL (sous-titres traduits)';

  @override
  String get settingsOpenSubtitles =>
      'Clé OpenSubtitles (sous-titres complets)';

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
}
