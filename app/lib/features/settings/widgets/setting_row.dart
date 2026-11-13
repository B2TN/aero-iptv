import 'package:flutter/widgets.dart';

import '../../../design_system/tokens/aero_tokens.dart';

/// Ligne de réglage : un libellé et sa valeur.
class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.label,
    required this.value,
    required this.focused,
    this.toggled,
    super.key,
  });

  final String label;
  final String value;
  final bool focused;

  /// Réglage oui / non : un interrupteur s'affiche après la valeur.
  final bool? toggled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AeroText.heading.copyWith(
              color: focused ? AeroColors.leaf : AeroColors.foam,
              fontWeight: FontWeight.w300,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 16),
        if (toggled case final on?) ...[
          _Switch(on: on),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(
            value,
            style: AeroText.body.copyWith(color: AeroColors.aqua),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Interrupteur : vert et à droite quand le réglage est actif.
class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 26,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: on ? const Color(0xFF34C77B) : const Color(0x8C010A18),
        borderRadius: const BorderRadius.all(Radius.circular(13)),
        border: Border.all(color: const Color(0x4DEAF8FF)),
      ),
      child: Align(
        alignment: on
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: SizedBox.square(
            dimension: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AeroColors.foam,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
