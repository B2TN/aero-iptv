// Dessine les textures de l'interface : le paysage du fond, ses nuages, les
// halos de focus et le cadre des cartes.
//
// Lancement depuis `app` : flutter test tool/render_aero_textures_test.dart
//
// Tout est calculé ici, une fois pour toutes, avec le moteur de rendu de
// Flutter. L'application ne fait qu'afficher ces images : aucun flou ni reflet
// n'est calculé à l'exécution pour les dessiner.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const String _root = 'assets/aero';

const Color _white = Color(0xFFFFFFFF);
const Color _foam = Color(0xFFEAF8FF);
const Color _aqua = Color(0xFF8FE4FF);
const Color _night = Color(0xFF020D1C);

Color _alpha(Color color, double alpha) => color.withValues(alpha: alpha);

Paint _linear(
  Rect rect,
  List<Color> colors, {
  Alignment begin = Alignment.topCenter,
  Alignment end = Alignment.bottomCenter,
  List<double>? stops,
}) => Paint()
  ..isAntiAlias = true
  ..shader = LinearGradient(
    begin: begin,
    end: end,
    colors: colors,
    stops: stops,
  ).createShader(rect);

Paint _radial(
  Rect rect,
  List<Color> colors, {
  Alignment center = Alignment.center,
  double radius = 0.5,
  List<double>? stops,
}) => Paint()
  ..isAntiAlias = true
  ..shader = RadialGradient(
    center: center,
    radius: radius,
    colors: colors,
    stops: stops,
  ).createShader(rect);

Paint _soft(Color color, double blur) => Paint()
  ..isAntiAlias = true
  ..color = color
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

Future<Uint8List> _render(
  int width,
  int height,
  void Function(Canvas canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData();
  picture.dispose();
  image.dispose();
  return data!.buffer.asUint8List();
}

img.Image _toImage(int width, int height, Uint8List rgba) =>
    img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

/// Le moteur rend en alpha prémultiplié, le PNG attend l'alpha direct.
///
/// Presque transparent, un pixel a perdu sa couleur dans les arrondis : il
/// prend alors [faint], au lieu d'une couleur au hasard qui ferait des
/// franges.
void _unpremultiply(Uint8List rgba, {List<int>? faint}) {
  for (var i = 0; i < rgba.length; i += 4) {
    final alpha = rgba[i + 3];
    if (alpha == 0 || alpha == 255) continue;
    if (faint != null && alpha < 24) {
      rgba.setRange(i, i + 3, faint);
      // Les traînes du flou, invisibles, ne voilent pas toute la bande.
      if (alpha < 3) rgba[i + 3] = 0;
      continue;
    }
    for (var c = 0; c < 3; c++) {
      rgba[i + c] = min(255, (rgba[i + c] * 255 / alpha).round());
    }
  }
}

/// Un léger grain évite les bandes visibles dans les dégradés.
void _dither(Uint8List rgba) {
  final random = Random(7);
  for (var i = 0; i < rgba.length; i += 4) {
    final grain = random.nextInt(3) - 1;
    for (var c = 0; c < 3; c++) {
      rgba[i + c] = (rgba[i + c] + grain).clamp(0, 255);
    }
  }
}

/// Dessine en unités logiques : le fichier fait [scale] fois cette taille.
Future<void> _png(
  String path,
  double width,
  double height,
  void Function(Canvas canvas) paint, {
  double scale = 2,
  List<int>? faint,
}) async {
  final pixelWidth = (width * scale).round();
  final pixelHeight = (height * scale).round();
  final rgba = await _render(pixelWidth, pixelHeight, (canvas) {
    canvas.scale(scale);
    paint(canvas);
  });
  _unpremultiply(rgba, faint: faint);
  File('$_root/$path')
    ..createSync(recursive: true)
    ..writeAsBytesSync(
      img.encodePng(_toImage(pixelWidth, pixelHeight, rgba), level: 9),
    );
}

// --- Paysage ----------------------------------------------------------------
//
// Une scène Frutiger Aero : un ciel clair, un soleil haut et ses reflets, des
// bulles de savon et des feuilles qui flottent, une ville de verre sur
// l'horizon, la mer qui scintille, puis, sous la coupe de l'eau, le monde
// sous-marin, ses rayons, ses bulles et ses poissons. La profondeur assombrit
// le bas de l'image : les rangées de cartes s'y lisent sans effort.

const double _skyWidth = 1920;
const double _skyHeight = 1080;

/// Horizon : pied de la ville et bord de la mer.
const double _horizon = 540;

/// Coupe de l'eau : au-dessus, l'air ; dessous, le monde sous-marin.
const double _waterline = 628;

/// Soleil haut, à droite : la lumière de la scène vient de lui.
const Offset _sun = Offset(1600, 140);

const Color _deep = Color(0xFF031F47);

/// Hauteur de la coupe de l'eau à l'abscisse [x] : une houle légère.
double _swell(double x) =>
    _waterline + 4 * sin(x / 88) + 2.2 * sin(x / 31 + 1.3);

/// Cumulus : une masse de boules, chacune éclairée du côté du soleil et
/// ombrée dessous, sur une base presque plate. [base] est le milieu de cette
/// base.
void _cumulus(
  Canvas canvas,
  Offset base,
  double width,
  double height,
  Random random, {
  double alpha = 1,
  Color light = _white,
  Color shade = const Color(0xFF9CB8DC),
  double bottomFade = 0.14,
}) {
  final bounds = Rect.fromLTRB(
    base.dx - width,
    base.dy - height * 2.2,
    base.dx + width,
    base.dy + height,
  );
  canvas.saveLayer(bounds, Paint()..color = _alpha(_white, alpha));
  final count = 16 + (width / 26).round();
  final puffs = <(Offset, double)>[];
  for (var k = 0; k < count; k++) {
    final u = random.nextDouble();
    // Plus grosses et plus hautes au milieu.
    final profile = pow(sin(u * pi), 0.8).toDouble();
    final radius =
        height * (0.16 + 0.3 * profile) * (0.7 + random.nextDouble() * 0.6);
    final rise =
        height * (0.12 + 0.78 * profile) * (0.7 + random.nextDouble() * 0.4);
    puffs.add((
      Offset(base.dx - width / 2 + u * width, base.dy - rise + radius * 0.85),
      radius,
    ));
  }
  // Du bas vers le haut : les boules du sommet recouvrent celles du dessous.
  puffs.sort((a, b) => b.$1.dy.compareTo(a.$1.dy));
  for (final (point, radius) in puffs) {
    final rect = Rect.fromCircle(center: point, radius: radius);
    canvas.drawCircle(
      point,
      radius,
      _radial(
        rect,
        [light, Color.lerp(light, shade, 0.3)!, shade],
        center: const Alignment(0.35, -0.5),
        radius: 0.95,
        stops: const [0, 0.55, 1],
      )..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.07 + 0.6),
    );
  }
  canvas
    ..drawRect(
      bounds,
      _linear(
        Rect.fromLTRB(
          bounds.left,
          base.dy - height * 0.06,
          bounds.right,
          base.dy + height * bottomFade,
        ),
        [_white, _alpha(_white, 0)],
      )..blendMode = BlendMode.dstIn,
    )
    ..restore();
}

/// Bulle de savon : un voile qui s'éclaire vers le bord, un liseré irisé et le
/// reflet du soleil.
void _bubble(Canvas canvas, Offset center, double radius, {double alpha = 1}) {
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas
    ..drawCircle(
      center,
      radius,
      _radial(
        rect,
        [
          _alpha(_white, 0),
          _alpha(_white, 0.05 * alpha),
          _alpha(_white, 0.26 * alpha),
        ],
        stops: const [0, 0.72, 1],
      ),
    )
    ..drawCircle(
      center,
      radius - radius * 0.03,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, radius * 0.06)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.02 + 0.4)
        ..shader = SweepGradient(
          colors: [
            _alpha(const Color(0xFF8FF3FF), 0.55 * alpha),
            _alpha(const Color(0xFFFFA8EA), 0.45 * alpha),
            _alpha(const Color(0xFFFFF3A6), 0.5 * alpha),
            _alpha(const Color(0xFFA6FFB8), 0.45 * alpha),
            _alpha(const Color(0xFF8FF3FF), 0.55 * alpha),
          ],
        ).createShader(rect),
    )
    ..drawCircle(
      center,
      radius,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _alpha(_white, 0.55 * alpha),
    )
    ..save()
    ..translate(center.dx + radius * 0.4, center.dy - radius * 0.42)
    ..rotate(0.7)
    ..drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 0.46,
        height: radius * 0.24,
      ),
      _soft(_alpha(_white, 0.9 * alpha), radius * 0.035 + 0.4),
    )
    ..restore()
    ..drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.8),
      1.95,
      1.1,
      false,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * 0.07
        ..color = _alpha(_white, 0.32 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.03 + 0.4),
    );
}

/// Petite étincelle à quatre branches.
void _sparkle(Canvas canvas, Offset center, double size, double alpha) {
  final paint = _soft(_alpha(_white, alpha), size * 0.06 + 0.3);
  for (final angle in [0.0, pi / 2]) {
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle)
      ..drawPath(
        Path()
          ..moveTo(-size, 0)
          ..lineTo(0, -size * 0.09)
          ..lineTo(size, 0)
          ..lineTo(0, size * 0.09)
          ..close(),
        paint,
      )
      ..restore();
  }
  canvas.drawCircle(
    center,
    size * 0.22,
    _soft(_alpha(_white, alpha), size * 0.2),
  );
}

/// Feuille verte et brillante, comme sur les fonds d'écran de l'époque.
void _leaf(Canvas canvas, Offset center, double length, double angle) {
  final width = length * 0.4;
  final shape = Path()
    ..moveTo(-length / 2, 0)
    ..quadraticBezierTo(-length * 0.08, -width, length / 2, 0)
    ..quadraticBezierTo(-length * 0.08, width, -length / 2, 0)
    ..close();
  final rect = Rect.fromCenter(
    center: Offset.zero,
    width: length,
    height: width * 2,
  );
  final vein = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..color = _alpha(const Color(0xFFEFFFCB), 0.75)
    ..strokeWidth = length * 0.022;
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(angle)
    ..drawPath(
      shape.shift(Offset(length * 0.05, length * 0.1)),
      _soft(_alpha(const Color(0xFF0B3B6E), 0.22), length * 0.08),
    )
    ..drawPath(
      shape,
      _linear(
        rect,
        const [Color(0xFFD4F98A), Color(0xFF74CF3E), Color(0xFF2C8A2B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    )
    ..drawLine(
      Offset(-length * 0.62, length * 0.04),
      Offset(length * 0.42, 0),
      vein,
    );
  vein
    ..strokeWidth = length * 0.012
    ..color = _alpha(const Color(0xFFEFFFCB), 0.4);
  for (var i = 1; i <= 4; i++) {
    final x = -length / 2 + i * length / 5.4;
    canvas
      ..drawLine(Offset(x, 0), Offset(x + length * 0.13, -width * 0.55), vein)
      ..drawLine(Offset(x, 0), Offset(x + length * 0.13, width * 0.55), vein);
  }
  canvas
    ..save()
    ..clipPath(shape)
    ..drawOval(
      Rect.fromLTWH(-length * 0.36, -width * 0.95, length * 0.62, width * 0.7),
      _soft(_alpha(_white, 0.4), length * 0.05),
    )
    ..restore()
    ..restore();
}

/// Ville de verre posée sur l'horizon, à droite, avec son reflet dans l'eau.
/// Rend la liste des tours, pour leurs reflets.
List<Rect> _city(Canvas canvas) {
  final random = Random(5);
  final towers = <Rect>[];
  // Deux rangs : les tours du fond, plus pâles, puis celles de devant.
  for (final front in [false, true]) {
    var x = front ? 1150.0 : 1110.0;
    while (x < _skyWidth + 20) {
      final width = 28 + random.nextDouble() * (front ? 46 : 36);
      // Plus hautes au cœur de la ville.
      final heart = exp(-pow((x - 1620) / 260, 2));
      final height =
          (front ? 40 : 70) +
          heart * (front ? 180 : 200) * (0.55 + random.nextDouble() * 0.5) +
          random.nextDouble() * 40;
      final rect = Rect.fromLTWH(x, _horizon - height, width, height);
      towers.add(rect);
      _tower(canvas, rect, random, far: !front);
      x += width * (0.75 + random.nextDouble() * 0.5);
    }
  }
  return towers;
}

void _tower(Canvas canvas, Rect rect, Random random, {required bool far}) {
  final glass = far
      ? const [Color(0xFFC6E6F8), Color(0xFF9CCDEE), Color(0xFF7DB8E4)]
      : const [Color(0xFFE4F5FF), Color(0xFF7FBDEB), Color(0xFF3F8CD2)];
  // Toit : plat, en flèche ou arrondi.
  final roof = random.nextInt(4);
  final body = Path()..addRect(rect);
  if (roof == 1) {
    body
      ..moveTo(rect.left + rect.width * 0.2, rect.top)
      ..lineTo(rect.center.dx, rect.top - rect.width * 0.9)
      ..lineTo(rect.right - rect.width * 0.2, rect.top)
      ..close();
  } else if (roof == 2) {
    body.addOval(
      Rect.fromCenter(
        center: rect.topCenter,
        width: rect.width,
        height: rect.width * 0.7,
      ),
    );
  }
  canvas
    ..save()
    ..clipPath(body)
    ..drawRect(
      body.getBounds(),
      // Le côté du soleil est le plus clair.
      _linear(
        rect,
        rect.center.dx < _sun.dx ? glass.reversed.toList() : glass,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    );
  // Étages et montants des vitres.
  final lines = Paint()
    ..color = _alpha(const Color(0xFF2F6FAE), far ? 0.07 : 0.13)
    ..strokeWidth = 1;
  for (var y = rect.top + 5; y < rect.bottom; y += far ? 5 : 7) {
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), lines);
  }
  lines.color = _alpha(_white, far ? 0.08 : 0.16);
  for (var x = rect.left + 6; x < rect.right; x += 9) {
    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), lines);
  }
  // Face à l'ombre, du côté opposé au soleil : la tour prend du volume.
  final shadeLeft = rect.center.dx < _sun.dx;
  canvas.drawRect(
    Rect.fromLTRB(
      shadeLeft ? rect.left : rect.right - rect.width * 0.3,
      rect.top - rect.width,
      shadeLeft ? rect.left + rect.width * 0.3 : rect.right,
      rect.bottom,
    ),
    Paint()..color = _alpha(const Color(0xFF1E5FA6), far ? 0.18 : 0.32),
  );
  // Reflet du ciel sur la façade.
  canvas
    ..drawRect(
      Rect.fromLTWH(
        rect.left + rect.width * 0.18,
        rect.top - rect.width,
        rect.width * 0.16,
        rect.height + rect.width,
      ),
      _soft(_alpha(_white, far ? 0.25 : 0.45), 1.5),
    )
    ..drawRect(
      body.getBounds(),
      _linear(rect, [_alpha(_white, 0.35), _alpha(_white, 0)])
        ..blendMode = BlendMode.srcOver,
    )
    ..restore();
}

/// Rive verte sous la ville, avec ses arbres ronds.
void _shore(Canvas canvas, double from, double to, Random random) {
  final bank = Path()..moveTo(from, _horizon + 2);
  for (var x = from; x <= to; x += 20) {
    bank.lineTo(x, _horizon - 3 - 3 * sin(x / 70));
  }
  bank
    ..lineTo(to, _horizon + 6)
    ..lineTo(from, _horizon + 6)
    ..close();
  canvas.drawPath(
    bank,
    _linear(Rect.fromLTRB(from, _horizon - 8, to, _horizon + 6), const [
      Color(0xFF8EDC54),
      Color(0xFF3E9A33),
    ]),
  );
  for (var x = from + 8; x < to; x += 9 + random.nextDouble() * 12) {
    final radius = 5 + random.nextDouble() * 9;
    final center = Offset(x, _horizon - radius * 0.7);
    canvas.drawCircle(
      center,
      radius,
      _radial(
        Rect.fromCircle(center: center, radius: radius),
        const [Color(0xFFB4EE6E), Color(0xFF4FAF3C), Color(0xFF2A7A30)],
        center: const Alignment(0.3, -0.5),
        radius: 0.95,
        stops: const [0, 0.5, 1],
      ),
    );
  }
}

/// Île lointaine à gauche, bleuie par la distance.
void _island(Canvas canvas) {
  final random = Random(9);
  final ground = Path()..moveTo(0, _horizon + 2);
  for (var x = 0.0; x <= 520; x += 10) {
    final rise = 46 * pow(sin(x / 520 * pi), 1.3) + 6 * sin(x / 23);
    ground.lineTo(x, _horizon - rise);
  }
  ground
    ..lineTo(520, _horizon + 2)
    ..close();
  canvas.drawPath(
    ground,
    _linear(Rect.fromLTRB(0, _horizon - 52, 520, _horizon), const [
      Color(0xFF8CC9B4),
      Color(0xFF5FA88F),
    ]),
  );
  // Quelques tours au loin, presque fondues dans la brume.
  for (var i = 0; i < 6; i++) {
    final width = 10 + random.nextDouble() * 12;
    final height = 30 + random.nextDouble() * 50;
    final x = 300 + i * 22.0 + random.nextDouble() * 8;
    canvas.drawRect(
      Rect.fromLTWH(x, _horizon - 40 - height, width, height + 20),
      _linear(
        Rect.fromLTWH(x, _horizon - 40 - height, width, height),
        const [Color(0xFFD2EEF9), Color(0xFFA9D6EE)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    );
  }
}

/// Mer vue de haut, de l'horizon à la coupe : reflets de la ville, scintillement
/// sous le soleil, rides de la houle.
void _sea(Canvas canvas, List<Rect> towers) {
  const band = Rect.fromLTRB(0, _horizon, _skyWidth, _waterline + 14);
  canvas
    ..save()
    ..clipRect(band)
    ..drawRect(
      band,
      _linear(
        band,
        const [Color(0xFFB3E6F8), Color(0xFF5FB8EA), Color(0xFF2690DB)],
        stops: const [0, 0.35, 1],
      ),
    );
  // Reflets des tours, brisés par la houle.
  final ripple = Random(17);
  for (final tower in towers) {
    final depth = tower.height * 0.45;
    for (var y = _horizon; y < _horizon + depth; y += 3) {
      final fade = 1 - (y - _horizon) / depth;
      canvas.drawRect(
        Rect.fromLTWH(
          tower.left + (ripple.nextDouble() - 0.5) * 6,
          y,
          tower.width,
          2,
        ),
        Paint()..color = _alpha(const Color(0xFFE8F7FF), 0.28 * fade),
      );
    }
  }
  // Colonne de lumière sous le soleil.
  canvas.drawRect(
    band,
    _linear(
      band,
      [_alpha(_white, 0), _alpha(_white, 0.45), _alpha(_white, 0)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      stops: [
        (_sun.dx - 260) / _skyWidth,
        _sun.dx / _skyWidth,
        (_sun.dx + 260) / _skyWidth,
      ],
    ),
  );
  // Rides et éclats : plus longs et plus vifs près de la coupe, et sous le
  // soleil.
  final glitter = Random(21);
  for (var i = 0; i < 1400; i++) {
    final near = pow(glitter.nextDouble(), 0.7).toDouble();
    final y = _horizon + near * (_waterline - _horizon + 10);
    final x = glitter.nextDouble() * _skyWidth;
    final sunny = exp(-pow((x - _sun.dx) / 200, 2));
    final length = (3 + glitter.nextDouble() * 26) * (0.35 + near);
    final alpha = (0.1 + glitter.nextDouble() * 0.25 + sunny * 0.6).clamp(
      0.0,
      0.95,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, y),
          width: length,
          height: 0.8 + near * 1.6,
        ),
        const Radius.circular(1),
      ),
      Paint()..color = _alpha(_white, alpha),
    );
  }
  for (var i = 0; i < 9; i++) {
    _sparkle(
      canvas,
      Offset(
        _sun.dx + (glitter.nextDouble() - 0.5) * 300,
        _horizon + 20 + glitter.nextDouble() * 60,
      ),
      8 + glitter.nextDouble() * 10,
      0.85,
    );
  }
  // Ligne claire de l'horizon.
  canvas
    ..drawRect(
      const Rect.fromLTWH(0, _horizon - 1, _skyWidth, 3),
      _soft(_alpha(_white, 0.6), 1.5),
    )
    ..restore();
}

/// Poisson tropical, tourné vers la gauche ou la droite.
void _fish(
  Canvas canvas,
  Offset center,
  double length, {
  required bool facingLeft,
  required bool yellow,
  required double depth,
}) {
  final h = length * 0.64;
  final l = length;
  final body = Path()
    ..moveTo(-l * 0.5, l * 0.02)
    ..cubicTo(-l * 0.42, -h * 0.58, l * 0.08, -h * 0.64, l * 0.33, -h * 0.08)
    ..lineTo(l * 0.33, h * 0.08)
    ..cubicTo(l * 0.08, h * 0.6, -l * 0.42, h * 0.5, -l * 0.5, l * 0.02)
    ..close();
  final tail = Path()
    ..moveTo(l * 0.28, 0)
    ..lineTo(l * 0.54, -h * 0.34)
    ..quadraticBezierTo(l * 0.46, 0, l * 0.54, h * 0.34)
    ..close();
  final dorsal = Path()
    ..moveTo(-l * 0.2, -h * 0.44)
    ..quadraticBezierTo(l * 0.08, -h * 0.82, l * 0.31, -h * 0.12)
    ..lineTo(l * 0.1, -h * 0.4)
    ..close();
  final anal = Path()
    ..moveTo(-l * 0.05, h * 0.42)
    ..quadraticBezierTo(l * 0.15, h * 0.7, l * 0.3, h * 0.12)
    ..close();
  final bounds = Rect.fromCenter(
    center: Offset.zero,
    width: l * 1.3,
    height: h * 2,
  );
  final colors = yellow
      ? const [Color(0xFFFFE45C), Color(0xFFF2B705)]
      : const [Color(0xFF4FA2FF), Color(0xFF1C4FC4)];
  final fin = yellow ? const Color(0xFFFFD23F) : const Color(0xFFFFD84A);
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..scale(facingLeft ? 1 : -1, 1)
    ..saveLayer(bounds, Paint())
    ..drawPath(tail, Paint()..color = _alpha(fin, 0.92))
    ..drawPath(dorsal, Paint()..color = _alpha(colors.last, 0.9))
    ..drawPath(anal, Paint()..color = _alpha(colors.last, 0.85))
    ..drawPath(body, _linear(bounds, colors))
    ..save()
    ..clipPath(body);
  if (yellow) {
    // Bande blanche derrière la tête, bande sombre sur l'œil.
    canvas
      ..drawRect(
        Rect.fromLTRB(-l * 0.3, -h, -l * 0.21, h),
        Paint()..color = _alpha(_white, 0.9),
      )
      ..drawRect(
        Rect.fromLTRB(-l * 0.39, -h, -l * 0.32, h),
        Paint()..color = const Color(0xFF1B1B24),
      )
      ..drawCircle(
        Offset(l * 0.16, h * 0.08),
        l * 0.05,
        Paint()..color = const Color(0xFF1B1B24),
      );
  } else {
    canvas.drawPath(
      Path()
        ..moveTo(-l * 0.3, -h * 0.2)
        ..quadraticBezierTo(l * 0.05, -h * 0.05, l * 0.3, -h * 0.3)
        ..quadraticBezierTo(l * 0.1, h * 0.12, -l * 0.3, -h * 0.2),
      Paint()..color = const Color(0xFF0E2766),
    );
  }
  canvas
    ..drawOval(
      Rect.fromLTWH(-l * 0.32, -h * 0.5, l * 0.5, h * 0.36),
      _soft(_alpha(_white, 0.38), l * 0.04),
    )
    ..restore()
    ..drawCircle(
      Offset(-l * 0.35, -h * 0.08),
      l * 0.045,
      Paint()..color = _white,
    )
    ..drawCircle(
      Offset(-l * 0.36, -h * 0.08),
      l * 0.027,
      Paint()..color = const Color(0xFF10131C),
    )
    // La profondeur bleuit et assombrit le poisson.
    ..drawRect(
      bounds,
      Paint()
        ..color = _alpha(const Color(0xFF0B4E92), depth * 0.6)
        ..blendMode = BlendMode.srcATop,
    )
    ..restore()
    ..restore();
}

void _underwater(Canvas canvas) {
  final surface = Path()..moveTo(0, _swell(0));
  for (var x = 0.0; x <= _skyWidth; x += 8) {
    surface.lineTo(x, _swell(x));
  }
  final water = Path.from(surface)
    ..lineTo(_skyWidth, _skyHeight)
    ..lineTo(0, _skyHeight)
    ..close();
  const deepRect = Rect.fromLTRB(0, _waterline - 10, _skyWidth, _skyHeight);
  canvas
    ..save()
    ..clipPath(water)
    ..drawRect(
      deepRect,
      _linear(
        deepRect,
        const [
          Color(0xFF1C93DA),
          Color(0xFF1279C4),
          Color(0xFF0A5AA6),
          Color(0xFF073C7C),
          _deep,
        ],
        stops: const [0, 0.14, 0.38, 0.66, 1],
      ),
    );

  // Rayons de lumière depuis la surface, penchés comme le soleil.
  final rays = Random(31);
  for (var i = 0; i < 10; i++) {
    final x = i * (_skyWidth + 300) / 10 + rays.nextDouble() * 120;
    final width = 30 + rays.nextDouble() * 110;
    final shaft = Path()
      ..moveTo(x, _waterline)
      ..lineTo(x + width, _waterline)
      ..lineTo(x + width - 210, _waterline + 430)
      ..lineTo(x - 260, _waterline + 430)
      ..close();
    canvas.drawPath(
      shaft,
      _linear(const Rect.fromLTWH(0, _waterline, 10, 430), [
        _alpha(_white, 0.1 + rays.nextDouble() * 0.12),
        _alpha(_white, 0),
      ])..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  // Réseau des reflets de la houle, juste sous la surface.
  final caustics = Random(41);
  for (var i = 0; i < 70; i++) {
    final y = _waterline + 10 + pow(caustics.nextDouble(), 1.8) * 150;
    final x0 = caustics.nextDouble() * _skyWidth - 100;
    final span = 160 + caustics.nextDouble() * 360;
    final wave = 30 + caustics.nextDouble() * 50;
    final amplitude = 4 + caustics.nextDouble() * 8;
    final line = Path()..moveTo(x0, y);
    for (var x = 0.0; x <= span; x += 6) {
      line.lineTo(x0 + x, y + amplitude * sin(x / wave + i));
    }
    final fade = 1 - (y - _waterline) / 170;
    canvas.drawPath(
      line,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + caustics.nextDouble()
        ..color = _alpha(_white, (0.06 + caustics.nextDouble() * 0.1) * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
  }

  // Fond marin : rochers, coraux et algues, presque noyés dans le bleu.
  final bed = Random(51);
  for (var i = 0; i < 26; i++) {
    final center = Offset(
      bed.nextDouble() * _skyWidth,
      _skyHeight - 10 + bed.nextDouble() * 30,
    );
    final radius = 40 + bed.nextDouble() * 90;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2.2, height: radius),
      _radial(Rect.fromCircle(center: center, radius: radius), const [
        Color(0xFF0E4A7E),
        Color(0xFF062A55),
      ], center: const Alignment(0.2, -0.6)),
    );
  }
  for (var i = 0; i < 40; i++) {
    final x = bed.nextDouble() * _skyWidth;
    final height = 50 + bed.nextDouble() * 110;
    final weed = Path()..moveTo(x, _skyHeight);
    for (var y = 0.0; y <= height; y += 6) {
      weed.lineTo(x + 7 * sin(y / 18 + i), _skyHeight - y);
    }
    canvas.drawPath(
      weed,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3 + bed.nextDouble() * 3
        ..color = _alpha(
          bed.nextBool() ? const Color(0xFF2E9C7A) : const Color(0xFF3FB27C),
          0.45,
        ),
    );
  }
  for (var i = 0; i < 7; i++) {
    _coral(
      canvas,
      Offset(bed.nextDouble() * _skyWidth, _skyHeight - 6),
      40 + bed.nextDouble() * 50,
      bed,
    );
  }

  // Poissons, sur les côtés.
  const school = [
    (Offset(210, 742), 74.0, false, true, 0.1),
    (Offset(330, 800), 52.0, false, false, 0.25),
    (Offset(150, 860), 44.0, false, true, 0.4),
    (Offset(1660, 720), 88.0, true, true, 0.05),
    (Offset(1790, 790), 58.0, true, false, 0.2),
    (Offset(1530, 846), 46.0, true, true, 0.35),
    (Offset(980, 900), 40.0, true, false, 0.55),
  ];
  for (final (center, length, left, yellow, depth) in school) {
    _fish(
      canvas,
      center,
      length,
      facingLeft: left,
      yellow: yellow,
      depth: depth,
    );
  }

  // Bulles qui montent.
  final bubbles = Random(61);
  for (final column in [120.0, 640.0, 1240.0, 1860.0]) {
    var y = _skyHeight - 40;
    while (y > _waterline + 16) {
      final radius = 2 + bubbles.nextDouble() * 9;
      _bubble(
        canvas,
        Offset(column + (bubbles.nextDouble() - 0.5) * 60, y),
        radius,
        alpha: 0.75,
      );
      y -= radius * 2 + 8 + bubbles.nextDouble() * 34;
    }
  }

  // Dessous de la surface, plus clair, puis la profondeur qui assombrit.
  canvas
    ..drawRect(
      const Rect.fromLTWH(0, _waterline - 8, _skyWidth, 34),
      _linear(const Rect.fromLTWH(0, _waterline - 8, _skyWidth, 34), [
        _alpha(_white, 0.32),
        _alpha(_white, 0),
      ]),
    )
    ..drawRect(
      const Rect.fromLTRB(0, _waterline + 90, _skyWidth, _skyHeight),
      _linear(
        const Rect.fromLTRB(0, _waterline + 90, _skyWidth, _skyHeight),
        [_alpha(_night, 0), _alpha(_night, 0.35), _alpha(_night, 0.72)],
        stops: const [0, 0.5, 1],
      ),
    )
    ..restore();

  // La coupe : un trait de lumière sur la houle.
  canvas
    ..drawPath(
      surface,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = _alpha(_white, 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    )
    ..drawPath(
      surface,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = _alpha(_white, 0.9),
    );
  // Gouttes au-dessus de la houle, à gauche.
  final drops = Random(71);
  for (var i = 0; i < 12; i++) {
    final x = 120 + drops.nextDouble() * 520;
    final center = Offset(x, _swell(x) - 6 - drops.nextDouble() * 34);
    _bubble(canvas, center, 2 + drops.nextDouble() * 4, alpha: 0.9);
  }
}

/// Corail en éventail, ses branches qui se divisent.
void _coral(Canvas canvas, Offset root, double size, Random random) {
  final color = [
    const Color(0xFFE07A8F),
    const Color(0xFFF2A65A),
    const Color(0xFFB57BE0),
  ][random.nextInt(3)];
  final paint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = _alpha(color, 0.5);
  void branch(Offset from, double angle, double length, int level) {
    final to = from + Offset(cos(angle) * length, sin(angle) * length);
    canvas.drawLine(from, to, paint..strokeWidth = 1.5 + level * 1.4);
    if (level == 0) return;
    branch(
      to,
      angle - 0.35 - random.nextDouble() * 0.2,
      length * 0.72,
      level - 1,
    );
    branch(
      to,
      angle + 0.35 + random.nextDouble() * 0.2,
      length * 0.72,
      level - 1,
    );
  }

  branch(root, -pi / 2, size * 0.42, 3);
}

void _sky(Canvas canvas) {
  const rect = Rect.fromLTWH(0, 0, _skyWidth, _skyHeight);
  canvas.drawRect(
    rect,
    _linear(
      const Rect.fromLTWH(0, 0, _skyWidth, _horizon),
      const [
        Color(0xFF0A5CC2),
        Color(0xFF1C80DE),
        Color(0xFF4BAEEE),
        Color(0xFF9CD9F7),
        Color(0xFFDDF5FD),
      ],
      stops: const [0, 0.3, 0.6, 0.85, 1],
    ),
  );

  // Halo du soleil, ses rayons croisés et son disque.
  canvas
    ..drawCircle(
      _sun,
      620,
      _radial(
        Rect.fromCircle(center: _sun, radius: 620),
        [
          _alpha(const Color(0xFFFFFBEA), 0.7),
          _alpha(const Color(0xFFE6F8FF), 0.25),
          _alpha(const Color(0xFFE6F8FF), 0),
        ],
        stops: const [0, 0.28, 1],
      ),
    )
    ..drawCircle(_sun, 120, _soft(_alpha(_white, 0.65), 40))
    ..drawCircle(_sun, 46, _soft(_white, 8));
  for (final (angle, length) in [
    (0.0, 520.0),
    (pi / 2, 360.0),
    (pi / 4, 220.0),
    (-pi / 4, 220.0),
  ]) {
    canvas
      ..save()
      ..translate(_sun.dx, _sun.dy)
      ..rotate(angle)
      ..drawOval(
        Rect.fromCenter(center: Offset.zero, width: length * 2, height: 5),
        _soft(_alpha(_white, 0.5), 3),
      )
      ..restore();
  }

  // Voiles de cirrus, très haut.
  final cirrus = Random(13);
  for (var i = 0; i < 9; i++) {
    final start = Offset(
      cirrus.nextDouble() * _skyWidth,
      40 + cirrus.nextDouble() * 170,
    );
    final length = 220 + cirrus.nextDouble() * 320;
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          start.dx + length / 2,
          start.dy - 18 - cirrus.nextDouble() * 20,
          start.dx + length,
          start.dy + 6,
        ),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5 + cirrus.nextDouble() * 9
        ..color = _alpha(_white, 0.16 + cirrus.nextDouble() * 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  // Grands cumulus derrière la ville et l'île.
  final clouds = Random(3);
  _cumulus(canvas, const Offset(1520, _horizon + 6), 820, 250, clouds);
  _cumulus(canvas, const Offset(520, _horizon + 4), 760, 170, clouds);
  _cumulus(
    canvas,
    const Offset(1040, _horizon + 8),
    420,
    110,
    clouds,
    alpha: 0.9,
  );
  _cumulus(canvas, const Offset(180, 330), 300, 90, clouds, alpha: 0.85);

  _island(canvas);
  final towers = _city(canvas);
  _shore(canvas, 1080, _skyWidth, Random(23));
  // Brume au pied de la ville : la distance se voit.
  canvas.drawRect(
    const Rect.fromLTRB(0, _horizon - 300, _skyWidth, _horizon),
    _linear(const Rect.fromLTRB(0, _horizon - 300, _skyWidth, _horizon), [
      _alpha(const Color(0xFFE8F8FF), 0),
      _alpha(const Color(0xFFE8F8FF), 0.2),
    ]),
  );
  _sea(canvas, towers);

  // Bulles de savon et feuilles qui flottent dans le ciel.
  for (final (center, radius) in const [
    (Offset(320, 196), 74.0),
    (Offset(470, 104), 34.0),
    (Offset(176, 300), 24.0),
    (Offset(830, 236), 50.0),
    (Offset(1010, 112), 28.0),
    (Offset(1200, 300), 20.0),
    (Offset(660, 380), 16.0),
  ]) {
    _bubble(canvas, center, radius);
  }
  _leaf(canvas, const Offset(408, 300), 78, -0.55);
  _leaf(canvas, const Offset(236, 128), 54, 0.85);
  _leaf(canvas, const Offset(910, 330), 40, 2.4);

  // Reflets du soleil dans l'objectif, sur la ligne qui mène au centre.
  const toward = Offset(960, 540);
  for (final (t, radius, color, alpha) in const [
    (0.32, 34.0, Color(0xFF9FF0FF), 0.16),
    (0.5, 14.0, Color(0xFFB7FFB0), 0.22),
    (0.68, 58.0, Color(0xFF8CC8FF), 0.09),
    (0.9, 22.0, Color(0xFFFFD9A0), 0.16),
    (1.15, 80.0, Color(0xFFBFE6FF), 0.07),
  ]) {
    final center = Offset.lerp(_sun, toward, t)!;
    canvas.drawCircle(
      center,
      radius,
      _soft(_alpha(color, alpha), radius * 0.15),
    );
  }
  canvas.drawCircle(
    Offset.lerp(_sun, toward, 0.78)!,
    44,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = _alpha(_white, 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );

  _underwater(canvas);

  // Le haut se fonce un peu, sous la barre de navigation.
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _skyWidth, 200),
    _linear(const Rect.fromLTWH(0, 0, _skyWidth, 200), [
      _alpha(_night, 0.28),
      _alpha(_night, 0),
    ]),
  );
}

Future<void> _writeSky() async {
  final width = _skyWidth.round();
  final height = _skyHeight.round();
  final rgba = await _render(width, height, _sky);
  _dither(rgba);
  File('$_root/backgrounds/sky.jpg')
    ..createSync(recursive: true)
    ..writeAsBytesSync(
      img.encodeJpg(
        _toImage(width, height, rgba).convert(numChannels: 3),
        quality: 90,
      ),
    );
}

/// Largeur et hauteur de la bande de nuages qui défile : elle se raccorde à
/// elle-même, bord droit contre bord gauche.
const double cloudBandWidth = 2400;
const double cloudBandHeight = 460;

/// Nuages qui passent devant le ciel, à demi-résolution : la bande pèse
/// quatre fois moins en mémoire, sans différence à l'écran.
Future<void> _cloudBand() => _png(
  'backgrounds/clouds.png',
  cloudBandWidth,
  cloudBandHeight,
  (canvas) {
    const band = Rect.fromLTWH(0, 0, cloudBandWidth, cloudBandHeight);
    canvas.saveLayer(band, Paint());
    final random = Random(11);
    const count = 7;
    for (var i = 0; i < count; i++) {
      final x = (i + 0.2 + random.nextDouble() * 0.6) * cloudBandWidth / count;
      final y = 170 + random.nextDouble() * 200;
      final width = 180 + random.nextDouble() * 200;
      final height = width * (0.32 + random.nextDouble() * 0.12);
      final seed = i * 7 + 3;
      // Trois copies : un nuage coupé par un bord reprend de l'autre côté.
      for (final shift in [-cloudBandWidth, 0.0, cloudBandWidth]) {
        _cumulus(
          canvas,
          Offset(x + shift, y),
          width,
          height,
          Random(seed),
          alpha: 0.78,
        );
      }
    }
    // Les bords haut et bas s'effacent : la bande n'a pas de limite visible.
    canvas
      ..drawRect(
        band,
        _linear(
          band,
          [_alpha(_white, 0), _white, _white, _alpha(_white, 0)],
          stops: const [0, 0.12, 0.85, 1],
        )..blendMode = BlendMode.dstIn,
      )
      ..restore();
  },
  scale: 0.5,
  faint: const [226, 236, 248],
);

/// Aperçu du fond, nuages compris, pour juger le rendu sans lancer l'app.
Future<void> _preview(String path) async {
  final width = _skyWidth.round();
  final height = _skyHeight.round();
  final codec = await ui.instantiateImageCodec(
    File('$_root/backgrounds/clouds.png').readAsBytesSync(),
  );
  final clouds = (await codec.getNextFrame()).image;
  final rgba = await _render(width, height, (canvas) {
    _sky(canvas);
    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(-300, 24, cloudBandWidth, cloudBandHeight),
      image: clouds,
      fit: BoxFit.fill,
    );
  });
  clouds.dispose();
  File(path).writeAsBytesSync(
    img.encodeJpg(
      _toImage(width, height, rgba).convert(numChannels: 3),
      quality: 85,
    ),
  );
}

// --- Focus et cartes -----------------------------------------------------------

/// Anneau lumineux d'un élément actif : un trait blanc net et un halo de ciel.
/// Le centre reste transparent.
void _halo(Canvas canvas, double size, double inset, double radius) {
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(inset, inset, size - inset * 2, size - inset * 2),
    Radius.circular(radius),
  );
  final outer = Path()
    ..addRect(Rect.fromLTWH(0, 0, size, size))
    ..addRRect(body)
    ..fillType = PathFillType.evenOdd;
  canvas
    ..save()
    ..clipPath(outer)
    ..drawRRect(body, _soft(_alpha(const Color(0xFF8ADCFF), 0.9), 8))
    ..drawRRect(body.inflate(1.5), _soft(_alpha(_white, 0.75), 2.5))
    ..restore()
    ..drawRRect(
      body.inflate(0.6),
      Paint()
        ..color = _white
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
}

Future<void> _focusHalos() async {
  await _png('focus/focus_halo.png', 96, 96, (canvas) {
    _halo(canvas, 96, 16, 14);
  });
  await _png('focus/focus_pill.png', 96, 96, (canvas) {
    _halo(canvas, 96, 16, 24);
  });
}

/// Cadre d'une carte : un liseré de verre et un reflet discret. Étiré entier :
/// toutes les cartes ont les mêmes proportions, et un seul dessin suffit.
Future<void> _cardFrame() => _png('chrome/card_frame.png', 140, 210, (canvas) {
  const rect = Rect.fromLTWH(0, 0, 140, 210);
  final shape = RRect.fromRectAndRadius(
    rect.deflate(0.5),
    const Radius.circular(12),
  );
  final sheen = Path()
    ..moveTo(0, 0)
    ..lineTo(118, 0)
    ..quadraticBezierTo(64, 50, 0, 82)
    ..close();
  canvas
    ..save()
    ..clipRRect(shape)
    ..drawPath(
      sheen,
      _linear(rect, [_alpha(_white, 0.11), _alpha(_white, 0.01)]),
    )
    ..restore()
    ..drawRRect(
      shape,
      _linear(rect, [_alpha(_foam, 0.42), _alpha(_aqua, 0.16)])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
});

Future<void> _chevron() => _png('icons/chevron.png', 22, 40, (canvas) {
  final path = Path()
    ..moveTo(15, 7)
    ..lineTo(6, 20)
    ..lineTo(15, 33);
  canvas
    ..drawPath(
      path,
      Paint()
        ..color = _alpha(_aqua, 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    )
    ..drawPath(
      path,
      Paint()
        ..color = _alpha(_foam, 0.95)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('textures', () async {
    final directory = Directory(_root);
    if (directory.existsSync()) directory.deleteSync(recursive: true);

    await _writeSky();
    await _cloudBand();
    await _focusHalos();
    await _cardFrame();
    await _chevron();
    final preview = Platform.environment['AERO_PREVIEW'];
    if (preview != null) await _preview(preview);

    var total = 0;
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      total += file.lengthSync();
    }
    // ignore: avoid_print
    print('Textures : ${total ~/ 1024} Ko');
  });
}
