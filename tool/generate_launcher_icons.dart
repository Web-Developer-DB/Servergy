// Generates every binary launcher asset from the committed ServergyMark.
// Run with `dart run tool/generate_launcher_icons.dart` after changing the
// SVG master. The visual geometry intentionally mirrors the SVG so platform
// launchers do not depend on an editor-specific export step.
import 'dart:io';

import 'package:image/image.dart' as image;

const _navy = (9, 42, 61, 255);
const _surface = (246, 248, 251, 255);
const _green = (78, 226, 154, 255);
const _cyan = (117, 214, 244, 255);

void main() {
  final root = Directory.current;
  final master = _drawMark(1024, includeBackground: true);
  final foreground = _drawMark(1024, includeBackground: false);
  final monochrome = _drawMark(1024, monochrome: true);

  _writePng(root.uri.resolve('assets/branding/servergy-icon.png'), master);
  _writePng(
    root.uri.resolve('assets/branding/servergy-icon-foreground.png'),
    foreground,
  );
  _writePng(
    root.uri.resolve('assets/branding/servergy-icon-monochrome.png'),
    monochrome,
  );

  const androidSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  for (final entry in androidSizes.entries) {
    _writePng(
      root.uri.resolve('android/app/src/main/res/${entry.key}/ic_launcher.png'),
      image.copyResize(master, width: entry.value, height: entry.value),
    );
  }
  _writePng(
    root.uri.resolve(
      'android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png',
    ),
    foreground,
  );
  _writePng(
    root.uri.resolve(
      'android/app/src/main/res/drawable-nodpi/ic_launcher_monochrome.png',
    ),
    monochrome,
  );

  final ico = image.copyResize(master, width: 16, height: 16);
  for (final size in [24, 32, 48, 64, 128, 256]) {
    ico.addFrame(image.copyResize(master, width: size, height: size));
  }
  _writeBytes(
    root.uri.resolve('windows/runner/resources/app_icon.ico'),
    image.encodeIco(ico),
  );

  for (final size in [16, 24, 32, 48, 64, 128, 256, 512]) {
    _writePng(
      root.uri.resolve(
        'linux/packaging/icons/hicolor/${size}x$size/apps/'
        'dev.servergy.servergy.png',
      ),
      image.copyResize(master, width: size, height: size),
    );
  }
  final scalable = File.fromUri(
    root.uri.resolve(
      'linux/packaging/icons/hicolor/scalable/apps/dev.servergy.servergy.svg',
    ),
  );
  scalable.parent.createSync(recursive: true);
  File.fromUri(
    root.uri.resolve('assets/branding/servergy-mark.svg'),
  ).copySync(scalable.path);
}

image.Image _drawMark(
  int size, {
  bool includeBackground = false,
  bool monochrome = false,
}) {
  final canvas = image.Image(width: size, height: size, numChannels: 4);
  image.fill(canvas, color: _color(0, 0, 0, 0));
  int scale(num value) => (value * size / 1024).round();

  if (includeBackground) {
    image.fillRect(
      canvas,
      x1: scale(32),
      y1: scale(32),
      x2: scale(992),
      y2: scale(992),
      radius: scale(232),
      color: _tupleColor(_navy),
    );
  }

  final rackColor = _tupleColor(monochrome ? _surface : _surface);
  final detailColor = _tupleColor(monochrome ? _surface : _navy);
  final green = _tupleColor(monochrome ? _surface : _green);
  final cyan = _tupleColor(monochrome ? _surface : _cyan);
  for (final top in [250, 440, 630]) {
    image.fillRect(
      canvas,
      x1: scale(224),
      y1: scale(top),
      x2: scale(800),
      y2: scale(top + 144),
      radius: scale(44),
      color: rackColor,
    );
    if (!monochrome) {
      image.fillRect(
        canvas,
        x1: scale(302),
        y1: scale(top + 53),
        x2: scale(546),
        y2: scale(top + 75),
        radius: scale(11),
        color: detailColor,
      );
    }
    image.fillCircle(
      canvas,
      x: scale(666),
      y: scale(top + 72),
      radius: scale(28),
      color: green,
      antialias: true,
    );
    image.fillCircle(
      canvas,
      x: scale(732),
      y: scale(top + 72),
      radius: scale(28),
      color: cyan,
      antialias: true,
    );
  }
  return canvas;
}

image.ColorRgba8 _tupleColor((int, int, int, int) value) =>
    _color(value.$1, value.$2, value.$3, value.$4);

image.ColorRgba8 _color(int red, int green, int blue, int alpha) =>
    image.ColorRgba8(red, green, blue, alpha);

void _writePng(Uri uri, image.Image value) =>
    _writeBytes(uri, image.encodePng(value));

void _writeBytes(Uri uri, List<int> bytes) {
  final file = File.fromUri(uri);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes, flush: true);
}
