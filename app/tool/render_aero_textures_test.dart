// Dessine les textures de l'interface, d'aprÃ¨s la maquette Frutiger Aero.
//
// Lancement depuis `app` : flutter test tool/render_aero_textures_test.dart
//
// Tout est calculÃ© ici, une fois pour toutes, avec le moteur de rendu de Flutter.
// Sur un stick de 1 Go, l'application ne fait qu'afficher ces images : aucun flou
// ni reflet n'est calculÃ© Ã  l'exÃ©cution. Les images sont Ã  l'Ã©chelle 2.

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
const Color _aqua = Color(0xFF7FE3FF);

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

/// Le moteur rend en alpha prÃ©multipliÃ©, le PNG attend l'alpha direct.
void _unpremultiply(Uint8List rgba) {
  for (var i = 0; i < rgba.length; i += 4) {
    final alpha = rgba[i + 3];
    if (alpha == 0 || alpha == 255) continue;
    for (var c = 0; c < 3; c++) {
      rgba[i + c] = min(255, (rgba[i + c] * 255 / alpha).round());
    }
  }
}

/// Dessine en unitÃ©s logiques : le fichier fait deux fois cette taille.
Future<void> _png(
  String path,
  double width,
  double height,
  void Function(Canvas canvas) paint, {
  double scale = 2,
}) async {
  final pixelWidth = (width * scale).round();
  final pixelHeight = (height * scale).round();
  final rgba = await _render(pixelWidth, pixelHeight, (canvas) {
    canvas.scale(scale);
    paint(canvas);
  });
  _unpremultiply(rgba);
  File('$_root/$path')
    ..createSync(recursive: true)
    ..writeAsBytesSync(
      img.encodePng(_toImage(pixelWidth, pixelHeight, rgba), level: 9),
    );
}

// --- Verre ---------------------------------------------------------------

/// Plaque de verre sombre. Le reflet supÃ©rieur est une forme Ã  part, comme sur la
/// barre de la maquette : c'est lui qui donne l'Ã©paisseur.
void _glass(
  Canvas canvas,
  Rect rect,
  double radius, {
  Color top = const Color(0xFF2E5275),
  Color bottom = const Color(0xFF0B2442),
  double opacity = 0.74,
  double gloss = 0.17,
  double rim = 0.42,
}) {
  final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  canvas.drawRRect(
    shape,
    _linear(rect, [_alpha(top, opacity), _alpha(bottom, opacity + 0.12)]),
  );
  final inset = max(3.0, radius * 0.18);
  final band = Rect.fromLTRB(
    rect.left + inset,
    rect.top + inset,
    rect.right - inset,
    rect.top + rect.height * 0.44,
  );
  canvas.drawRRect(
    RRect.fromRectAndCorners(
      band,
      topLeft: Radius.circular(max(radius - inset, 2)),
      topRight: Radius.circular(max(radius - inset, 2)),
      bottomLeft: Radius.circular(min(band.height * 0.45, radius)),
      bottomRight: Radius.circular(min(band.height * 0.45, radius)),
    ),
    _linear(band, [_alpha(_white, gloss), _alpha(_white, gloss * 0.12)]),
  );
  canvas.drawRRect(
    shape.deflate(0.5),
    _linear(rect, [_alpha(_foam, rim), _alpha(_foam, rim * 0.34)])
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
}

Future<void> _glassPanel() => _png('panels/glass_panel.png', 64, 64, (canvas) {
  _glass(canvas, const Rect.fromLTWH(0, 0, 64, 64), 20);
});

/// Barre de navigation : une seule taille, donc aucun dÃ©coupage en neuf zones.
const Size _navSize = Size(500, 76);

Future<void> _navBar() => _png(
  'panels/nav_bar.png',
  _navSize.width + 40,
  _navSize.height + 16,
  (canvas) {
    canvas.translate(20, 8);
    final rect = Offset.zero & _navSize;
    _glass(
      canvas,
      rect,
      30,
      top: const Color(0xFF3A6185),
      bottom: const Color(0xFF17385A),
      opacity: 0.62,
      gloss: 0.2,
      rim: 0.5,
    );
    _flare(canvas, Offset(_navSize.width * 0.34, 0.5), 150);
    _flare(canvas, Offset(_navSize.width * 0.5, _navSize.height - 0.5), 190);
  },
);

/// Trait de lumiÃ¨re posÃ© sur une arÃªte de verre.
void _flare(Canvas canvas, Offset center, double width) {
  final rect = Rect.fromCenter(center: center, width: width, height: 9);
  canvas
    ..drawOval(
      rect,
      _radial(rect, [
        _alpha(_white, 0.85),
        _alpha(_aqua, 0.4),
        _alpha(_aqua, 0),
      ]),
    )
    ..drawOval(
      Rect.fromCenter(center: center, width: width * 0.55, height: 2.4),
      Paint()
        ..color = _alpha(_white, 0.95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
}

Future<void> _edgeFlare() => _png('chrome/edge_flare.png', 300, 12, (canvas) {
  _flare(canvas, const Offset(150, 6), 296);
});

/// Halo de l'onglet actif, sous son icÃ´ne.
Future<void> _navActive() => _png('chrome/nav_active.png', 96, 64, (canvas) {
  const rect = Rect.fromLTWH(0, 0, 96, 64);
  canvas.drawOval(
    rect,
    _radial(
      rect,
      [
        _alpha(_aqua, 0.42),
        _alpha(const Color(0xFF2FA8E0), 0.16),
        _alpha(_aqua, 0),
      ],
      stops: const [0, 0.55, 1],
    ),
  );
});

/// Anneau lumineux d'un Ã©lÃ©ment actif. Le centre reste transparent.
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
    ..drawRRect(
      body,
      Paint()
        ..color = _alpha(const Color(0xFF56D8FF), 0.95)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    )
    ..drawRRect(
      body.inflate(1),
      Paint()
        ..color = _alpha(_aqua, 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    )
    ..restore()
    ..drawRRect(
      body.inflate(0.4),
      Paint()
        ..color = _white
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
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

/// Bouton en gel. La couleur reste sombre au repos, comme sur la maquette, et
/// s'illumine seulement quand il a le focus.
Future<void> _pill(
  String path, {
  required Color edge,
  required Color top,
  required Color bottom,
  required bool focused,
}) => _png(path, 96, 48, (canvas) {
  const rect = Rect.fromLTWH(1, 1, 94, 46);
  final shape = RRect.fromRectAndRadius(rect, const Radius.circular(23));
  canvas.drawRRect(
    shape,
    _linear(rect, [
      _alpha(top, focused ? 0.98 : 0.72),
      _alpha(bottom, focused ? 0.98 : 0.84),
    ]),
  );
  const band = Rect.fromLTRB(7, 5, 89, 22);
  canvas
    ..drawRRect(
      RRect.fromRectAndCorners(
        band,
        topLeft: const Radius.circular(17),
        topRight: const Radius.circular(17),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      ),
      _linear(band, [
        _alpha(_white, focused ? 0.3 : 0.2),
        _alpha(_white, focused ? 0.06 : 0.03),
      ]),
    )
    // LumiÃ¨re remontant du bas du gel.
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(16, 34, 80, 45),
        const Radius.circular(6),
      ),
      Paint()
        ..color = _alpha(edge, focused ? 0.55 : 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    )
    ..drawRRect(
      shape,
      _linear(rect, [_alpha(edge, 0.95), _alpha(edge, 0.6)])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
});

Future<void> _buttons() async {
  await _pill(
    'chrome/pill_blue.png',
    edge: const Color(0xFF6CBCF5),
    top: const Color(0xFF2B5B8E),
    bottom: const Color(0xFF12335A),
    focused: false,
  );
  await _pill(
    'chrome/pill_blue_focus.png',
    edge: const Color(0xFFB4E6FF),
    top: const Color(0xFF2E86CF),
    bottom: const Color(0xFF104A8E),
    focused: true,
  );
  await _pill(
    'chrome/pill_green.png',
    edge: const Color(0xFF5FE39A),
    top: const Color(0xFF2E7A5C),
    bottom: const Color(0xFF123F35),
    focused: false,
  );
  await _pill(
    'chrome/pill_green_focus.png',
    edge: const Color(0xFFC4FFD9),
    top: const Color(0xFF2B9A64),
    bottom: const Color(0xFF0C5A3C),
    focused: true,
  );
}

/// Cadre d'une carte, avec son reflet. Ã‰tirÃ© entier : toutes les cartes ont les
/// mÃªmes proportions, et un seul dessin suffit.
Future<void> _cardFrame() => _png('chrome/card_frame.png', 128, 192, (canvas) {
  const rect = Rect.fromLTWH(0, 0, 128, 192);
  final shape = RRect.fromRectAndRadius(
    rect.deflate(0.75),
    const Radius.circular(10),
  );
  final sheen = Path()
    ..moveTo(0, 0)
    ..lineTo(104, 0)
    ..quadraticBezierTo(58, 44, 0, 74)
    ..close();
  canvas
    ..save()
    ..clipRRect(shape)
    ..drawPath(
      sheen,
      _linear(rect, [_alpha(_white, 0.15), _alpha(_white, 0.02)]),
    )
    ..drawRect(
      const Rect.fromLTRB(0, 150, 128, 192),
      _linear(const Rect.fromLTRB(0, 150, 128, 192), [
        _alpha(const Color(0xFF04142B), 0),
        _alpha(const Color(0xFF04142B), 0.38),
      ]),
    )
    ..restore()
    ..drawRRect(
      shape,
      _linear(rect, [_alpha(_foam, 0.5), _alpha(const Color(0xFF7FB4D8), 0.3)])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
});

Future<void> _cardGhost() => _png('chrome/card_ghost.png', 128, 192, (canvas) {
  const rect = Rect.fromLTWH(0, 0, 128, 192);
  final shape = RRect.fromRectAndRadius(
    rect.deflate(0.75),
    const Radius.circular(10),
  );
  canvas
    ..drawRRect(shape, Paint()..color = _alpha(const Color(0xFF7FB4D8), 0.08))
    ..drawRRect(
      shape,
      Paint()
        ..color = _alpha(_foam, 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
});

/// Cadre du grand visuel de l'accueil.
Future<void> _heroFrame() => _png('chrome/hero_frame.png', 64, 64, (canvas) {
  const rect = Rect.fromLTWH(0, 0, 64, 64);
  final shape = RRect.fromRectAndRadius(
    rect.deflate(1),
    const Radius.circular(14),
  );
  canvas
    ..drawRRect(
      shape.deflate(1.5),
      Paint()
        ..color = _alpha(_aqua, 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    )
    ..drawRRect(
      shape,
      _linear(rect, [_alpha(_white, 0.72), _alpha(_aqua, 0.5)])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
});

/// Grand reflet courbe du visuel, comme sur la vitre d'un aquarium.
Future<void> _heroGloss() => _png('chrome/hero_gloss.png', 280, 102, (canvas) {
  const rect = Rect.fromLTWH(0, 0, 280, 102);
  final sheen = Path()
    ..moveTo(0, 102)
    ..quadraticBezierTo(60, 42, 196, 54)
    ..quadraticBezierTo(112, 72, 92, 102)
    ..close();
  canvas
    ..drawPath(
      sheen,
      _linear(
        rect,
        [_alpha(_white, 0.17), _alpha(_white, 0.02)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
    )
    ..drawRect(
      rect,
      _linear(
        rect,
        [
          _alpha(_white, 0.09),
          _alpha(_white, 0),
          _alpha(const Color(0xFF04142B), 0),
          _alpha(const Color(0xFF04142B), 0.32),
        ],
        stops: const [0, 0.26, 0.6, 1],
      ),
    );
}, scale: 1);

Future<void> _chevron() => _png('icons/chevron.png', 22, 40, (canvas) {
  final path = Path()
    ..moveTo(15, 7)
    ..lineTo(6, 20)
    ..lineTo(15, 33);
  canvas
    ..drawPath(
      path,
      Paint()
        ..color = _alpha(_aqua, 0.5)
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

// --- IcÃ´nes 3D, dessinÃ©es dans un carrÃ© de 100 unitÃ©s ---------------------

Future<void> _icon(
  String name,
  double size,
  void Function(Canvas canvas) paint,
) => _png('icons/$name.png', size, size, (canvas) {
  canvas.scale(size / 100);
  paint(canvas);
});

void _dropShadow(Canvas canvas, Rect rect) => canvas.drawOval(
  rect,
  Paint()
    ..color = _alpha(const Color(0xFF00112B), 0.55)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
);

void _home(Canvas canvas) {
  _dropShadow(canvas, const Rect.fromLTRB(18, 83, 82, 95));

  const walls = Rect.fromLTRB(21, 42, 79, 90);
  canvas
    // CheminÃ©e.
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(67, 14, 79, 42),
        const Radius.circular(2),
      ),
      _linear(
        const Rect.fromLTRB(67, 14, 79, 42),
        const [Color(0xFFFF8A5C), Color(0xFFB62C1E)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    )
    ..drawRRect(
      RRect.fromRectAndCorners(
        walls,
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      ),
      _linear(
        walls,
        const [Color(0xFFFFFFFF), Color(0xFFE4F0FA), Color(0xFFA9C6E2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

  const door = Rect.fromLTRB(41, 58, 59, 90);
  canvas.drawRRect(
    RRect.fromRectAndCorners(
      door,
      topLeft: const Radius.circular(4),
      topRight: const Radius.circular(4),
    ),
    _linear(door, const [Color(0xFF2E7BE0), Color(0xFF0B3D94)]),
  );

  final roof = Path()
    ..moveTo(50, 7)
    ..quadraticBezierTo(52, 7, 54, 9)
    ..lineTo(96, 47)
    ..quadraticBezierTo(98, 51, 93, 54)
    ..lineTo(88, 57)
    ..quadraticBezierTo(85, 58, 83, 56)
    ..lineTo(50, 27)
    ..lineTo(17, 56)
    ..quadraticBezierTo(15, 58, 12, 57)
    ..lineTo(7, 54)
    ..quadraticBezierTo(2, 51, 4, 47)
    ..lineTo(46, 9)
    ..quadraticBezierTo(48, 7, 50, 7)
    ..close();
  canvas
    ..drawPath(
      roof.shift(const Offset(0, 2.2)),
      Paint()..color = _alpha(const Color(0xFF7A1208), 0.75),
    )
    ..drawPath(
      roof,
      _linear(
        const Rect.fromLTRB(4, 7, 96, 58),
        const [Color(0xFFFFB25A), Color(0xFFFF6A2B), Color(0xFFD9271A)],
        stops: const [0, 0.42, 1],
      ),
    );
  final gleam = Path()
    ..moveTo(50, 12)
    ..lineTo(90, 48)
    ..lineTo(84, 50)
    ..lineTo(50, 20)
    ..lineTo(16, 50)
    ..lineTo(10, 48)
    ..close();
  canvas.drawPath(gleam, Paint()..color = _alpha(_white, 0.34));
}

void _television(Canvas canvas) {
  _dropShadow(canvas, const Rect.fromLTRB(20, 86, 80, 96));
  final antenna = Paint()
    ..color = const Color(0xFFD7E9F6)
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;
  canvas
    ..drawLine(const Offset(50, 21), const Offset(34, 6), antenna)
    ..drawLine(const Offset(50, 21), const Offset(66, 6), antenna);

  const stand = Rect.fromLTRB(30, 74, 70, 92);
  final foot = Path()
    ..moveTo(40, 74)
    ..lineTo(60, 74)
    ..lineTo(64, 84)
    ..lineTo(76, 86)
    ..quadraticBezierTo(78, 91, 74, 91)
    ..lineTo(26, 91)
    ..quadraticBezierTo(22, 91, 24, 86)
    ..lineTo(36, 84)
    ..close();
  canvas.drawPath(
    foot,
    _linear(stand, const [Color(0xFF7CC2F2), Color(0xFF1A62B8)]),
  );

  const body = Rect.fromLTRB(7, 20, 93, 78);
  canvas.drawRRect(
    RRect.fromRectAndRadius(body, const Radius.circular(9)),
    _linear(
      body,
      const [Color(0xFFF2FAFF), Color(0xFF9CC8EA), Color(0xFF4F8FCB)],
      stops: const [0, 0.5, 1],
    ),
  );
  const screen = Rect.fromLTRB(14, 27, 86, 71);
  final glass = RRect.fromRectAndRadius(screen, const Radius.circular(5));
  canvas
    ..drawRRect(
      glass,
      _linear(
        screen,
        const [Color(0xFF8BEBFF), Color(0xFF12B6F2), Color(0xFF0A49C2)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        stops: const [0, 0.48, 1],
      ),
    )
    ..save()
    ..clipRRect(glass);
  final sheen = Path()
    ..moveTo(14, 27)
    ..lineTo(68, 27)
    ..quadraticBezierTo(46, 44, 14, 54)
    ..close();
  canvas
    ..drawPath(sheen, Paint()..color = _alpha(_white, 0.3))
    ..restore();
}

void _magnifier(Canvas canvas) {
  _dropShadow(canvas, const Rect.fromLTRB(50, 82, 96, 94));
  final handle = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFF3F8FF2), Color(0xFF0D3F9E)],
    ).createShader(const Rect.fromLTRB(62, 62, 92, 92))
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 13
    ..strokeCap = StrokeCap.round;
  canvas
    ..drawLine(const Offset(70, 70), const Offset(86, 86), handle)
    ..drawLine(
      const Offset(69, 67),
      const Offset(85, 83),
      Paint()
        ..color = _alpha(_white, 0.34)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  const center = Offset(43, 43);
  final lens = Rect.fromCircle(center: center, radius: 35);
  canvas
    ..drawLine(
      const Offset(62, 62),
      const Offset(71, 71),
      Paint()
        ..color = const Color(0xFFCDE6F6)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    )
    ..drawCircle(
      center,
      31,
      _radial(
        lens,
        [
          _alpha(const Color(0xFFC5F1FF), 0.8),
          _alpha(const Color(0xFF3FB0EE), 0.72),
          _alpha(const Color(0xFF1468CC), 0.82),
        ],
        center: const Alignment(-0.3, -0.35),
        radius: 0.72,
      ),
    )
    ..drawCircle(
      center,
      31,
      _linear(lens, const [Color(0xFFF4FCFF), Color(0xFF58AEE6)])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5,
    );
  final gleam = Path()
    ..addArc(Rect.fromCircle(center: center, radius: 23), pi * 1.05, pi * 0.62);
  canvas.drawPath(
    gleam,
    Paint()
      ..color = _alpha(_white, 0.78)
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round,
  );
}

void _gear(Canvas canvas) {
  _dropShadow(canvas, const Rect.fromLTRB(20, 84, 80, 95));
  const center = Offset(50, 48);
  const teeth = 9;
  final outline = Path();
  for (var i = 0; i < teeth * 4; i++) {
    final angle = i * 2 * pi / (teeth * 4) - pi / 2;
    final radius = (i + 1) % 4 < 2 ? 41.0 : 32.0;
    final point = center + Offset(cos(angle), sin(angle)) * radius;
    i == 0
        ? outline.moveTo(point.dx, point.dy)
        : outline.lineTo(point.dx, point.dy);
  }
  outline.close();
  const box = Rect.fromLTRB(7, 5, 93, 91);
  canvas
    ..drawPath(
      outline.shift(const Offset(0, 2.4)),
      Paint()..color = _alpha(const Color(0xFF16385F), 0.9),
    )
    ..drawPath(
      outline,
      _linear(
        box,
        const [Color(0xFFF4FBFF), Color(0xFFA9CCE6), Color(0xFF5F8DB8)],
        stops: const [0, 0.5, 1],
      ),
    )
    ..drawCircle(
      center,
      17,
      _linear(box, const [Color(0xFF0E3A6E), Color(0xFF2B7FC9)]),
    )
    ..drawCircle(
      center,
      17,
      Paint()
        ..color = _alpha(_white, 0.62)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
}

void _history(Canvas canvas) {
  const rect = Rect.fromLTRB(8, 8, 92, 92);
  final ring = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD7FBFF), Color(0xFF53C7EA)],
    ).createShader(rect)
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final dial = Path()
    ..addArc(
      Rect.fromCircle(center: const Offset(52, 50), radius: 37),
      -pi * 1.12,
      pi * 1.72,
    );
  canvas
    ..drawPath(dial, ring)
    ..drawPath(
      Path()
        ..moveTo(4, 30)
        ..lineTo(18, 46)
        ..lineTo(32, 32),
      ring,
    )
    ..drawPath(
      Path()
        ..moveTo(52, 28)
        ..lineTo(52, 52)
        ..lineTo(70, 62),
      ring,
    );
}

void _tvStar(Canvas canvas) {
  const body = Rect.fromLTRB(6, 34, 76, 92);
  final shell = RRect.fromRectAndRadius(body, const Radius.circular(10));
  final antenna = Paint()
    ..color = const Color(0xFFD5F2FF)
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.5
    ..strokeCap = StrokeCap.round;
  canvas
    ..drawLine(const Offset(40, 34), const Offset(24, 18), antenna)
    ..drawLine(const Offset(40, 34), const Offset(56, 18), antenna)
    ..drawRRect(
      shell,
      _linear(
        body,
        const [Color(0xFF62E0F2), Color(0xFF7D6BF2), Color(0xFFD65FE8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    )
    ..drawRRect(
      RRect.fromRectAndRadius(body.deflate(8), const Radius.circular(5)),
      _linear(body, const [Color(0xFF103A73), Color(0xFF0A1E46)]),
    );
  final star = Path();
  const center = Offset(74, 26);
  for (var i = 0; i < 10; i++) {
    final angle = i * pi / 5 - pi / 2;
    final radius = i.isEven ? 23.0 : 10.5;
    final point = center + Offset(cos(angle), sin(angle)) * radius;
    i == 0 ? star.moveTo(point.dx, point.dy) : star.lineTo(point.dx, point.dy);
  }
  star.close();
  canvas
    ..drawPath(
      star,
      Paint()
        ..color = _alpha(const Color(0xFFFFC53A), 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    )
    ..drawPath(
      star,
      _linear(const Rect.fromLTRB(50, 2, 98, 50), const [
        Color(0xFFFFF0A8),
        Color(0xFFFFAE1F),
      ]),
    );
}

void _clapper(Canvas canvas) {
  const body = Rect.fromLTRB(10, 44, 90, 92);
  canvas.drawRRect(
    RRect.fromRectAndRadius(body, const Radius.circular(7)),
    _linear(body, const [Color(0xFF8BE3FF), Color(0xFF1B7FD8)]),
  );
  void stripes(Rect bar) {
    final shape = RRect.fromRectAndRadius(bar, const Radius.circular(3));
    canvas
      ..save()
      ..clipRRect(shape)
      ..drawRect(bar, Paint()..color = const Color(0xFF12284A));
    final stripe = Paint()..color = const Color(0xFFF2FBFF);
    for (var x = bar.left - 8; x < bar.right; x += 22) {
      canvas.drawPath(
        Path()
          ..moveTo(x + 10, bar.top)
          ..lineTo(x + 21, bar.top)
          ..lineTo(x + 11, bar.bottom)
          ..lineTo(x, bar.bottom)
          ..close(),
        stripe,
      );
    }
    canvas.restore();
  }

  stripes(const Rect.fromLTRB(10, 32, 90, 46));
  canvas
    ..save()
    ..translate(10, 30)
    ..rotate(-0.26)
    ..translate(-10, -30);
  stripes(const Rect.fromLTRB(10, 16, 90, 30));
  canvas.restore();
}

void _play(Canvas canvas) {
  final shape = Path()
    ..moveTo(22, 13)
    ..quadraticBezierTo(22, 5, 30, 9)
    ..lineTo(88, 44)
    ..quadraticBezierTo(95, 50, 88, 56)
    ..lineTo(30, 91)
    ..quadraticBezierTo(22, 95, 22, 87)
    ..close();
  const box = Rect.fromLTRB(20, 5, 94, 95);
  canvas
    ..drawPath(
      shape,
      Paint()
        ..color = _alpha(const Color(0xFF53F08F), 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    )
    ..drawPath(
      shape,
      _linear(
        box,
        const [Color(0xFFD8FFC4), Color(0xFF55E07A), Color(0xFF17A34F)],
        stops: const [0, 0.5, 1],
      ),
    );
  final gleam = Path()
    ..moveTo(29, 14)
    ..lineTo(84, 47)
    ..quadraticBezierTo(50, 44, 29, 62)
    ..close();
  canvas.drawPath(gleam, Paint()..color = _alpha(_white, 0.32));
}

void _info(Canvas canvas) {
  const center = Offset(50, 50);
  final orb = Rect.fromCircle(center: center, radius: 46);
  canvas
    ..drawCircle(
      center,
      46,
      _radial(
        orb,
        const [Color(0xFFE2F6FF), Color(0xFF6EC4F5), Color(0xFF1668C8)],
        center: const Alignment(-0.2, -0.45),
        radius: 0.9,
        stops: const [0, 0.5, 1],
      ),
    )
    ..drawCircle(
      center,
      46,
      Paint()
        ..color = _alpha(_white, 0.85)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    )
    ..drawOval(
      const Rect.fromLTRB(22, 9, 78, 42),
      _linear(const Rect.fromLTRB(22, 9, 78, 42), [
        _alpha(_white, 0.78),
        _alpha(_white, 0.04),
      ]),
    );
  const ink = Color(0xFF0D3D80);
  canvas
    ..drawCircle(const Offset(50, 28), 8, Paint()..color = ink)
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(42, 42, 58, 78),
        const Radius.circular(3.5),
      ),
      Paint()..color = ink,
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(36, 42, 54, 49),
        const Radius.circular(2.5),
      ),
      Paint()..color = ink,
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(36, 71, 64, 78),
        const Radius.circular(2.5),
      ),
      Paint()..color = ink,
    );
}

// --- Fond ----------------------------------------------------------------

const double _backWidth = 1600;
const double _backHeight = 900;

/// Ruban de lumiÃ¨re entre deux courbes, faÃ§on vague de verre.
void _ribbon(
  Canvas canvas, {
  required double Function(double u) top,
  required double Function(double u) bottom,
  required List<Color> colors,
  double edge = 0,
}) {
  const steps = 64;
  final upper = <Offset>[
    for (var i = 0; i <= steps; i++)
      Offset(i / steps * _backWidth, top(i / steps) * _backHeight),
  ];
  final lower = <Offset>[
    for (var i = steps; i >= 0; i--)
      Offset(i / steps * _backWidth, bottom(i / steps) * _backHeight),
  ];
  final band = Path()..addPolygon([...upper, ...lower], true);
  canvas.drawPath(
    band,
    _linear(
      const Rect.fromLTWH(0, 0, _backWidth, _backHeight),
      colors,
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    )..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );
  if (edge > 0) {
    final line = Path()..addPolygon(upper, false);
    canvas
      ..drawPath(
        line,
        _linear(
            const Rect.fromLTWH(0, 0, _backWidth, _backHeight),
            [for (final color in colors) _alpha(color, color.a * edge)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawPath(
        line,
        _linear(
            const Rect.fromLTWH(0, 0, _backWidth, _backHeight),
            [for (final color in colors) _alpha(color, color.a * edge * 0.8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
  }
}

void _bubble(Canvas canvas, Offset center, double radius, [double light = 1]) {
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas
    ..drawCircle(
      center,
      radius,
      _radial(
        rect,
        [
          _alpha(const Color(0xFF9FE6FF), 0),
          _alpha(const Color(0xFF9FE6FF), 0.03 * light),
          _alpha(const Color(0xFFBFEFFF), 0.26 * light),
        ],
        stops: const [0, 0.72, 1],
      ),
    )
    ..drawCircle(
      center,
      radius - 0.6,
      Paint()
        ..color = _alpha(_white, 0.22 * light)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    )
    ..drawPath(
      Path()..addArc(
        Rect.fromCircle(center: center, radius: radius * 0.74),
        pi * 1.1,
        pi * 0.36,
      ),
      Paint()
        ..color = _alpha(_white, 0.42 * light)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(1, radius * 0.1)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          max(0.5, radius * 0.03),
        ),
    );
}

void _background(Canvas canvas) {
  const size = Rect.fromLTWH(0, 0, _backWidth, _backHeight);
  canvas
    ..drawRect(
      size,
      _linear(
        size,
        const [Color(0xFF020C22), Color(0xFF06223F), Color(0xFF0A4B63)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, 0.52, 1],
      ),
    )
    // LumiÃ¨re du large, en haut Ã  droite.
    ..drawRect(
      size,
      _radial(
        size,
        [
          _alpha(const Color(0xFF12789A), 0.85),
          _alpha(const Color(0xFF12789A), 0),
        ],
        center: const Alignment(1.05, -1),
        radius: 1.05,
      ),
    )
    // Fond vert du lagon, en bas Ã  droite.
    ..drawRect(
      size,
      _radial(
        size,
        [
          _alpha(const Color(0xFF137A4F), 0.9),
          _alpha(const Color(0xFF137A4F), 0),
        ],
        center: const Alignment(1.05, 1.1),
        radius: 0.95,
      ),
    )
    ..drawRect(
      size,
      _radial(
        size,
        [
          _alpha(const Color(0xFF01081A), 0.72),
          _alpha(const Color(0xFF01081A), 0),
        ],
        center: const Alignment(-1.05, 1.05),
        radius: 1.1,
      ),
    );

  double wave(double u, double a, double b, double c, double d) =>
      a + b * sin(u * pi * c + d);

  _ribbon(
    canvas,
    top: (u) => wave(u, 0.53, 0.105, 1.55, 2.5) - 0.04 * u,
    bottom: (u) => wave(u, 0.64, 0.085, 1.5, 2.45) - 0.05 * u,
    colors: [
      _alpha(const Color(0xFF6FB6E8), 0.1),
      _alpha(const Color(0xFF6FB6E8), 0.2),
      _alpha(const Color(0xFF8FE0F0), 0.06),
      _alpha(const Color(0xFF9CE8F2), 0.2),
    ],
    edge: 2.2,
  );
  _ribbon(
    canvas,
    top: (u) => wave(u, 0.58, 0.13, 1.25, 3.1) - 0.1 * u * u,
    bottom: (u) => wave(u, 0.70, 0.10, 1.25, 3.0) - 0.12 * u * u,
    colors: [
      _alpha(const Color(0xFF5FA4DC), 0.14),
      _alpha(const Color(0xFF5FA4DC), 0.05),
      _alpha(const Color(0xFF8FE0F0), 0.1),
      _alpha(const Color(0xFFBDF2F5), 0.34),
    ],
    edge: 1.8,
  );
  _ribbon(
    canvas,
    top: (u) => wave(u, 0.70, 0.075, 1.15, 0.2) - 0.05 * u,
    bottom: (u) => wave(u, 0.77, 0.06, 1.15, 0.1) - 0.05 * u,
    colors: [
      _alpha(const Color(0xFF3E7FBC), 0.02),
      _alpha(const Color(0xFF6FB6E8), 0.08),
      _alpha(const Color(0xFF7FD8C8), 0.14),
      _alpha(const Color(0xFF8FE8C8), 0.12),
    ],
    edge: 1.2,
  );

  // Bulles autour du grand visuel, comme sur la maquette.
  const bubbles = [
    [1420.0, 118.0, 36.0],
    [1316.0, 118.0, 6.0],
    [1340.0, 102.0, 7.0],
    [1442.0, 112.0, 8.0],
    [760.0, 196.0, 16.0],
    [708.0, 288.0, 25.0],
    [680.0, 232.0, 8.0],
    [670.0, 318.0, 7.0],
    [712.0, 356.0, 11.0],
    [655.0, 230.0, 3.0],
    [1487.0, 240.0, 32.0],
    [1510.0, 238.0, 17.0],
    [775.0, 418.0, 5.0],
    [1483.0, 343.0, 4.0],
  ];
  for (final bubble in bubbles) {
    _bubble(canvas, Offset(bubble[0], bubble[1]), bubble[2]);
  }
}

/// Un lÃ©ger grain Ã©vite les bandes visibles dans les dÃ©gradÃ©s sombres.
void _dither(Uint8List rgba) {
  final random = Random(7);
  for (var i = 0; i < rgba.length; i += 4) {
    final grain = random.nextInt(3) - 1;
    for (var c = 0; c < 3; c++) {
      rgba[i + c] = (rgba[i + c] + grain).clamp(0, 255);
    }
  }
}

Future<void> _writeBackground() async {
  final width = _backWidth.round();
  final height = _backHeight.round();
  final rgba = await _render(width, height, _background);
  _dither(rgba);
  File('$_root/backgrounds/abyss.jpg')
    ..createSync(recursive: true)
    ..writeAsBytesSync(
      img.encodeJpg(
        _toImage(width, height, rgba).convert(numChannels: 3),
        quality: 92,
      ),
    );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('textures', () async {
    final directory = Directory(_root);
    if (directory.existsSync()) directory.deleteSync(recursive: true);

    await _writeBackground();
    await _glassPanel();
    await _navBar();
    await _edgeFlare();
    await _navActive();
    await _focusHalos();
    await _buttons();
    await _cardFrame();
    await _cardGhost();
    await _heroFrame();
    await _heroGloss();
    await _chevron();
    await _icon('nav_home', 56, _home);
    await _icon('nav_live', 56, _television);
    await _icon('nav_search', 56, _magnifier);
    await _icon('nav_settings', 56, _gear);
    await _icon('row_continue', 34, _history);
    await _icon('row_series', 34, _tvStar);
    await _icon('row_movies', 34, _clapper);
    await _icon('play', 30, _play);
    await _icon('info', 30, _info);

    var total = 0;
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      total += file.lengthSync();
    }
    // ignore: avoid_print
    print('Textures : ${total ~/ 1024} Ko');
  });
}
