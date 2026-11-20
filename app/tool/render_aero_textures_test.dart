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

const double _skyWidth = 1920;
const double _skyHeight = 1080;

/// Soleil bas, à droite : la lumière du paysage vient de lui.
const Offset _sun = Offset(1480, 636);

/// Nuage cotonneux : des boules floues, ombrées dessous, éclairées dessus.
void _cloud(
  Canvas canvas,
  Offset center,
  double width,
  double height,
  double alpha,
  Random random, {
  Color shade = const Color(0xFF86A9D2),
  Color light = _white,
  double bottomFade = 0.22,
}) {
  const count = 11;
  // Base du nuage : le dessous d'un cumulus est presque plat.
  final base = center.dy + height * 0.3;
  final bounds = Rect.fromCenter(
    center: center,
    width: width + height * 3,
    height: height * 4,
  );
  canvas.saveLayer(bounds, Paint());
  final puffs = <(Offset, double)>[];
  for (var k = 0; k < count; k++) {
    final u = k / (count - 1);
    final radius =
        height *
        (0.32 + 0.48 * sin(u * pi)) *
        (0.8 + random.nextDouble() * 0.4);
    puffs.add((
      Offset(
        center.dx - width / 2 + u * width,
        center.dy +
            height * 0.25 -
            radius * 0.6 +
            (random.nextDouble() - 0.5) * height * 0.15,
      ),
      radius,
    ));
  }
  // L'ombre ne dépasse que dessous.
  for (final (point, radius) in puffs) {
    canvas.drawCircle(
      point.translate(0, radius * 0.3),
      radius * 0.78,
      _soft(_alpha(shade, alpha * 0.4), radius * 0.4),
    );
  }
  for (final (point, radius) in puffs) {
    canvas.drawCircle(
      point,
      radius * 0.9,
      _soft(_alpha(light, alpha * 0.85), radius * 0.4),
    );
  }
  for (final (point, radius) in puffs) {
    canvas.drawCircle(
      point.translate(radius * 0.12, -radius * 0.28),
      radius * 0.5,
      _soft(_alpha(_white, alpha * 0.55), radius * 0.35),
    );
  }
  canvas
    ..drawRect(
      bounds,
      _linear(
        Rect.fromLTRB(
          bounds.left,
          base - height * 0.12,
          bounds.right,
          base + height * bottomFade,
        ),
        [_white, _alpha(_white, 0)],
      )..blendMode = BlendMode.dstIn,
    )
    ..restore();
}

/// Crête d'une colline, de gauche à droite.
List<Offset> _ridge(
  double base,
  double amplitude,
  double frequency,
  double phase, {
  double tilt = 0,
}) => [
  for (var i = 0; i <= 120; i++)
    Offset(
      i / 120 * _skyWidth,
      base +
          amplitude * sin(i / 120 * pi * frequency + phase) +
          amplitude * 0.3 * sin(i / 120 * pi * frequency * 2.6 + phase * 1.7) +
          tilt * i / 120,
    ),
];

void _hill(
  Canvas canvas,
  List<Offset> ridge,
  List<Color> colors, {
  double rim = 0,
}) {
  final top = ridge.map((point) => point.dy).reduce(min);
  final body = Path()..moveTo(0, _skyHeight);
  for (final point in ridge) {
    body.lineTo(point.dx, point.dy);
  }
  body
    ..lineTo(_skyWidth, _skyHeight)
    ..close();
  final rect = Rect.fromLTRB(0, top, _skyWidth, _skyHeight);
  canvas.drawPath(body, _linear(rect, colors));
  if (rim == 0) return;
  // Lumière rasante sur la crête, plus vive du côté du soleil.
  final edge = Path()..moveTo(ridge.first.dx, ridge.first.dy);
  for (final point in ridge.skip(1)) {
    edge.lineTo(point.dx, point.dy);
  }
  canvas
    ..save()
    ..clipPath(body)
    ..drawPath(
      edge,
      _linear(
          Rect.fromLTRB(0, top, _skyWidth, top + 1),
          [
            _alpha(const Color(0xFFD8F7A8), rim * 0.2),
            _alpha(const Color(0xFFE6FBB8), rim),
            _alpha(const Color(0xFFD8F7A8), rim * 0.35),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0, 0.76, 1],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    )
    ..restore();
}

void _sky(Canvas canvas) {
  const rect = Rect.fromLTWH(0, 0, _skyWidth, _skyHeight);
  canvas.drawRect(
    rect,
    _linear(
      rect,
      const [
        Color(0xFF0A3784),
        Color(0xFF1A5FBE),
        Color(0xFF3A8CDB),
        Color(0xFF86CBF0),
        Color(0xFFCDEEF9),
      ],
      stops: const [0, 0.3, 0.48, 0.6, 0.66],
    ),
  );

  // Rayons qui partent du soleil, à peine visibles.
  final beams = Path();
  for (var i = 0; i < 7; i++) {
    final angle = pi + 0.3 + i * 0.36;
    const spread = 0.04;
    beams
      ..moveTo(_sun.dx, _sun.dy)
      ..lineTo(
        _sun.dx + cos(angle - spread) * 1800,
        _sun.dy + sin(angle - spread) * 1800,
      )
      ..lineTo(
        _sun.dx + cos(angle + spread) * 1800,
        _sun.dy + sin(angle + spread) * 1800,
      )
      ..close();
  }
  canvas.drawPath(
    beams,
    _radial(Rect.fromCircle(center: _sun, radius: 1400), [
      _alpha(_white, 0.07),
      _alpha(_white, 0),
    ])..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
  );

  // Halo du soleil, puis son disque.
  canvas
    ..drawCircle(
      _sun,
      980,
      _radial(
        Rect.fromCircle(center: _sun, radius: 980),
        [
          _alpha(const Color(0xFFFFF5D9), 0.62),
          _alpha(const Color(0xFFFFE6B0), 0.2),
          _alpha(const Color(0xFFFFE6B0), 0),
        ],
        stops: const [0, 0.32, 1],
      ),
    )
    ..drawCircle(_sun, 110, _soft(_alpha(_white, 0.55), 46))
    ..drawCircle(_sun, 42, _soft(_white, 9));

  // Bancs de nuages immobiles au-dessus de l'horizon, dorés près du soleil.
  final banks = Random(3);
  for (var i = 0; i < 8; i++) {
    final x = 100 + i * 250 + banks.nextDouble() * 90;
    final warm = 1 - ((x - _sun.dx).abs() / 900).clamp(0.0, 1.0);
    _cloud(
      canvas,
      Offset(x, 636 + banks.nextDouble() * 30),
      200 + banks.nextDouble() * 140,
      54 + banks.nextDouble() * 22,
      0.36,
      banks,
      shade: Color.lerp(
        const Color(0xFF7FA3CF),
        const Color(0xFFE0B98C),
        warm,
      )!,
      light: Color.lerp(_white, const Color(0xFFFFF1D2), warm)!,
      // Le dessous se fond dans la brume de l'horizon, sans trait.
      bottomFade: 0.9,
    );
  }

  _hill(canvas, _ridge(690, 16, 3.1, 0.4), const [
    Color(0xFF8DC3D9),
    Color(0xFF5E9CB9),
  ]);
  _hill(canvas, _ridge(742, 28, 2.2, 1.2), const [
    Color(0xFF59B07A),
    Color(0xFF2E7A57),
  ], rim: 0.5);
  _hill(canvas, _ridge(806, 40, 1.6, 2.6, tilt: -40), const [
    Color(0xFF43A052),
    Color(0xFF1C5C33),
  ], rim: 0.8);

  // Le bas s'assombrit : les rangées de cartes s'y lisent sans effort.
  const shade = Rect.fromLTRB(0, _skyHeight * 0.56, _skyWidth, _skyHeight);
  canvas
    ..drawRect(
      shade,
      _linear(
        shade,
        [
          _alpha(_night, 0),
          _alpha(_night, 0.5),
          _alpha(_night, 0.86),
          _alpha(_night, 0.97),
        ],
        stops: const [0, 0.32, 0.6, 1],
      ),
    )
    // Le haut se fonce un peu, sous la barre de navigation.
    ..drawRect(
      const Rect.fromLTWH(0, 0, _skyWidth, 220),
      _linear(const Rect.fromLTWH(0, 0, _skyWidth, 220), [
        _alpha(_night, 0.32),
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

/// Nuages flous : à demi-résolution, la bande pèse quatre fois moins en
/// mémoire, sans différence à l'écran.
Future<void> _cloudBand() => _png(
  'backgrounds/clouds.png',
  cloudBandWidth,
  cloudBandHeight,
  (canvas) {
    const band = Rect.fromLTWH(0, 0, cloudBandWidth, cloudBandHeight);
    canvas.saveLayer(band, Paint());
    final random = Random(11);
    const count = 9;
    for (var i = 0; i < count; i++) {
      final x = (i + random.nextDouble() * 0.5) * cloudBandWidth / count;
      final y = 110 + random.nextDouble() * 240;
      final width = 170 + random.nextDouble() * 170;
      final height = width * (0.3 + random.nextDouble() * 0.1);
      final alpha = 0.16 + random.nextDouble() * 0.14;
      final seed = i * 7 + 3;
      // Trois copies : un nuage coupé par un bord reprend de l'autre côté.
      for (final shift in [-cloudBandWidth, 0.0, cloudBandWidth]) {
        _cloud(
          canvas,
          Offset(x + shift, y),
          width,
          height,
          alpha,
          Random(seed),
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
          stops: const [0, 0.2, 0.8, 1],
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
