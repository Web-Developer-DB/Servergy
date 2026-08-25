// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _profileKey = 'servergy.profile.v3';
const _profileV2Key = 'servergy.profile.v2';
const _legacyProfileKey = 'servergy.profile.v1';
const _passwordKey = 'servergy.password.v1';
const _privateKeyKey = 'servergy.private-key.v1';
const _hostKeyKey = 'servergy.host-key.v3';
const _oldHostKeyKey = 'servergy.host-key.v2';
const _diagnosticsKey = 'servergy.diagnostics.v1';

/// Small platform bridge for Android's local-network permission and its Wi-Fi
/// multicast filter. Desktop platforms do not need either operation.
class LocalNetworkAccess {
  static const _channel = MethodChannel('dev.servergy.servergy/local_network');

  Future<bool> ensureAllowed() async {
    if (!Platform.isAndroid) return true;
    return (await _channel.invokeMethod<bool>('ensureAccess')) ?? false;
  }

  Future<void> acquireMulticastLock() async {
    if (Platform.isAndroid) await _channel.invokeMethod<void>('acquireMulticast');
  }

  Future<void> releaseMulticastLock() async {
    if (Platform.isAndroid) await _channel.invokeMethod<void>('releaseMulticast');
  }
}

/// A host key is tied to one endpoint, not merely to a display name.
class HostKeyTrust {
  const HostKeyTrust({
    required this.scope,
    required this.algorithm,
    required this.fingerprint,
  });

  final String scope;
  final String algorithm;
  final String fingerprint;

  Map<String, String> toJson() => <String, String>{
    'scope': scope,
    'algorithm': algorithm,
    'fingerprint': fingerprint,
  };

  static HostKeyTrust? fromJson(String raw) {
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      final scope = value['scope'] as String?;
      final algorithm = value['algorithm'] as String?;
      final fingerprint = value['fingerprint'] as String?;
      if (scope == null || algorithm == null || fingerprint == null) return null;
      if (!fingerprint.startsWith('SHA256:')) return null;
      return HostKeyTrust(
        scope: scope,
        algorithm: algorithm,
        fingerprint: fingerprint,
      );
    } catch (_) {
      return null;
    }
  }
}

abstract class ProfileStore {
  Future<ServerProfile?> loadProfile();
  Future<void> saveProfile(ServerProfile profile);
  Future<void> updatePassword(SecretUpdate update);
  Future<bool> hasPassword();
  Future<String?> password();
  Future<void> savePrivateKey(String? pem);
  Future<String?> privateKey();
  Future<HostKeyTrust?> hostKeyFor(ServerProfile profile);
  Future<void> trustHostKey(ServerProfile profile, HostKeyTrust trust);
  Future<void> clearHostKey();
  Future<List<DiagnosticEvent>> diagnostics();
  Future<void> addDiagnostic(DiagnosticEvent event);
}

/// Persists only non-secret profile data in preferences. Credentials and host
/// trust records never leave the system-provided secure storage.
class SettingsStore implements ProfileStore {
  SettingsStore({
    SharedPreferencesAsync? preferences,
    FlutterSecureStorage? secrets,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _secrets = secrets ?? const FlutterSecureStorage();

  final SharedPreferencesAsync _preferences;
  final FlutterSecureStorage _secrets;

  @override
  Future<ServerProfile?> loadProfile() async {
    final current = await _preferences.getString(_profileKey);
    if (current != null) return ServerProfile.fromJson(current);
    final v2 = await _preferences.getString(_profileV2Key);
    final legacy = v2 ?? await _preferences.getString(_legacyProfileKey);
    final profile = legacy == null ? null : ServerProfile.fromJson(legacy);
    if (profile != null) await saveProfile(profile);
    // V2 stored a non-comparable, double-encoded fingerprint. Force a safe
    // one-time verification rather than accepting it after the format change.
    await _secrets.delete(key: _oldHostKeyKey);
    return profile;
  }

  @override
  Future<void> saveProfile(ServerProfile profile) =>
      _preferences.setString(_profileKey, jsonEncode(profile.toJson()));

  @override
  Future<void> updatePassword(SecretUpdate update) => switch (update.kind) {
    SecretUpdateKind.keep => Future<void>.value(),
    SecretUpdateKind.delete => _secrets.delete(key: _passwordKey),
    SecretUpdateKind.replace => update.value == null || update.value!.isEmpty
        ? Future<void>.error(
            const ServergyError('Das SSH-Passwort darf nicht leer sein.'),
          )
        : _secrets.write(key: _passwordKey, value: update.value!),
  };

  @override
  Future<bool> hasPassword() async => (await password())?.isNotEmpty ?? false;

  @override
  Future<String?> password() => _secrets.read(key: _passwordKey);

  @override
  Future<void> savePrivateKey(String? pem) => pem == null || pem.isEmpty
      ? _secrets.delete(key: _privateKeyKey)
      : _secrets.write(key: _privateKeyKey, value: pem);

  @override
  Future<String?> privateKey() => _secrets.read(key: _privateKeyKey);

  @override
  Future<HostKeyTrust?> hostKeyFor(ServerProfile profile) async {
    final raw = await _secrets.read(key: _hostKeyKey);
    if (raw == null) return null;
    final trust = HostKeyTrust.fromJson(raw);
    return trust?.scope == _hostKeyScope(profile) ? trust : null;
  }

  @override
  Future<void> trustHostKey(ServerProfile profile, HostKeyTrust trust) =>
      _secrets.write(key: _hostKeyKey, value: jsonEncode(trust.toJson()));

  @override
  Future<void> clearHostKey() => _secrets.delete(key: _hostKeyKey);

  String _hostKeyScope(ServerProfile profile) =>
      '${profile.host.toLowerCase()}:${profile.sshPort}';

  @override
  Future<List<DiagnosticEvent>> diagnostics() async {
    final raw = await _preferences.getString(_diagnosticsKey);
    if (raw == null) return const [];
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      return values
          .whereType<Map<String, dynamic>>()
          .map(DiagnosticEvent.fromJson)
          .whereType<DiagnosticEvent>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> addDiagnostic(DiagnosticEvent event) async {
    final events = await diagnostics();
    // Events intentionally contain no endpoint, user name, MAC, or secret.
    final retained = <DiagnosticEvent>[...events, event];
    if (retained.length > 50) retained.removeRange(0, retained.length - 50);
    await _preferences.setString(
      _diagnosticsKey,
      jsonEncode(retained.map((item) => item.toJson()).toList()),
    );
  }
}

abstract class NetworkGateway {
  Future<bool> isReachable(ServerProfile profile);
  Future<void> wake(ServerProfile profile);
}

class NetworkService implements NetworkGateway {
  Uint8List magicPacket(MacAddress mac) {
    final packet = Uint8List(102)..fillRange(0, 6, 0xff);
    for (var repeat = 0; repeat < 16; repeat++) {
      packet.setRange(6 + repeat * 6, 12 + repeat * 6, mac.bytes);
    }
    return packet;
  }

  @override
  Future<bool> isReachable(ServerProfile profile) async {
    try {
      final socket = await Socket.connect(
        profile.host,
        profile.sshPort,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Future<void> wake(ServerProfile profile) async {
    final wol = profile.wakeOnLan;
    if (wol == null) {
      throw const ServergyError(
        'Wake-on-LAN ist noch nicht eingerichtet. Ergänze MAC-Adresse und Broadcast-Adresse in den Einstellungen.',
        code: 'wol_not_configured',
      );
    }
    final target = InternetAddress.tryParse(wol.broadcast);
    if (target == null || target.type != InternetAddressType.IPv4) {
      throw const ServergyError(
        'Die Broadcast-Adresse ist ungültig. Prüfe die Einstellungen.',
        code: 'invalid_broadcast',
      );
    }
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      final packet = magicPacket(wol.mac);
      for (var attempt = 0; attempt < 3; attempt++) {
        if (socket.send(packet, target, wol.port) != packet.length) {
          throw const ServergyError(
            'Wake-on-LAN konnte nicht gesendet werden. Prüfe das Heimnetz.',
            code: 'wol_send_failed',
          );
        }
        if (attempt < 2)
          await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } on SocketException {
      throw const ServergyError(
        'Das lokale Netzwerk ist nicht erreichbar. Verbinde dich mit Heimnetz oder VPN.',
        code: 'network_unavailable',
      );
    } finally {
      socket.close();
    }
  }
}

abstract class DiscoveryGateway {
  Future<NetworkScope> currentScope();
  Stream<DiscoveredServer> discover(
    NetworkScope scope, {
    required int port,
    required bool Function() isCancelled,
  });
}

/// Finds possible SSH endpoints only after an explicit user request.
class DiscoveryService implements DiscoveryGateway {
  DiscoveryService({NetworkInfo? networkInfo})
    : _networkInfo = networkInfo ?? NetworkInfo();

  final NetworkInfo _networkInfo;
  final LocalNetworkAccess _localAccess = LocalNetworkAccess();

  @override
  Future<NetworkScope> currentScope() async {
    final ip = await _networkInfo.getWifiIP();
    final mask = await _networkInfo.getWifiSubmask();
    final broadcast = await _networkInfo.getWifiBroadcast();
    if (!_isIpv4(ip) || !_isIpv4(mask)) {
      throw const ServergyError(
        'Das aktuelle lokale IPv4-Netz konnte nicht bestimmt werden. Gib Hostname oder IP-Adresse manuell ein.',
        code: 'network_scope_unavailable',
      );
    }
    final ipValue = _ipv4ToInt(ip!);
    final maskValue = _ipv4ToInt(mask!);
    final prefix = _prefixLength(maskValue);
    if (prefix == null) {
      throw const ServergyError(
        'Die Netzmaske ist ungültig. Gib Hostname oder IP-Adresse manuell ein.',
        code: 'network_scope_unavailable',
      );
    }
    // A /16 may contain 65,000 devices. Search only the local /24 slice so
    // the operation remains predictable and cannot become a broad scanner.
    final scanMask = prefix < 24 ? 0xffffff00 : maskValue;
    final network = ipValue & scanMask;
    final scanBroadcast = network | (~scanMask & 0xffffffff);
    final actualBroadcast = _isIpv4(broadcast)
        ? broadcast!
        : _intToIpv4((ipValue & maskValue) | (~maskValue & 0xffffffff));
    return NetworkScope(
      localAddress: ip,
      netmask: mask,
      broadcast: actualBroadcast,
      firstHost: network + 1,
      lastHost: scanBroadcast - 1,
      label: '${_intToIpv4(network)}/${prefix < 24 ? 24 : prefix}',
    );
  }

  @override
  Stream<DiscoveredServer> discover(
    NetworkScope scope, {
    required int port,
    required bool Function() isCancelled,
  }) {
    final controller = StreamController<DiscoveredServer>();
    final found = <String, DiscoveredServer>{};

    void emit(DiscoveredServer candidate) {
      final key = '${candidate.host}:${candidate.port}';
      final merged = found[key]?.merge(candidate) ?? candidate;
      found[key] = merged;
      controller.add(merged);
    }

    Future<void>(() async {
      try {
        await Future.wait<void>([
          _scanTcp(scope, port, isCancelled, emit),
          _scanMdns(isCancelled, emit),
        ]);
        await controller.close();
      } catch (error, stack) {
        controller.addError(error, stack);
        await controller.close();
      }
    });
    return controller.stream;
  }

  Future<void> _scanTcp(
    NetworkScope scope,
    int port,
    bool Function() cancelled,
    void Function(DiscoveredServer) emit,
  ) async {
    final local = _ipv4ToInt(scope.localAddress);
    const parallelism = 24;
    final addresses = <int>[
      for (var value = scope.firstHost; value <= scope.lastHost; value++)
        if (value != local) value,
    ];
    for (
      var start = 0;
      start < addresses.length && !cancelled();
      start += parallelism
    ) {
      final end = (start + parallelism).clamp(0, addresses.length);
      await Future.wait<void>([
        for (final value in addresses.sublist(start, end))
          _probeSsh(
            _intToIpv4(value),
            port,
            cancelled,
            emit,
            sources: const <DiscoverySource>{DiscoverySource.portScan},
          ),
      ]);
    }
  }

  Future<void> _probeSsh(
    String host,
    int port,
    bool Function() cancelled,
    void Function(DiscoveredServer) emit,
    {
    required Set<DiscoverySource> sources,
    String? serviceName,
  }
  ) async {
    if (cancelled()) return;
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 350),
      );
      final chunk = await socket.first.timeout(const Duration(milliseconds: 500));
      final banner = ascii
          .decode(chunk, allowInvalid: true)
          .split(RegExp(r'\r?\n'))
          .first;
      if (!banner.startsWith('SSH-') || cancelled()) return;
      emit(DiscoveredServer(
        host: host,
        port: port,
        banner: banner,
        serviceName: serviceName,
        sources: sources,
      ));
    } on SocketException {
      // Closed or filtered ports are expected during a local search.
    } on TimeoutException {
      // A non-SSH service that stays silent is not a useful candidate.
    } finally {
      socket?.destroy();
    }
  }

  Future<void> _scanMdns(
    bool Function() cancelled,
    void Function(DiscoveredServer) emit,
  ) async {
    final client = MDnsClient();
    try {
      // Older Android Wi-Fi stacks otherwise discard mDNS replies. The lock is
      // held only for this short foreground query and always released below.
      await _localAccess.acquireMulticastLock();
      await client.start();
      final ptrs = client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('_ssh._tcp.local'),
          )
          .timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close());
      await for (final ptr in ptrs) {
        if (cancelled()) return;
        final services = client
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
            .timeout(const Duration(milliseconds: 500), onTimeout: (sink) => sink.close());
        await for (final service in services) {
          final addresses = client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(service.target),
              )
              .timeout(const Duration(milliseconds: 500), onTimeout: (sink) => sink.close());
          await for (final address in addresses) {
            if (cancelled()) return;
            await _probeSsh(
              address.address.address,
              service.port,
              cancelled,
              emit,
              sources: const <DiscoverySource>{DiscoverySource.mdns},
              serviceName: ptr.domainName,
            );
          }
        }
      }
    } on SocketException {
      // mDNS may be blocked by a router; the TCP scan remains available.
    } finally {
      client.stop();
      await _localAccess.releaseMulticastLock();
    }
  }
}

bool _isIpv4(String? value) =>
    value != null &&
    InternetAddress.tryParse(value)?.type == InternetAddressType.IPv4;

int _ipv4ToInt(String value) => value
    .split('.')
    .fold<int>(0, (result, part) => (result << 8) | int.parse(part));

String _intToIpv4(int value) => List<String>.generate(
  4,
  (index) => '${(value >> (24 - index * 8)) & 0xff}',
).join('.');

int? _prefixLength(int mask) {
  var seenZero = false;
  var result = 0;
  for (var bit = 31; bit >= 0; bit--) {
    final one = (mask & (1 << bit)) != 0;
    if (one && seenZero) return null;
    if (one) result++;
    if (!one) seenZero = true;
  }
  return result;
}

abstract class SshGateway {
  Future<void> test(
    ServerProfile profile,
    SshCredentials credentials, {
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  });
  Future<void> poweroff(
    ServerProfile profile,
    SshCredentials credentials, {
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  });
}

class SshService implements SshGateway {
  SshService(this._store);

  final ProfileStore _store;

  @override
  Future<void> test(
    ServerProfile profile,
    SshCredentials credentials, {
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) async {
    final client = await _connect(profile, credentials, onUnknownHostKey);
    try {
      final result = await client.runWithResult('printf servergy-ok');
      if (result.exitCode != 0 || utf8.decode(result.stdout) != 'servergy-ok') {
        throw const ServergyError(
          'Der SSH-Test lieferte keine erwartete Antwort.',
          code: 'ssh_command_failed',
        );
      }
    } finally {
      await client.close();
    }
  }

  @override
  Future<void> poweroff(
    ServerProfile profile,
    SshCredentials credentials, {
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) async {
    final client = await _connect(profile, credentials, onUnknownHostKey);
    try {
      final result = await client.runWithResult(
        'sudo -n /usr/local/sbin/servergy-poweroff',
      );
      final acknowledgement = utf8.decode(result.stdout).trim();
      if (result.exitCode != 0 || acknowledgement != 'servergy-poweroff-accepted') {
        throw const ServergyError(
          'Der Server hat den Ausschaltbefehl nicht bestätigt. Prüfe die sudoers-Regel und den Servergy-Helper.',
          code: 'poweroff_not_acknowledged',
        );
      }
    } finally {
      await client.close();
    }
  }

  Future<SSHClient> _connect(
    ServerProfile profile,
    SshCredentials credentials,
    Future<bool> Function(String fingerprint) onUnknownHostKey,
  ) async {
    List<SSHKeyPair>? identities;
    if (credentials.hasKey) {
      try {
        identities = await compute(_decodeKeys, (
          pem: credentials.privateKeyPem!,
          passphrase: credentials.keyPassphrase,
        ));
      } catch (_) {
        throw const ServergyError(
          'Der SSH-Schlüssel konnte nicht gelesen werden. Prüfe Format oder Passphrase.',
          code: 'invalid_key',
        );
      }
    }
    final stored = await _store.hostKeyFor(profile);
    final socket = await SSHSocket.connect(
      profile.host,
      profile.sshPort,
      timeout: const Duration(seconds: 8),
    );
    final client = SSHClient(
      socket,
      username: profile.username,
      identities: identities,
      onPasswordRequest: credentials.hasPassword
          ? () => credentials.password!
          : null,
      handshakeTimeout: const Duration(seconds: 10),
      authTimeout: const Duration(seconds: 10),
      onVerifyHostKey: (type, fingerprint) async {
        // dartssh2 already provides ASCII text in OpenSSH's SHA256: format.
        final canonical = utf8.decode(fingerprint);
        if (stored == null) {
          final trusted = await onUnknownHostKey('$type $canonical');
          if (trusted) {
            await _store.trustHostKey(
              profile,
              HostKeyTrust(
                scope: '${profile.host.toLowerCase()}:${profile.sshPort}',
                algorithm: type,
                fingerprint: canonical,
              ),
            );
          }
          return trusted;
        }
        if (stored.algorithm != type || stored.fingerprint != canonical) {
          throw const ServergyError(
            'Der SSH-Host-Key hat sich geändert. Verbindung blockiert; vergleiche den Fingerprint.',
            code: 'host_key_changed',
          );
        }
        return true;
      },
    );
    await client.authenticated;
    return client;
  }
}

List<SSHKeyPair> _decodeKeys(({String pem, String? passphrase}) input) =>
    SSHKeyPair.fromPem(input.pem, input.passphrase);
