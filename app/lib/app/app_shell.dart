import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/components/aero_canvas.dart';
import '../design_system/glass/glass_panel.dart';
import '../design_system/tokens/aero_tokens.dart';
import '../features/home/screens/home_screen.dart';
import '../features/live_tv/screens/live_tv_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../focus/focus_frame.dart';
import '../focus/focus_guard.dart';
import '../focus/focusable.dart';
import 'aero_iptv_app.dart';
import 'app_state.dart';

const Size _barSize = Size(540, 92);

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

  @override
  void initState() {
    super.initState();
    ref.listenManual(activeSourceProvider.select((source) => source?.id), (
      _,
      id,
    ) {
      final source = ref.read(activeSourceProvider);
      if (id == null || source == null) return;
      unawaited(
        ref.read(importControllerProvider.notifier).refreshIfOutdated(source),
      );
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    for (final node in _tabNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Retour : l'onglet Accueil d'abord, puis la barre, et enfin la sortie.
  void _onBack(AppTab tab) {
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
          child: Column(
            children: [
              _TopBar(tab: tab, nodes: _tabNodes),
              Expanded(
                child: switch (tab) {
                  AppTab.home => const HomeScreen(),
                  AppTab.live => const LiveTvScreen(),
                  AppTab.search => const SearchScreen(),
                  AppTab.settings => const SettingsScreen(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.tab, required this.nodes});

  final AppTab tab;
  final Map<AppTab, FocusNode> nodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(importControllerProvider);
    final message = status.running || status.failure != null
        ? importMessage(l10n, status)
        : null;

    Widget item(AppTab target, String asset, String label) => _NavItem(
      asset: asset,
      label: label,
      selected: tab == target,
      focusNode: nodes[target]!,
      onSelect: () => ref.read(currentTabProvider.notifier).show(target),
    );

    return SizedBox(
      height: AeroMetrics.topBarHeight,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox.fromSize(
              size: _barSize,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AeroAssets.navBar),
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    item(AppTab.home, AeroAssets.navHome, l10n.navHome),
                    item(AppTab.live, AeroAssets.navLive, l10n.navLive),
                    item(AppTab.search, AeroAssets.navSearch, l10n.navSearch),
                    item(
                      AppTab.settings,
                      AeroAssets.navSettings,
                      l10n.navSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (message != null)
            PositionedDirectional(
              start: 20,
              top: 14,
              width: 250,
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

/// Icône de la barre. L'onglet ouvert reste identifiable quand le focus est
/// ailleurs, grâce à la lumière posée sous lui.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.asset,
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onSelect,
  });

  final String asset;
  final String label;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Focusable(
        focusNode: focusNode,
        onSelect: onSelect,
        scale: 1.08,
        halo: HaloShape.pill,
        builder: (context, focused) => SizedBox(
          width: 92,
          height: 62,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selected)
                const Image(
                  image: AssetImage(AeroAssets.navActive),
                  fit: BoxFit.fill,
                  width: 92,
                  height: 62,
                ),
              Image.asset(asset, width: 50, height: 50),
            ],
          ),
        ),
      ),
    ),
  );
}
