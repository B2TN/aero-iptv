import 'package:flutter/widgets.dart';

import '../glass/glass_panel.dart';
import '../tokens/aero_tokens.dart';
import 'aero_button.dart';
import 'aero_menu.dart';

/// Largeur d'une fiche d'information.
const double _sheetWidth = 620;

/// Fiche d'information par-dessus l'écran : un titre, des lignes « libellé,
/// valeur », des remarques, et un bouton pour la fermer. Retour la ferme
/// aussi.
Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  required String closeLabel,
  String? subtitle,
  List<(String, String)> rows = const [],
  List<String> notes = const [],
}) => showAeroOverlay<void>(
  context,
  label: title,
  builder: (context) => Center(
    child: SizedBox(
      width: _sheetWidth,
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AeroText.title),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: AeroText.caption),
            ],
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(label, style: AeroText.body)),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: AeroText.body.copyWith(color: AeroColors.aqua),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            for (final note in notes) ...[
              const SizedBox(height: 10),
              Text(note, style: AeroText.body),
            ],
            const SizedBox(height: 22),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AeroButton(
                label: closeLabel,
                autofocus: true,
                onSelect: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
