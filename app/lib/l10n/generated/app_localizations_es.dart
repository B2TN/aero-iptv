// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navHome => 'Inicio';

  @override
  String get navLive => 'TV en directo';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get homeContinue => 'Seguir viendo';

  @override
  String get homeSeries => 'Series populares';

  @override
  String get homeMovies => 'Películas populares';

  @override
  String get homePlay => 'Reproducir';

  @override
  String get homeOpen => 'Abrir';

  @override
  String get emptyTitle => 'Añade tu primera lista';

  @override
  String get emptyBody =>
      'Basta una dirección M3U o una cuenta Xtream para encontrar tus canales, películas y series.';

  @override
  String get emptyCatalogTitle => 'Esta lista aún está vacía';

  @override
  String get emptyCatalogBody =>
      'Actualízala desde Ajustes para cargar su contenido.';

  @override
  String get actionAddPlaylist => 'Añadir una lista';

  @override
  String get actionOpenSettings => 'Abrir Ajustes';

  @override
  String get loading => 'Cargando';

  @override
  String get loadErrorTitle => 'No se pudo cargar el contenido';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionBack => 'Volver';

  @override
  String get liveChooseCountry => 'Elige un país';

  @override
  String get liveUnknownCountry => 'Otros';

  @override
  String get liveAllChannels => 'Todos los canales';

  @override
  String get liveNoChannels => 'No hay canales en este grupo';

  @override
  String get liveChooseStream => 'Elige una emisión';

  @override
  String liveStreamDefault(int number) {
    return 'Emisión $number';
  }

  @override
  String get searchPrompt => 'Busca una película o una serie';

  @override
  String get searchTrending => 'Tendencias';

  @override
  String get searchResults => 'Resultados';

  @override
  String searchNoResult(String query) {
    return 'Sin resultados para «$query»';
  }

  @override
  String get detailChooseVersion => 'Elige una versión';

  @override
  String detailSeason(int number) {
    return 'Temporada $number';
  }

  @override
  String detailEpisode(int number) {
    return 'Episodio $number';
  }

  @override
  String get detailNoEpisodes =>
      'No hay episodios disponibles para esta versión';

  @override
  String get playerFailedTitle => 'No se puede reproducir esta emisión';

  @override
  String get playerFailedBody =>
      'Puede que esté desconectada. Reinténtalo o elige otra emisión.';

  @override
  String get playerPlay => 'Reproducir';

  @override
  String get playerPause => 'Pausa';

  @override
  String get playerAudio => 'Audio';

  @override
  String get playerSubtitles => 'Subtítulos';

  @override
  String get playerSubtitlesOff => 'Desactivar';

  @override
  String playerTrack(int number) {
    return 'Pista $number';
  }

  @override
  String get playerLive => 'En directo';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsGroupSeries => 'Agrupar versiones de series';

  @override
  String get settingsGroupChannels => 'Agrupar calidades de canales';

  @override
  String get settingsDelay => 'Retraso de canales en directo';

  @override
  String settingsDelayValue(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds s',
      zero: 'Ninguno',
    );
    return '$_temp0';
  }

  @override
  String get settingsLanguage => 'Idioma de la aplicación';

  @override
  String get settingsPlaylists => 'Listas';

  @override
  String settingsPlaylistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listas',
      one: '1 lista',
      zero: 'Ninguna',
    );
    return '$_temp0';
  }

  @override
  String get settingsOn => 'Activado';

  @override
  String get settingsOff => 'Desactivado';

  @override
  String get settingsAttribution =>
      'Este producto utiliza la API de TMDB, pero no está avalado ni certificado por TMDB.';

  @override
  String get playlistsTitle => 'Listas';

  @override
  String get playlistNew => 'Nueva lista';

  @override
  String get playlistEdit => 'Editar la lista';

  @override
  String get playlistName => 'Nombre';

  @override
  String get playlistType => 'Tipo';

  @override
  String get playlistUrl => 'Dirección de la lista';

  @override
  String get playlistEpgUrl => 'Dirección de la guía XMLTV (opcional)';

  @override
  String get playlistServer => 'Dirección del servidor';

  @override
  String get playlistUsername => 'Usuario';

  @override
  String get playlistPassword => 'Contraseña';

  @override
  String get playlistCountry => 'País predeterminado';

  @override
  String get playlistCountryNone => 'Ninguno';

  @override
  String get playlistEmptyField => 'Sin definir';

  @override
  String get playlistSave => 'Guardar';

  @override
  String get playlistRefresh => 'Actualizar';

  @override
  String get playlistActivate => 'Usar esta lista';

  @override
  String get playlistActive => 'En uso';

  @override
  String get playlistDelete => 'Eliminar';

  @override
  String playlistDeleteConfirm(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get playlistMissingFields =>
      'Indica el nombre y la dirección antes de guardar.';

  @override
  String get playlistSynced => 'Actualizada';

  @override
  String get playlistNotSynced => 'Nunca actualizada';

  @override
  String importRunning(int count) {
    return 'Actualizando: $count elementos';
  }

  @override
  String get importDone => 'Actualización completada';

  @override
  String get importEpgFailed =>
      'Actualización completada, sin la guía de programas';

  @override
  String get importAuthFailed =>
      'Credenciales rechazadas. Compruébalas y reinténtalo.';

  @override
  String importAuthRejected(int code) {
    return 'El servidor ha rechazado el acceso (código $code). Comprueba el usuario, la contraseña y la dirección.';
  }

  @override
  String importServerFailed(int code) {
    return 'El servidor ha devuelto un error (código $code). Reinténtalo más tarde o prueba otra dirección.';
  }

  @override
  String get importNetworkFailed =>
      'Servidor inaccesible. Comprueba la dirección y reinténtalo.';

  @override
  String get importFormatFailed =>
      'El contenido recibido no es una lista válida.';

  @override
  String get importConnecting => 'Conectando con el servidor…';

  @override
  String importReceivingChannels(int count) {
    return 'Recibiendo canales: $count elementos recibidos';
  }

  @override
  String importReceivingMovies(int count) {
    return 'Recibiendo películas: $count elementos recibidos';
  }

  @override
  String importReceivingSeries(int count) {
    return 'Recibiendo series: $count elementos recibidos';
  }

  @override
  String get importIndexing => 'Preparando el catálogo…';

  @override
  String get importGuide =>
      'Catálogo listo. Recibiendo la guía de programación…';

  @override
  String importPartial(String sections) {
    return 'Actualización incompleta. No recibido: $sections.';
  }

  @override
  String get importSectionChannels => 'canales';

  @override
  String get importSectionMovies => 'películas';

  @override
  String get importSectionSeries => 'series';

  @override
  String get importFailedTitle => 'La actualización ha fallado';

  @override
  String get entryConfirm => 'Confirmar';

  @override
  String get entryShow => 'Mostrar';

  @override
  String get entryHide => 'Ocultar';

  @override
  String get entryCancel => 'Cancelar';

  @override
  String get confirmDelete => 'Eliminar';

  @override
  String get confirmKeep => 'Conservar';

  @override
  String get homeResume => 'Reanudar';

  @override
  String get homeRestart => 'Empezar de nuevo';

  @override
  String get homeRemoveContinue => 'Quitar de Seguir viendo';

  @override
  String get playerVersion => 'Versión';

  @override
  String get playerExternal => 'Reproductor externo';

  @override
  String get playerExternalMissing =>
      'No se ha encontrado ningún reproductor externo. Instala VLC o mpv.';

  @override
  String get playerNoOtherVersion => 'No hay otra versión disponible';

  @override
  String get playerVersionMissing => 'Este episodio no está en esa versión';

  @override
  String playerEndsAt(String time) {
    return 'Termina a las $time';
  }

  @override
  String get playerFullscreen => 'Pantalla completa';

  @override
  String get playerExitFullscreen => 'Salir de pantalla completa';

  @override
  String get playerMono => 'mono';

  @override
  String get playerStereo => 'estéreo';

  @override
  String get playerSubtitlesDownload => 'Descargar subtítulos';

  @override
  String get playerSubtitlesSearching => 'Buscando subtítulos...';

  @override
  String get playerSubtitlesLoaded => 'Subtítulos cargados';

  @override
  String get playerSubtitlesUntranslated =>
      'Subtítulos cargados en inglés: traducción no configurada';

  @override
  String get playerSubtitlesNotFound => 'Esta fuente no contiene subtítulos';

  @override
  String get playerSubtitlesFailed => 'No se pudieron descargar los subtítulos';

  @override
  String get settingsDeepL => 'Clave de DeepL (subtítulos traducidos)';

  @override
  String get settingsOpenSubtitles =>
      'Clave de OpenSubtitles (subtítulos completos)';

  @override
  String get settingsKeySet => 'Configurada';

  @override
  String get settingsKeyUnset => 'Sin configurar';

  @override
  String get settingsKeyReplace => 'Sustituir la clave';

  @override
  String get settingsKeyRemove => 'Eliminar la clave';

  @override
  String get versionSubtitled => 'subtitulado';

  @override
  String get versionDubbed => 'doblado';

  @override
  String get homeInfo => 'Información';

  @override
  String get homeNoOverview => 'No hay descripción disponible.';

  @override
  String get settingsKeyGet => 'Obtener una clave';

  @override
  String settingsKeyScan(String service) {
    return 'Escanee este código con su teléfono para abrir la página de $service y después introduzca su clave aquí.';
  }

  @override
  String playerServerAnswer(String answer) {
    return 'Respuesta del servidor: $answer';
  }

  @override
  String get playerServerSilent => 'El servidor no responde a este flujo.';

  @override
  String get playerConnectionsFullTitle => 'Todas sus conexiones están en uso';

  @override
  String get playerConnectionsFullBody =>
      'Su suscripción limita las reproducciones simultáneas. Detenga la reproducción en sus otros dispositivos o aplicaciones e inténtelo de nuevo.';

  @override
  String get playerConnecting => 'Conexión ocupada, reintentando...';

  @override
  String get playerClose => 'Salir de la reproducción';

  @override
  String get playerSkipIntro => 'Saltar intro';

  @override
  String get playerNextEpisode => 'Siguiente episodio';

  @override
  String get playerSubtitlesLanguage => 'Traducir los subtítulos a';

  @override
  String get playerSubtitlesImagesOnly =>
      'Los subtítulos de esta fuente son imágenes y no se pueden traducir';
}
