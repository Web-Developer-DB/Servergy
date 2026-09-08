import 'dart:convert';
import 'dart:typed_data';

/// Immutable, Flutter-free domain vocabulary shared by persistence, network
/// services, controllers, and widgets.
///
/// Keep this file free of I/O and UI imports. That makes the validation and
/// migration rules deterministic, easy to unit-test, and safe for assistants
/// to reuse without accidentally initiating a network operation.

/// The supported login strategies. A key is preferred because a password never
/// has to be entered or retained for the normal control flow.
enum AuthenticationMode { keyPreferred, passwordOnly }

/// The user-visible lifecycle of the one configured server.
///
/// `checking`, `waking`, and `shuttingDown` are transient controller states;
/// they are not claims about the remote machine. Only a TCP check may turn the
/// state into `online` or `offline`.
enum ServerStatus { unknown, checking, offline, online, waking, shuttingDown }

/// Whitelisted operation names for the redacted local event log.
///
/// Do not add arbitrary command output or endpoint data to this enum: its
/// values are exported for support and must remain privacy-safe.
enum DiagnosticAction {
  load,
  refresh,
  wake,
  sshTest,
  shutdown,
  provisioning,
  helperRemoval,
  configuration,
  discovery,
}

/// Describes how a secret in the operating-system key store is changed.
///
/// `keep` is important when an edit form intentionally never reads a stored
/// password back into memory. A blank text field can therefore mean “leave the
/// existing secret alone”, rather than “delete it”.
enum SecretUpdateKind { keep, replace, delete }

/// A tri-state instruction for secret persistence, rather than a secret value
/// read from an edit form. See [SecretUpdateKind] for why a blank field is not
/// automatically interpreted as deletion.
class SecretUpdate {
  const SecretUpdate._(this.kind, this.value);

  const SecretUpdate.keep() : this._(SecretUpdateKind.keep, null);
  const SecretUpdate.delete() : this._(SecretUpdateKind.delete, null);
  const SecretUpdate.replace(String value)
    : this._(SecretUpdateKind.replace, value);

  final SecretUpdateKind kind;
  final String? value;
}

/// A safe, user-facing failure with a stable, redacted machine-readable code.
///
/// Gateways throw this type for expected failures. Controllers map library and
/// socket exceptions to it before an error reaches the UI or diagnostics.
class ServergyError implements Exception {
  const ServergyError(this.message, {this.code = 'unknown'});

  final String message;
  final String code;
}

/// Parsed six-byte Ethernet unicast address used to build a WOL magic packet.
///
/// The parser accepts common separators but normalizes output to uppercase
/// colon notation. It rejects all-zero and multicast addresses because neither
/// identifies a unique server network adapter.
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

/// Everything needed to wake an already configured, powered-off server.
///
/// It deliberately lives separately from the SSH endpoint: SSH can be set up
/// and verified first, while the user looks up the network card's MAC address.
/// The minimum non-secret data required to wake a server via UDP broadcast.
///
/// These values live in the public profile because a MAC and broadcast address
/// are configuration, not credentials. They are nevertheless excluded from
/// diagnostics to avoid disclosing local-network topology in support exports.
class WakeOnLanSettings {
  const WakeOnLanSettings({
    required this.mac,
    required this.broadcast,
    required this.port,
  });

  final MacAddress mac;
  final String broadcast;
  final int port;

  Map<String, Object> toJson() => <String, Object>{
    'mac': mac.toString(),
    'broadcast': broadcast,
    'port': port,
  };

  static WakeOnLanSettings fromJson(Map<String, dynamic> json) =>
      WakeOnLanSettings(
        mac: MacAddress.parse(ServerProfile.requiredString(json, 'mac')),
        broadcast: validateBroadcast(
          ServerProfile.requiredString(json, 'broadcast'),
        ),
        port: validatePort(json['port'], label: 'UDP-Port'),
      );
}

/// Public connection configuration for Servergy's deliberately single server.
///
/// Passwords, private keys, key passphrases, and SSH host-key trust are kept
/// elsewhere in platform secure storage. This separation is an important
/// invariant: [toJson] must never grow to serialize a secret.
class ServerProfile {
  const ServerProfile({
    required this.name,
    required this.host,
    required this.sshPort,
    required this.username,
    this.wakeOnLan,
    this.authenticationMode = AuthenticationMode.keyPreferred,
  });

  final String name;
  final String host;
  final int sshPort;
  final String username;
  final WakeOnLanSettings? wakeOnLan;
  final AuthenticationMode authenticationMode;

  bool get canWake => wakeOnLan != null;

  /// Serializes the current V3 public profile format.
  ///
  /// The version marker drives backwards-compatible migration in [fromJson];
  /// it intentionally has no password, private key, passphrase, or host key.
  Map<String, Object> toJson() => <String, Object>{
    'version': 3,
    'name': name,
    'host': host,
    'sshPort': sshPort,
    'username': username,
    if (wakeOnLan != null) 'wakeOnLan': wakeOnLan!.toJson(),
    'authenticationMode': authenticationMode.name,
  };

  /// Reads V3 plus older V1/V2 formats defensively.
  ///
  /// Corrupt, manually edited, or unknown data returns `null` instead of
  /// crashing startup. A missing historical authentication mode represents
  /// password-based setup, which preserves the old behaviour safely.
  static ServerProfile? fromJson(String source) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final modeName = json['authenticationMode'] as String?;
      // V1 profiles had no mode and used a password. Preserve that behaviour
      // after migration rather than silently assuming an unavailable key.
      final mode = modeName == null
          ? AuthenticationMode.passwordOnly
          : AuthenticationMode.values.byName(modeName);
      final legacyWake = json['wakeOnLan'];
      final wake = switch (legacyWake) {
        Map<String, dynamic> values => WakeOnLanSettings.fromJson(values),
        _ when json['mac'] != null => WakeOnLanSettings(
          mac: MacAddress.parse(requiredString(json, 'mac')),
          broadcast: validateBroadcast(requiredString(json, 'broadcast')),
          port: validatePort(json['wolPort'], label: 'UDP-Port'),
        ),
        _ => null,
      };
      return ServerProfile(
        name: requiredString(json, 'name'),
        host: validateHost(requiredString(json, 'host')),
        sshPort: validatePort(json['sshPort'], label: 'SSH-Port'),
        username: requiredString(json, 'username'),
        wakeOnLan: wake,
        authenticationMode: mode,
      );
    } catch (_) {
      return null;
    }
  }

  static String requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) throw const FormatException();
    return value.trim();
  }
}

/// A local IPv4 range that the user explicitly allowed the app to inspect.
/// A bounded local IPv4 range calculated from the active network interface.
///
/// Integer address boundaries allow discovery to scan without repeatedly
/// parsing strings; [broadcast] remains a string because it is passed to the
/// WOL socket and displayed to the user.
class NetworkScope {
  const NetworkScope({
    required this.localAddress,
    required this.netmask,
    required this.broadcast,
    required this.firstHost,
    required this.lastHost,
    required this.label,
  });

  final String localAddress;
  final String netmask;
  final String broadcast;
  final int firstHost;
  final int lastHost;
  final String label;
}

/// Evidence by which a candidate was found. Neither source proves identity;
/// SSH host-key confirmation is the trust boundary.
enum DiscoverySource { mdns, portScan }

/// A candidate, not proof of the identity of a homeserver.
/// An ephemeral discovery result shown during setup, never persisted directly.
///
/// Results from mDNS and a TCP probe may describe the same endpoint; [merge]
/// retains both sources so the UI can explain why the candidate is listed.
class DiscoveredServer {
  const DiscoveredServer({
    required this.host,
    required this.port,
    required this.banner,
    required this.sources,
    this.serviceName,
  });

  final String host;
  final int port;
  final String banner;
  final Set<DiscoverySource> sources;
  final String? serviceName;

  DiscoveredServer merge(DiscoveredServer other) => DiscoveredServer(
    host: host,
    port: port,
    banner: banner.isNotEmpty ? banner : other.banner,
    serviceName: serviceName ?? other.serviceName,
    sources: <DiscoverySource>{...sources, ...other.sources},
  );
}

/// A Wake-on-LAN proposal read from a verified SSH connection. The Linux
/// adapter name is presentation-only; a profile deliberately persists only
/// the values needed to send the magic packet.
class WakeOnLanCandidate {
  const WakeOnLanCandidate({
    required this.interfaceName,
    required this.settings,
  });

  final String interfaceName;
  final WakeOnLanSettings settings;
}

/// Validates a bare hostname or IP literal, not a URL, userinfo, or path.
///
/// This keeps the endpoint unambiguous before it is supplied to socket and SSH
/// APIs and avoids treating a pasted URL as a connection target.
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

/// Converts a JSON or form port value and constrains it to the TCP/UDP range.
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

/// Validates syntax for an IPv4 broadcast destination.
///
/// The active network determines whether this address is appropriate; this
/// domain-level check only ensures that it is a well-formed IPv4 literal.
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

/// Short-lived SSH authentication material passed from controller to gateway.
///
/// It intentionally has no JSON conversion and should never be recorded in
/// diagnostics. Key passphrases remain only in memory for one operation.
class SshCredentials {
  const SshCredentials({this.privateKeyPem, this.keyPassphrase, this.password});

  final String? privateKeyPem;
  final String? keyPassphrase;
  final String? password;

  bool get hasKey => privateKeyPem?.isNotEmpty ?? false;
  bool get hasPassword => password?.isNotEmpty ?? false;
}

/// A bounded, redacted support event with no profile or credential fields.
///
/// [code] is a stable technical category, not raw exception text. This allows
/// diagnostics to be useful without leaking remote commands or network data.
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
