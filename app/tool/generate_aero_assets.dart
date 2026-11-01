// Génère les icônes de l'application et la bannière des TV.
//
// Lancement depuis `app` : dart run tool/generate_aero_assets.dart
//
// Les textures de l'interface viennent de `tool/render_aero_textures_test.dart`.

import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const List<int> _foam = [232, 251, 255];
const List<int> _aqua = [57, 198, 240];
const List<int> _lagoon = [11, 111, 184];
const List<int> _abyss = [5, 58, 91];

double _clamp(double value) => value.clamp(0.0, 1.0);

double _smooth(double edge0, double edge1, double x) {
  final t = _clamp((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

double _mix(double a, double b, double t) => a + (b - a) * t;

List<double> _mixColor(List<int> a, List<int> b, double t) => [
  for (var i = 0; i < 3; i++) _mix(a[i].toDouble(), b[i].toDouble(), t),
];

/// Compose une couche sur le pixel courant, en alpha prémultiplié.
class _Pixel {
  double r = 0;
  double g = 0;
  double b = 0;
  double a = 0;

  void over(List<num> color, double alpha) {
    final source = _clamp(alpha);
    final remaining = a * (1 - source);
    final total = source + remaining;
    if (total <= 0) return;
    r = (color[0] * source + r * remaining) / total;
    g = (color[1] * source + g * remaining) / total;
    b = (color[2] * source + b * remaining) / total;
    a = total;
  }

  void write(img.Image image, int x, int y) => image.setPixelRgba(
    x,
    y,
    r.round(),
    g.round(),
    b.round(),
    (a * 255).round(),
  );
}

img.Image _paint(
  int width,
  int height,
  void Function(_Pixel pixel, double x, double y) shader,
) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = _Pixel();
      shader(pixel, x + 0.5, y + 0.5);
      pixel.write(image, x, y);
    }
  }
  return image;
}

/// Sphère brillante de l'icône.
img.Image _orb({double size = 96}) {
  final center = size / 2;
  final radius = center - 3;
  return _paint(size.toInt(), size.toInt(), (pixel, x, y) {
    final dx = (x - center) / radius;
    final dy = (y - center) / radius;
    final distance = sqrt(dx * dx + dy * dy);
    final inside = _smooth(1.0, 0.975, distance);
    if (inside <= 0) return;
    pixel.over(_mixColor(_aqua, _abyss, _smooth(-0.8, 1, dy)), inside);
    // Lumière remontant du bas de la sphère.
    pixel.over(_foam, inside * _smooth(0.25, 1, dy) * 0.55 * (1 - dx.abs()));
    // Reflet en croissant dans le haut.
    final highlight = sqrt(pow(dx / 0.74, 2) + pow((dy + 0.42) / 0.5, 2));
    pixel.over([255, 255, 255], _smooth(1, 0.8, highlight) * 0.72);
  });
}

/// Fond de la bannière : ciel d'été, soleil, nuages et lagon.
img.Image _lagoonBackground() {
  const width = 960;
  const height = 540;
  const horizon = 0.36;
  final image = img.Image(width: width, height: height);
  final random = Random(7);

  final clouds = [
    for (var i = 0; i < 26; i++)
      [
        random.nextDouble(),
        0.05 + random.nextDouble() * 0.24,
        0.05 + random.nextDouble() * 0.11,
        0.25 + random.nextDouble() * 0.55,
      ],
  ];

  for (var y = 0; y < height; y++) {
    final v = y / height;
    for (var x = 0; x < width; x++) {
      final u = x / width;
      final List<double> color;
      if (v < horizon) {
        final t = v / horizon;
        color = _mixColor(_lagoon, const [
          150,
          214,
          240,
        ], pow(t, 2.4).toDouble());
        // Soleil en haut à droite.
        final sun = sqrt(pow((u - 0.82) * 1.78, 2) + pow(v - 0.05, 2));
        final glow = pow(_clamp(1 - sun / 0.62), 3).toDouble();
        for (var i = 0; i < 3; i++) {
          color[i] = _mix(color[i], 255, glow * 0.9);
        }
        for (final cloud in clouds) {
          final dx = (u - cloud[0]) / (cloud[2] * 1.9);
          final dy = (v - cloud[1]) / (cloud[2] * 0.62);
          final puff = _clamp(1 - sqrt(dx * dx + dy * dy)) * cloud[3];
          for (var i = 0; i < 3; i++) {
            color[i] = _mix(color[i], 255, puff * 0.3);
          }
        }
      } else {
        final t = (v - horizon) / (1 - horizon);
        color = _mixColor(_aqua, _abyss, pow(t, 0.72).toDouble());
        final wave =
            sin(x * 0.03 + pow(y - height * horizon, 1.2) * 0.28) *
            sin(x * 0.011 - y * 0.12);
        final sparkle = _smooth(0.72, 0.98, wave) * (1 - t * 0.8);
        for (var i = 0; i < 3; i++) {
          color[i] = _mix(color[i], 255, sparkle * 0.4);
        }
      }
      image.setPixelRgb(
        x,
        y,
        color[0].round(),
        color[1].round(),
        color[2].round(),
      );
    }
  }

  // Bulles remontant du lagon.
  for (var i = 0; i < 34; i++) {
    final cx = random.nextDouble() * width;
    final cy = height * (0.42 + random.nextDouble() * 0.58);
    final radius = 3 + random.nextDouble() * 15;
    for (var y = (cy - radius).floor(); y <= cy + radius; y++) {
      for (var x = (cx - radius).floor(); x <= cx + radius; x++) {
        if (x < 0 || y < 0 || x >= width || y >= height) continue;
        final d = sqrt(pow(x - cx, 2) + pow(y - cy, 2)) / radius;
        if (d > 1) continue;
        final rim = _smooth(0.72, 0.98, d) * (1 - _smooth(0.98, 1, d)) * 0.42;
        final shine =
            (1 -
                _smooth(
                  0,
                  0.26,
                  sqrt(
                    pow((x - cx + radius * 0.34) / radius, 2) +
                        pow((y - cy + radius * 0.38) / radius, 2),
                  ),
                )) *
            0.7;
        final alpha = max(rim, shine);
        final pixel = image.getPixel(x, y);
        image.setPixelRgb(
          x,
          y,
          _mix(pixel.r.toDouble(), 255, alpha).round(),
          _mix(pixel.g.toDouble(), 255, alpha).round(),
          _mix(pixel.b.toDouble(), 255, alpha).round(),
        );
      }
    }
  }
  return img.gaussianBlur(image, radius: 1);
}

/// Icône de l'application : la sphère, avec un triangle de lecture.
img.Image _appIcon() {
  const size = 256;
  final icon = _orb(size: size.toDouble());
  img.fillPolygon(
    icon,
    vertices: [
      img.Point(size * 0.40, size * 0.30),
      img.Point(size * 0.40, size * 0.72),
      img.Point(size * 0.74, size * 0.51),
    ],
    color: img.ColorRgba8(255, 255, 255, 235),
  );
  return icon;
}

/// Bannière de l'écran d'accueil des TV : 320 × 180 pixels en xhdpi. Le nom de
/// l'application doit y figurer en toutes lettres.
img.Image _tvBanner(img.Image icon) {
  const width = 320;
  const height = 180;
  final banner = img
      .copyResize(
        _lagoonBackground(),
        width: width,
        height: height,
        interpolation: img.Interpolation.average,
      )
      .convert(numChannels: 4);
  img.compositeImage(
    banner,
    img.copyResize(icon, width: 84, height: 84),
    dstX: 16,
    dstY: 48,
  );
  img.drawString(
    banner,
    'Aero IPTV',
    font: img.arial24,
    x: 108,
    y: 80,
    color: img.ColorRgb8(5, 58, 91),
  );
  img.drawString(
    banner,
    'Aero IPTV',
    font: img.arial24,
    x: 107,
    y: 78,
    color: img.ColorRgb8(255, 255, 255),
  );
  return banner;
}

void _writeLauncherIcons(img.Image icon) {
  const sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  sizes.forEach((density, size) {
    _writePng(
      'android/app/src/main/res/mipmap-$density/ic_launcher.png',
      img.copyResize(
        icon,
        width: size,
        height: size,
        interpolation: img.Interpolation.cubic,
      ),
    );
  });
}

void _writeWindowsIcon(img.Image icon) {
  final frames = [
    for (final size in const [16, 32, 48, 64, 128, 256])
      size == 256
          ? icon
          : img.copyResize(
              icon,
              width: size,
              height: size,
              interpolation: img.Interpolation.cubic,
            ),
  ];
  File(
    'windows/runner/resources/app_icon.ico',
  ).writeAsBytesSync(img.IcoEncoder().encodeImages(frames));
}

void _writePng(String path, img.Image image) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image, level: 9));
}

void main() {
  final icon = _appIcon();
  _writeLauncherIcons(icon);
  _writeWindowsIcon(icon);
  _writePng(
    'android/app/src/main/res/drawable-xhdpi/tv_banner.png',
    _tvBanner(icon),
  );
}
