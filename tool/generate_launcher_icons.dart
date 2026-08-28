// Generates every binary launcher asset from the approved Servergy brand
// lockup. Run with `dart run tool/generate_launcher_icons.dart` after
// replacing assets/branding/servergy-brand-lockup.png.
//
// The supplied lockup contains the app tile and its wordmark on a preview
// checkerboard. This tool deterministically isolates the tile, turns its
// rounded outer corners transparent, and creates every platform derivative.
// The source lockup is not bundled with the Flutter application.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as image;

const _brandLockup = 'assets/branding/servergy-brand-lockup.png';
const _masterSize = 1024;
// Android adaptive icons may mask and crop the outer 18 dp of a 108 dp
// foreground layer. Keep every meaningful part of the Servergy mark in the
// central safe zone so launchers such as MIUI do not cut off either arrow.
const _androidAdaptiveForegroundScale = .72;

void main() {
  final root = Directory.current;
  final master = _loadMaster(root);
  final foreground = _makeAndroidAdaptiveForeground(master);
  final monochrome = _makeMonochrome(foreground);

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
      _resize(master, entry.value),
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

  final ico = _resize(master, 16);
  for (final size in [24, 32, 48, 64, 128, 256]) {
    ico.addFrame(_resize(master, size));
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
      _resize(master, size),
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

  stdout.writeln('Generated Android, Windows, and Linux launcher icons.');
}

image.Image _loadMaster(Directory root) {
  final sourceFile = File.fromUri(root.uri.resolve(_brandLockup));
  if (!sourceFile.existsSync()) {
    throw StateError('Approved brand lockup is missing: ${sourceFile.path}');
  }
  final source = image.decodePng(sourceFile.readAsBytesSync());
  if (source == null) {
    throw StateError(
      'Unable to decode approved brand lockup: ${sourceFile.path}',
    );
  }

  final extractedTile = _extractTile(source);
  return _resize(extractedTile, _masterSize);
}

image.Image _extractTile(image.Image source) {
  final bounds = _findNavyTileBounds(source);
  final side = math.max(bounds.width, bounds.height);
  final tile = image.copyCrop(
    source,
    x: bounds.left,
    y: bounds.top,
    width: bounds.width,
    height: bounds.height,
  );
  final square = image.Image(width: side, height: side, numChannels: 4);
  image.fill(square, color: image.ColorRgba8(0, 0, 0, 0));
  final insetX = ((side - tile.width) / 2).floor();
  final insetY = ((side - tile.height) / 2).floor();
  for (var y = 0; y < tile.height; y++) {
    for (var x = 0; x < tile.width; x++) {
      final pixel = tile.getPixel(x, y);
      square.setPixelRgba(
        x + insetX,
        y + insetY,
        _byte(pixel.r),
        _byte(pixel.g),
        _byte(pixel.b),
        _byte(pixel.a),
      );
    }
  }

  // The supplied file is an RGB preview, so its checkerboard is baked into
  // the pixels. A rounded mask preserves the approved dark tile while making
  // only the outside corners transparent for launcher use.
  return _maskRoundedCorners(square, radius: side * 0.26);
}

_Bounds _findNavyTileBounds(image.Image source) {
  var left = source.width;
  var top = source.height;
  var right = -1;
  var bottom = -1;

  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (!_isNavy(source.getPixel(x, y))) continue;
      left = math.min(left, x);
      top = math.min(top, y);
      right = math.max(right, x);
      bottom = math.max(bottom, y);
    }
  }

  if (right < 0 || bottom < 0) {
    throw StateError(
      'Unable to locate the navy app tile in the approved lockup.',
    );
  }
  return _Bounds(left, top, right, bottom);
}

image.Image _maskRoundedCorners(image.Image source, {required double radius}) {
  final result = image.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      final roundedAlpha = _roundedRectAlpha(
        x + 0.5,
        y + 0.5,
        source.width.toDouble(),
        source.height.toDouble(),
        radius,
      );
      final alpha = (_byte(pixel.a) * roundedAlpha / 255).round();
      final detail = _isApprovedMarkDetail(
        pixel,
        x,
        y,
        source.width,
        source.height,
      );
      result.setPixelRgba(
        x,
        y,
        detail ? _byte(pixel.r) : 6,
        detail ? _byte(pixel.g) : 41,
        detail ? _byte(pixel.b) : 59,
        alpha,
      );
    }
  }
  return result;
}

int _roundedRectAlpha(
  double x,
  double y,
  double width,
  double height,
  double radius,
) {
  final halfWidth = width / 2;
  final halfHeight = height / 2;
  final dx = math.max((x - halfWidth).abs() - (halfWidth - radius), 0.0);
  final dy = math.max((y - halfHeight).abs() - (halfHeight - radius), 0.0);
  final distance = math.sqrt(dx * dx + dy * dy) - radius;
  return _byte((0.5 - distance).clamp(0.0, 1.0) * 255);
}

image.Image _makeAndroidAdaptiveForeground(image.Image master) {
  final isolatedMark = image.Image(
    width: master.width,
    height: master.height,
    numChannels: 4,
  );
  for (var y = 0; y < master.height; y++) {
    for (var x = 0; x < master.width; x++) {
      final pixel = master.getPixel(x, y);
      final alpha = _byte(pixel.a);
      isolatedMark.setPixelRgba(
        x,
        y,
        _byte(pixel.r),
        _byte(pixel.g),
        _byte(pixel.b),
        alpha == 0 || _isNavy(pixel) ? 0 : alpha,
      );
    }
  }

  final foreground = image.Image(
    width: master.width,
    height: master.height,
    numChannels: 4,
  );
  image.fill(foreground, color: image.ColorRgba8(0, 0, 0, 0));
  final scaledSize = (master.width * _androidAdaptiveForegroundScale).round();
  final inset = (master.width - scaledSize) ~/ 2;
  image.compositeImage(
    foreground,
    _resize(isolatedMark, scaledSize),
    dstX: inset,
    dstY: inset,
  );
  return foreground;
}

image.Image _makeMonochrome(image.Image foreground) {
  final monochrome = image.Image(
    width: foreground.width,
    height: foreground.height,
    numChannels: 4,
  );
  for (var y = 0; y < foreground.height; y++) {
    for (var x = 0; x < foreground.width; x++) {
      final alpha = _byte(foreground.getPixel(x, y).a);
      monochrome.setPixelRgba(x, y, 255, 255, 255, alpha);
    }
  }
  return monochrome;
}

image.Image _resize(image.Image source, int size) => image.copyResize(
  source,
  width: size,
  height: size,
  interpolation: image.Interpolation.cubic,
);

bool _isNavy(image.Pixel pixel) {
  final red = _byte(pixel.r);
  final green = _byte(pixel.g);
  final blue = _byte(pixel.b);
  return red < 80 &&
      green < 110 &&
      blue < 130 &&
      green - red > 12 &&
      blue - green > 6;
}

bool _isApprovedMarkDetail(
  image.Pixel pixel,
  int x,
  int y,
  int width,
  int height,
) {
  final red = _byte(pixel.r);
  final green = _byte(pixel.g);
  final blue = _byte(pixel.b);
  final brightest = math.max(red, math.max(green, blue));
  final darkest = math.min(red, math.min(green, blue));
  final coloredElement = brightest > 90 && brightest - darkest >= 25;
  final serverBay =
      brightest > 145 &&
      darkest > 105 &&
      x >= width * .17 &&
      x <= width * .76 &&
      y >= height * .25 &&
      y <= height * .78;
  return coloredElement || serverBay;
}

int _byte(num value) => value.round().clamp(0, 255).toInt();

class _Bounds {
  const _Bounds(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left + 1;
  int get height => bottom - top + 1;
  double get centerX => (left + right + 1) / 2;
  double get centerY => (top + bottom + 1) / 2;
}

void _writePng(Uri uri, image.Image value) =>
    _writeBytes(uri, image.encodePng(value));

void _writeBytes(Uri uri, List<int> bytes) {
  final file = File.fromUri(uri);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes, flush: true);
}
