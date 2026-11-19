import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_state.dart';
import '../../design_system/components/aero_button.dart';
import '../../design_system/glass/glass_panel.dart';
import '../../design_system/tokens/aero_tokens.dart';
import 'release_notes_screen.dart';
import 'update_controller.dart';

/// Bandeau d'une nouvelle version, en haut à droite : ses notes, l'installer,
/// ou le fermer jusqu'à la version suivante. Il se rejoint au D-pad par la
/// droite des onglets.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final update = ref.watch(updateControllerProvider);
    final release = update.release;
    if (release == null) return const SizedBox.shrink();
    final controller = ref.read(updateControllerProvider.notifier);
    final downloading = update.phase == UpdatePhase.downloading;
    final message = switch (update.phase) {
      UpdatePhase.offered => l10n.updateAvailable('${release.version}'),
      UpdatePhase.downloading => l10n.updateDownloading(
        ((update.progress ?? 0) * 100).round(),
      ),
      UpdatePhase.needsPermission => l10n.updatePermission,
      UpdatePhase.failed => l10n.updateFailed,
    };
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 7, 7, 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            // Sur deux lignes, pour laisser de la place aux onglets.
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              message,
              style: AeroText.caption.copyWith(color: AeroColors.foam),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!downloading) ...[
            const SizedBox(width: 10),
            Semantics(
              label: l10n.updateNotes,
              child: AeroButton(
                label: '',
                icon: Icons.info_outline_rounded,
                onSelect: () => openReleaseNotes(context, release),
              ),
            ),
            const SizedBox(width: 8),
            AeroButton(
              label: update.phase == UpdatePhase.offered
                  ? l10n.updateInstall
                  : l10n.actionRetry,
              tone: AeroTone.green,
              onSelect: controller.install,
            ),
            const SizedBox(width: 8),
            Semantics(
              label: l10n.updateDismiss,
              child: AeroButton(
                label: '',
                icon: Icons.close_rounded,
                onSelect: controller.dismiss,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
