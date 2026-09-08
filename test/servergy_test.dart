import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:servergy/core/appearance.dart';
import 'package:servergy/core/app_metadata.dart';
import 'package:servergy/core/language.dart';
import 'package:servergy/core/models.dart';
import 'package:servergy/core/services.dart';
import 'package:servergy/servergy_app.dart';

void main() {
  test('builds the standard 102 byte Wake-on-LAN packet', () {
    final mac = MacAddress.parse('AA:BB:CC:DD:EE:FF');
    final packet = NetworkService().magicPacket(mac);

    expect(packet, hasLength(102));
    expect(packet.take(6), everyElement(0xff));
    for (var repeat = 0; repeat < 16; repeat++) {
      expect(packet.sublist(6 + repeat * 6, 12 + repeat * 6), mac.bytes);
    }
  });

  test('normalizes supported MAC address spellings', () {
    expect(
      MacAddress.parse('aa-bb-cc-dd-ee-ff').toString(),
      'AA:BB:CC:DD:EE:FF',
    );
    expect(MacAddress.parse('aabbccddeeff').toString(), 'AA:BB:CC:DD:EE:FF');
  });

  test('rejects invalid, empty, and multicast MAC addresses', () {
    expect(
      () => MacAddress.parse('AA:BB:CC:DD:EE'),
      throwsA(isA<ServergyError>()),
    );
    expect(
      () => MacAddress.parse('00:00:00:00:00:00'),
      throwsA(isA<ServergyError>()),
    );
    expect(
      () => MacAddress.parse('01:00:5E:00:00:FB'),
      throwsA(isA<ServergyError>()),
    );
  });

  test('ignores malformed persisted server profiles', () {
    expect(ServerProfile.fromJson('{not json}'), isNull);
    expect(
      ServerProfile.fromJson(
        '{"name":"Server","host":"192.168.1.2","sshPort":22}',
      ),
      isNull,
    );
  });

  test('migrates a V1 profile to password authentication safely', () {
    final profile = ServerProfile.fromJson('''
      {"name":"Server","host":"192.168.1.2","sshPort":22,
       "username":"servergy","mac":"AA:BB:CC:DD:EE:FF",
       "broadcast":"192.168.1.255","wolPort":9,"rememberPassword":true}
    ''');

    expect(profile, isNotNull);
    expect(profile!.authenticationMode, AuthenticationMode.passwordOnly);
    expect(profile.toJson()['version'], 3);
    expect(profile.toJson(), isNot(contains('rememberPassword')));
    expect(profile.wakeOnLan?.mac.toString(), 'AA:BB:CC:DD:EE:FF');
  });

  test('allows a V3 SSH profile before Wake-on-LAN is configured', () {
    const profile = ServerProfile(
      name: 'Server',
      host: 'server.lan',
      sshPort: 22,
      username: 'servergy',
      authenticationMode: AuthenticationMode.passwordOnly,
    );

    final restored = ServerProfile.fromJson(jsonEncode(profile.toJson()));
    expect(restored, isNotNull);
    expect(restored!.canWake, isFalse);
    expect(restored.wakeOnLan, isNull);
  });

  test('serializes only configured Wake-on-LAN settings', () {
    final profile = ServerProfile(
      name: 'Server',
      host: '192.168.178.10',
      sshPort: 22,
      username: 'servergy',
      wakeOnLan: WakeOnLanSettings(
        mac: MacAddress.parse('AA:BB:CC:DD:EE:FF'),
        broadcast: '192.168.178.255',
        port: 9,
      ),
    );

    expect(profile.toJson()['wakeOnLan'], isA<Map<String, Object>>());
    expect(profile.canWake, isTrue);
  });

  test('accepts only the fixed Debian Wake-on-LAN inspection response', () {
    final (interfaceName, mac) = parseWakeOnLanInspection(
      'servergy-wol-v1\tenp3s0\tAA:BB:CC:DD:EE:FF\n',
    );

    expect(interfaceName, 'enp3s0');
    expect(mac.toString(), 'AA:BB:CC:DD:EE:FF');
  });

  test('rejects malformed Wake-on-LAN inspection responses', () {
    expect(
      () => parseWakeOnLanInspection('enp3s0\tAA:BB:CC:DD:EE:FF'),
      throwsA(isA<ServergyError>()),
    );
    expect(
      () => parseWakeOnLanInspection('servergy-wol-v1\tlo\t00:00:00:00:00:00'),
      throwsA(isA<ServergyError>()),
    );
    expect(
      () => parseWakeOnLanInspection(
        'servergy-wol-v1\tbad name\tAA:BB:CC:DD:EE:FF',
      ),
      throwsA(isA<ServergyError>()),
    );
  });

  test('expresses password writes without exposing a stored password', () {
    expect(const SecretUpdate.keep().kind, SecretUpdateKind.keep);
    expect(const SecretUpdate.delete().kind, SecretUpdateKind.delete);
    expect(const SecretUpdate.replace('secret').value, 'secret');
  });

  test(
    'provisioning payload is immutable and renders one narrow sudo rule',
    () {
      expect(ServergyProvisioningPayload.hasExpectedIntegrity, isTrue);
      expect(
        ServergyProvisioningPayload.sudoersFor('servergy'),
        'servergy ALL=(root) NOPASSWD: /usr/local/sbin/servergy-poweroff\n',
      );
      expect(ServergyProvisioningPayload.helper, contains('start --no-block'));
      expect(
        ServergyProvisioningPayload.helper,
        contains('servergy-poweroff-accepted'),
      );
      expect(
        ServergyProvisioningPayload.helper,
        isNot(contains('shutdown now')),
      );
    },
  );

  test('provisioning accepts only safe Linux user names for sudoers', () {
    expect(validateProvisioningUsername('servergy'), 'servergy');
    expect(validateProvisioningUsername('_service-2'), '_service-2');
    expect(
      () => validateProvisioningUsername('servergy ALL=(ALL) ALL'),
      throwsA(isA<ServergyError>()),
    );
    expect(
      () => validateProvisioningUsername('root; shutdown'),
      throwsA(isA<ServergyError>()),
    );
  });

  test('validates hosts, ports, and IPv4 broadcast addresses', () {
    expect(validateHost('server.lan'), 'server.lan');
    expect(
      () => validateHost('ssh://server.lan'),
      throwsA(isA<ServergyError>()),
    );
    expect(validatePort('65535', label: 'Port'), 65535);
    expect(
      () => validatePort('0', label: 'Port'),
      throwsA(isA<ServergyError>()),
    );
    expect(validateBroadcast('192.168.178.255'), '192.168.178.255');
    expect(
      () => validateBroadcast('2001:db8::1'),
      throwsA(isA<ServergyError>()),
    );
  });

  test('diagnostic export is structurally redacted', () {
    final event = DiagnosticEvent(
      at: DateTime(2026, 8, 25, 12),
      action: DiagnosticAction.sshTest,
      success: false,
      code: 'auth_denied',
      duration: const Duration(milliseconds: 250),
    );

    final line = event.toExportLine();
    expect(line, contains('sshTest'));
    expect(line, contains('auth_denied'));
    expect(line, isNot(contains('192.168')));
    expect(line, isNot(contains('password')));
  });

  test('derives the stable channel from installed package metadata', () {
    final metadata = AppMetadata.fromPackageInfo(
      PackageInfo(
        appName: 'servergy',
        packageName: 'dev.servergy.servergy',
        version: '0.1.0',
        buildNumber: '7',
      ),
    );

    expect(metadata.name, 'Servergy');
    expect(metadata.releaseChannel, 'Stabil');
    expect(metadata.versionLabel, '0.1.0 (Build 7)');
    expect(metadata.supportText, contains('Plattform:'));
    expect(metadata.supportText, isNot(contains('192.168.')));
  });

  test(
    'falls back to system mode for missing or invalid appearance values',
    () {
      expect(
        AppearancePreference.fromStorage(null),
        AppearancePreference.system,
      );
      expect(
        AppearancePreference.fromStorage('unexpected'),
        AppearancePreference.system,
      );
      expect(
        AppearancePreference.fromStorage('light'),
        AppearancePreference.light,
      );
      expect(
        AppearancePreference.fromStorage('dark'),
        AppearancePreference.dark,
      );
    },
  );

  test('appearance controller loads and persists the selected mode', () async {
    final store = _MemoryAppearanceStore(AppearancePreference.dark);
    final container = ProviderContainer(
      overrides: [appearanceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    container.read(appearanceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(appearanceProvider).preference,
      AppearancePreference.dark,
    );

    await container
        .read(appearanceProvider.notifier)
        .select(AppearancePreference.light);
    expect(store.saved, AppearancePreference.light);
    expect(
      container.read(appearanceProvider).preference,
      AppearancePreference.light,
    );

    final restoredContainer = ProviderContainer(
      overrides: [appearanceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(restoredContainer.dispose);
    restoredContainer.read(appearanceProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      restoredContainer.read(appearanceProvider).preference,
      AppearancePreference.light,
    );
  });

  test(
    'appearance controller restores the previous mode after save failure',
    () async {
      final store = _MemoryAppearanceStore(AppearancePreference.system)
        ..failSave = true;
      final container = ProviderContainer(
        overrides: [appearanceStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container
          .read(appearanceProvider.notifier)
          .select(AppearancePreference.dark);

      final state = container.read(appearanceProvider);
      expect(state.preference, AppearancePreference.system);
      expect(state.saving, isFalse);
      expect(state.error, 'Darstellung konnte nicht gespeichert werden.');
    },
  );

  test('language preference safely parses stored values', () {
    expect(LanguagePreference.fromStorage(null), LanguagePreference.system);
    expect(
      LanguagePreference.fromStorage('unexpected'),
      LanguagePreference.system,
    );
    expect(LanguagePreference.fromStorage('german'), LanguagePreference.german);
    expect(
      LanguagePreference.fromStorage('english'),
      LanguagePreference.english,
    );
  });

  test('system locale chooses German only for the de language code', () {
    const supported = [Locale('de'), Locale('en')];
    expect(
      resolveServergyLocale(const Locale('de', 'DE'), supported),
      const Locale('de'),
    );
    expect(
      resolveServergyLocale(const Locale('de', 'AT'), supported),
      const Locale('de'),
    );
    expect(
      resolveServergyLocale(const Locale('en', 'US'), supported),
      const Locale('en'),
    );
    expect(
      resolveServergyLocale(const Locale('fr', 'FR'), supported),
      const Locale('en'),
    );
    expect(resolveServergyLocale(null, supported), const Locale('en'));
  });

  test('language controller persists and restores a selection', () async {
    final store = _MemoryLanguageStore(LanguagePreference.german);
    final container = ProviderContainer(
      overrides: [languageStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    container.read(languageProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(languageProvider).preference,
      LanguagePreference.german,
    );

    await container
        .read(languageProvider.notifier)
        .select(LanguagePreference.english);
    expect(store.saved, LanguagePreference.english);

    final restored = ProviderContainer(
      overrides: [languageStoreProvider.overrideWithValue(store)],
    );
    addTearDown(restored.dispose);
    restored.read(languageProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      restored.read(languageProvider).preference,
      LanguagePreference.english,
    );
  });

  test(
    'language controller restores the previous value after save failure',
    () async {
      final store = _MemoryLanguageStore()..failSave = true;
      final container = ProviderContainer(
        overrides: [languageStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container
          .read(languageProvider.notifier)
          .select(LanguagePreference.english);

      final state = container.read(languageProvider);
      expect(state.preference, LanguagePreference.system);
      expect(state.saving, isFalse);
      expect(state.error, 'Die Sprache konnte nicht gespeichert werden.');
    },
  );
}

class _MemoryAppearanceStore implements AppearanceStore {
  _MemoryAppearanceStore([this.preference = AppearancePreference.system]);

  AppearancePreference preference;
  AppearancePreference? saved;
  bool failSave = false;

  @override
  Future<AppearancePreference> load() async => preference;

  @override
  Future<void> save(AppearancePreference value) async {
    if (failSave) throw StateError('write failed');
    saved = value;
    preference = value;
  }
}

class _MemoryLanguageStore implements LanguageStore {
  _MemoryLanguageStore([this.preference = LanguagePreference.system]);

  LanguagePreference preference;
  LanguagePreference? saved;
  bool failSave = false;

  @override
  Future<LanguagePreference> load() async => preference;

  @override
  Future<void> save(LanguagePreference value) async {
    if (failSave) throw StateError('write failed');
    saved = value;
    preference = value;
  }
}
