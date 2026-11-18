import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../tokens/aero_tokens.dart';

const BorderRadius _trackRadius = BorderRadius.all(Radius.circular(4));

/// Barre d'avancement d'une lecture, posée dans une gouttière de verre.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    required this.fraction,
    this.color = AeroColors.progressStart,
    this.height = 9,
    super.key,
  });

  /// Avancement, de 0 à 1.
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x4004142B),
        borderRadius: _trackRadius,
        border: Border.all(color: const Color(0x4DBFE6FA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: _trackRadius,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Marque d'un contenu vu jusqu'au bout.
class WatchedMark extends StatelessWidget {
  const WatchedMark({required this.label, this.size = 22, super.key});

  /// Lu par les lecteurs d'écran : « Vu ».
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.check_circle_rounded,
    color: AeroColors.leaf,
    size: size,
    semanticLabel: label,
  );
}
