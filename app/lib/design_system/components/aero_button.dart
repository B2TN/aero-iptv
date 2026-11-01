import 'package:flutter/widgets.dart';

import '../../focus/focus_frame.dart';
import '../../focus/focusable.dart';
import '../tokens/aero_tokens.dart';

const Rect _pillSlice = Rect.fromLTRB(26, 22, 70, 26);

/// En dessous de ces tailles, les bords de la texture ne tiendraient plus.
const double _minWidth = 64;
const double _minHeight = 46;

/// Couleur du gel : le vert est réservé à l'action de lecture.
enum AeroTone {
  blue(AeroAssets.pillBlue, AeroAssets.pillBlueFocus),
  green(AeroAssets.pillGreen, AeroAssets.pillGreenFocus);

  const AeroTone(this.asset, this.focusAsset);

  final String asset;
  final String focusAsset;
}

/// Bouton en gel brillant, qui s'illumine quand il a le focus.
class AeroButton extends StatelessWidget {
  const AeroButton({
    required this.label,
    required this.onSelect,
    this.icon,
    this.image,
    this.tone = AeroTone.blue,
    this.minWidth = _minWidth,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    super.key,
  });

  final String label;
  final IconData? icon;

  /// Icône pré-rendue, à la place de [icon].
  final String? image;
  final AeroTone tone;
  final double minWidth;
  final VoidCallback? onSelect;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    final asset = image;
    return Focusable(
      onSelect: onSelect,
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      halo: HaloShape.pill,
      builder: (context, focused) => ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: _minHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(focused ? tone.focusAsset : tone.asset),
              centerSlice: _pillSlice,
              scale: AeroAssets.scale,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (asset != null)
                  Image.asset(asset, width: 28, height: 28)
                else if (icon != null)
                  Icon(icon, color: AeroColors.foam, size: 20),
                if ((asset != null || icon != null) && label.isNotEmpty)
                  const SizedBox(width: 10),
                if (label.isNotEmpty) Text(label, style: AeroText.body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
