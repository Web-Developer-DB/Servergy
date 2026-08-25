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
    expect(profile.toJson()['version'], 2);
    expect(profile.toJson(), isNot(contains('rememberPassword')));
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
