import 'package:flutter/widgets.dart';

import '../../focus/dpad_collection.dart';
import '../glass/glass_panel.dart';
import '../tokens/aero_tokens.dart';
import 'aero_canvas.dart';

const double _rowHeight = 48;
const double _menuWidth = 440;
const int _visibleRows = 7;

/// Ouvre une fenêtre posée sur l'écran courant, qui garde le focus.
Future<T?> showAeroOverlay<T>(
  BuildContext context, {
  required String label,
  required WidgetBuilder builder,
}) => Navigator.of(context).push<T>(
  PageRouteBuilder<T>(
    opaque: false,
    barrierColor: AeroColors.veil,
    barrierDismissible: true,
    barrierLabel: label,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => AeroScale(child: builder(context)),
  ),
);

/// Petit menu de choix : flux d'une chaîne, version d'une série, langue...
///
/// Retourne l'index choisi, ou `null` si l'utilisateur fait retour.
Future<int?> showAeroMenu(
  BuildContext context, {
  required String title,
  required List<String> options,
}) => showAeroOverlay<int>(
  context,
  label: title,
  builder: (context) => _AeroMenu(title: title, options: options),
);

class _AeroMenu extends StatelessWidget {
  const _AeroMenu({required this.title, required this.options});

  final String title;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    final rows = options.length.clamp(1, _visibleRows);
    return Center(
      child: SizedBox(
        width: _menuWidth,
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AeroText.heading),
              const SizedBox(height: 14),
              SizedBox(
                height: rows * (_rowHeight + 8) + 8,
                child: DpadCollection.vertical(
                  autofocus: true,
                  itemCount: options.length,
                  itemExtent: _rowHeight,
                  padding: const EdgeInsets.all(4),
                  onSelect: (index) => Navigator.of(context).pop(index),
                  itemBuilder: (context, index, focused) =>
                      _MenuRow(label: options[index], focused: focused),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.focused});

  final String label;
  final bool focused;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        label,
        style: AeroText.body.copyWith(
          color: focused ? AeroColors.leaf : AeroColors.foam,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
