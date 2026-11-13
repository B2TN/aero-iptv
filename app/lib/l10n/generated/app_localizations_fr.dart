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
}
