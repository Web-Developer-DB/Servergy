// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
    if (Platform.isAndroid)
      await _channel.invokeMethod<void>('acquireMulticast');
  }

  Future<void> releaseMulticastLock() async {
    if (Platform.isAndroid)
      await _channel.invokeMethod<void>('releaseMulticast');
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
      if (scope == null || algorithm == null || fingerprint == null)
        return null;
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

/// The only three files the app may install on a server. They are constants,
/// rather than user-editable templates, so provisioning can never turn into a
/// remote shell or arbitrary file deployment feature.
class ServergyProvisioningPayload {
  const ServergyProvisioningPayload._();

  static const helperPath = '/usr/local/sbin/servergy-poweroff';
  static const servicePath = '/etc/systemd/system/servergy-poweroff.service';
  static const sudoersPath = '/etc/sudoers.d/servergy';

  static const helper = '''#!/bin/sh
set -eu
/usr/bin/systemctl start --no-block servergy-poweroff.service
printf '%s\\n' 'servergy-poweroff-accepted'
''';

  static const service = '''[Unit]
Description=Power off this host after a Servergy request

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 2
ExecStart=/usr/bin/systemctl poweroff --no-block
''';

  // These values are deliberately literals. If an accidental source change
  // alters one of the privileged payloads, provisioning stops before a byte
  // reaches the server.
  static const _helperSha256 =
      'b1581599fd33f4b41a8c9c724a90ee3d2508b7e9f1ec899cfd06c2d21b4df3b7';
  static const _serviceSha256 =
      'cdf63afec0a31981461a4ad46e10d9a6385af664638ea465404263fae526e563';

  static bool get hasExpectedIntegrity =>
      sha256.convert(utf8.encode(helper)).toString() == _helperSha256 &&
      sha256.convert(utf8.encode(service)).toString() == _serviceSha256;

  static String sudoersFor(String username) {
    validateProvisioningUsername(username);
    return '$username ALL=(root) NOPASSWD: $helperPath${String.fromCharCode(10)}';
  }
}

/// Linux user names are inserted into a sudoers file. Rejecting whitespace,
/// punctuation, and shell-like syntax here is more reliable than attempting
/// to escape a value in a privileged configuration language.
String validateProvisioningUsername(String value) {
  final username = value.trim();
  if (!RegExp(r'^[a-z_][a-z0-9_-]{0,31}\$?$').hasMatch(username)) {
    throw const ServergyError(
      'Der SSH-Benutzername kann nicht sicher in eine sudoers-Regel übernommen werden. Richte den Helper mit der manuellen Anleitung ein.',
      code: 'provision_username_unsupported',
    );
  }
  return username;
}

abstract class ProfileStore {
  Future<ServerProfile?> loadProfile();
  Future<void> saveProfile(ServerProfile profile);

  /// Removes the one local connection profile and all secrets that belong to
  /// it. Diagnostics are deliberately retained because they are redacted and
  /// can still help explain a previous setup problem.
  Future<void> deleteConnection();
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
  Future<void> deleteConnection() async {
    // Remove every known public profile version. This also prevents a deleted
    // V3 profile from being recreated from a leftover migration source.
    await Future.wait<void>([
      _preferences.remove(_profileKey),
      _preferences.remove(_profileV2Key),
      _preferences.remove(_legacyProfileKey),
      // Password, private key, and host-key trust are all scoped to this one
      // Servergy v1 connection and must never survive its deletion.
      _secrets.delete(key: _passwordKey),
      _secrets.delete(key: _privateKeyKey),
      _secrets.delete(key: _hostKeyKey),
      _secrets.delete(key: _oldHostKeyKey),
    ]);
  }

  @override
  Future<void> updatePassword(SecretUpdate update) => switch (update.kind) {
    SecretUpdateKind.keep => Future<void>.value(),
    SecretUpdateKind.delete => _secrets.delete(key: _passwordKey),
    SecretUpdateKind.replace =>
      update.value == null || update.value!.isEmpty
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

/// Supplies only the active local IPv4 range. It is shared by discovery and
/// WOL setup so both features use the same, bounded broadcast calculation.
abstract interface class NetworkScopeGateway {
  Future<NetworkScope> currentScope();
}

abstract class DiscoveryGateway implements NetworkScopeGateway {
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
    void Function(DiscoveredServer) emit, {
    required Set<DiscoverySource> sources,
    String? serviceName,
  }) async {
    if (cancelled()) return;
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 350),
      );
      final chunk = await socket.first.timeout(
        const Duration(milliseconds: 500),
      );
      final banner = ascii
          .decode(chunk, allowInvalid: true)
          .split(RegExp(r'\r?\n'))
          .first;
      if (!banner.startsWith('SSH-') || cancelled()) return;
      emit(
        DiscoveredServer(
          host: host,
          port: port,
          banner: banner,
          serviceName: serviceName,
          sources: sources,
        ),
      );
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
          .timeout(
            const Duration(seconds: 2),
            onTimeout: (sink) => sink.close(),
          );
      await for (final ptr in ptrs) {
        if (cancelled()) return;
        final services = client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )
            .timeout(
              const Duration(milliseconds: 500),
              onTimeout: (sink) => sink.close(),
            );
        await for (final service in services) {
          final addresses = client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(service.target),
              )
              .timeout(
                const Duration(milliseconds: 500),
                onTimeout: (sink) => sink.close(),
              );
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
  Future<WakeOnLanCandidate> inspectWakeOnLan(
    ServerProfile profile,
    SshCredentials credentials, {
    required String broadcast,
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  });
}

/// Kept separate from [SshGateway] so normal status checks and power actions
/// cannot accidentally gain installation capabilities. Implementations must
/// only install [ServergyProvisioningPayload]'s fixed files.
abstract class ServerProvisioningGateway {
  Future<void> provisionPoweroffHelper(
    ServerProfile profile,
    SshCredentials credentials, {
    required String sudoPassword,
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
    required bool Function() isCancelled,
  });

  Future<void> removePoweroffHelper(
    ServerProfile profile,
    SshCredentials credentials, {
    required String sudoPassword,
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
    required bool Function() isCancelled,
  });
}

class SshService implements SshGateway, ServerProvisioningGateway {
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
      if (result.exitCode != 0 ||
          acknowledgement != 'servergy-poweroff-accepted') {
        // stderr is inspected only to choose a safe, concrete next step. It
        // is never stored in diagnostics because server output could contain
        // environment-specific information.
        throw _poweroffFailure(
          exitCode: result.exitCode ?? -1,
          stderr: utf8.decode(result.stderr),
          acknowledgement: acknowledgement,
        );
      }
    } finally {
      await client.close();
    }
  }

  /// Installs the immutable, least-privilege shutdown protocol. The temporary
  /// sudo password is sent only through the SSH channel's stdin by
  /// [_runSudo]; it is never interpolated into a command or persisted.
  @override
  Future<void> provisionPoweroffHelper(
    ServerProfile profile,
    SshCredentials credentials, {
    required String sudoPassword,
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
    required bool Function() isCancelled,
  }) async {
    final username = validateProvisioningUsername(profile.username);
    if (!ServergyProvisioningPayload.hasExpectedIntegrity) {
      throw const ServergyError(
        'Die integrierten Servergy-Dateien konnten nicht geprüft werden. Aktualisiere die App und versuche es erneut.',
        code: 'provision_payload_invalid',
      );
    }
    if (sudoPassword.isEmpty) {
      throw const ServergyError(
        'Gib das sudo-Passwort für die einmalige Servervorbereitung ein.',
        code: 'provision_password_required',
      );
    }

    final client = await _connect(profile, credentials, onUnknownHostKey);
    SftpClient? sftp;
    String? stagingDirectory;
    try {
      _ensureProvisioningActive(isCancelled);
      await _requireSudo(client, sudoPassword, const ['/usr/bin/id', '-u']);
      _ensureProvisioningActive(isCancelled);

      sftp = await client.sftp();
      final home = await sftp.absolute('.');
      stagingDirectory = '$home/.servergy-provisioning-${_stagingNonce()}';
      await sftp.mkdir(
        stagingDirectory,
        SftpFileAttrs(
          mode: SftpFileMode(
            userRead: true,
            userWrite: true,
            userExecute: true,
            groupRead: false,
            groupWrite: false,
            groupExecute: false,
            otherRead: false,
            otherWrite: false,
            otherExecute: false,
          ),
        ),
      );
      await _uploadStagedFile(
        sftp,
        '$stagingDirectory/helper',
        ServergyProvisioningPayload.helper,
      );
      await _uploadStagedFile(
        sftp,
        '$stagingDirectory/service',
        ServergyProvisioningPayload.service,
      );
      await _uploadStagedFile(
        sftp,
        '$stagingDirectory/sudoers',
        ServergyProvisioningPayload.sudoersFor(username),
      );
      _ensureProvisioningActive(isCancelled);

      // Check sudoers before placing it below /etc. A syntax error must never
      // be allowed to make a system's sudo configuration harder to recover.
      await _requireSudo(client, sudoPassword, [
        '/usr/sbin/visudo',
        '-cf',
        '$stagingDirectory/sudoers',
      ]);
      await _requireSudo(client, sudoPassword, [
        '/usr/bin/install',
        '-o',
        'root',
        '-g',
        'root',
        '-m',
        '0755',
        '$stagingDirectory/helper',
        ServergyProvisioningPayload.helperPath,
      ]);
      await _requireSudo(client, sudoPassword, [
        '/usr/bin/install',
        '-o',
        'root',
        '-g',
        'root',
        '-m',
        '0644',
        '$stagingDirectory/service',
        ServergyProvisioningPayload.servicePath,
      ]);
      await _requireSudo(client, sudoPassword, const [
        '/usr/bin/systemctl',
        'daemon-reload',
      ]);
      _ensureProvisioningActive(isCancelled);

      await _verifyInstalledPayload(client, sudoPassword);
      await _requireSudo(client, sudoPassword, [
        '/usr/bin/install',
        '-o',
        'root',
        '-g',
        'root',
        '-m',
        '0440',
        '$stagingDirectory/sudoers',
        ServergyProvisioningPayload.sudoersPath,
      ]);
      await _requireSudo(client, sudoPassword, const [
        '/usr/sbin/visudo',
        '-cf',
        ServergyProvisioningPayload.sudoersPath,
      ]);
    } on ServergyError {
      rethrow;
    } catch (_) {
      throw const ServergyError(
        'Die Servervorbereitung konnte nicht vollständig abgeschlossen werden. Prüfe die manuelle Anleitung auf dem Server.',
        code: 'provision_failed',
      );
    } finally {
      if (sftp != null && stagingDirectory != null) {
        await _removeStaging(sftp, stagingDirectory);
      }
      await sftp?.close();
      await client.close();
    }
  }

  /// Reverses only the three fixed Servergy shutdown files. It deliberately
  /// does not alter SSH access, WOL settings, users, groups, or any unrelated
  /// sudo rules. The restricted sudoers file is removed last so a failed
  /// cleanup leaves the least disruptive recoverable state on the server.
  @override
  Future<void> removePoweroffHelper(
    ServerProfile profile,
    SshCredentials credentials, {
    required String sudoPassword,
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
    required bool Function() isCancelled,
  }) async {
    if (sudoPassword.isEmpty) {
      throw const ServergyError(
        'Gib das sudo-Passwort ein, um die Servergy-Ausschaltdateien zu entfernen.',
        code: 'removal_password_required',
      );
    }
    final client = await _connect(profile, credentials, onUnknownHostKey);
    try {
      _ensureProvisioningActive(isCancelled);
      await _requireSudo(
        client,
        sudoPassword,
        const ['/usr/bin/id', '-u'],
        removal: true,
      );
      _ensureProvisioningActive(isCancelled);
      await _requireSudo(client, sudoPassword, const [
        '/usr/bin/rm',
        '-f',
        ServergyProvisioningPayload.helperPath,
      ], removal: true);
      await _requireSudo(client, sudoPassword, const [
        '/usr/bin/rm',
        '-f',
        ServergyProvisioningPayload.servicePath,
      ], removal: true);
      await _requireSudo(client, sudoPassword, const [
        '/usr/bin/systemctl',
        'daemon-reload',
      ], removal: true);
      _ensureProvisioningActive(isCancelled);
      // Remove the permission last. This operation intentionally requires a
      // normally sudo-capable administrator and never relies on the narrow
      // Servergy rule that is about to be deleted.
      await _requireSudo(client, sudoPassword, const [
        '/usr/bin/rm',
        '-f',
        ServergyProvisioningPayload.sudoersPath,
      ], removal: true);
    } on ServergyError {
      rethrow;
    } catch (_) {
      throw const ServergyError(
        'Die Servergy-Ausschaltdateien konnten nicht vollständig entfernt werden. Prüfe die manuelle Anleitung auf dem Server.',
        code: 'removal_failed',
      );
    } finally {
      await client.close();
    }
  }

  @override
  Future<WakeOnLanCandidate> inspectWakeOnLan(
    ServerProfile profile,
    SshCredentials credentials, {
    required String broadcast,
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) async {
    final client = await _connect(profile, credentials, onUnknownHostKey);
    try {
      // This is a constant Debian/Linux command. No user-provided host,
      // interface, path, or argument becomes part of the remote command.
      final result = await client.runWithResult(_wakeOnLanInspectCommand);
      if (result.exitCode != 0) {
        throw const ServergyError(
          'Der aktive Netzwerkadapter des Servers konnte nicht bestimmt werden. Richte Wake-on-LAN manuell ein.',
          code: 'wol_adapter_unavailable',
        );
      }
      final (interfaceName, mac) = parseWakeOnLanInspection(
        utf8.decode(result.stdout),
      );
      return WakeOnLanCandidate(
        interfaceName: interfaceName,
        settings: WakeOnLanSettings(
          mac: mac,
          broadcast: validateBroadcast(broadcast),
          port: 9,
        ),
      );
    } finally {
      await client.close();
    }
  }

  Future<void> _uploadStagedFile(
    SftpClient sftp,
    String path,
    String contents,
  ) async {
    final file = await sftp.open(
      path,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.exclusive,
    );
    try {
      await file.writeBytes(Uint8List.fromList(utf8.encode(contents)));
    } finally {
      await file.close();
    }
  }

  Future<_SshCommandResult> _requireSudo(
    SSHClient client,
    String password,
    List<String> arguments, {
    bool removal = false,
  }
  ) async {
    final result = await _runSudo(client, password, arguments);
    if (result.exitCode == 0) return result;
    throw removal
        ? _removalFailure(result.stderr)
        : _provisioningFailure(result.stderr);
  }

  Future<_SshCommandResult> _runSudo(
    SSHClient client,
    String password,
    List<String> arguments,
  ) async {
    // Every element is constant or an internally generated staging path. The
    // quote routine still treats every argument as hostile, which protects
    // unusual remote home directories and makes the command auditable.
    final command = "sudo -S -p '' -- ${arguments.map(_shellQuote).join(' ')}";
    final session = await client.execute(command);
    final stdout = BytesBuilder(copy: false);
    final stderr = BytesBuilder(copy: false);
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    final stdoutSubscription = session.stdout.listen(
      stdout.add,
      onDone: stdoutDone.complete,
      onError: stdoutDone.completeError,
      cancelOnError: true,
    );
    final stderrSubscription = session.stderr.listen(
      stderr.add,
      onDone: stderrDone.complete,
      onError: stderrDone.completeError,
      cancelOnError: true,
    );
    try {
      // Sudo consumes the first line, then the invoked fixed program receives
      // EOF. The password is intentionally absent from [command].
      session.stdin.add(Uint8List.fromList(utf8.encode('$password\n')));
      await session.stdin.close();
      await Future.wait<void>([stdoutDone.future, stderrDone.future]);
      await session.done;
      return _SshCommandResult(
        exitCode: session.exitCode,
        stdout: utf8.decode(stdout.takeBytes()),
        stderr: utf8.decode(stderr.takeBytes()),
      );
    } catch (_) {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      session.close();
      rethrow;
    }
  }

  Future<void> _verifyInstalledPayload(
    SSHClient client,
    String password,
  ) async {
    final helperHash = await _requireSudo(client, password, const [
      '/usr/bin/sha256sum',
      ServergyProvisioningPayload.helperPath,
    ]);
    final serviceHash = await _requireSudo(client, password, const [
      '/usr/bin/sha256sum',
      ServergyProvisioningPayload.servicePath,
    ]);
    final helperStat = await _requireSudo(client, password, const [
      '/usr/bin/stat',
      '-c',
      '%U:%G:%a',
      ServergyProvisioningPayload.helperPath,
    ]);
    final serviceStat = await _requireSudo(client, password, const [
      '/usr/bin/stat',
      '-c',
      '%U:%G:%a',
      ServergyProvisioningPayload.servicePath,
    ]);
    if (helperHash.stdout.split(RegExp(r'\s+')).first !=
            ServergyProvisioningPayload._helperSha256 ||
        serviceHash.stdout.split(RegExp(r'\s+')).first !=
            ServergyProvisioningPayload._serviceSha256 ||
        helperStat.stdout.trim() != 'root:root:755' ||
        serviceStat.stdout.trim() != 'root:root:644') {
      throw const ServergyError(
        'Die installierten Servergy-Dateien konnten nicht sicher geprüft werden. Nutze die manuelle Anleitung auf dem Server.',
        code: 'provision_verification_failed',
      );
    }
  }

  Future<void> _removeStaging(SftpClient sftp, String directory) async {
    // Cleanup must not hide the original installation result. A disconnected
    // server is reported as a partial installation rather than as success.
    for (final name in const ['helper', 'service', 'sudoers']) {
      try {
        await sftp.remove('$directory/$name');
      } catch (_) {}
    }
    try {
      await sftp.rmdir(directory);
    } catch (_) {}
  }

  void _ensureProvisioningActive(bool Function() isCancelled) {
    if (isCancelled()) {
      throw const ServergyError(
        'Die Servervorbereitung wurde abgebrochen. Prüfe bei Bedarf die manuelle Anleitung.',
        code: 'provision_cancelled',
      );
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

class _SshCommandResult {
  const _SshCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int? exitCode;
  final String stdout;
  final String stderr;
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\\\"'\\\"'")}'";

String _stagingNonce() => List<String>.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

ServergyError _provisioningFailure(String stderr) {
  final output = stderr.toLowerCase();
  if (output.contains('sorry, try again') ||
      output.contains('incorrect password') ||
      output.contains('authentication failure')) {
    return const ServergyError(
      'Das sudo-Passwort wurde abgelehnt. Es wurde nicht gespeichert. Prüfe es und versuche die Servervorbereitung erneut.',
      code: 'provision_sudo_auth_failed',
    );
  }
  if (output.contains('not allowed to run sudo') ||
      output.contains('is not in the sudoers file') ||
      output.contains('not in sudoers')) {
    return const ServergyError(
      'Der SSH-Benutzer darf keine Administratorbefehle ausführen. Führe die manuelle Servergy-Anleitung an der Serverkonsole aus.',
      code: 'provision_sudo_denied',
    );
  }
  if (output.contains('no tty present') || output.contains('requiretty')) {
    return const ServergyError(
      'Der Server verlangt für sudo ein Terminal. Passe die sudo-Konfiguration manuell an und richte den Helper anschließend ein.',
      code: 'provision_sudo_tty_required',
    );
  }
  if (output.contains('sudo: command not found')) {
    return const ServergyError(
      'Auf dem Server fehlt sudo. Installiere sudo über die Serverkonsole und nutze danach die manuelle Anleitung.',
      code: 'provision_sudo_missing',
    );
  }
  if (output.contains('systemctl') && output.contains('not found')) {
    return const ServergyError(
      'Dieses System verwendet kein unterstütztes systemd. Richte das Herunterfahren manuell ein.',
      code: 'provision_systemd_unavailable',
    );
  }
  return const ServergyError(
    'Die Servervorbereitung wurde vom Server abgelehnt. Prüfe sudo, systemd und die manuelle Anleitung.',
    code: 'provision_command_failed',
  );
}

ServergyError _removalFailure(String stderr) {
  final output = stderr.toLowerCase();
  if (output.contains('sorry, try again') ||
      output.contains('incorrect password') ||
      output.contains('authentication failure')) {
    return const ServergyError(
      'Das sudo-Passwort wurde abgelehnt. Die Servergy-Dateien wurden nicht entfernt.',
      code: 'removal_sudo_auth_failed',
    );
  }
  if (output.contains('not allowed to run sudo') ||
      output.contains('is not in the sudoers file') ||
      output.contains('not in sudoers')) {
    return const ServergyError(
      'Der SSH-Benutzer darf die Servergy-Dateien nicht entfernen. Nutze einen separat berechtigten Administratorzugang oder die Anleitung im README.',
      code: 'removal_sudo_denied',
    );
  }
  if (output.contains('no tty present') || output.contains('requiretty')) {
    return const ServergyError(
      'Der Server verlangt für sudo ein Terminal. Entferne die Dateien über einen Administratorzugang an der Serverkonsole.',
      code: 'removal_sudo_tty_required',
    );
  }
  return const ServergyError(
    'Die Servergy-Dateien konnten nicht vollständig entfernt werden. Prüfe die Anleitung im README.',
    code: 'removal_command_failed',
  );
}

List<SSHKeyPair> _decodeKeys(({String pem, String? passphrase}) input) =>
    SSHKeyPair.fromPem(input.pem, input.passphrase);

/// Maps the fixed shutdown helper's common failure modes to instructions a
/// homeserver owner can act on without exposing raw remote command output.
ServergyError _poweroffFailure({
  required int exitCode,
  required String stderr,
  required String acknowledgement,
}) {
  final output = stderr.toLowerCase();
  if (output.contains('sudo: command not found')) {
    return const ServergyError(
      'Auf dem Server fehlt sudo. Installiere sudo und richte danach den Servergy-Helper ein.',
      code: 'poweroff_sudo_missing',
    );
  }
  if (output.contains('not allowed to run sudo') ||
      output.contains('is not in the sudoers file') ||
      output.contains('not in sudoers')) {
    return const ServergyError(
      'Der SSH-Benutzer darf den Servergy-Helper nicht ausführen. Prüfe die sudoers-Regel in der Serveranleitung.',
      code: 'poweroff_sudo_denied',
    );
  }
  if (output.contains('a password is required') ||
      output.contains('no password was provided')) {
    return const ServergyError(
      'Die sudoers-Regel verlangt noch ein Passwort. Erlaube ausschließlich den Servergy-Helper mit NOPASSWD.',
      code: 'poweroff_sudo_password_required',
    );
  }
  if (output.contains('servergy-poweroff') &&
      (output.contains('not found') || output.contains('no such file'))) {
    return const ServergyError(
      'Der Servergy-Ausschalt-Helper fehlt auf dem Server. Richte ihn nach der Serveranleitung ein.',
      code: 'poweroff_helper_missing',
    );
  }
  if (exitCode == 0 && acknowledgement.isNotEmpty) {
    return const ServergyError(
      'Der Server verwendete keinen gültigen Servergy-Ausschalt-Helper. Prüfe dessen Ausgabe und die systemd-Unit.',
      code: 'poweroff_invalid_acknowledgement',
    );
  }
  return const ServergyError(
    'Der Server hat den Ausschaltbefehl nicht bestätigt. Prüfe den Servergy-Helper, die systemd-Unit und die sudoers-Regel.',
    code: 'poweroff_not_acknowledged',
  );
}

const _wakeOnLanInspectCommand = r'''set -eu
iface=$(/usr/sbin/ip -o route show default | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
test -n "$iface"
mac=$(cat "/sys/class/net/$iface/address")
printf 'servergy-wol-v1\t%s\t%s\n' "$iface" "$mac"''';

/// Accepts only the small protocol emitted by [_wakeOnLanInspectCommand].
/// Keeping the parser strict prevents command errors or banners from becoming
/// a silently stored WOL address.
(String, MacAddress) parseWakeOnLanInspection(String output) {
  final fields = output.trim().split('\t');
  if (fields.length != 3 || fields.first != 'servergy-wol-v1') {
    throw const ServergyError(
      'Der Server lieferte keine verwertbaren Wake-on-LAN-Daten. Richte Wake-on-LAN manuell ein.',
      code: 'wol_adapter_invalid_response',
    );
  }
  final interfaceName = fields[1];
  if (!RegExp(r'^[A-Za-z0-9_.:-]{1,15}$').hasMatch(interfaceName)) {
    throw const ServergyError(
      'Der Server lieferte einen ungültigen Netzwerkadapter. Richte Wake-on-LAN manuell ein.',
      code: 'wol_adapter_invalid_response',
    );
  }
  try {
    return (interfaceName, MacAddress.parse(fields[2]));
  } on ServergyError {
    throw const ServergyError(
      'Der Server lieferte keine gültige Wake-on-LAN-MAC-Adresse. Richte Wake-on-LAN manuell ein.',
      code: 'wol_mac_invalid',
    );
  }
}
