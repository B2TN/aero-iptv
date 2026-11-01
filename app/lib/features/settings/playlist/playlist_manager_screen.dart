import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../design_system/components/aero_button.dart';
import '../../../design_system/components/aero_canvas.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../focus/focus_guard.dart';
import '../widgets/setting_row.dart';
import 'playlist_editor_screen.dart';

Future<void> openPlaylistManager(BuildContext context) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => const PlaylistManagerScreen(),
      ),
    );

/// Liste des playlists.
class PlaylistManagerScreen extends ConsumerStatefulWidget {
  const PlaylistManagerScreen({super.key});

  @override
  ConsumerState<PlaylistManagerScreen> createState() =>
      _PlaylistManagerScreenState();
}

class _PlaylistManagerScreenState extends ConsumerState<PlaylistManagerScreen> {
  final FocusNode _addNode = FocusNode(debugLabel: 'AddPlaylist');

  @override
  void dispose() {
    _addNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sources =
        ref.watch(sourcesProvider).value ?? const <PlaylistSource>[];
    final active = ref.watch(activeSourceProvider);
    final status = importMessage(l10n, ref.watch(importControllerProvider));

    return FocusGuard(
      fallback: () => _addNode,
      child: AeroCanvas(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 160, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AeroButton(
                    label: l10n.actionBack,
                    onSelect: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(l10n.playlistsTitle, style: AeroText.title),
                  ),
                  AeroButton(
                    label: l10n.actionAddPlaylist,
                    focusNode: _addNode,
                    autofocus: sources.isEmpty,
                    onSelect: () => openPlaylistEditor(context, null),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: sources.isEmpty
                    ? const SizedBox.shrink()
                    : GlassPanel(
                        padding: const EdgeInsets.all(12),
                        child: DpadCollection.vertical(
                          autofocus: true,
                          itemCount: sources.length,
                          itemExtent: 64,
                          padding: const EdgeInsets.all(4),
                          onSelect: (index) =>
                              openPlaylistEditor(context, sources[index]),
                          itemBuilder: (context, index, focused) {
                            final source = sources[index];
                            return SettingRow(
                              label: source.name,
                              value: source.id == active?.id
                                  ? l10n.playlistActive
                                  : source.lastSyncedAt == null
                                  ? l10n.playlistNotSynced
                                  : l10n.playlistSynced,
                              focused: focused,
                            );
                          },
                        ),
                      ),
              ),
              if (status != null) ...[
                const SizedBox(height: 16),
                Text(status, style: AeroText.body),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
