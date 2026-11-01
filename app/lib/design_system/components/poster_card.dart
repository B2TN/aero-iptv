import 'package:flutter/widgets.dart';

import '../tokens/aero_tokens.dart';
import 'poster_image.dart';

const BorderRadius _radius = BorderRadius.all(Radius.circular(10));
const BorderRadius _trackRadius = BorderRadius.all(Radius.circular(4));

/// Affiche de film ou de série, sous un cadre de verre pré-rendu.
class PosterCard extends StatelessWidget {
  const PosterCard({
    required this.title,
    required this.imageUrl,
    this.focused = false,
    this.progress,
    this.progressColor = AeroColors.progressStart,
    super.key,
  });

  final String title;
  final String? imageUrl;
  final bool focused;

  /// Avancement de la lecture, de 0 à 1.
  final double? progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    final fraction = progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: _radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PosterImage(
                  url: imageUrl,
                  decodeWidth: 240,
                  placeholder: _Placeholder(title: title),
                ),
                const IgnorePointer(
                  child: Image(
                    image: AssetImage(AeroAssets.cardFrame),
                    fit: BoxFit.fill,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (fraction != null) ...[
          const SizedBox(height: 5),
          _ProgressTrack(fraction: fraction, color: progressColor),
        ],
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            title,
            style: AeroText.caption.copyWith(
              color: focused ? AeroColors.leaf : AeroColors.foam,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Barre d'avancement, posée dans une gouttière de verre.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 9,
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

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x66174470),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          title,
          style: AeroText.caption.copyWith(color: AeroColors.foam),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}
