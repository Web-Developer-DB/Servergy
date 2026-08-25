import 'package:flutter_test/flutter_test.dart';
import 'package:servergy/servergy_app.dart';

void main() {
  test('builds the standard 102 byte Wake-on-LAN packet', () {
    final mac = MacAddress.parse('AA:BB:CC:DD:EE:FF');
    final packet = NetworkService().magicPacket(mac);

    expect(packet, hasLength(102));
    expect(packet.take(6), everyElement(0xff));
    expect(packet.sublist(6, 12), mac.bytes);
    expect(packet.sublist(96, 102), mac.bytes);
  });

  test('normalizes supported MAC address spellings', () {
    expect(
      MacAddress.parse('aa-bb-cc-dd-ee-ff').toString(),
      'AA:BB:CC:DD:EE:FF',
    );
    expect(MacAddress.parse('aabbccddeeff').toString(), 'AA:BB:CC:DD:EE:FF');
  });
}
