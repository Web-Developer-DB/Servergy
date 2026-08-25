import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profileKey = 'servergy.profile.v1';
const _passwordKey = 'servergy.password.v1';
const _hostKeyKey = 'servergy.hostkey.v1';

final controllerProvider = NotifierProvider<ServerController, AppState>(
  ServerController.new,
);

class ServergyApp extends StatelessWidget {
  const ServergyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xff071f2d);
    const green = Color(0xff00f26a);
    const cyan = Color(0xff08c5f5);
    return MaterialApp(
      title: 'Servergy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: navy,
          brightness: Brightness.light,
        ).copyWith(primary: navy, secondary: green, tertiary: cyan),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: green,
              brightness: Brightness.dark,
            ).copyWith(
              primary: green,
              secondary: cyan,
              surface: const Color(0xff102735),
            ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

enum ServerStatus { unknown, checking, offline, online, waking, shuttingDown }

class AppState {
  const AppState({
    this.profile,
    this.status = ServerStatus.unknown,
    this.message,
    this.error,
    this.busy = false,
  });

  final ServerProfile? profile;
  final ServerStatus status;
  final String? message;
  final String? error;
  final bool busy;

  AppState copyWith({
    ServerProfile? profile,
    ServerStatus? status,
    String? message,
    String? error,
    bool? busy,
    bool clearMessage = false,
    bool clearError = false,
  }) => AppState(
    profile: profile ?? this.profile,
    status: status ?? this.status,
    message: clearMessage ? null : message ?? this.message,
    error: clearError ? null : error ?? this.error,
    busy: busy ?? this.busy,
  );
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
    required this.rememberPassword,
  });

  final String name;
  final String host;
  final int sshPort;
  final String username;
  final MacAddress mac;
  final String broadcast;
  final int wolPort;
  final bool rememberPassword;

  Map<String, Object> toJson() => {
    'name': name,
    'host': host,
    'sshPort': sshPort,
    'username': username,
    'mac': mac.toString(),
    'broadcast': broadcast,
    'wolPort': wolPort,
    'rememberPassword': rememberPassword,
  };

  static ServerProfile? fromJson(String source) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      return ServerProfile(
        name: json['name'] as String,
        host: json['host'] as String,
        sshPort: json['sshPort'] as int,
        username: json['username'] as String,
        mac: MacAddress.parse(json['mac'] as String),
        broadcast: json['broadcast'] as String,
        wolPort: json['wolPort'] as int,
        rememberPassword: json['rememberPassword'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

class MacAddress {
  const MacAddress._(this.bytes);
  final Uint8List bytes;

  factory MacAddress.parse(String value) {
    final compact = value.replaceAll(RegExp('[:.\\-\\s]'), '');
    if (!RegExp(r'^[0-9a-fA-F]{12}$').hasMatch(compact)) {
      throw const ServergyError('Die MAC-Adresse ist ungültig.');
    }
    final bytes = Uint8List.fromList([
      for (var i = 0; i < 12; i += 2)
        int.parse(compact.substring(i, i + 2), radix: 16),
    ]);
    if (bytes.every((byte) => byte == 0) || bytes.first.isOdd) {
      throw const ServergyError(
        'Die MAC-Adresse muss eine eindeutige Geräteadresse sein.',
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

class ServergyError implements Exception {
  const ServergyError(this.message);
  final String message;
}

class SettingsStore {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final FlutterSecureStorage _secrets = const FlutterSecureStorage();

  Future<ServerProfile?> loadProfile() async {
    final value = await _preferences.getString(_profileKey);
    return value == null ? null : ServerProfile.fromJson(value);
  }

  Future<void> saveProfile(ServerProfile profile, String password) async {
    await _preferences.setString(_profileKey, jsonEncode(profile.toJson()));
    if (profile.rememberPassword && password.isNotEmpty) {
      await _secrets.write(key: _passwordKey, value: password);
    } else if (!profile.rememberPassword) {
      await _secrets.delete(key: _passwordKey);
    }
  }

  Future<String?> password() => _secrets.read(key: _passwordKey);
  Future<String?> hostKeyFor(ServerProfile profile) async {
    final raw = await _secrets.read(key: _hostKeyKey);
    if (raw == null) return null;
    try {
      final record = jsonDecode(raw) as Map<String, dynamic>;
      if (record['scope'] == _hostKeyScope(profile)) {
        return record['fingerprint'] as String?;
      }
    } on FormatException {
      // An older app version stored the fingerprint without a server scope.
      // It is deliberately ignored so that a new confirmation is required.
    }
    return null;
  }

  Future<void> trustHostKey(ServerProfile profile, String fingerprint) =>
      _secrets.write(
        key: _hostKeyKey,
        value: jsonEncode(<String, String>{
          'scope': _hostKeyScope(profile),
          'fingerprint': fingerprint,
        }),
      );

  String _hostKeyScope(ServerProfile profile) => <String>[
    profile.host.trim().toLowerCase(),
    profile.sshPort.toString(),
  ].join(':');
}

class NetworkService {
  Uint8List magicPacket(MacAddress mac) {
    final packet = Uint8List(102)..fillRange(0, 6, 0xff);
    for (var repeat = 0; repeat < 16; repeat++) {
      packet.setRange(6 + repeat * 6, 12 + repeat * 6, mac.bytes);
    }
    return packet;
  }

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

  Future<void> wake(ServerProfile profile) async {
    final target = InternetAddress.tryParse(profile.broadcast);
    if (target == null || target.type != InternetAddressType.IPv4) {
      throw const ServergyError(
        'Die Broadcast-Adresse muss eine IPv4-Adresse sein.',
      );
    }
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      final packet = magicPacket(profile.mac);
      for (var attempt = 0; attempt < 3; attempt++) {
        if (socket.send(packet, target, profile.wolPort) != packet.length) {
          throw const ServergyError(
            'Wake-on-LAN konnte nicht gesendet werden.',
          );
        }
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
    } finally {
      socket.close();
    }
  }
}

class SshService {
  Future<void> test(
    ServerProfile profile,
    String password, {
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) async {
    final client = await _connect(profile, password, onUnknownHostKey);
    try {
      final output = await client.run('printf servergy-ok');
      if (utf8.decode(output) != 'servergy-ok') {
        throw const ServergyError(
          'Der SSH-Test lieferte keine erwartete Antwort.',
        );
      }
    } finally {
      await client.close();
    }
  }

  Future<void> poweroff(
    ServerProfile profile,
    String password, {
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) async {
    final client = await _connect(profile, password, onUnknownHostKey);
    try {
      await client.execute('sudo -n /usr/local/sbin/servergy-poweroff');
    } finally {
      await client.close();
    }
  }

  Future<SSHClient> _connect(
    ServerProfile profile,
    String password,
    Future<bool> Function(String fingerprint) onUnknownHostKey,
  ) async {
    final stored = await SettingsStore().hostKeyFor(profile);
    final socket = await SSHSocket.connect(
      profile.host,
      profile.sshPort,
      timeout: const Duration(seconds: 8),
    );
    final client = SSHClient(
      socket,
      username: profile.username,
      handshakeTimeout: const Duration(seconds: 10),
      authTimeout: const Duration(seconds: 10),
      onPasswordRequest: () => password,
      onVerifyHostKey: (type, fingerprint) async {
        final current = <String>[type, utf8.decode(fingerprint)].join(':');
        if (stored == null) {
          return onUnknownHostKey(current);
        }
        if (stored != current) {
          throw const ServergyError(
            'Der SSH-Host-Key hat sich geändert. Verbindung blockiert.',
          );
        }
        return true;
      },
    );
    await client.authenticated;
    return client;
  }
}

class ServerController extends Notifier<AppState> {
  final _settings = SettingsStore();
  final _network = NetworkService();
  final _ssh = SshService();

  @override
  AppState build() {
    unawaited(_load());
    return const AppState();
  }

  Future<void> _load() async {
    final profile = await _settings.loadProfile();
    if (!ref.mounted) return;
    state = state.copyWith(profile: profile);
    if (profile != null) await refresh();
  }

  Future<void> save(ServerProfile profile, String password) async {
    await _settings.saveProfile(profile, password);
    if (!ref.mounted) return;
    state = state.copyWith(
      profile: profile,
      message: 'Einstellungen gespeichert.',
      clearError: true,
    );
    await refresh();
  }

  Future<void> refresh() async {
    final profile = state.profile;
    if (profile == null || state.busy) return;
    state = state.copyWith(status: ServerStatus.checking);
    final online = await _network.isReachable(profile);
    if (ref.mounted) {
      state = state.copyWith(
        status: online ? ServerStatus.online : ServerStatus.offline,
      );
    }
  }

  Future<void> wake() async {
    final profile = state.profile;
    if (profile == null || state.busy) return;
    state = state.copyWith(
      busy: true,
      status: ServerStatus.waking,
      clearError: true,
    );
    try {
      if (await _network.isReachable(profile)) {
        state = state.copyWith(
          busy: false,
          status: ServerStatus.online,
          message: 'Der Server läuft bereits.',
        );
        return;
      }
      await _network.wake(profile);
      state = state.copyWith(
        message: 'Startsignal gesendet – warte auf den Server …',
      );
      for (var attempt = 0; attempt < 45; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (await _network.isReachable(profile)) {
          state = state.copyWith(
            busy: false,
            status: ServerStatus.online,
            message: 'Server ist erreichbar.',
          );
          return;
        }
      }
      _fail(
        'Startsignal wurde gesendet, aber der Server ist noch nicht erreichbar.',
      );
    } on ServergyError catch (error) {
      _fail(error.message);
    } on SocketException {
      _fail('Das lokale Netzwerk ist nicht erreichbar.');
    }
  }

  Future<void> testSsh(BuildContext context) => _sshAction(context, false);
  Future<void> shutdown(BuildContext context) => _sshAction(context, true);

  Future<void> _sshAction(BuildContext context, bool shutdown) async {
    final profile = state.profile;
    if (profile == null || state.busy) return;
    state = state.copyWith(
      busy: true,
      status: shutdown ? ServerStatus.shuttingDown : ServerStatus.checking,
      clearError: true,
    );
    try {
      if (shutdown && !await _network.isReachable(profile)) {
        state = state.copyWith(
          busy: false,
          status: ServerStatus.offline,
          message: 'Der Server ist bereits ausgeschaltet.',
        );
        return;
      }
      final storedPassword = await _settings.password();
      if (!context.mounted) return;
      final password = storedPassword ?? await _askPassword(context);
      if (!context.mounted) return;
      if (password == null || password.isEmpty) {
        state = state.copyWith(busy: false);
        return;
      }
      Future<bool> trust(String fingerprint) =>
          _askHostTrust(context, fingerprint);
      if (shutdown) {
        await _ssh.poweroff(profile, password, onUnknownHostKey: trust);
        for (var attempt = 0; attempt < 30; attempt++) {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (!await _network.isReachable(profile)) {
            state = state.copyWith(
              busy: false,
              status: ServerStatus.offline,
              message: 'Server wurde heruntergefahren.',
            );
            return;
          }
        }
        _fail('Der Server ist weiterhin erreichbar. Bitte prüfe ihn manuell.');
      } else {
        await _ssh.test(profile, password, onUnknownHostKey: trust);
        state = state.copyWith(
          busy: false,
          message: 'SSH-Verbindung erfolgreich getestet.',
        );
      }
    } on ServergyError catch (error) {
      _fail(error.message);
    } on SSHAuthFailError {
      _fail('Die SSH-Anmeldung wurde abgelehnt.');
    } on SocketException {
      _fail('Der Server ist über SSH nicht erreichbar.');
    } catch (_) {
      _fail('Die SSH-Aktion ist fehlgeschlagen.');
    }
  }

  Future<String?> _askPassword(BuildContext context) async {
    final input = TextEditingController();
    final value = await showDialog<({String password, bool remember})>(
      context: context,
      builder: (context) => _PasswordDialog(controller: input),
    );
    input.dispose();
    if (value?.remember ?? false) {
      await _settings.saveProfile(state.profile!, value!.password);
    }
    return value?.password;
  }

  Future<bool> _askHostTrust(BuildContext context, String fingerprint) async {
    final trust = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('SSH-Server bestätigen'),
        content: SelectableText(
          <String>[
            'Fingerprint:\n\n',
            fingerprint,
            '\n\nVergleiche ihn mit dem Homeserver, bevor du vertraust.',
          ].join(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vertrauen'),
          ),
        ],
      ),
    );
    if (trust ?? false) {
      await _settings.trustHostKey(state.profile!, fingerprint);
    }
    return trust ?? false;
  }

  void clearNotice() =>
      state = state.copyWith(clearMessage: true, clearError: true);
  void _fail(String error) =>
      state = state.copyWith(busy: false, error: error, clearMessage: true);
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AppState>(controllerProvider, (_, next) {
      final text = next.error ?? next.message;
      if (text != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
        ref.read(controllerProvider.notifier).clearNotice();
      }
    });
    final state = ref.watch(controllerProvider);
    final profile = state.profile;
    final (color, text) = switch (state.status) {
      ServerStatus.online => (Colors.green, 'Server ist erreichbar'),
      ServerStatus.offline => (Colors.grey, 'Server ist ausgeschaltet'),
      ServerStatus.waking => (Colors.amber, 'Startsignal wurde gesendet …'),
      ServerStatus.shuttingDown => (
        Colors.orange,
        'Server wird heruntergefahren …',
      ),
      ServerStatus.checking => (Colors.amber, 'Serverstatus wird geprüft …'),
      ServerStatus.unknown => (Colors.blueGrey, 'Status noch nicht geprüft'),
    };
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [ServergyMark(), SizedBox(width: 10), Text('Servergy')],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Dein Homeserver. Nur wenn du ihn brauchst.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              text,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: state.busy
                                ? null
                                : () => ref
                                      .read(controllerProvider.notifier)
                                      .refresh(),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile?.name ?? 'Noch kein Homeserver eingerichtet.',
                      ),
                      if (profile != null) Text(profile.host),
                      if (state.busy)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: LinearProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: profile == null || state.busy
                    ? null
                    : () => ref.read(controllerProvider.notifier).wake(),
                icon: const Icon(Icons.keyboard_arrow_up),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Server starten'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: profile == null || state.busy
                    ? null
                    : () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Server herunterfahren?'),
                            content: Text(
                              <String>[
                                'Aktive Dienste auf ',
                                profile.name,
                                ' können unterbrochen werden.',
                              ].join(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Abbrechen'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Herunterfahren'),
                              ),
                            ],
                          ),
                        );
                        if (yes ?? false) {
                          if (!context.mounted) return;
                          await ref
                              .read(controllerProvider.notifier)
                              .shutdown(context);
                        }
                      },
                icon: const Icon(Icons.keyboard_arrow_down),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Server herunterfahren'),
                ),
              ),
              TextButton.icon(
                onPressed: profile == null || state.busy
                    ? null
                    : () => ref
                          .read(controllerProvider.notifier)
                          .testSsh(context),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('SSH-Verbindung testen'),
              ),
              if (profile == null)
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                  child: const Text('Homeserver einrichten'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final key = GlobalKey<FormState>();
  final name = TextEditingController(text: 'Homeserver');
  final host = TextEditingController();
  final sshPort = TextEditingController(text: '22');
  final user = TextEditingController();
  final mac = TextEditingController();
  final broadcast = TextEditingController(text: '255.255.255.255');
  final wolPort = TextEditingController(text: '9');
  final password = TextEditingController();
  bool remember = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(controllerProvider).profile;
    if (p != null) {
      name.text = p.name;
      host.text = p.host;
      sshPort.text = p.sshPort.toString();
      user.text = p.username;
      mac.text = p.mac.toString();
      broadcast.text = p.broadcast;
      wolPort.text = p.wolPort.toString();
      remember = p.rememberPassword;
    }
  }

  @override
  void dispose() {
    for (final item in [
      name,
      host,
      sshPort,
      user,
      mac,
      broadcast,
      wolPort,
      password,
    ]) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Einstellungen')),
    body: Form(
      key: key,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Server', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _field(name, 'Anzeigename'),
          _field(host, 'Hostname oder IP-Adresse'),
          _field(sshPort, 'SSH-Port', number: true),
          _field(user, 'SSH-Benutzername'),
          const SizedBox(height: 16),
          Text('Wake-on-LAN', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _field(mac, 'MAC-Adresse'),
          _field(broadcast, 'Broadcast-Adresse'),
          _field(wolPort, 'UDP-Port', number: true),
          const SizedBox(height: 16),
          Text('Zugang', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Passwort',
              helperText:
                  'Leer lassen, um ein gespeichertes Passwort zu behalten.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: remember,
            onChanged: (value) => setState(() => remember = value),
            title: const Text('Passwort sicher speichern'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Einstellungen speichern'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: number ? TextInputType.number : null,
      validator: (value) => value == null || value.trim().isEmpty
          ? '$label ist erforderlich.'
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );
  Future<void> _save() async {
    if (!key.currentState!.validate()) {
      return;
    }
    try {
      final ssh = int.parse(sshPort.text);
      final wol = int.parse(wolPort.text);
      if (ssh < 1 || ssh > 65535 || wol < 1 || wol > 65535) {
        throw const ServergyError('Ports müssen zwischen 1 und 65535 liegen.');
      }
      if (InternetAddress.tryParse(broadcast.text.trim())?.type !=
          InternetAddressType.IPv4) {
        throw const ServergyError(
          'Die Broadcast-Adresse muss eine IPv4-Adresse sein.',
        );
      }
      await ref
          .read(controllerProvider.notifier)
          .save(
            ServerProfile(
              name: name.text.trim(),
              host: host.text.trim(),
              sshPort: ssh,
              username: user.text.trim(),
              mac: MacAddress.parse(mac.text),
              broadcast: broadcast.text.trim(),
              wolPort: wol,
              rememberPassword: remember,
            ),
            password.text,
          );
      if (mounted) Navigator.pop(context);
    } on FormatException {
      _notice('Ports müssen gültige Zahlen sein.');
    } on ServergyError catch (e) {
      _notice(e.message);
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.controller});
  final TextEditingController controller;
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  bool remember = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('SSH-Passwort'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Passwort'),
        ),
        CheckboxListTile(
          value: remember,
          onChanged: (value) => setState(() => remember = value ?? false),
          title: const Text('Sicher speichern'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          password: widget.controller.text,
          remember: remember,
        )),
        child: const Text('Fortfahren'),
      ),
    ],
  );
}

class ServergyMark extends StatelessWidget {
  const ServergyMark({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: const Color(0xff071f2d),
      borderRadius: BorderRadius.circular(9),
    ),
    child: const Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.storage_rounded, color: Color(0xfff8fafc), size: 20),
        Positioned(
          right: 0,
          top: 0,
          child: Icon(
            Icons.keyboard_arrow_up,
            color: Color(0xff00f26a),
            size: 18,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xff08c5f5),
            size: 18,
          ),
        ),
      ],
    ),
  );
}
