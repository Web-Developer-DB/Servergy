import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:servergy/core/models.dart';
import 'package:servergy/core/services.dart';

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
}
