import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Product metadata comes from the installed application package so the UI
/// never needs to maintain a second copy of the version declared in pubspec.
class AppMetadata {
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

  String get versionLabel => build.isEmpty || build == '–'
      ? version
      : '$version (Build $build)';

  String get supportText => '$name\nVersion: $version\n'
      'Build: $build\nKanal: $releaseChannel\nPlattform: $platform';

  factory AppMetadata.fromPackageInfo(PackageInfo info) {
    final prerelease = info.version.split('-').skip(1).join('-');
    final channel = prerelease.isEmpty
        ? 'Stabil'
        : '${prerelease.split('.').first[0].toUpperCase()}'
              '${prerelease.split('.').first.substring(1)}';
    return AppMetadata(
      name: info.appName.isEmpty ? 'Servergy' : info.appName,
      version: info.version,
      build: info.buildNumber,
      releaseChannel: channel,
      platform: Platform.operatingSystem,
    );
  }

  /// Widget tests do not register the platform plugin. The fallback avoids
  /// leaking a hard-coded release version into the product UI.
  factory AppMetadata.unavailable() => AppMetadata(
    name: 'Servergy',
    version: 'Nicht verfügbar',
    build: '–',
    releaseChannel: 'Entwicklung',
    platform: Platform.operatingSystem,
  );
}

final appMetadataProvider = FutureProvider<AppMetadata>((ref) async {
  try {
    return AppMetadata.fromPackageInfo(await PackageInfo.fromPlatform());
  } catch (_) {
    return AppMetadata.unavailable();
  }
});
