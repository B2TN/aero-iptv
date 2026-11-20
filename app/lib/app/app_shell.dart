import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/components/aero_canvas.dart';
import '../design_system/glass/glass_panel.dart';
import '../design_system/tokens/aero_look.dart';
import '../design_system/tokens/aero_tokens.dart';
import '../features/home/screens/home_screen.dart';
import '../features/live_tv/providers/live_tv_providers.dart';
import '../features/live_tv/screens/live_tv_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/tutorial/tutorial_screen.dart';
import '../focus/focus_frame.dart';
import '../focus/focus_guard.dart';
import '../focus/focusable.dart';
import 'aero_iptv_app.dart';
import 'app_state.dart';
import '../features/updates/update_banner.dart';
import '../features/updates/update_controller.dart';
import 'daily_sync.dart';
import 'trends.dart';

/// Structure commune : barre supérieure et onglet actif.
///
/// Un seul onglet reste monté. `IndexedStack` garderait les images et les listes
/// de tous les onglets en mémoire, ce qu'un stick de 1 Go ne peut pas se
/// permettre. `FocusMemory` restitue la position au retour sur un onglet.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final Map<AppTab, FocusNode> _tabNodes = {
    for (final tab in AppTab.values) tab: FocusNode(debugLabel: tab.name),
  };

  /// Vrai le temps d'une image après Haut depuis le contenu : si le focus
  /// arrive alors sur la barre, il va à l'onglet affiché, et non à l'onglet
  /// voisin que la géométrie aurait choisi.
  bool _climbing = false;

  /// Synchronisation et tendances quotidiennes : retour au premier plan, et
  /// vérification de chaque heure, application ouverte.
  late final AppLifecycleListener _lifecycle;
  late final Timer _hourly;

  /// Le tutoriel ne se propose qu'une fois par lancement.
  bool _tutorialChecked = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusMoved);
    final daily = ref.read(dailySyncProvider.notifier);
    ref.listenManual(activeSourceProvider.select((source) => source?.id), (
      _,
      id,
    ) {
      final source = ref.read(activeSourceProvider);
      if (id == null || source == null) return;
      // De nouvelles règles réimportent tout ; sinon, la synchronisation du
      // jour, si elle n'a pas encore eu lieu.
      unawaited(
        ref
            .read(importControllerProvider.notifier)
            .refreshIfOutdated(source)
            .then((_) => daily.check(atLaunch: true)),
      );
    }, fireImmediately: true);
    final updates = ref.read(updateControllerProvider.notifier);
    // Nouvelle version : au lancement, puis toutes les 24 h.
    unawaited(updates.check());
    final trends = ref.read(trendsProvider.notifier);
    // Tendances : une fois les réglages lus, qui disent le pays.
    ref.listenManual(settingsReadyProvider, (_, ready) {
      if (ready) unawaited(trends.check());
    }, fireImmediately: true);
    // Nouvelle langue : les tendances sont redemandées dans cette langue.
    ref.listenManual(
      settingsProvider.select((settings) => settings.languageCode),
      (previous, language) {
        if (ref.read(settingsReadyProvider) && previous != language) {
          unawaited(trends.check());
        }
      },
    );
    ref.listenManual(
      tutorialDueProvider,
      (_, due) => _checkTutorial(due),
      fireImmediately: true,
    );
    _lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(daily.check());
        unawaited(updates.checkIfDue());
        unawaited(trends.check());
      },
    );
    _hourly = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(daily.check());
      unawaited(updates.checkIfDue());
      unawaited(trends.check());
    });
  }

  /// Le tutoriel s'ouvre à la première installation. Une installation déjà
  /// configurée ne le voit pas : il reste à relancer depuis les Paramètres.
  void _checkTutorial(bool? due) {
    if (due == null || _tutorialChecked) return;
    _tutorialChecked = true;
    if (!due) {
      if (!ref.read(settingsProvider).tutorialDone) {
        updateSettings(ref, (current) => current.copyWith(tutorialDone: true));
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(openTutorial(context));
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _hourly.cancel();
    FocusManager.instance.removeListener(_onFocusMoved);
    for (final node in _tabNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onContentKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _climbing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _climbing = false);
    }
    // La flèche poursuit son chemin : le déplacement reste celui d'origine.
    return KeyEventResult.ignored;
  }

  void _onFocusMoved() {
    if (!_climbing) return;
    _climbing = false;
    final primary = FocusManager.instance.primaryFocus;
    final selected = _tabNodes[ref.read(currentTabProvider)]!;
    if (primary != selected && _tabNodes.containsValue(primary)) {
      selected.requestFocus();
    }
  }

  /// Retour : ce qui est ouvert dans l'onglet, puis l'onglet Accueil, puis la
  /// barre, et enfin la sortie.
  void _onBack(AppTab tab) {
    // Dans les chaînes, un pays ouvert se referme sur la grille des pays.
    if (tab == AppTab.live && ref.read(selectedCountryProvider) != null) {
      ref.read(selectedCountryProvider.notifier).clear();
      return;
    }
    // Dans les Paramètres, les réglages rendent la main aux catégories.
    if (tab == AppTab.settings && ref.read(settingsPaneProvider)) {
      ref.read(settingsPaneProvider.notifier).close();
      return;
    }
    if (tab != AppTab.home) {
      ref.read(currentTabProvider.notifier).show(AppTab.home);
      _tabNodes[AppTab.home]!.requestFocus();
    } else if (_tabNodes.values.any((node) => node.hasFocus)) {
      closeApplication();
    } else {
      _tabNodes[AppTab.home]!.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(currentTabProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack(tab);
      },
      child: FocusGuard(
        fallback: () => _tabNodes[tab]!,
        child: AeroCanvas(
          child: Stack(
            children: [
              // La barre se pose sur le contenu : le grand visuel de l'accueil
              // monte jusqu'en haut de l'écran.
              Positioned.fill(
                top: tab == AppTab.home ? 0 : AeroMetrics.topBarHeight,
                child: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onKeyEvent: _onContentKey,
                  child: switch (tab) {
                    AppTab.home => const HomeScreen(),
                    AppTab.live => const LiveTvScreen(),
                    AppTab.search => const SearchScreen(),
                    AppTab.settings => const SettingsScreen(),
                  },
                ),
              ),
              // Le haut s'assombrit sous la barre : elle reste lisible quand
              // les rangées défilent dessous.
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 128,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xA6020D1C), Color(0x00020D1C)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _TopBar(tab: tab, nodes: _tabNodes),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barre de navigation : la marque, les onglets au centre, et à droite
/// l'heure ou la nouvelle version.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.tab, required this.nodes});

  final AppTab tab;
  final Map<AppTab, FocusNode> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(importControllerProvider);
    final message = status.needsAttention ? importMessage(l10n, status) : null;
    final update = ref.watch(
      updateControllerProvider.select((state) => state.release != null),
    );

    Widget item(AppTab target, IconData icon, String label) => _NavItem(
      icon: icon,
      label: label,
      selected: tab == target,
      focusNode: nodes[target]!,
      onSelect: () => ref.read(currentTabProvider.notifier).show(target),
    );

    return SizedBox(
      height: AeroMetrics.topBarHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const PositionedDirectional(
            start: AeroMetrics.pagePadding,
            top: 0,
            bottom: 0,
            child: _Brand(),
          ),
          Align(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                item(AppTab.home, Icons.home_rounded, l10n.navHome),
                item(AppTab.live, Icons.live_tv_rounded, l10n.navLive),
                item(AppTab.search, Icons.search_rounded, l10n.navSearch),
                item(AppTab.settings, Icons.settings_rounded, l10n.navSettings),
              ],
            ),
          ),
          PositionedDirectional(
            end: 20,
            top: update ? 12 : 0,
            bottom: update ? null : 0,
            child: update ? const UpdateBanner() : const _BarClock(),
          ),
          if (message != null)
            PositionedDirectional(
              start: AeroMetrics.pagePadding,
              top: AeroMetrics.topBarHeight - 6,
              width: 280,
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  message,
                  style: AeroText.caption.copyWith(color: AeroColors.foam),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Marque : une bulle de verre et le nom de l'application.
class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        width: 26,
        height: 26,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.35, -0.45),
              radius: 0.9,
              colors: [Color(0xFFFFFFFF), Color(0xFF8FE4FF), Color(0xFF1F6FC5)],
              stops: [0, 0.35, 1],
            ),
            border: Border.fromBorderSide(BorderSide(color: Color(0x99FFFFFF))),
            boxShadow: [BoxShadow(color: Color(0x668FE4FF), blurRadius: 10)],
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'Aero IPTV',
        style: AeroText.title.copyWith(fontSize: 20, letterSpacing: 0),
      ),
    ],
  );
}

/// Heure, à droite de la barre, remise à jour à chaque minute.
class _BarClock extends StatefulWidget {
  const _BarClock();

  @override
  State<_BarClock> createState() => _BarClockState();
}

class _BarClockState extends State<_BarClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer = Timer(Duration(seconds: 60 - DateTime.now().second), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return Center(
      child: Text(
        '${two(now.hour)}:${two(now.minute)}',
        style: AeroText.heading.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Onglet de la barre : son icône et son nom. L'onglet ouvert est souligné
/// d'un trait vert ; l'onglet qui a le focus devient une pastille blanche.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onSelect,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final performance = AeroLook.of(context).isPerformance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        child: Focusable(
          focusNode: focusNode,
          onSelect: onSelect,
          scale: 1.06,
          halo: HaloShape.pill,
          builder: (context, focused) {
            final ink = focused
                ? AeroColors.abyss
                : selected
                ? AeroColors.foam
                : AeroColors.mist;
            return DecoratedBox(
              decoration: focused
                  ? BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                      color: performance ? AeroColors.foam : null,
                      gradient: performance
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFFFFFF), Color(0xFFDCF1FF)],
                            ),
                    )
                  : const BoxDecoration(),
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 20, color: ink),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: AeroText.label.copyWith(
                              color: ink,
                              fontWeight: selected || focused
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (selected && !focused)
                        Positioned(
                          bottom: 2,
                          child: SizedBox(
                            width: 22,
                            height: 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AeroColors.leaf,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(2),
                                ),
                                boxShadow: performance
                                    ? null
                                    : const [
                                        BoxShadow(
                                          color: Color(0x999BEA7C),
                                          blurRadius: 8,
                                        ),
                                      ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
