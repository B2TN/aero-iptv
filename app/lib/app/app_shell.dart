import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/components/aero_canvas.dart';
import '../design_system/glass/glass_panel.dart';
import '../design_system/tokens/aero_look.dart';
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
    final message = status.needsAttention ? importMessage(l10n, status) : null;

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
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: GlassPanel(
                padding: const EdgeInsets.all(7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    item(AppTab.home, Icons.home_rounded, l10n.navHome),
                    item(AppTab.live, Icons.live_tv_rounded, l10n.navLive),
                    item(AppTab.search, Icons.search_rounded, l10n.navSearch),
                    item(
                      AppTab.settings,
                      Icons.settings_rounded,
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

/// Onglet de la barre : un bouton rond, et l'onglet ouvert s'allonge pour
/// afficher son nom. Il reste ainsi identifiable quand le focus est ailleurs.
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

  BoxDecoration _decoration({required bool performance}) {
    if (selected) {
      return performance
          ? const BoxDecoration(
              color: AeroColors.leaf,
              borderRadius: BorderRadius.all(Radius.circular(26)),
            )
          : const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(26)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE9FFF2), AeroColors.leaf, Color(0xFF5CD993)],
                stops: [0, 0.55, 1],
              ),
              boxShadow: [BoxShadow(color: Color(0x738CF5B4), blurRadius: 18)],
            );
    }
    return performance
        ? const BoxDecoration(
            color: PerformanceColors.button,
            shape: BoxShape.circle,
          )
        : const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2E77BE), Color(0xFF154A80)],
            ),
            border: Border.fromBorderSide(BorderSide(color: Color(0x80EAF8FF))),
          );
  }

  @override
  Widget build(BuildContext context) {
    final performance = AeroLook.of(context).isPerformance;
    final ink = selected ? AeroColors.abyss : AeroColors.foam;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        child: Focusable(
          focusNode: focusNode,
          onSelect: onSelect,
          scale: 1.08,
          halo: HaloShape.pill,
          builder: (context, focused) => DecoratedBox(
            decoration: _decoration(performance: performance),
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 24, color: ink),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: AeroText.body.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
