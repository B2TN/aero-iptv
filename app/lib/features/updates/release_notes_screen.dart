import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../app/app_state.dart';
import '../../design_system/components/aero_button.dart';
import '../../design_system/components/aero_canvas.dart';
import '../../design_system/components/markdown_text.dart';
import '../../design_system/glass/glass_panel.dart';
import '../../design_system/tokens/aero_tokens.dart';
import 'update_controller.dart';

/// Pas de défilement d'une flèche.
const double _scrollStep = 120;

/// Ouvre les notes de [release].
Future<void> openReleaseNotes(BuildContext context, AppRelease release) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => ReleaseNotesScreen(release: release),
      ),
    );

/// Notes d'une version, rendues depuis leur Markdown. Haut et Bas les font
/// défiler ; le focus reste sur les boutons.
class ReleaseNotesScreen extends ConsumerStatefulWidget {
  const ReleaseNotesScreen({required this.release, super.key});

  final AppRelease release;

  @override
  ConsumerState<ReleaseNotesScreen> createState() => _ReleaseNotesScreenState();
}

class _ReleaseNotesScreenState extends ConsumerState<ReleaseNotesScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => _scrollStep,
      LogicalKeyboardKey.arrowUp => -_scrollStep,
      _ => null,
    };
    if (step == null || !_scroll.hasClients) return KeyEventResult.ignored;
    final position = _scroll.position;
    _scroll.jumpTo((position.pixels + step).clamp(0, position.maxScrollExtent));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final release = widget.release;
    return AeroCanvas(
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Padding(
          padding: const EdgeInsets.all(AeroMetrics.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.updateNotesTitle('${release.version}'),
                style: AeroText.title,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GlassPanel(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: MarkdownText(release.notes),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  AeroButton(
                    label: l10n.updateInstall,
                    icon: Icons.system_update_alt_rounded,
                    tone: AeroTone.green,
                    autofocus: true,
                    onSelect: () {
                      Navigator.of(context).pop();
                      ref.read(updateControllerProvider.notifier).install();
                    },
                  ),
                  const SizedBox(width: 16),
                  AeroButton(
                    label: l10n.updateDismiss,
                    onSelect: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
