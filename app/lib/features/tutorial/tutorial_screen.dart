import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_state.dart';
import '../../design_system/components/aero_button.dart';
import '../../design_system/components/aero_canvas.dart';
import '../../design_system/glass/glass_panel.dart';
import '../../design_system/tokens/aero_look.dart';
import '../../design_system/tokens/aero_tokens.dart';
import '../../focus/focus_guard.dart';
import '../../l10n/country_names.dart';
import '../../l10n/generated/app_localizations.dart';
import '../settings/playlist/playlist_editor_screen.dart';
import '../settings/settings_actions.dart';

/// Ouvre le tutoriel. Une fois fermé, terminé ou passé, il ne revient plus de
/// lui-même.
Future<void> openTutorial(BuildContext context) => Navigator.of(context).push(
  PageRouteBuilder<void>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => const TutorialScreen(),
  ),
);

/// Étapes du tutoriel, dans l'ordre.
enum TutorialStep {
  welcome,
  playlist,
  performance,
  controls,
  home,
  details,
  live,
  player,
  sync,
}

/// Ce qu'une étape montre : une explication, et pour celles qui font
/// configurer quelque chose, le réglage actuel et le bouton qui le change.
typedef _Page = ({
  IconData icon,
  String title,
  String body,
  ({String label, String value})? setting,
  ({String label, Future<void> Function() run})? action,
});

/// Tutoriel du premier lancement, relançable depuis les Paramètres : une étape
/// par écran, « Passer » toujours visible.
///
/// Retour revient à l'étape précédente, et ferme le tutoriel depuis la
/// première.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final FocusNode _skipNode = FocusNode(debugLabel: 'TutorialSkip');
  final FocusNode _previousNode = FocusNode(debugLabel: 'TutorialPrevious');
  final FocusNode _actionNode = FocusNode(debugLabel: 'TutorialAction');
  final FocusNode _nextNode = FocusNode(debugLabel: 'TutorialNext');
  int _index = 0;

  TutorialStep get _step => TutorialStep.values[_index];

  bool get _isLast => _index == TutorialStep.values.length - 1;

  /// Sans playlist, l'application n'a rien à montrer : l'étape qui en ajoute
  /// une met son bouton en avant. Tant que les playlists ne sont pas lues,
  /// rien ne presse.
  bool get _needsPlaylist =>
      _step == TutorialStep.playlist &&
      (ref.read(sourcesProvider).value?.isEmpty ?? false);

  @override
  void dispose() {
    _skipNode.dispose();
    _previousNode.dispose();
    _actionNode.dispose();
    _nextNode.dispose();
    super.dispose();
  }

  /// Le focus reste sur le même bouton d'une étape à l'autre, sauf si ce
  /// bouton disparaît, ou si l'étape attend une configuration.
  void _go(int index) {
    setState(() => _index = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nodes = [_skipNode, _previousNode, _actionNode, _nextNode];
      if (_needsPlaylist) {
        _actionNode.requestFocus();
      } else if (!nodes.any((node) => node.hasFocus)) {
        _nextNode.requestFocus();
      }
    });
  }

  void _back() => _index == 0 ? _close() : _go(_index - 1);

  void _close() {
    updateSettings(ref, (current) => current.copyWith(tutorialDone: true));
    Navigator.of(context).pop();
  }

  Future<void> _addPlaylist() async {
    await openPlaylistEditor(context, null);
    // La playlist ajoutée, la suite du tutoriel.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (ref.read(sourcesProvider).value ?? const []).isNotEmpty) {
        _nextNode.requestFocus();
      }
    });
  }

  _Page _page(AppLocalizations l10n) {
    final settings = ref.watch(settingsProvider);
    String onOff(bool value) => value ? l10n.settingsOn : l10n.settingsOff;
    switch (_step) {
      case TutorialStep.welcome:
        return (
          icon: Icons.waving_hand_rounded,
          title: l10n.tutorialWelcomeTitle,
          body: l10n.tutorialWelcomeBody,
          setting: (
            label: l10n.settingsLanguage,
            value:
                languageNames[settings.languageCode] ?? settings.languageCode,
          ),
          action: (
            label: l10n.tutorialChangeLanguage,
            run: () => chooseLanguage(context, ref),
          ),
        );
      case TutorialStep.playlist:
        final count = ref.watch(sourcesProvider).value?.length ?? 0;
        return (
          icon: Icons.playlist_add_rounded,
          title: l10n.tutorialPlaylistTitle,
          body: l10n.tutorialPlaylistBody,
          setting: (
            label: l10n.settingsPlaylists,
            value: l10n.settingsPlaylistCount(count),
          ),
          action: (label: l10n.actionAddPlaylist, run: _addPlaylist),
        );
      case TutorialStep.performance:
        final performance = ref.watch(lookProvider).isPerformance;
        final advice = ref.watch(smallDeviceProvider)
            ? l10n.tutorialPerformanceSmall
            : l10n.tutorialPerformanceLarge;
        return (
          icon: Icons.speed_rounded,
          title: l10n.tutorialPerformanceTitle,
          body: '${l10n.tutorialPerformanceBody}\n$advice',
          setting: (
            label: l10n.settingsPerformance,
            // Sans choix de l'utilisateur, l'appareil a décidé : on le dit.
            value: settings.performanceMode == null
                ? l10n.settingsPerformanceAuto(onOff(performance))
                : onOff(performance),
          ),
          action: (
            label: performance
                ? l10n.tutorialPerformanceOff
                : l10n.tutorialPerformanceOn,
            run: () async => updateSettings(
              ref,
              (current) => current.copyWith(performanceMode: !performance),
            ),
          ),
        );
      case TutorialStep.controls:
        return (
          icon: Icons.settings_remote_rounded,
          title: l10n.tutorialControlsTitle,
          body: l10n.tutorialControlsBody,
          setting: null,
          action: null,
        );
      case TutorialStep.home:
        return (
          icon: Icons.home_rounded,
          title: l10n.tutorialHomeTitle,
          body: l10n.tutorialHomeBody,
          setting: null,
          action: null,
        );
      case TutorialStep.details:
        return (
          icon: Icons.layers_rounded,
          title: l10n.tutorialDetailsTitle,
          body: l10n.tutorialDetailsBody,
          setting: null,
          action: null,
        );
      case TutorialStep.live:
        return (
          icon: Icons.live_tv_rounded,
          title: l10n.tutorialLiveTitle,
          body: l10n.tutorialLiveBody,
          setting: null,
          action: null,
        );
      case TutorialStep.player:
        final deepL = deepLKeyService(l10n);
        final hasKey = ref.watch(deepL.key) != null;
        return (
          icon: Icons.subtitles_rounded,
          title: l10n.tutorialPlayerTitle,
          body: l10n.tutorialPlayerBody,
          setting: (
            label: deepL.title,
            value: hasKey ? l10n.settingsKeySet : l10n.settingsKeyUnset,
          ),
          action: (
            label: hasKey ? l10n.settingsKeyReplace : l10n.tutorialAddKey,
            run: () => editApiKey(context, ref, deepL),
          ),
        );
      case TutorialStep.sync:
        return (
          icon: Icons.sync_rounded,
          title: l10n.tutorialSyncTitle,
          body: l10n.tutorialSyncBody,
          setting: null,
          action: null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Lues dès la première étape : celle de la playlist les connaît déjà.
    ref.watch(sourcesProvider);
    final page = _page(l10n);
    final count = TutorialStep.values.length;
    final needsPlaylist = _needsPlaylist;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: FocusGuard(
        fallback: () => _nextNode,
        child: AeroCanvas(
          child: Center(
            child: SizedBox(
              width: 820,
              child: GlassPanel(
                padding: const EdgeInsets.fromLTRB(36, 24, 36, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.tutorialStep(_index + 1, count),
                          style: AeroText.caption,
                        ),
                        const SizedBox(width: 16),
                        _StepDots(count: count, current: _index),
                        const Spacer(),
                        AeroButton(
                          label: l10n.tutorialSkip,
                          focusNode: _skipNode,
                          minWidth: 0,
                          onSelect: _close,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // Une hauteur commune : d'une étape à l'autre, la carte
                    // et ses boutons ne bougent pas.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 260),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StepIcon(icon: page.icon),
                          const SizedBox(width: 26),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(page.title, style: AeroText.title),
                                const SizedBox(height: 12),
                                Text(page.body, style: AeroText.body),
                                if (page.setting case final setting?) ...[
                                  const SizedBox(height: 18),
                                  _Setting(
                                    label: setting.label,
                                    value: setting.value,
                                  ),
                                ],
                                // Le bouton suit le réglage qu'il change.
                                if (page.action case final action?) ...[
                                  const SizedBox(height: 14),
                                  AeroButton(
                                    label: action.label,
                                    focusNode: _actionNode,
                                    tone: needsPlaylist
                                        ? AeroTone.green
                                        : AeroTone.blue,
                                    onSelect: () => unawaited(action.run()),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        if (_index > 0)
                          AeroButton(
                            label: l10n.tutorialPrevious,
                            focusNode: _previousNode,
                            onSelect: () => _go(_index - 1),
                          ),
                        const Spacer(),
                        AeroButton(
                          label: _isLast
                              ? l10n.tutorialFinish
                              : l10n.tutorialNext,
                          focusNode: _nextNode,
                          tone: needsPlaylist ? AeroTone.blue : AeroTone.green,
                          autofocus: true,
                          onSelect: _isLast ? _close : () => _go(_index + 1),
                        ),
                      ],
                    ),
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

/// Avancement : un point par étape, l'étape en cours allongée.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < count; index++)
        Container(
          width: index == current ? 22 : 8,
          height: 8,
          margin: const EdgeInsetsDirectional.only(end: 6),
          decoration: BoxDecoration(
            color: index <= current ? AeroColors.aqua : const Color(0x40EAF8FF),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ),
    ],
  );
}

/// Pastille de l'étape : une bulle d'eau en mode Aero, un disque plein en
/// mode Performance.
class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final performance = AeroLook.of(context).isPerformance;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: performance ? AeroColors.lagoon : null,
        gradient: performance
            ? null
            : const RadialGradient(
                center: Alignment(-0.35, -0.45),
                radius: 0.95,
                colors: [Color(0xFFDDF7FF), AeroColors.aqua, AeroColors.lagoon],
                stops: [0, 0.35, 1],
              ),
        border: Border.all(color: const Color(0x80EAF8FF), width: 1.5),
      ),
      child: Icon(icon, size: 42, color: AeroColors.abyss),
    );
  }
}

/// Réglage que l'étape fait configurer, et sa valeur actuelle.
class _Setting extends StatelessWidget {
  const _Setting({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0x33041A33),
      borderRadius: BorderRadius.all(Radius.circular(12)),
      border: Border.fromBorderSide(BorderSide(color: Color(0x40BFE6FA))),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Flexible(child: Text(label, style: AeroText.caption)),
          const SizedBox(width: 16),
          Text(
            value,
            style: AeroText.body.copyWith(
              color: AeroColors.leaf,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
