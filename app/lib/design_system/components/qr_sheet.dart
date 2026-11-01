import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

import '../glass/glass_panel.dart';
import '../tokens/aero_tokens.dart';
import 'aero_button.dart';
import 'aero_menu.dart';

const double _sheetWidth = 460;
const double _codeSize = 280;

/// Marge blanche imposée par la norme, sans laquelle un lecteur peut échouer.
const int _quietModules = 4;

/// Montre une adresse en QR code, à ouvrir avec un téléphone.
Future<void> showQrSheet(
  BuildContext context, {
  required String title,
  required String hint,
  required String url,
  required String closeLabel,
}) => showAeroOverlay<void>(
  context,
  label: title,
  builder: (context) => Center(
    child: SizedBox(
      width: _sheetWidth,
      child: GlassPanel(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AeroText.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(hint, style: AeroText.body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            RepaintBoundary(
              child: CustomPaint(
                size: const Size.square(_codeSize),
                painter: QrPainter(url),
              ),
            ),
            const SizedBox(height: 12),
            Text(url, style: AeroText.caption, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AeroButton(
              label: closeLabel,
              autofocus: true,
              onSelect: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// Dessine le code en noir sur blanc : c'est ce que les lecteurs attendent, même
/// sur une interface sombre.
class QrPainter extends CustomPainter {
  QrPainter(this.data)
    : _image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
      );

  final String data;
  final QrImage _image;

  @override
  void paint(Canvas canvas, Size size) {
    final count = _image.moduleCount;
    final cell = size.shortestSide / (count + _quietModules * 2);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final dark = Paint()
      ..color = const Color(0xFF000000)
      ..isAntiAlias = false;
    for (var row = 0; row < count; row++) {
      for (var column = 0; column < count; column++) {
        if (!_image.isDark(row, column)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (column + _quietModules) * cell,
            (row + _quietModules) * cell,
            cell,
            cell,
          ),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(QrPainter oldDelegate) => oldDelegate.data != data;
}
