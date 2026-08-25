import 'dart:convert';
import 'dart:typed_data';

/// The supported login strategies. A key is preferred because a password never
/// has to be entered or retained for the normal control flow.
enum AuthenticationMode { keyPreferred, passwordOnly }

enum ServerStatus { unknown, checking, offline, online, waking, shuttingDown }

enum DiagnosticAction { load, refresh, wake, sshTest, shutdown, configuration }

class ServergyError implements Exception {
  const ServergyError(this.message, {this.code = 'unknown'});

  final String message;
  final String code;
}

class MacAddress {
  MacAddress._(Uint8List bytes) : bytes = Uint8List.fromList(bytes);

  /// A defensive copy prevents callers from changing an address after parsing.
  final Uint8List bytes;

  factory MacAddress.parse(String value) {
    final compact = value.replaceAll(RegExp('[:.\\-\\s]'), '');
    if (!RegExp(r'^[0-9a-fA-F]{12}$').hasMatch(compact)) {
      throw const ServergyError(
        'Die MAC-Adresse ist ungültig.',
        code: 'invalid_mac',
      );
    }
    final bytes = Uint8List.fromList([
      for (var index = 0; index < 12; index += 2)
        int.parse(compact.substring(index, index + 2), radix: 16),
    ]);
    if (bytes.every((byte) => byte == 0) || bytes.first.isOdd) {
      throw const ServergyError(
        'Die MAC-Adresse muss eine eindeutige Unicast-Adresse sein.',
        code: 'invalid_mac',
      );
    }
    return MacAddress._(bytes);
  }

  @override
  String toString() => bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(':')
      .toUpperCase();
}

class ServerProfile {
  const ServerProfile({
    required this.name,
    required this.host,
    required this.sshPort,
    required this.username,
    required this.mac,
    required this.broadcast,
    required this.wolPort,
    this.authenticationMode = AuthenticationMode.keyPreferred,
  });

  final String name;
  final String host;
  final int sshPort;
  final String username;
  final MacAddress mac;
  final String broadcast;
  final int wolPort;
  final AuthenticationMode authenticationMode;

  /// V2 intentionally has no password, private key, passphrase or host key.
  Map<String, Object> toJson() => <String, Object>{
    'version': 2,
    'name': name,
    'host': host,
    'sshPort': sshPort,
    'username': username,
    'mac': mac.toString(),
    'broadcast': broadcast,
    'wolPort': wolPort,
    'authenticationMode': authenticationMode.name,
  };

  static ServerProfile? fromJson(String source) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final modeName = json['authenticationMode'] as String?;
      // V1 profiles had no mode and used a password. Preserve that behaviour
      // after migration rather than silently assuming an unavailable key.
      final mode = modeName == null
          ? AuthenticationMode.passwordOnly
          : AuthenticationMode.values.byName(modeName);
      return ServerProfile(
        name: _requiredString(json, 'name'),
        host: validateHost(_requiredString(json, 'host')),
        sshPort: validatePort(json['sshPort'], label: 'SSH-Port'),
        username: _requiredString(json, 'username'),
        mac: MacAddress.parse(_requiredString(json, 'mac')),
        broadcast: validateBroadcast(_requiredString(json, 'broadcast')),
        wolPort: validatePort(json['wolPort'], label: 'UDP-Port'),
        authenticationMode: mode,
      );
    } catch (_) {
      return null;
    }
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) throw const FormatException();
    return value.trim();
  }
}

String validateHost(String value) {
  final host = value.trim();
  if (host.isEmpty || host.contains(RegExp(r'[/:?#@\s]'))) {
    throw const ServergyError(
      'Bitte gib nur einen Hostnamen oder eine IP-Adresse ein.',
      code: 'invalid_host',
    );
  }
  return host;
}

int validatePort(Object? value, {required String label}) {
  final port = switch (value) {
    int number => number,
    String text => int.tryParse(text.trim()),
    _ => null,
  };
  if (port == null || port < 1 || port > 65535) {
    throw ServergyError(
      '$label muss zwischen 1 und 65535 liegen.',
      code: 'invalid_port',
    );
  }
  return port;
}

String validateBroadcast(String value) {
  final address = value.trim();
  final match = RegExp(
    r'^(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}$',
  ).hasMatch(address);
  if (!match) {
    throw const ServergyError(
      'Die Broadcast-Adresse muss eine IPv4-Adresse sein.',
      code: 'invalid_broadcast',
    );
  }
  return address;
}

class SshCredentials {
  const SshCredentials({this.privateKeyPem, this.keyPassphrase, this.password});

  final String? privateKeyPem;
  final String? keyPassphrase;
  final String? password;

  bool get hasKey => privateKeyPem?.isNotEmpty ?? false;
  bool get hasPassword => password?.isNotEmpty ?? false;
}

class DiagnosticEvent {
  const DiagnosticEvent({
    required this.at,
    required this.action,
    required this.success,
    required this.code,
    required this.duration,
  });

  final DateTime at;
  final DiagnosticAction action;
  final bool success;
  final String code;
  final Duration duration;

  Map<String, Object> toJson() => <String, Object>{
    'at': at.toUtc().toIso8601String(),
    'action': action.name,
    'success': success,
    'code': code,
    'durationMs': duration.inMilliseconds,
  };

  static DiagnosticEvent? fromJson(Map<String, dynamic> json) {
    try {
      return DiagnosticEvent(
        at: DateTime.parse(json['at'] as String).toLocal(),
        action: DiagnosticAction.values.byName(json['action'] as String),
        success: json['success'] as bool,
        code: json['code'] as String,
        duration: Duration(milliseconds: json['durationMs'] as int),
      );
    } catch (_) {
      return null;
    }
  }

  String toExportLine() =>
      '${at.toIso8601String()} | ${action.name} | '
      '${success ? 'ok' : 'error'} | $code | ${duration.inMilliseconds}ms';
}
