import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/tokens/aero_tokens.dart';
import '../focus/dpad_shortcuts.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_shell.dart';
import 'app_state.dart';

/// Racine de l'application.
///
/// `WidgetsApp` remplace `MaterialApp` : l'interface n'utilise aucun composant
/// Material, et leurs thèmes occuperaient de la mémoire pour rien.
class AeroIptvApp extends ConsumerStatefulWidget {
  const AeroIptvApp({super.key});

  @override
  ConsumerState<AeroIptvApp> createState() => _AeroIptvAppState();
}

class _AeroIptvAppState extends ConsumerState<AeroIptvApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(
      settingsProvider.select((settings) => settings.languageCode),
    );
    return WidgetsApp(
      navigatorKey: _navigator,
      title: 'Aero IPTV',
      color: AeroColors.lagoon,
      debugShowCheckedModeBanner: false,
      textStyle: AeroText.body,
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      shortcuts: dpadShortcuts,
      actions: {
        ...WidgetsApp.defaultActions,
        BackIntent: CallbackAction<BackIntent>(
          onInvoke: (_) {
            _navigator.currentState?.maybePop();
            return null;
          },
        ),
      },
      home: const AppShell(),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => builder(context),
      ),
    );
  }
}

/// Quitte l'application depuis l'accueil.
void closeApplication() => SystemNavigator.pop();
