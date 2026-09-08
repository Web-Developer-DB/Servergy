// Builds the colourful README showcase from the unedited product screenshots.
// Run with: dart run tool/generate_readme_showcase.dart
import 'dart:io';

import 'package:image/image.dart' as image;

const _backgroundPath = 'assets/screenshots/showcase-aurora-background.png';
const _dashboardPath = 'assets/screenshots/dashboard-dark.png';
const _settingsPath = 'assets/screenshots/settings-dark.png';
const _outputPath = 'assets/screenshots/app-showcase.png';

void main() {
  final background = _read(_backgroundPath);
  final dashboard = _read(_dashboardPath);
  final settings = _read(_settingsPath);

  final canvas = image.copyResize(
    background,
    width: 1200,
    height: 760,
    interpolation: image.Interpolation.cubic,
  );
  final dashboardPreview = image.copyResize(
    dashboard,
    height: 615,
    interpolation: image.Interpolation.cubic,
  );
  final settingsPreview = image.copyResize(
    settings,
    height: 615,
    interpolation: image.Interpolation.cubic,
  );

  _placePreview(
    canvas,
    dashboardPreview,
    x: 207,
    y: 72,
    frame: image.ColorRgb8(77, 232, 184),
  );
  _placePreview(
    canvas,
    settingsPreview,
    x: 653,
    y: 72,
    frame: image.ColorRgb8(163, 125, 255),
  );

  File(_outputPath).writeAsBytesSync(image.encodePng(canvas, level: 6));
  stdout.writeln('Generated $_outputPath');
}

image.Image _read(String path) {
  final bytes = File(path).readAsBytesSync();
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Unable to decode $path');
  }
  return decoded;
}

void _placePreview(
  image.Image canvas,
  image.Image preview, {
  required int x,
  required int y,
  required image.Color frame,
}) {
  const outer = 12;
  const inner = 4;
  final width = preview.width + outer * 2;
  final height = preview.height + outer * 2;

  image.fillRect(
    canvas,
    x1: x + 12,
    y1: y + 16,
    x2: x + 12 + width - 1,
    y2: y + 16 + height - 1,
    color: image.ColorRgb8(3, 12, 25),
  );
  image.fillRect(
    canvas,
    x1: x,
    y1: y,
    x2: x + width - 1,
    y2: y + height - 1,
    color: frame,
  );
  image.fillRect(
    canvas,
    x1: x + inner,
    y1: y + inner,
    x2: x + width - inner - 1,
    y2: y + height - inner - 1,
    color: image.ColorRgb8(8, 23, 36),
  );
  image.compositeImage(canvas, preview, dstX: x + outer, dstY: y + outer);
}
