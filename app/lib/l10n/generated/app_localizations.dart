import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navLive.
  ///
  /// In fr, this message translates to:
  /// **'Live TV'**
  String get navLive;

  /// No description provided for @navSearch.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get navSearch;

  /// No description provided for @navSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get navSettings;

  /// No description provided for @homeContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer à regarder'**
  String get homeContinue;

  /// No description provided for @homeSeries.
  ///
  /// In fr, this message translates to:
  /// **'Séries populaires'**
  String get homeSeries;

  /// No description provided for @homeMovies.
  ///
  /// In fr, this message translates to:
  /// **'Films populaires'**
  String get homeMovies;

  /// No description provided for @homePlay.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get homePlay;

  /// No description provided for @homeOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir'**
  String get homeOpen;

  /// No description provided for @emptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez votre première playlist'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Une adresse M3U ou un compte Xtream suffit pour retrouver vos chaînes, films et séries.'**
  String get emptyBody;

  /// No description provided for @emptyCatalogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Cette playlist est encore vide'**
  String get emptyCatalogTitle;

  /// No description provided for @emptyCatalogBody.
  ///
  /// In fr, this message translates to:
  /// **'Actualisez-la depuis les paramètres pour charger son contenu.'**
  String get emptyCatalogBody;

  /// No description provided for @actionAddPlaylist.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une playlist'**
  String get actionAddPlaylist;

  /// No description provided for @actionOpenSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les paramètres'**
  String get actionOpenSettings;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement'**
  String get loading;

  /// No description provided for @loadErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Le contenu n\'a pas pu être chargé'**
  String get loadErrorTitle;

  /// No description provided for @actionRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get actionRetry;

  /// No description provided for @actionBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get actionBack;

  /// No description provided for @liveChooseCountry.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un pays'**
  String get liveChooseCountry;

  /// No description provided for @liveUnknownCountry.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get liveUnknownCountry;

  /// No description provided for @liveAllChannels.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les chaînes'**
  String get liveAllChannels;

  /// No description provided for @liveNoChannels.
  ///
  /// In fr, this message translates to:
  /// **'Aucune chaîne dans ce groupe'**
  String get liveNoChannels;

  /// No description provided for @liveChooseStream.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un flux'**
  String get liveChooseStream;

  /// No description provided for @liveStreamDefault.
  ///
  /// In fr, this message translates to:
  /// **'Flux {number}'**
  String liveStreamDefault(int number);

  /// No description provided for @searchPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Cherchez un film ou une série'**
  String get searchPrompt;

  /// No description provided for @searchTrending.
  ///
  /// In fr, this message translates to:
  /// **'Tendances'**
  String get searchTrending;

  /// No description provided for @searchResults.
  ///
  /// In fr, this message translates to:
  /// **'Résultats'**
  String get searchResults;

  /// No description provided for @searchNoResult.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour « {query} »'**
  String searchNoResult(String query);

  /// No description provided for @detailChooseVersion.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une version'**
  String get detailChooseVersion;

  /// No description provided for @detailSeason.
  ///
  /// In fr, this message translates to:
  /// **'Saison {number}'**
  String detailSeason(int number);

  /// No description provided for @detailEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Épisode {number}'**
  String detailEpisode(int number);

  /// No description provided for @detailNoEpisodes.
  ///
  /// In fr, this message translates to:
  /// **'Aucun épisode disponible pour cette version'**
  String get detailNoEpisodes;

  /// No description provided for @detailResumeEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Saison {season}, épisode {episode}'**
  String detailResumeEpisode(int season, int episode);

  /// No description provided for @detailResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get detailResume;

  /// No description provided for @detailPlay.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get detailPlay;

  /// No description provided for @detailPlayFromStart.
  ///
  /// In fr, this message translates to:
  /// **'Lecture depuis le début'**
  String get detailPlayFromStart;

  /// No description provided for @playerFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce flux ne peut pas être lu'**
  String get playerFailedTitle;

  /// No description provided for @playerFailedBody.
  ///
  /// In fr, this message translates to:
  /// **'Il est peut-être hors ligne. Réessayez ou choisissez un autre flux.'**
  String get playerFailedBody;

  /// No description provided for @playerPlay.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get playerPlay;

  /// No description provided for @playerPause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// No description provided for @playerAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get playerAudio;

  /// No description provided for @playerSubtitles.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres'**
  String get playerSubtitles;

  /// No description provided for @playerSubtitlesOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver'**
  String get playerSubtitlesOff;

  /// No description provided for @playerTrack.
  ///
  /// In fr, this message translates to:
  /// **'Piste {number}'**
  String playerTrack(int number);

  /// No description provided for @playerLive.
  ///
  /// In fr, this message translates to:
  /// **'En direct'**
  String get playerLive;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settingsTitle;

  /// No description provided for @settingsGroupSeries.
  ///
  /// In fr, this message translates to:
  /// **'Regrouper les versions des séries'**
  String get settingsGroupSeries;

  /// No description provided for @settingsGroupChannels.
  ///
  /// In fr, this message translates to:
  /// **'Regrouper les qualités des chaînes'**
  String get settingsGroupChannels;

  /// No description provided for @settingsGroupMovies.
  ///
  /// In fr, this message translates to:
  /// **'Regrouper les versions des films'**
  String get settingsGroupMovies;

  /// No description provided for @settingsDelay.
  ///
  /// In fr, this message translates to:
  /// **'Retard des chaînes en direct'**
  String get settingsDelay;

  /// No description provided for @settingsDelayValue.
  ///
  /// In fr, this message translates to:
  /// **'{seconds, plural, =0{Aucun} other{{seconds} s}}'**
  String settingsDelayValue(int seconds);

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'application'**
  String get settingsLanguage;

  /// No description provided for @settingsPlaylists.
  ///
  /// In fr, this message translates to:
  /// **'Playlists'**
  String get settingsPlaylists;

  /// No description provided for @settingsPlaylistCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune} =1{1 playlist} other{{count} playlists}}'**
  String settingsPlaylistCount(int count);

  /// No description provided for @settingsOn.
  ///
  /// In fr, this message translates to:
  /// **'Activé'**
  String get settingsOn;

  /// No description provided for @settingsOff.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get settingsOff;

  /// No description provided for @settingsAttribution.
  ///
  /// In fr, this message translates to:
  /// **'Ce produit utilise l\'API TMDB, sans être approuvé ni certifié par TMDB.'**
  String get settingsAttribution;

  /// No description provided for @playlistsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Playlists'**
  String get playlistsTitle;

  /// No description provided for @playlistNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle playlist'**
  String get playlistNew;

  /// No description provided for @playlistEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la playlist'**
  String get playlistEdit;

  /// No description provided for @playlistName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get playlistName;

  /// No description provided for @playlistType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get playlistType;

  /// No description provided for @playlistUrl.
  ///
  /// In fr, this message translates to:
  /// **'Adresse de la playlist'**
  String get playlistUrl;

  /// No description provided for @playlistEpgUrl.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du guide XMLTV (facultatif)'**
  String get playlistEpgUrl;

  /// No description provided for @playlistServer.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du serveur'**
  String get playlistServer;

  /// No description provided for @playlistUsername.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant'**
  String get playlistUsername;

  /// No description provided for @playlistPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get playlistPassword;

  /// No description provided for @playlistCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays par défaut'**
  String get playlistCountry;

  /// No description provided for @playlistCountryNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get playlistCountryNone;

  /// No description provided for @playlistEmptyField.
  ///
  /// In fr, this message translates to:
  /// **'Non renseigné'**
  String get playlistEmptyField;

  /// No description provided for @playlistSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get playlistSave;

  /// No description provided for @playlistRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get playlistRefresh;

  /// No description provided for @playlistActivate.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser cette playlist'**
  String get playlistActivate;

  /// No description provided for @playlistActive.
  ///
  /// In fr, this message translates to:
  /// **'En cours d\'utilisation'**
  String get playlistActive;

  /// No description provided for @playlistDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get playlistDelete;

  /// No description provided for @playlistDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} » ?'**
  String playlistDeleteConfirm(String name);

  /// No description provided for @playlistMissingFields.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez le nom et l\'adresse avant d\'enregistrer.'**
  String get playlistMissingFields;

  /// No description provided for @playlistSaveFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement a échoué'**
  String get playlistSaveFailedTitle;

  /// No description provided for @playlistSynced.
  ///
  /// In fr, this message translates to:
  /// **'Actualisée'**
  String get playlistSynced;

  /// No description provided for @playlistNotSynced.
  ///
  /// In fr, this message translates to:
  /// **'Jamais actualisée'**
  String get playlistNotSynced;

  /// No description provided for @importRunning.
  ///
  /// In fr, this message translates to:
  /// **'Actualisation : {count} éléments'**
  String importRunning(int count);

  /// No description provided for @importDone.
  ///
  /// In fr, this message translates to:
  /// **'Actualisation terminée'**
  String get importDone;

  /// No description provided for @importEpgFailed.
  ///
  /// In fr, this message translates to:
  /// **'Actualisation terminée, sans le guide des programmes'**
  String get importEpgFailed;

  /// No description provided for @importAuthFailed.
  ///
  /// In fr, this message translates to:
  /// **'Identifiants refusés. Vérifiez-les puis réessayez.'**
  String get importAuthFailed;

  /// No description provided for @importAuthRejected.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé par le serveur (code {code}). Vérifiez le nom d\'utilisateur, le mot de passe et l\'adresse.'**
  String importAuthRejected(int code);

  /// No description provided for @importServerFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur a renvoyé une erreur (code {code}). Réessayez plus tard ou essayez une autre adresse.'**
  String importServerFailed(int code);

  /// No description provided for @importNetworkFailed.
  ///
  /// In fr, this message translates to:
  /// **'Serveur injoignable. Vérifiez l\'adresse puis réessayez.'**
  String get importNetworkFailed;

  /// No description provided for @importFormatFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le contenu reçu n\'est pas une playlist valide.'**
  String get importFormatFailed;

  /// No description provided for @importSecureFailed.
  ///
  /// In fr, this message translates to:
  /// **'La connexion sécurisée (https) au serveur a été refusée. Vérifiez la date et l\'heure de l\'appareil, puis réessayez.'**
  String get importSecureFailed;

  /// No description provided for @importLastStep.
  ///
  /// In fr, this message translates to:
  /// **'Dernière étape : {step}'**
  String importLastStep(String step);

  /// No description provided for @importVaultFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le coffre chiffré de l\'appareil ne fonctionne pas (erreur {cause}) : les identifiants de la playlist n\'ont pas pu être enregistrés ou relus.'**
  String importVaultFailed(String cause);

  /// No description provided for @importErrorDetail.
  ///
  /// In fr, this message translates to:
  /// **'Détail : {detail}'**
  String importErrorDetail(String detail);

  /// No description provided for @importUnrefined.
  ///
  /// In fr, this message translates to:
  /// **'Actualisation terminée, sans : {steps}.'**
  String importUnrefined(String steps);

  /// No description provided for @importRefineHomonyms.
  ///
  /// In fr, this message translates to:
  /// **'la séparation des séries homonymes'**
  String get importRefineHomonyms;

  /// No description provided for @importRefineVersions.
  ///
  /// In fr, this message translates to:
  /// **'le regroupement des versions'**
  String get importRefineVersions;

  /// No description provided for @importRefineSearch.
  ///
  /// In fr, this message translates to:
  /// **'l\'index de recherche'**
  String get importRefineSearch;

  /// No description provided for @importStorageFull.
  ///
  /// In fr, this message translates to:
  /// **'L\'appareil n\'a plus assez de place pour enregistrer le catalogue. Libérez de l\'espace de stockage, puis réessayez.'**
  String get importStorageFull;

  /// No description provided for @importStorageFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'appareil n\'a pas pu enregistrer le catalogue (erreur SQLite {code}). Réessayez. Si l\'erreur revient, signalez-la avec ce code.'**
  String importStorageFailed(int code);

  /// No description provided for @importUnexpected.
  ///
  /// In fr, this message translates to:
  /// **'L\'import s\'est arrêté sur une erreur inattendue ({kind}). Réessayez. Si l\'erreur revient, signalez-la avec ce nom.'**
  String importUnexpected(String kind);

  /// No description provided for @importConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion au serveur…'**
  String get importConnecting;

  /// No description provided for @importReceivingChannels.
  ///
  /// In fr, this message translates to:
  /// **'Réception des chaînes : {count} éléments reçus'**
  String importReceivingChannels(int count);

  /// No description provided for @importReceivingMovies.
  ///
  /// In fr, this message translates to:
  /// **'Réception des films : {count} éléments reçus'**
  String importReceivingMovies(int count);

  /// No description provided for @importReceivingSeries.
  ///
  /// In fr, this message translates to:
  /// **'Réception des séries : {count} éléments reçus'**
  String importReceivingSeries(int count);

  /// No description provided for @importIndexing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation du catalogue…'**
  String get importIndexing;

  /// No description provided for @importGuide.
  ///
  /// In fr, this message translates to:
  /// **'Catalogue prêt. Réception du guide des programmes…'**
  String get importGuide;

  /// No description provided for @importPartial.
  ///
  /// In fr, this message translates to:
  /// **'Actualisation incomplète. Non reçu : {sections}.'**
  String importPartial(String sections);

  /// No description provided for @importSectionChannels.
  ///
  /// In fr, this message translates to:
  /// **'chaînes'**
  String get importSectionChannels;

  /// No description provided for @importSectionMovies.
  ///
  /// In fr, this message translates to:
  /// **'films'**
  String get importSectionMovies;

  /// No description provided for @importSectionSeries.
  ///
  /// In fr, this message translates to:
  /// **'séries'**
  String get importSectionSeries;

  /// No description provided for @importFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'L\'actualisation a échoué'**
  String get importFailedTitle;

  /// No description provided for @entryConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get entryConfirm;

  /// No description provided for @entryShow.
  ///
  /// In fr, this message translates to:
  /// **'Afficher'**
  String get entryShow;

  /// No description provided for @entryHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get entryHide;

  /// No description provided for @entryCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get entryCancel;

  /// No description provided for @confirmDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get confirmDelete;

  /// No description provided for @confirmKeep.
  ///
  /// In fr, this message translates to:
  /// **'Conserver'**
  String get confirmKeep;

  /// No description provided for @homeResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get homeResume;

  /// No description provided for @homeRestart.
  ///
  /// In fr, this message translates to:
  /// **'Recommencer'**
  String get homeRestart;

  /// No description provided for @homeRemoveContinue.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer de Continuer à regarder'**
  String get homeRemoveContinue;

  /// No description provided for @playerVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version'**
  String get playerVersion;

  /// No description provided for @playerExternal.
  ///
  /// In fr, this message translates to:
  /// **'Lecteur externe'**
  String get playerExternal;

  /// No description provided for @playerExternalMissing.
  ///
  /// In fr, this message translates to:
  /// **'Aucun lecteur externe trouvé. Installez VLC ou mpv.'**
  String get playerExternalMissing;

  /// No description provided for @playerNoOtherVersion.
  ///
  /// In fr, this message translates to:
  /// **'Aucune autre version disponible'**
  String get playerNoOtherVersion;

  /// No description provided for @playerVersionMissing.
  ///
  /// In fr, this message translates to:
  /// **'Cet épisode n\'existe pas dans cette version'**
  String get playerVersionMissing;

  /// No description provided for @playerEndsAt.
  ///
  /// In fr, this message translates to:
  /// **'Fin à {time}'**
  String playerEndsAt(String time);

  /// No description provided for @playerFullscreen.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran'**
  String get playerFullscreen;

  /// No description provided for @playerExitFullscreen.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le plein écran'**
  String get playerExitFullscreen;

  /// No description provided for @playerMono.
  ///
  /// In fr, this message translates to:
  /// **'mono'**
  String get playerMono;

  /// No description provided for @playerStereo.
  ///
  /// In fr, this message translates to:
  /// **'stéréo'**
  String get playerStereo;

  /// No description provided for @playerSubtitlesTranslate.
  ///
  /// In fr, this message translates to:
  /// **'Traduire les sous-titres'**
  String get playerSubtitlesTranslate;

  /// No description provided for @playerSubtitlesLoaded.
  ///
  /// In fr, this message translates to:
  /// **'Sous-titres chargés'**
  String get playerSubtitlesLoaded;

  /// No description provided for @playerSubtitlesNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Cette source ne contient aucun sous-titre'**
  String get playerSubtitlesNotFound;

  /// No description provided for @playerSubtitlesFailed.
  ///
  /// In fr, this message translates to:
  /// **'Traduction des sous-titres impossible'**
  String get playerSubtitlesFailed;

  /// No description provided for @settingsSubtitleAppearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence des sous-titres'**
  String get settingsSubtitleAppearance;

  /// No description provided for @subtitlePreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get subtitlePreview;

  /// No description provided for @subtitleSample.
  ///
  /// In fr, this message translates to:
  /// **'On remonte avant la tempête.'**
  String get subtitleSample;

  /// No description provided for @subtitleSize.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get subtitleSize;

  /// No description provided for @subtitleFont.
  ///
  /// In fr, this message translates to:
  /// **'Police'**
  String get subtitleFont;

  /// No description provided for @subtitleColor.
  ///
  /// In fr, this message translates to:
  /// **'Couleur du texte'**
  String get subtitleColor;

  /// No description provided for @subtitleEdge.
  ///
  /// In fr, this message translates to:
  /// **'Contour'**
  String get subtitleEdge;

  /// No description provided for @subtitleBackground.
  ///
  /// In fr, this message translates to:
  /// **'Fond'**
  String get subtitleBackground;

  /// No description provided for @subtitleBackgroundOpacity.
  ///
  /// In fr, this message translates to:
  /// **'Opacité du fond'**
  String get subtitleBackgroundOpacity;

  /// No description provided for @subtitlePosition.
  ///
  /// In fr, this message translates to:
  /// **'Position'**
  String get subtitlePosition;

  /// No description provided for @subtitleReset.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir les réglages d\'origine'**
  String get subtitleReset;

  /// No description provided for @subtitleSizeSmall.
  ///
  /// In fr, this message translates to:
  /// **'Petite'**
  String get subtitleSizeSmall;

  /// No description provided for @subtitleSizeMedium.
  ///
  /// In fr, this message translates to:
  /// **'Moyenne'**
  String get subtitleSizeMedium;

  /// No description provided for @subtitleSizeLarge.
  ///
  /// In fr, this message translates to:
  /// **'Grande'**
  String get subtitleSizeLarge;

  /// No description provided for @subtitleSizeExtraLarge.
  ///
  /// In fr, this message translates to:
  /// **'Très grande'**
  String get subtitleSizeExtraLarge;

  /// No description provided for @subtitleFontStandard.
  ///
  /// In fr, this message translates to:
  /// **'Standard'**
  String get subtitleFontStandard;

  /// No description provided for @subtitleFontBold.
  ///
  /// In fr, this message translates to:
  /// **'Grasse'**
  String get subtitleFontBold;

  /// No description provided for @subtitleFontSerif.
  ///
  /// In fr, this message translates to:
  /// **'À empattements'**
  String get subtitleFontSerif;

  /// No description provided for @subtitleFontMonospace.
  ///
  /// In fr, this message translates to:
  /// **'Chasse fixe'**
  String get subtitleFontMonospace;

  /// No description provided for @subtitleColorWhite.
  ///
  /// In fr, this message translates to:
  /// **'Blanc'**
  String get subtitleColorWhite;

  /// No description provided for @subtitleColorYellow.
  ///
  /// In fr, this message translates to:
  /// **'Jaune'**
  String get subtitleColorYellow;

  /// No description provided for @subtitleColorCyan.
  ///
  /// In fr, this message translates to:
  /// **'Cyan'**
  String get subtitleColorCyan;

  /// No description provided for @subtitleColorGreen.
  ///
  /// In fr, this message translates to:
  /// **'Vert'**
  String get subtitleColorGreen;

  /// No description provided for @subtitleEdgeNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get subtitleEdgeNone;

  /// No description provided for @subtitleEdgeOutline.
  ///
  /// In fr, this message translates to:
  /// **'Contour noir'**
  String get subtitleEdgeOutline;

  /// No description provided for @subtitleEdgeShadow.
  ///
  /// In fr, this message translates to:
  /// **'Ombre'**
  String get subtitleEdgeShadow;

  /// No description provided for @subtitleBackgroundNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get subtitleBackgroundNone;

  /// No description provided for @subtitleBackgroundBlack.
  ///
  /// In fr, this message translates to:
  /// **'Noir'**
  String get subtitleBackgroundBlack;

  /// No description provided for @subtitleBackgroundGrey.
  ///
  /// In fr, this message translates to:
  /// **'Gris'**
  String get subtitleBackgroundGrey;

  /// No description provided for @subtitleBackgroundNavy.
  ///
  /// In fr, this message translates to:
  /// **'Bleu nuit'**
  String get subtitleBackgroundNavy;

  /// No description provided for @subtitleOpacityValue.
  ///
  /// In fr, this message translates to:
  /// **'{percent} %'**
  String subtitleOpacityValue(int percent);

  /// No description provided for @subtitlePositionBottom.
  ///
  /// In fr, this message translates to:
  /// **'En bas'**
  String get subtitlePositionBottom;

  /// No description provided for @subtitlePositionRaised.
  ///
  /// In fr, this message translates to:
  /// **'Un peu relevée'**
  String get subtitlePositionRaised;

  /// No description provided for @subtitlePositionHigher.
  ///
  /// In fr, this message translates to:
  /// **'Plus haut'**
  String get subtitlePositionHigher;

  /// No description provided for @subtitlePositionTop.
  ///
  /// In fr, this message translates to:
  /// **'En haut'**
  String get subtitlePositionTop;

  /// No description provided for @settingsDeepL.
  ///
  /// In fr, this message translates to:
  /// **'Clé DeepL (sous-titres traduits)'**
  String get settingsDeepL;

  /// No description provided for @settingsKeySet.
  ///
  /// In fr, this message translates to:
  /// **'Configurée'**
  String get settingsKeySet;

  /// No description provided for @settingsKeyUnset.
  ///
  /// In fr, this message translates to:
  /// **'Non configurée'**
  String get settingsKeyUnset;

  /// No description provided for @settingsKeyReplace.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer la clé'**
  String get settingsKeyReplace;

  /// No description provided for @settingsKeyRemove.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la clé'**
  String get settingsKeyRemove;

  /// No description provided for @versionSubtitled.
  ///
  /// In fr, this message translates to:
  /// **'sous-titré'**
  String get versionSubtitled;

  /// No description provided for @versionDubbed.
  ///
  /// In fr, this message translates to:
  /// **'doublé'**
  String get versionDubbed;

  /// No description provided for @homeInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get homeInfo;

  /// No description provided for @homeNoOverview.
  ///
  /// In fr, this message translates to:
  /// **'Aucune description disponible.'**
  String get homeNoOverview;

  /// No description provided for @settingsKeyGet.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir une clé'**
  String get settingsKeyGet;

  /// No description provided for @settingsKeyScan.
  ///
  /// In fr, this message translates to:
  /// **'Scannez ce code avec votre téléphone pour ouvrir la page {service}, puis saisissez votre clé ici.'**
  String settingsKeyScan(String service);

  /// No description provided for @playerServerAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Réponse du serveur : {answer}'**
  String playerServerAnswer(String answer);

  /// No description provided for @playerServerSilent.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur ne répond pas à ce flux.'**
  String get playerServerSilent;

  /// No description provided for @playerConnectionsFullTitle.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos connexions sont utilisées'**
  String get playerConnectionsFullTitle;

  /// No description provided for @playerConnectionsFullBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre abonnement limite le nombre de lectures simultanées. Arrêtez la lecture sur vos autres appareils ou applications, puis réessayez.'**
  String get playerConnectionsFullBody;

  /// No description provided for @playerConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion occupée, nouvel essai...'**
  String get playerConnecting;

  /// No description provided for @playerClose.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la lecture'**
  String get playerClose;

  /// No description provided for @playerSkipIntro.
  ///
  /// In fr, this message translates to:
  /// **'Passer l\'intro'**
  String get playerSkipIntro;

  /// No description provided for @playerNextEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Épisode suivant'**
  String get playerNextEpisode;

  /// No description provided for @playerSubtitlesLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Traduire les sous-titres en'**
  String get playerSubtitlesLanguage;

  /// No description provided for @playerSubtitlesImagesOnly.
  ///
  /// In fr, this message translates to:
  /// **'Les sous-titres de cette source sont des images : ils ne peuvent pas être traduits'**
  String get playerSubtitlesImagesOnly;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
