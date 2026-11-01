import 'package:flutter/widgets.dart';

import '../../../design_system/tokens/aero_tokens.dart';

/// Ligne de réglage : un libellé et sa valeur.
class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.label,
    required this.value,
    required this.focused,
    super.key,
  });

  final String label;
  final String value;
  final bool focused;

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
