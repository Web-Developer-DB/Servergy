// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const _profileKey = 'servergy.profile.v2';
const _legacyProfileKey = 'servergy.profile.v1';
const _passwordKey = 'servergy.password.v1';
const _privateKeyKey = 'servergy.private-key.v1';
const _hostKeyKey = 'servergy.host-key.v2';
const _diagnosticsKey = 'servergy.diagnostics.v1';

abstract class ProfileStore {
  Future<ServerProfile?> loadProfile();
  Future<void> saveProfile(ServerProfile profile);
  Future<void> savePassword(String? value);
  Future<String?> password();
  Future<void> savePrivateKey(String? pem);
  Future<String?> privateKey();
  Future<String?> hostKeyFor(ServerProfile profile);
  Future<void> trustHostKey(ServerProfile profile, String fingerprint);
  Future<List<DiagnosticEvent>> diagnostics();
  Future<void> addDiagnostic(DiagnosticEvent event);
}

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
    final v2 = await _preferences.getString(_profileKey);
    if (v2 != null) return ServerProfile.fromJson(v2);
    final legacy = await _preferences.getString(_legacyProfileKey);
    final profile = legacy == null ? null : ServerProfile.fromJson(legacy);
    if (profile != null) await saveProfile(profile);
    return profile;
  }

  @override
  Future<void> saveProfile(ServerProfile profile) =>
      _preferences.setString(_profileKey, jsonEncode(profile.toJson()));

  @override
  Future<void> savePassword(String? value) => value == null || value.isEmpty
      ? _secrets.delete(key: _passwordKey)
      : _secrets.write(key: _passwordKey, value: value);

  @override
  Future<String?> password() => _secrets.read(key: _passwordKey);

  @override
  Future<void> savePrivateKey(String? pem) => pem == null || pem.isEmpty
      ? _secrets.delete(key: _privateKeyKey)
      : _secrets.write(key: _privateKeyKey, value: pem);

  @override
  Future<String?> privateKey() => _secrets.read(key: _privateKeyKey);

  @override
  Future<String?> hostKeyFor(ServerProfile profile) async {
    final raw = await _secrets.read(key: _hostKeyKey);
    if (raw == null) return null;
    try {
      final record = jsonDecode(raw) as Map<String, dynamic>;
      return record['scope'] == _hostKeyScope(profile)
          ? record['fingerprint'] as String?
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> trustHostKey(ServerProfile profile, String fingerprint) =>
      _secrets.write(
        key: _hostKeyKey,
        value: jsonEncode(<String, String>{
          'scope': _hostKeyScope(profile),
          'fingerprint': fingerprint,
        }),
      );

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
    // Diagnostics deliberately contain neither endpoint nor credential data.
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
    final target = InternetAddress.tryParse(profile.broadcast);
    if (target == null || target.type != InternetAddressType.IPv4) {
      throw const ServergyError(
        'Die Broadcast-Adresse ist ungültig. Prüfe die Einstellungen.',
        code: 'invalid_broadcast',
      );
    }
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      final packet = magicPacket(profile.mac);
      for (var attempt = 0; attempt < 3; attempt++) {
        if (socket.send(packet, target, profile.wolPort) != packet.length) {
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
      if (result.exitCode != 0) {
        throw const ServergyError(
          'Der Server hat den Ausschaltbefehl abgelehnt. Prüfe die sudoers-Regel.',
          code: 'sudo_denied',
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
    final storedFingerprint = await _store.hostKeyFor(profile);
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
        final value = '$type:${base64Encode(fingerprint)}';
        if (storedFingerprint == null) {
          final trusted = await onUnknownHostKey(value);
          if (trusted) await _store.trustHostKey(profile, value);
          return trusted;
        }
        if (storedFingerprint != value) {
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
