import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../design_system/components/aero_button.dart';
import '../../../design_system/components/aero_canvas.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/subtitle_text.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../focus/focus_guard.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/setting_row.dart';

Future<void> openSubtitleAppearance(BuildContext context) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => const SubtitleAppearanceScreen(),
      ),
    );

/// Nom d'une taille de texte.
String subtitleSizeName(AppLocalizations l10n, SubtitleSize size) =>
    switch (size) {
      SubtitleSize.small => l10n.subtitleSizeSmall,
      SubtitleSize.medium => l10n.subtitleSizeMedium,
      SubtitleSize.large => l10n.subtitleSizeLarge,
      SubtitleSize.extraLarge => l10n.subtitleSizeExtraLarge,
    };

/// Nom d'une couleur de texte.
String subtitleColorName(AppLocalizations l10n, SubtitleColor color) =>
    switch (color) {
      SubtitleColor.white => l10n.subtitleColorWhite,
      SubtitleColor.yellow => l10n.subtitleColorYellow,
      SubtitleColor.cyan => l10n.subtitleColorCyan,
      SubtitleColor.green => l10n.subtitleColorGreen,
    };

/// Un réglage : son libellé, sa valeur affichée, et ses choix possibles.
typedef _Option = ({
  String label,
  String value,
  List<String> choices,
  int current,
  SubtitleStyle Function(SubtitleStyle style, int choice) apply,
});

/// Apparence des sous-titres, avec un aperçu qui suit chaque changement.
class SubtitleAppearanceScreen extends ConsumerStatefulWidget {
  const SubtitleAppearanceScreen({super.key});

  @override
  ConsumerState<SubtitleAppearanceScreen> createState() =>
      _SubtitleAppearanceScreenState();
}

class _SubtitleAppearanceScreenState
    extends ConsumerState<SubtitleAppearanceScreen> {
  final FocusNode _backNode = FocusNode(debugLabel: 'SubtitleBack');

  @override
  void dispose() {
    _backNode.dispose();
    super.dispose();
  }

  List<_Option> _options(AppLocalizations l10n, SubtitleStyle style) {
    String name<T extends Enum>(List<T> values, T value, List<String> names) =>
        names[values.indexOf(value)];
    final fonts = [
      l10n.subtitleFontStandard,
      l10n.subtitleFontBold,
      l10n.subtitleFontSerif,
      l10n.subtitleFontMonospace,
    ];
    final edges = [
      l10n.subtitleEdgeNone,
      l10n.subtitleEdgeOutline,
      l10n.subtitleEdgeShadow,
    ];
    final backgrounds = [
      l10n.subtitleBackgroundNone,
      l10n.subtitleBackgroundBlack,
      l10n.subtitleBackgroundGrey,
      l10n.subtitleBackgroundNavy,
    ];
    final positions = [
      l10n.subtitlePositionBottom,
      l10n.subtitlePositionRaised,
      l10n.subtitlePositionHigher,
      l10n.subtitlePositionTop,
    ];
    final opacities = [
      for (final percent in SubtitleStyle.opacities)
        l10n.subtitleOpacityValue(percent),
    ];
    return [
      (
        label: l10n.subtitleSize,
        value: subtitleSizeName(l10n, style.size),
        choices: [
          for (final size in SubtitleSize.values) subtitleSizeName(l10n, size),
        ],
        current: style.size.index,
        apply: (style, choice) =>
            style.copyWith(size: SubtitleSize.values[choice]),
      ),
      (
        label: l10n.subtitleFont,
        value: name(SubtitleFont.values, style.font, fonts),
        choices: fonts,
        current: style.font.index,
        apply: (style, choice) =>
            style.copyWith(font: SubtitleFont.values[choice]),
      ),
      (
        label: l10n.subtitleColor,
        value: subtitleColorName(l10n, style.color),
        choices: [
          for (final color in SubtitleColor.values)
            subtitleColorName(l10n, color),
        ],
        current: style.color.index,
        apply: (style, choice) =>
            style.copyWith(color: SubtitleColor.values[choice]),
      ),
      (
        label: l10n.subtitleEdge,
        value: name(SubtitleEdge.values, style.edge, edges),
        choices: edges,
        current: style.edge.index,
        apply: (style, choice) =>
            style.copyWith(edge: SubtitleEdge.values[choice]),
      ),
      (
        label: l10n.subtitleBackground,
        value: name(SubtitleBackground.values, style.background, backgrounds),
        choices: backgrounds,
        current: style.background.index,
        apply: (style, choice) =>
            style.copyWith(background: SubtitleBackground.values[choice]),
      ),
      (
        label: l10n.subtitleBackgroundOpacity,
        value: l10n.subtitleOpacityValue(style.backgroundOpacity),
        choices: opacities,
        current: SubtitleStyle.opacities.indexOf(style.backgroundOpacity),
        apply: (style, choice) =>
            style.copyWith(backgroundOpacity: SubtitleStyle.opacities[choice]),
      ),
      (
        label: l10n.subtitlePosition,
        value: name(SubtitlePosition.values, style.position, positions),
        choices: positions,
        current: style.position.index,
        apply: (style, choice) =>
            style.copyWith(position: SubtitlePosition.values[choice]),
      ),
    ];
  }

  void _save(SubtitleStyle style) => updateSettings(
    ref,
    (settings) => settings.copyWith(subtitleStyle: style),
  );

  Future<void> _choose(_Option option, SubtitleStyle style) async {
    final choice = await showAeroMenu(
      context,
      title: option.label,
      options: option.choices,
    );
    if (choice == null || !mounted) return;
    _save(option.apply(style, choice));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = ref.watch(
      settingsProvider.select((settings) => settings.subtitleStyle),
    );
    final options = _options(l10n, style);
    return FocusGuard(
      fallback: () => _backNode,
      child: AeroCanvas(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AeroButton(
                    label: l10n.actionBack,
                    focusNode: _backNode,
                    onSelect: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      l10n.settingsSubtitleAppearance,
                      style: AeroText.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 500,
                      child: GlassPanel(
                        padding: const EdgeInsets.all(12),
                        child: DpadCollection.vertical(
                          autofocus: true,
                          itemCount: options.length + 1,
                          itemExtent: 52,
                          padding: const EdgeInsets.all(4),
                          onSelect: (index) => index == options.length
                              ? _save(const SubtitleStyle())
                              : _choose(options[index], style),
                          itemBuilder: (context, index, focused) =>
                              index == options.length
                              ? SettingRow(
                                  label: l10n.subtitleReset,
                                  value: '',
                                  focused: focused,
                                )
                              : SettingRow(
                                  label: options[index].label,
                                  value: options[index].value,
                                  focused: focused,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.subtitlePreview, style: AeroText.heading),
                          const SizedBox(height: 10),
                          _Preview(
                            sample: _FixedText(l10n.subtitleSample),
                            style: style,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Réplique d'exemple, qui ne change jamais.
final class _FixedText implements ValueListenable<String> {
  const _FixedText(this.value);

  @override
  final String value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Image fixe, réduite, avec la réplique telle que le lecteur l'affichera.
class _Preview extends StatelessWidget {
  const _Preview({required this.sample, required this.style});

  final ValueListenable<String> sample;
  final SubtitleStyle style;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.all(Radius.circular(14)),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: FittedBox(
        child: SizedBox(
          width: AeroMetrics.canvas.width,
          height: AeroMetrics.canvas.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Un ciel au coucher du soleil sur la mer : clair en haut, sombre
              // en bas, pour juger le texte sur les deux.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF2C6E8E),
                      Color(0xFFE8A86A),
                      Color(0xFF3A2E48),
                      Color(0xFF1E2236),
                    ],
                    stops: [0, 0.6, 0.61, 1],
                  ),
                ),
              ),
              SubtitleLayer(text: sample, style: style),
            ],
          ),
        ),
      ),
    ),
  );
}
