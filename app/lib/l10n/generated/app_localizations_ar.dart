// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navLive => 'البث المباشر';

  @override
  String get navSearch => 'بحث';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get homeContinue => 'متابعة المشاهدة';

  @override
  String get homeSeries => 'المسلسلات الرائجة';

  @override
  String get homeMovies => 'الأفلام الرائجة';

  @override
  String get homePlay => 'تشغيل';

  @override
  String get homeOpen => 'فتح';

  @override
  String get emptyTitle => 'أضف قائمة التشغيل الأولى';

  @override
  String get emptyBody =>
      'يكفي عنوان M3U أو حساب Xtream للوصول إلى قنواتك وأفلامك ومسلسلاتك.';

  @override
  String get emptyCatalogTitle => 'قائمة التشغيل هذه فارغة حاليًا';

  @override
  String get emptyCatalogBody => 'حدّثها من الإعدادات لتحميل محتواها.';

  @override
  String get actionAddPlaylist => 'إضافة قائمة تشغيل';

  @override
  String get actionOpenSettings => 'فتح الإعدادات';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get loadErrorTitle => 'تعذّر تحميل المحتوى';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionBack => 'رجوع';

  @override
  String get liveChooseCountry => 'اختر بلدًا';

  @override
  String get liveUnknownCountry => 'أخرى';

  @override
  String get liveAllChannels => 'كل القنوات';

  @override
  String get liveNoChannels => 'لا توجد قنوات في هذه المجموعة';

  @override
  String get liveChooseStream => 'اختر بثًا';

  @override
  String liveStreamDefault(int number) {
    return 'بث $number';
  }

  @override
  String get searchPrompt => 'ابحث عن فيلم أو مسلسل';

  @override
  String get searchTrending => 'الرائج';

  @override
  String get searchResults => 'النتائج';

  @override
  String searchNoResult(String query) {
    return 'لا توجد نتائج عن «$query»';
  }

  @override
  String get detailChooseVersion => 'اختر نسخة';

  @override
  String detailSeason(int number) {
    return 'الموسم $number';
  }

  @override
  String detailEpisode(int number) {
    return 'الحلقة $number';
  }

  @override
  String get detailNoEpisodes => 'لا توجد حلقات متاحة لهذه النسخة';

  @override
  String detailResumeEpisode(int season, int episode) {
    return 'الموسم $season، الحلقة $episode';
  }

  @override
  String get detailResume => 'استئناف';

  @override
  String get detailPlay => 'تشغيل';

  @override
  String get detailPlayFromStart => 'تشغيل من البداية';

  @override
  String get playerFailedTitle => 'يتعذّر تشغيل هذا البث';

  @override
  String get playerFailedBody =>
      'قد يكون غير متصل. أعد المحاولة أو اختر بثًا آخر.';

  @override
  String get playerPlay => 'تشغيل';

  @override
  String get playerPause => 'إيقاف مؤقت';

  @override
  String get playerAudio => 'الصوت';

  @override
  String get playerSubtitles => 'الترجمة';

  @override
  String get playerSubtitlesOff => 'إيقاف';

  @override
  String playerTrack(int number) {
    return 'المسار $number';
  }

  @override
  String get playerLive => 'مباشر';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsGroupSeries => 'تجميع نسخ المسلسلات';

  @override
  String get settingsGroupChannels => 'تجميع جودات القنوات';

  @override
  String get settingsGroupMovies => 'تجميع نسخ الأفلام';

  @override
  String get settingsPerformance => 'وضع الأداء';

  @override
  String settingsPerformanceAuto(String state) {
    return 'تلقائي ($state)';
  }

  @override
  String get settingsDelay => 'تأخير القنوات المباشرة';

  @override
  String settingsDelayValue(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds ث',
      zero: 'بدون',
    );
    return '$_temp0';
  }

  @override
  String get settingsLanguage => 'لغة التطبيق';

  @override
  String get settingsPlaylists => 'قوائم التشغيل';

  @override
  String settingsPlaylistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      zero: 'لا شيء',
    );
    return '$_temp0';
  }

  @override
  String get settingsOn => 'مفعّل';

  @override
  String get settingsOff => 'معطّل';

  @override
  String get settingsAttribution =>
      'يستخدم هذا المنتج واجهة برمجة TMDB، لكنه غير معتمد أو موثّق من TMDB.';

  @override
  String get playlistsTitle => 'قوائم التشغيل';

  @override
  String get playlistNew => 'قائمة تشغيل جديدة';

  @override
  String get playlistEdit => 'تعديل قائمة التشغيل';

  @override
  String get playlistName => 'الاسم';

  @override
  String get playlistType => 'النوع';

  @override
  String get playlistUrl => 'عنوان قائمة التشغيل';

  @override
  String get playlistEpgUrl => 'عنوان دليل XMLTV (اختياري)';

  @override
  String get playlistServer => 'عنوان الخادم';

  @override
  String get playlistUsername => 'اسم المستخدم';

  @override
  String get playlistPassword => 'كلمة المرور';

  @override
  String get playlistCountry => 'البلد الافتراضي';

  @override
  String get playlistCountryNone => 'بدون';

  @override
  String get playlistEmptyField => 'غير محدد';

  @override
  String get playlistSave => 'حفظ';

  @override
  String get playlistRefresh => 'تحديث';

  @override
  String get playlistActivate => 'استخدام هذه القائمة';

  @override
  String get playlistActive => 'قيد الاستخدام';

  @override
  String get playlistDelete => 'حذف';

  @override
  String playlistDeleteConfirm(String name) {
    return 'هل تريد حذف «$name»؟';
  }

  @override
  String get playlistMissingFields => 'أدخل الاسم والعنوان قبل الحفظ.';

  @override
  String get playlistSaveFailedTitle => 'تعذّر الحفظ';

  @override
  String get playlistSynced => 'تم التحديث';

  @override
  String get playlistNotSynced => 'لم يتم التحديث بعد';

  @override
  String importRunning(int count) {
    return 'جارٍ التحديث: $count عنصر';
  }

  @override
  String get importDone => 'اكتمل التحديث';

  @override
  String get importEpgFailed => 'اكتمل التحديث بدون دليل البرامج';

  @override
  String get importAuthFailed =>
      'تم رفض بيانات الدخول. تحقق منها ثم أعد المحاولة.';

  @override
  String importAuthRejected(int code) {
    return 'رفض الخادم الوصول (الرمز $code). تحقق من اسم المستخدم وكلمة المرور والعنوان.';
  }

  @override
  String importServerFailed(int code) {
    return 'أعاد الخادم خطأً (الرمز $code). أعد المحاولة لاحقًا أو جرّب عنوانًا آخر.';
  }

  @override
  String get importNetworkFailed =>
      'تعذّر الوصول إلى الخادم. تحقق من العنوان ثم أعد المحاولة.';

  @override
  String get importFormatFailed => 'المحتوى المستلم ليس قائمة تشغيل صالحة.';

  @override
  String get importSecureFailed =>
      'رُفض الاتصال الآمن (https) بالخادم. تحقّق من تاريخ الجهاز ووقته ثم أعد المحاولة.';

  @override
  String importLastStep(String step) {
    return 'آخر مرحلة: $step';
  }

  @override
  String importVaultFailed(String cause) {
    return 'خزنة الجهاز المشفّرة لا تعمل (خطأ $cause): تعذّر حفظ بيانات الدخول لقائمة التشغيل أو قراءتها.';
  }

  @override
  String importErrorDetail(String detail) {
    return 'التفاصيل: $detail';
  }

  @override
  String importUnrefined(String steps) {
    return 'اكتمل التحديث، دون: $steps.';
  }

  @override
  String get importRefineHomonyms => 'فصل المسلسلات التي تحمل الاسم نفسه';

  @override
  String get importRefineVersions => 'تجميع النسخ اللغوية';

  @override
  String get importRefineSearch => 'فهرس البحث';

  @override
  String get importStorageFull =>
      'لم تعد في الجهاز مساحة كافية لحفظ الكتالوج. أفرغ بعض مساحة التخزين ثم أعد المحاولة.';

  @override
  String importStorageFailed(int code) {
    return 'تعذّر على الجهاز حفظ الكتالوج (خطأ SQLite $code). أعد المحاولة، وإذا تكرّر الخطأ فأبلغ عنه مع هذا الرمز.';
  }

  @override
  String importUnexpected(String kind) {
    return 'توقّف الاستيراد بسبب خطأ غير متوقّع ($kind). أعد المحاولة، وإذا تكرّر الخطأ فأبلغ عنه مع هذا الاسم.';
  }

  @override
  String get importConnecting => 'جارٍ الاتصال بالخادم…';

  @override
  String importReceivingChannels(int count) {
    return 'جارٍ استلام القنوات: تم استلام $count عنصرًا';
  }

  @override
  String importReceivingMovies(int count) {
    return 'جارٍ استلام الأفلام: تم استلام $count عنصرًا';
  }

  @override
  String importReceivingSeries(int count) {
    return 'جارٍ استلام المسلسلات: تم استلام $count عنصرًا';
  }

  @override
  String get importIndexing => 'جارٍ تجهيز الكتالوج…';

  @override
  String get importGuide => 'الكتالوج جاهز. جارٍ استلام دليل البرامج…';

  @override
  String importPartial(String sections) {
    return 'التحديث غير مكتمل. لم يتم استلام: $sections.';
  }

  @override
  String get importSectionChannels => 'القنوات';

  @override
  String get importSectionMovies => 'الأفلام';

  @override
  String get importSectionSeries => 'المسلسلات';

  @override
  String get importFailedTitle => 'فشل التحديث';

  @override
  String get entryConfirm => 'تأكيد';

  @override
  String get entryShow => 'إظهار';

  @override
  String get entryHide => 'إخفاء';

  @override
  String get entryCancel => 'إلغاء';

  @override
  String get confirmDelete => 'حذف';

  @override
  String get confirmKeep => 'الاحتفاظ';

  @override
  String get homeResume => 'استئناف';

  @override
  String get homeRestart => 'البدء من جديد';

  @override
  String get homeRemoveContinue => 'إزالة من متابعة المشاهدة';

  @override
  String get playerVersion => 'النسخة';

  @override
  String get playerExternal => 'مشغل خارجي';

  @override
  String get playerExternalMissing =>
      'لم يتم العثور على مشغل خارجي. ثبّت VLC أو mpv.';

  @override
  String get playerNoOtherVersion => 'لا توجد نسخة أخرى';

  @override
  String get playerVersionMissing => 'هذه الحلقة غير موجودة في هذه النسخة';

  @override
  String playerEndsAt(String time) {
    return 'ينتهي عند $time';
  }

  @override
  String get playerFullscreen => 'ملء الشاشة';

  @override
  String get playerExitFullscreen => 'إنهاء ملء الشاشة';

  @override
  String get playerMono => 'أحادي';

  @override
  String get playerStereo => 'ستيريو';

  @override
  String get playerSubtitlesTranslate => 'ترجمة الترجمة النصية';

  @override
  String get playerSubtitlesLoaded => 'تم تحميل الترجمة';

  @override
  String get playerSubtitlesNotFound => 'لا يحتوي هذا المصدر على عناوين فرعية';

  @override
  String get playerSubtitlesFailed => 'تعذّرت ترجمة الترجمة النصية';

  @override
  String get settingsSubtitleAppearance => 'مظهر الترجمة النصية';

  @override
  String get subtitlePreview => 'معاينة';

  @override
  String get subtitleSample => 'سنصعد قبل العاصفة.';

  @override
  String get subtitleSize => 'الحجم';

  @override
  String get subtitleFont => 'الخط';

  @override
  String get subtitleColor => 'لون النص';

  @override
  String get subtitleEdge => 'الحافة';

  @override
  String get subtitleBackground => 'الخلفية';

  @override
  String get subtitleBackgroundOpacity => 'شفافية الخلفية';

  @override
  String get subtitlePosition => 'الموضع';

  @override
  String get subtitleReset => 'استعادة الإعدادات الأصلية';

  @override
  String get subtitleSizeSmall => 'صغير';

  @override
  String get subtitleSizeMedium => 'متوسط';

  @override
  String get subtitleSizeLarge => 'كبير';

  @override
  String get subtitleSizeExtraLarge => 'كبير جدًا';

  @override
  String get subtitleFontStandard => 'عادي';

  @override
  String get subtitleFontBold => 'عريض';

  @override
  String get subtitleFontSerif => 'مذيّل';

  @override
  String get subtitleFontMonospace => 'ثابت العرض';

  @override
  String get subtitleColorWhite => 'أبيض';

  @override
  String get subtitleColorYellow => 'أصفر';

  @override
  String get subtitleColorCyan => 'سماوي';

  @override
  String get subtitleColorGreen => 'أخضر';

  @override
  String get subtitleEdgeNone => 'بلا';

  @override
  String get subtitleEdgeOutline => 'حافة سوداء';

  @override
  String get subtitleEdgeShadow => 'ظل';

  @override
  String get subtitleBackgroundNone => 'بلا';

  @override
  String get subtitleBackgroundBlack => 'أسود';

  @override
  String get subtitleBackgroundGrey => 'رمادي';

  @override
  String get subtitleBackgroundNavy => 'أزرق داكن';

  @override
  String subtitleOpacityValue(int percent) {
    return '$percent٪';
  }

  @override
  String get subtitlePositionBottom => 'في الأسفل';

  @override
  String get subtitlePositionRaised => 'أعلى قليلًا';

  @override
  String get subtitlePositionHigher => 'أعلى';

  @override
  String get subtitlePositionTop => 'في الأعلى';

  @override
  String get settingsDeepL => 'مفتاح DeepL (ترجمة الأسطر)';

  @override
  String get settingsKeySet => 'مهيأ';

  @override
  String get settingsKeyUnset => 'غير مهيأ';

  @override
  String get settingsKeyReplace => 'استبدال المفتاح';

  @override
  String get settingsKeyRemove => 'إزالة المفتاح';

  @override
  String get versionSubtitled => 'مترجم';

  @override
  String get versionDubbed => 'مدبلج';

  @override
  String get homeInfo => 'معلومات';

  @override
  String get homeNoOverview => 'لا يوجد وصف.';

  @override
  String get settingsKeyGet => 'الحصول على مفتاح';

  @override
  String settingsKeyScan(String service) {
    return 'امسح هذا الرمز بهاتفك لفتح صفحة $service، ثم أدخل مفتاحك هنا.';
  }

  @override
  String playerServerAnswer(String answer) {
    return 'رد الخادم: $answer';
  }

  @override
  String get playerServerSilent => 'الخادم لا يستجيب لهذا البث.';

  @override
  String get playerConnectionsFullTitle => 'جميع اتصالاتك قيد الاستخدام';

  @override
  String get playerConnectionsFullBody =>
      'يحدّ اشتراكك من عدد عمليات البث المتزامنة. أوقف التشغيل على أجهزتك أو تطبيقاتك الأخرى، ثم حاول مجدداً.';

  @override
  String get playerConnecting => 'الاتصال مشغول، جارٍ إعادة المحاولة...';

  @override
  String get playerClose => 'الخروج من التشغيل';

  @override
  String get playerSkipIntro => 'تخطي المقدمة';

  @override
  String get playerNextEpisode => 'الحلقة التالية';

  @override
  String get playerSubtitlesLanguage => 'ترجمة العناوين الفرعية إلى';

  @override
  String get playerSubtitlesImagesOnly =>
      'العناوين الفرعية لهذا المصدر صور ولا يمكن ترجمتها';
}
