import 'package:flutter/widgets.dart';

import '../tokens/aero_look.dart';
import '../tokens/aero_tokens.dart';
import 'poster_image.dart';
import 'progress_track.dart';

const BorderRadius _radius = BorderRadius.all(Radius.circular(10));

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
    final performance = AeroLook.of(context).isPerformance;
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
                IgnorePointer(
                  child: performance
                      // Un simple filet, sans reflet de verre.
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: _radius,
                            border: Border.fromBorderSide(
                              BorderSide(color: PerformanceColors.panelBorder),
                            ),
                          ),
                        )
                      : const Image(
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
          ProgressTrack(fraction: fraction, color: progressColor),
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
