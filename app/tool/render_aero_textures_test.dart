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
import 'package:flutter/services.dart';
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
  String root = _root,
}) async {
  final pixelWidth = (width * scale).round();
  final pixelHeight = (height * scale).round();
  final rgba = await _render(pixelWidth, pixelHeight, (canvas) {
    canvas.scale(scale);
    paint(canvas);
  });
  _unpremultiply(rgba, faint: faint);
  File('$root/$path')
    ..createSync(recursive: true)
    ..writeAsBytesSync(
      img.encodePng(_toImage(pixelWidth, pixelHeight, rgba), level: 9),
    );
}

// --- Fond ---------------------------------------------------------------------
//
// Une aurore à la Frutiger Aero : un bleu profond, une grande lumière en haut
// à droite, des rubans de lumière satinés qui montent vers elle, et des points
// de lumière à plusieurs profondeurs. Abstrait, il laisse la vedette aux
// affiches et aux images des titres ; le bas s'assombrit sous les rangées.

const double _backWidth = 1920;
const double _backHeight = 1080;

/// Grande lumière, en haut à droite : les rubans montent vers elle.
const Offset _light = Offset(1440, 170);

/// Ruban de lumière satiné : des centaines de fils qui suivent la même courbe.
/// Là où il se resserre, il semble tourner sur lui-même et s'illumine.
void _ribbon(
  Canvas canvas, {
  required double Function(double u) center,
  required double Function(double u) width,
  required Color color,
  double alpha = 1,
  int threads = 90,
  double hotspot = 0.6,
}) {
  const from = -140.0;
  const to = _backWidth + 140;
  const steps = 160;
  List<Offset> line(double side) => [
    for (var i = 0; i <= steps; i++)
      Offset(
        from + i / steps * (to - from),
        center(i / steps) + side * width(i / steps) / 2,
      ),
  ];
  // Le ruban s'allume vers [hotspot] et s'éteint à ses deux bouts.
  Shader along(double strength, Color tint) => LinearGradient(
    colors: [
      _alpha(tint, 0),
      _alpha(tint, strength * 0.7),
      _alpha(Color.lerp(tint, _white, 0.6)!, strength),
      _alpha(tint, strength * 0.6),
      _alpha(tint, 0),
    ],
    stops: [0, hotspot - 0.32, hotspot, hotspot + 0.22, 1],
  ).createShader(const Rect.fromLTRB(from, 0, to, 1));

  final top = line(-1);
  final bottom = line(1);
  canvas.drawPath(
    Path()..addPolygon([...top, ...bottom.reversed], true),
    Paint()
      ..shader = along(0.2 * alpha, color)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
  );
  for (var t = 0; t < threads; t++) {
    final side = -1 + 2 * t / (threads - 1);
    // Plus clair vers l'arête du haut, avec des reflets en bandes.
    final shine =
        0.05 + 0.45 * pow((1 - side) / 2, 3) + 0.06 * (1 + sin(t * 0.7)) / 2;
    canvas.drawPath(
      Path()..addPolygon(line(side), false),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = along(shine * alpha, color),
    );
  }
  // Arête lumineuse du haut.
  final edge = Path()..addPolygon(top, false);
  canvas
    ..drawPath(
      edge,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..shader = along(0.35 * alpha, color)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    )
    ..drawPath(
      edge,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = along(0.9 * alpha, _white),
    );
}

/// Point de lumière flou, comme une lumière hors du champ de netteté. Les plus
/// grands gardent un liseré, comme une bulle de verre.
void _bokeh(
  Canvas canvas,
  Offset center,
  double radius,
  Color color,
  double alpha,
) {
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center,
    radius,
    _radial(
      rect,
      [
        _alpha(color, alpha * 0.5),
        _alpha(color, alpha * 0.75),
        _alpha(color, 0),
      ],
      stops: const [0, 0.8, 1],
    ),
  );
  if (radius > 14) {
    canvas.drawCircle(
      center,
      radius * 0.86,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06
        ..color = _alpha(_white, alpha * 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.04),
    );
  }
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
          ..lineTo(0, -size * 0.08)
          ..lineTo(size, 0)
          ..lineTo(0, size * 0.08)
          ..close(),
        paint,
      )
      ..restore();
  }
  canvas.drawCircle(
    center,
    size * 0.2,
    _soft(_alpha(_white, alpha), size * 0.2),
  );
}

/// Resserrement d'un ruban : nul aux points où il semble tourner, sans
/// cassure dans sa courbe.
double _twist(double angle) => cos(angle) * cos(angle);

/// Courbes des rubans, de gauche à droite, `u` allant de 0 à 1.
double _mainRibbon(double u) =>
    700 - 430 * u + 70 * sin(2 * pi * u * 0.85 + 0.5);
double _mainWidth(double u) =>
    150 * (0.12 + 0.88 * _twist(pi * u * 1.25 + 0.35));

void _aurora(Canvas canvas) {
  const rect = Rect.fromLTWH(0, 0, _backWidth, _backHeight);
  canvas
    ..drawRect(
      rect,
      _linear(
        rect,
        const [
          Color(0xFF0B4A93),
          Color(0xFF093F80),
          Color(0xFF072D5E),
          Color(0xFF021430),
        ],
        stops: const [0, 0.38, 0.68, 1],
      ),
    )
    // Grande lumière en haut à droite.
    ..drawCircle(
      _light,
      1150,
      _radial(
        Rect.fromCircle(center: _light, radius: 1150),
        [
          _alpha(const Color(0xFF8FE0FA), 0.72),
          _alpha(const Color(0xFF2E8EDB), 0.32),
          _alpha(const Color(0xFF2E8EDB), 0),
        ],
        stops: const [0, 0.3, 1],
      ),
    )
    ..drawCircle(_light, 200, _soft(_alpha(_white, 0.3), 80))
    // Reflet vert d'eau, en bas à gauche.
    ..drawCircle(
      const Offset(260, 820),
      760,
      _radial(Rect.fromCircle(center: const Offset(260, 820), radius: 760), [
        _alpha(const Color(0xFF2FC2A6), 0.26),
        _alpha(const Color(0xFF2FC2A6), 0),
      ]),
    );

  // Points de lumière lointains, très flous.
  final far = Random(4);
  for (var i = 0; i < 26; i++) {
    _bokeh(
      canvas,
      Offset(far.nextDouble() * _backWidth, far.nextDouble() * 760),
      40 + far.nextDouble() * 70,
      far.nextBool() ? const Color(0xFF9FE6FF) : const Color(0xFFBFF5E6),
      0.04 + far.nextDouble() * 0.05,
    );
  }

  // Rubans : un vert d'eau discret, un cyan, puis le grand ruban clair.
  _ribbon(
    canvas,
    center: (u) => 820 - 300 * u + 60 * sin(2 * pi * u * 0.8 + 3.6),
    width: (u) => 90 * (0.15 + 0.85 * _twist(pi * u * 1.6 + 1.2)),
    color: const Color(0xFF5FE0B4),
    alpha: 0.55,
    hotspot: 0.42,
    threads: 60,
  );
  _ribbon(
    canvas,
    center: (u) => 760 - 470 * u + 55 * sin(2 * pi * u * 1.1 + 2.0),
    width: (u) => 96 * (0.12 + 0.88 * _twist(pi * u * 1.4 + 2.2)),
    color: const Color(0xFF56C8F5),
    alpha: 0.75,
    hotspot: 0.7,
    threads: 70,
  );
  _ribbon(
    canvas,
    center: _mainRibbon,
    width: _mainWidth,
    color: const Color(0xFF8FE4FF),
    hotspot: 0.62,
    threads: 110,
  );
  _ribbon(
    canvas,
    center: (u) => 470 - 260 * u + 40 * sin(2 * pi * u * 0.9 + 5.0),
    width: (u) => 44 * (0.2 + 0.8 * _twist(pi * u * 1.1 + 0.6)),
    color: _white,
    alpha: 0.35,
    hotspot: 0.78,
    threads: 40,
  );

  // Points de lumière plus proches, et éclats le long du grand ruban.
  final near = Random(8);
  for (var i = 0; i < 70; i++) {
    final u = near.nextDouble();
    final spread = (near.nextDouble() - 0.5) * 360;
    final center = Offset(
      -140 + u * (_backWidth + 280),
      _mainRibbon(u) + spread,
    );
    final big = near.nextDouble() < 0.25;
    _bokeh(
      canvas,
      center,
      big ? 14 + near.nextDouble() * 22 : 2 + near.nextDouble() * 7,
      near.nextDouble() < 0.7
          ? const Color(0xFFCFF4FF)
          : const Color(0xFFC9FFE0),
      big ? 0.08 + near.nextDouble() * 0.1 : 0.25 + near.nextDouble() * 0.45,
    );
  }
  for (final u in [0.18, 0.33, 0.56, 0.64, 0.81]) {
    _sparkle(
      canvas,
      Offset(-140 + u * (_backWidth + 280), _mainRibbon(u) - _mainWidth(u) / 2),
      10 + near.nextDouble() * 12,
      0.85,
    );
  }

  canvas
    // Le bas s'assombrit sous les rangées de cartes.
    ..drawRect(
      const Rect.fromLTRB(0, _backHeight * 0.52, _backWidth, _backHeight),
      _linear(
        const Rect.fromLTRB(0, _backHeight * 0.52, _backWidth, _backHeight),
        [_alpha(_night, 0), _alpha(_night, 0.42), _alpha(_night, 0.8)],
        stops: const [0, 0.45, 1],
      ),
    )
    // Le haut se fonce un peu, sous la barre de navigation.
    ..drawRect(
      const Rect.fromLTWH(0, 0, _backWidth, 200),
      _linear(const Rect.fromLTWH(0, 0, _backWidth, 200), [
        _alpha(_night, 0.3),
        _alpha(_night, 0),
      ]),
    )
    // Coins plus sombres : le regard va au centre.
    ..drawRect(
      rect,
      _radial(
        rect,
        [_alpha(_night, 0), _alpha(_night, 0.4)],
        radius: 0.95,
        stops: const [0.55, 1],
      ),
    );
}

Future<void> _writeBackground() async {
  final width = _backWidth.round();
  final height = _backHeight.round();
  final rgba = await _render(width, height, _aurora);
  _dither(rgba);
  File('$_root/backgrounds/aurora.jpg')
    ..createSync(recursive: true)
    ..writeAsBytesSync(
      img.encodeJpg(
        _toImage(width, height, rgba).convert(numChannels: 3),
        quality: 92,
      ),
    );
}

/// Bande de points de lumière qui dérive lentement, de la hauteur de l'écran.
/// Elle se raccorde à elle-même, bord droit contre bord gauche, et pèse quatre
/// fois moins en mémoire à demi-résolution.
const double motesWidth = 2400;
const double motesHeight = 1080;

Future<void> _motes() => _png(
  'backgrounds/motes.png',
  motesWidth,
  motesHeight,
  (canvas) {
    final random = Random(12);
    for (var i = 0; i < 46; i++) {
      final x = random.nextDouble() * motesWidth;
      final y = 60 + random.nextDouble() * 760;
      final big = random.nextDouble() < 0.3;
      final radius = big
          ? 16 + random.nextDouble() * 26
          : 3 + random.nextDouble() * 8;
      final alpha = big
          ? 0.07 + random.nextDouble() * 0.08
          : 0.18 + random.nextDouble() * 0.3;
      final color = random.nextDouble() < 0.75
          ? const Color(0xFFCFF4FF)
          : const Color(0xFFC9FFE0);
      // Trois copies : un point coupé par un bord reprend de l'autre côté.
      for (final shift in [-motesWidth, 0.0, motesWidth]) {
        _bokeh(canvas, Offset(x + shift, y), radius, color, alpha);
      }
    }
  },
  scale: 0.5,
  faint: const [207, 244, 255],
);

/// Aperçu du fond, points de lumière compris, pour juger le rendu sans lancer
/// l'app.
Future<void> _preview(String path) async {
  final width = _backWidth.round();
  final height = _backHeight.round();
  final codec = await ui.instantiateImageCodec(
    File('$_root/backgrounds/motes.png').readAsBytesSync(),
  );
  final motes = (await codec.getNextFrame()).image;
  final rgba = await _render(width, height, (canvas) {
    _aurora(canvas);
    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(-300, 0, motesWidth, motesHeight),
      image: motes,
      fit: BoxFit.fill,
    );
  });
  motes.dispose();
  File(path).writeAsBytesSync(
    img.encodeJpg(
      _toImage(width, height, rgba).convert(numChannels: 3),
      quality: 88,
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

// --- README -----------------------------------------------------------------------
//
// Bannière et boutons de la page GitHub, dans la même direction artistique que
// l'application : l'aurore, le verre, Inter. GitHub n'accepte pas de police
// dans une image SVG : tout est dessiné ici, en PNG à l'échelle 2, ou en JPEG
// pour la bannière.

const String _docs = '../docs/assets';

/// Charge Inter et sa coupe Display : sans elles, le moteur de test écrit avec
/// une police de remplacement.
Future<void> _loadFonts() async {
  ByteData bytes(String path) =>
      ByteData.sublistView(File('assets/fonts/$path').readAsBytesSync());
  await (FontLoader('Inter')
        ..addFont(Future.value(bytes('Inter-Regular.ttf')))
        ..addFont(Future.value(bytes('Inter-Medium.ttf')))
        ..addFont(Future.value(bytes('Inter-SemiBold.ttf'))))
      .load();
  await (FontLoader(
    'InterDisplay',
  )..addFont(Future.value(bytes('InterDisplay-SemiBold.ttf')))).load();
}

ui.Paragraph _text(
  String text, {
  required double size,
  required Color color,
  String family = 'Inter',
  FontWeight weight = FontWeight.w400,
  double width = 4000,
  double height = 1.25,
  double letterSpacing = 0,
  List<Shadow> shadows = const [],
}) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(fontFamily: family, fontSize: size, height: height),
        )
        ..pushStyle(
          ui.TextStyle(
            color: color,
            fontFamily: family,
            fontSize: size,
            fontWeight: weight,
            height: height,
            letterSpacing: letterSpacing,
            shadows: shadows,
          ),
        )
        ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

/// Bulle de verre de la marque, comme dans la barre de l'application.
void _orb(Canvas canvas, Offset center, double radius) {
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas
    ..drawCircle(center, radius * 1.4, _soft(_alpha(_aqua, 0.35), radius * 0.5))
    ..drawCircle(
      center,
      radius,
      _radial(
        rect,
        const [Color(0xFFFFFFFF), Color(0xFF8FE4FF), Color(0xFF1F6FC5)],
        center: const Alignment(-0.35, -0.45),
        radius: 0.9,
        stops: const [0, 0.35, 1],
      ),
    )
    ..drawCircle(
      center,
      radius,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06
        ..color = _alpha(_white, 0.6),
    );
}

/// Bannière : l'aurore, la marque à gauche, l'accueil de la 0.3 dans un cadre
/// de verre à droite.
Future<void> _banner() async {
  const width = 1800.0;
  const height = 760.0;
  final codec = await ui.instantiateImageCodec(
    File('../docs/captures/0.3.0/01_home.jpg').readAsBytesSync(),
  );
  final shot = (await codec.getNextFrame()).image;
  final rgba = await _render(width.round(), height.round(), (canvas) {
    const rect = Rect.fromLTWH(0, 0, width, height);
    const scale = width / _backWidth;
    canvas
      ..save()
      ..translate(0, -(_backHeight * scale - height) / 2 + 30)
      ..scale(scale)
      ..drawRect(
        const Rect.fromLTWH(0, 0, _backWidth, _backHeight),
        Paint()..color = _night,
      );
    _aurora(canvas);
    canvas
      ..restore()
      // Le texte se lit sur un bleu plus sombre, à gauche.
      ..drawRect(
        rect,
        _linear(
          rect,
          [_alpha(_night, 0.6), _alpha(_night, 0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0, 0.5],
        ),
      );

    // L'accueil, dans un cadre de verre.
    const card = Rect.fromLTWH(730, 104, 980, 551.25);
    final frame = RRect.fromRectAndRadius(card, const Radius.circular(22));
    canvas
      ..drawRRect(
        frame.shift(const Offset(0, 26)),
        _soft(_alpha(const Color(0xFF010A18), 0.65), 38),
      )
      ..drawRRect(frame.inflate(10), _soft(_alpha(_aqua, 0.18), 18))
      ..save()
      ..clipRRect(frame);
    paintImage(
      canvas: canvas,
      rect: card,
      image: shot,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
    canvas
      ..drawRect(
        card,
        _linear(
          card,
          [_alpha(_white, 0.12), _alpha(_white, 0)],
          stops: const [0, 0.3],
        ),
      )
      ..restore()
      ..drawRRect(
        frame,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _alpha(_white, 0.4),
      );

    // La marque et ce que fait l'application.
    const lift = [Shadow(color: Color(0x99020D1C), blurRadius: 12)];
    _orb(canvas, const Offset(128, 236), 34);
    canvas
      ..drawParagraph(
        _text(
          'Aero IPTV',
          family: 'InterDisplay',
          size: 88,
          weight: FontWeight.w600,
          color: _white,
          letterSpacing: -1.5,
          shadows: lift,
        ),
        const Offset(182, 180),
      )
      ..drawParagraph(
        _text(
          'Your channels, movies and series on TV and PC, in an interface '
          'made of glass and light.',
          size: 33,
          color: const Color(0xFFE2EFFA),
          width: 580,
          height: 1.35,
          shadows: lift,
        ),
        const Offset(96, 318),
      );
    var x = 96.0;
    for (final platform in ['Android TV', 'Fire TV', 'Windows']) {
      final label = _text(
        platform,
        size: 22,
        weight: FontWeight.w600,
        color: _white,
      );
      final chip = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 520, label.maxIntrinsicWidth + 36, 46),
        const Radius.circular(23),
      );
      canvas
        ..drawRRect(chip, Paint()..color = _alpha(_white, 0.14))
        ..drawRRect(
          chip,
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = _alpha(_white, 0.35),
        )
        ..drawParagraph(label, Offset(x + 18, 520 + (46 - label.height) / 2));
      x += chip.width + 14;
    }
  });
  shot.dispose();
  File('$_docs/banner.jpg').writeAsBytesSync(
    img.encodeJpg(
      _toImage(width.round(), height.round(), rgba).convert(numChannels: 3),
      quality: 90,
    ),
  );
}

/// Bouton en gel : vert pour les téléchargements, comme le bouton Lecture de
/// l'application ; bleu pour les avis. Lisible sur les thèmes clair et sombre
/// de GitHub.
Future<void> _button(
  String name,
  String label, {
  required bool green,
  double height = 60,
  double size = 20,
}) async {
  const margin = 12.0;
  final ink = green ? const Color(0xFF03152B) : _white;
  final text = _text(label, size: size, weight: FontWeight.w600, color: ink);
  final width = text.maxIntrinsicWidth + height * 0.9;
  await _png('$name.png', width + margin * 2, height + margin * 2, (canvas) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(margin, margin, width, height),
      Radius.circular(height / 2),
    );
    final gel = green
        ? const [
            Color(0xFFF2FFE6),
            Color(0xFFB4F296),
            Color(0xFF7ED65C),
            Color(0xFF4FB33B),
          ]
        : const [
            Color(0xFFA9DCFF),
            Color(0xFF4A9BE6),
            Color(0xFF2671C9),
            Color(0xFF0F4C99),
          ];
    canvas
      ..drawRRect(
        body.shift(const Offset(0, 4)),
        _soft(_alpha(const Color(0xFF010A18), 0.35), 6),
      )
      ..drawRRect(
        body,
        _linear(body.outerRect, gel, stops: const [0, 0.45, 0.55, 1]),
      )
      ..drawRRect(
        body,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _alpha(_white, green ? 0.85 : 0.55),
      )
      ..drawParagraph(
        text,
        Offset(
          margin + (width - text.maxIntrinsicWidth) / 2,
          margin + (height - text.height) / 2,
        ),
      );
  }, root: _docs);
}

Future<void> _readmeAssets() async {
  await _loadFonts();
  await _banner();
  await _button('button-windows', 'Download for Windows', green: true);
  await _button('button-firetv', 'Download for Fire TV', green: true);
  await _button('button-androidtv', 'Download for Android TV', green: true);
  await _button('button-feedback', 'Share your feedback', green: false);
  await _button(
    'button-bug',
    'Report a bug',
    green: false,
    height: 48,
    size: 17,
  );
  await _button(
    'button-idea',
    'Suggest an idea',
    green: false,
    height: 48,
    size: 17,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Lancement seul : flutter test tool/render_aero_textures_test.dart
  // --plain-name readme
  test('readme', _readmeAssets);

  test('textures', () async {
    final directory = Directory(_root);
    if (directory.existsSync()) directory.deleteSync(recursive: true);

    await _writeBackground();
    await _motes();
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
