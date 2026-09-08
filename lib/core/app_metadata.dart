import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Product metadata comes from the installed application package so the UI
/// never needs to maintain a second copy of the version declared in pubspec.
/// Display-safe metadata derived from the installed package at runtime.
///
/// This is intentionally separate from [ServerProfile]: support information
/// describes the application build, never the configured homeserver.
class AppMetadata {
  static const productName = 'Servergy';

  const AppMetadata({
    required this.name,
    required this.version,
    required this.build,
    required this.releaseChannel,
    required this.platform,
  });

  final String name;
  final String version;
  final String build;
  final String releaseChannel;
  final String platform;

  String get versionLabel =>
      build.isEmpty || build == '–' ? version : '$version (Build $build)';

  String get supportText =>
      '$name\nVersion: $version\n'
      'Build: $build\nKanal: $releaseChannel\nPlattform: $platform';

  factory AppMetadata.fromPackageInfo(PackageInfo info) {
    final prerelease = info.version.split('-').skip(1).join('-');
    final channel = prerelease.isEmpty
        ? 'Stabil'
        : '${prerelease.split('.').first[0].toUpperCase()}'
              '${prerelease.split('.').first.substring(1)}';
    return AppMetadata(
      // Linux reports the lower-case Dart package name in version.json. Keep
      // support information aligned with the installed Android/Windows brand
      // without maintaining any version information outside package metadata.
      name: _productDisplayName(info.appName),
      version: info.version,
      build: info.buildNumber,
      releaseChannel: channel,
      platform: Platform.operatingSystem,
    );
  }

  /// Widget tests do not register the platform plugin. The fallback avoids
  /// leaking a hard-coded release version into the product UI.
  factory AppMetadata.unavailable() => AppMetadata(
    name: productName,
    version: 'Nicht verfügbar',
    build: '–',
    releaseChannel: 'Entwicklung',
    platform: Platform.operatingSystem,
  );

  static String _productDisplayName(String packageName) {
    final value = packageName.trim();
    return value.isEmpty || value.toLowerCase() == productName.toLowerCase()
        ? productName
        : value;
  }
}

/// Lazily loads package metadata and supplies a test-safe fallback when the
/// platform plugin is unavailable (for example in a widget test).
final appMetadataProvider = FutureProvider<AppMetadata>((ref) async {
  try {
    return AppMetadata.fromPackageInfo(await PackageInfo.fromPlatform());
  } catch (_) {
    return AppMetadata.unavailable();
  }
});
