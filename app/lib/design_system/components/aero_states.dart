import 'package:flutter/widgets.dart';

import '../glass/glass_panel.dart';
import '../tokens/aero_tokens.dart';
import 'aero_button.dart';

/// Écran vide ou en erreur : il indique toujours quoi faire ensuite.
class AeroMessage extends StatelessWidget {
  const AeroMessage({
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.autofocus = true,
    this.focusNode,
    super.key,
  });

  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool autofocus;

  /// `autofocus` est sans effet si un autre nœud a déjà le focus : ce nœud
  /// permet alors à l'écran de le lui donner explicitement.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 560,
      child: GlassPanel(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AeroText.title, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 12),
              Text(body!, style: AeroText.body, textAlign: TextAlign.center),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              AeroButton(
                label: actionLabel!,
                onSelect: onAction,
                autofocus: autofocus,
                focusNode: focusNode,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Indication de chargement, sans animation : une icône qui tourne en continu
/// forcerait le rendu de chaque image pendant toute l'attente.
class AeroLoading extends StatelessWidget {
  const AeroLoading({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Text(label, style: AeroText.body),
    ),
  );
}
