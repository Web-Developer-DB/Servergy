// RadioGroup is not yet available in the project's supported Flutter SDK;
// the current RadioListTile API remains compatible with Android, Linux, Windows.
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/controller.dart';
import 'core/models.dart';

class ServergyApp extends StatelessWidget {
  const ServergyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Servergy',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: ThemeMode.system,
    home: const HomeScreen(),
  );
}

ThemeData _theme(Brightness brightness) {
  const navy = Color(0xff071f2d);
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: navy, brightness: brightness)
      .copyWith(
        primary: dark ? const Color(0xff00d878) : const Color(0xff007a43),
        onPrimary: dark ? navy : Colors.white,
        secondary: dark ? const Color(0xff08bce8) : const Color(0xff007a9e),
        onSecondary: dark ? navy : Colors.white,
        tertiary: dark ? const Color(0xff08bce8) : navy,
        surface: dark ? const Color(0xff0d1d27) : const Color(0xfff8fafc),
      );
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: .52),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: shape,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
  );
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AppState>(controllerProvider, (_, next) {
      final notice = next.error ?? next.message;
      if (notice != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(notice)));
        ref.read(controllerProvider.notifier).clearNotice();
      }
    });
    final state = ref.watch(controllerProvider);
    final profile = state.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [ServergyMark(), SizedBox(width: 12), Text('Servergy')],
        ),
        actions: [
          IconButton(
            tooltip: 'Diagnose',
            onPressed: () => _open(context, const DiagnosticsScreen()),
            icon: const Icon(Icons.article_outlined),
          ),
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: () => _open(context, const SetupScreen()),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  'Dein Homeserver.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lokal steuern – im Heimnetz oder über dein VPN.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _StatusCard(state: state),
                const SizedBox(height: 24),
                if (profile == null)
                  const _SetupCallout()
                else
                  _Actions(profile: profile, state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, title, detail) = switch (state.status) {
      ServerStatus.online => (
        Icons.check_circle_rounded,
        scheme.primary,
        'Server ist erreichbar',
        'Bereit für deine Dienste',
      ),
      ServerStatus.offline => (
        Icons.power_settings_new_rounded,
        scheme.outline,
        'Server ist ausgeschaltet',
        'Start jederzeit per Wake-on-LAN',
      ),
      ServerStatus.waking => (
        Icons.wifi_tethering_rounded,
        scheme.tertiary,
        'Startsignal wurde gesendet',
        'Warte, bis der Server erreichbar ist',
      ),
      ServerStatus.shuttingDown => (
        Icons.keyboard_double_arrow_down_rounded,
        scheme.tertiary,
        'Server wird heruntergefahren',
        'Die Verbindung wird gleich getrennt',
      ),
      ServerStatus.checking => (
        Icons.sync_rounded,
        scheme.tertiary,
        'Serverstatus wird geprüft',
        'Einen Moment bitte',
      ),
      ServerStatus.unknown => (
        Icons.help_outline_rounded,
        scheme.outline,
        'Status noch nicht geprüft',
        'Aktualisiere, um den Status zu sehen',
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.profile?.name ?? 'Homeserver einrichten',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(title, style: TextStyle(color: color)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Status aktualisieren',
                  onPressed: state.busy
                      ? null
                      : ref.read(controllerProvider.notifier).refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(detail, style: TextStyle(color: scheme.onSurfaceVariant)),
            if (state.profile != null) ...[
              const SizedBox(height: 14),
              Chip(
                avatar: const Icon(Icons.dns_outlined, size: 18),
                label: Text(state.profile!.host),
              ),
            ],
            if (state.busy) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: ref
                    .read(controllerProvider.notifier)
                    .cancelOperation,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Aktion abbrechen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupCallout extends StatelessWidget {
  const _SetupCallout();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Einmal einrichten',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Der Assistent prüft deine Verbindungsdaten und erklärt die sichere Einrichtung.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _open(context, const SetupScreen()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Homeserver einrichten'),
          ),
        ],
      ),
    ),
  );
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.profile, required this.state});
  final ServerProfile profile;
  final AppState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(controllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Schnellaktionen',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: state.busy ? null : controller.wake,
          icon: const Icon(Icons.keyboard_double_arrow_up_rounded),
          label: const Text('Server starten'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
            side: BorderSide(color: scheme.error.withValues(alpha: .6)),
          ),
          onPressed: state.busy
              ? null
              : () => _confirmShutdown(context, controller),
          icon: const Icon(Icons.keyboard_double_arrow_down_rounded),
          label: const Text('Server herunterfahren'),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Icon(
              Icons.verified_user_outlined,
              color: scheme.secondary,
            ),
            title: const Text('SSH-Verbindung testen'),
            subtitle: const Text('Prüft Zugangsdaten und Server-Fingerprint.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            enabled: !state.busy,
            onTap: () => controller.testSsh(
              (request) => _askCredentials(context, request),
              (fingerprint) => _confirmTrust(context, fingerprint),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _confirmShutdown(
  BuildContext context,
  ServerController controller,
) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: Theme.of(dialog).colorScheme.error,
      ),
      title: const Text('Server herunterfahren?'),
      content: const Text(
        'Aktive Dienste können unterbrochen werden. Der Server wird über den eingeschränkten Servergy-Helper ausgeschaltet.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Herunterfahren'),
        ),
      ],
    ),
  );
  if (yes ?? false)
    await controller.shutdown(
      (request) => _askCredentials(context, request),
      (fingerprint) => _confirmTrust(context, fingerprint),
    );
}

Future<bool> _confirmTrust(BuildContext context, String fingerprint) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        title: const Text('SSH-Server bestätigen'),
        content: SelectableText(
          'Fingerprint:\n\n$fingerprint\n\nVergleiche ihn mit dem Homeserver, bevor du vertraust.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Vertrauen'),
          ),
        ],
      ),
    ) ??
    false;

Future<SshCredentials?> _askCredentials(
  BuildContext context,
  CredentialRequest request,
) async {
  final input = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.key_outlined),
      title: Text(
        request == CredentialRequest.keyPassphrase
            ? 'Passphrase für SSH-Schlüssel'
            : 'SSH-Passwort',
      ),
      content: TextField(
        controller: input,
        autofocus: true,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        decoration: const InputDecoration(labelText: 'Geheimnis'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, input.text),
          child: const Text('Fortfahren'),
        ),
      ],
    ),
  );
  input.dispose();
  if (value == null || value.isEmpty) return null;
  return request == CredentialRequest.keyPassphrase
      ? SshCredentials(keyPassphrase: value)
      : SshCredentials(password: value);
}

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'Homeserver');
  final _host = TextEditingController();
  final _sshPort = TextEditingController(text: '22');
  final _user = TextEditingController();
  final _mac = TextEditingController();
  final _broadcast = TextEditingController(text: '255.255.255.255');
  final _wolPort = TextEditingController(text: '9');
  final _password = TextEditingController();
  var _step = 0;
  var _mode = AuthenticationMode.keyPreferred;
  String? _keyPem;
  @override
  void initState() {
    super.initState();
    final p = ref.read(controllerProvider).profile;
    if (p != null) {
      _name.text = p.name;
      _host.text = p.host;
      _sshPort.text = '${p.sshPort}';
      _user.text = p.username;
      _mac.text = '${p.mac}';
      _broadcast.text = p.broadcast;
      _wolPort.text = '${p.wolPort}';
      _mode = p.authenticationMode;
    }
  }

  @override
  void dispose() {
    for (final item in [
      _name,
      _host,
      _sshPort,
      _user,
      _mac,
      _broadcast,
      _wolPort,
      _password,
    ]) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        ref.read(controllerProvider).profile == null
            ? 'Homeserver einrichten'
            : 'Einstellungen',
      ),
    ),
    body: SafeArea(
      top: false,
      child: Form(
        key: _form,
        child: Stepper(
          currentStep: _step,
          onStepCancel: _step == 0
              ? () => Navigator.pop(context)
              : () => setState(() => _step--),
          onStepContinue: _continue,
          controlsBuilder: (context, details) => Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: details.onStepContinue,
                    child: Text(_step == 4 ? 'Speichern' : 'Weiter'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(_step == 0 ? 'Abbrechen' : 'Zurück'),
                ),
              ],
            ),
          ),
          steps: [
            Step(
              title: const Text('Netzwerkgrenze'),
              isActive: _step >= 0,
              content: const _StepInfo(
                icon: Icons.home_outlined,
                text:
                    'Servergy steuert deinen Server nur im Heimnetz oder über ein bereits eingerichtetes VPN. Wake-on-LAN benötigt einen Netzwerkpfad für Broadcast-Pakete; viele VPNs leiten diese nicht weiter.',
              ),
            ),
            Step(
              title: const Text('Serververbindung'),
              isActive: _step >= 1,
              content: Column(
                children: [
                  _field(_name, 'Anzeigename', Icons.badge_outlined),
                  _field(_host, 'Hostname oder IP-Adresse', Icons.lan_outlined),
                  _field(
                    _sshPort,
                    'SSH-Port',
                    Icons.settings_ethernet_rounded,
                    number: true,
                  ),
                  _field(
                    _user,
                    'SSH-Benutzername',
                    Icons.person_outline_rounded,
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Wake-on-LAN'),
              isActive: _step >= 2,
              content: Column(
                children: [
                  _field(_mac, 'MAC-Adresse', Icons.memory_rounded),
                  _field(
                    _broadcast,
                    'Broadcast-Adresse',
                    Icons.broadcast_on_home_outlined,
                  ),
                  _field(
                    _wolPort,
                    'UDP-Port',
                    Icons.send_to_mobile_outlined,
                    number: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Tipp: Nutze die Broadcast-Adresse deines Subnetzes. 255.255.255.255 funktioniert nicht in jedem Netz.',
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('SSH-Zugang'),
              isActive: _step >= 3,
              content: _authStep(),
            ),
            Step(
              title: const Text('Prüfen und speichern'),
              isActive: _step >= 4,
              content: const _StepInfo(
                icon: Icons.verified_user_outlined,
                text:
                    'Speichere die Konfiguration und teste danach die SSH-Verbindung. Beim ersten Kontakt vergleichst du den angezeigten Server-Fingerprint mit deinem Homeserver.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _authStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RadioListTile<AuthenticationMode>(
        value: AuthenticationMode.keyPreferred,
        groupValue: _mode,
        onChanged: (v) => setState(() => _mode = v!),
        title: const Text('SSH-Schlüssel (empfohlen)'),
        subtitle: Text(
          _keyPem == null
              ? 'Importiere einen privaten OpenSSH-, RSA- oder EC-Schlüssel.'
              : 'Schlüssel ist für den Import ausgewählt.',
        ),
        secondary: const Icon(Icons.key_outlined),
      ),
      if (_mode == AuthenticationMode.keyPreferred)
        OutlinedButton.icon(
          onPressed: _importKey,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(
            _keyPem == null
                ? 'Schlüsseldatei auswählen'
                : 'Schlüsseldatei ändern',
          ),
        ),
      RadioListTile<AuthenticationMode>(
        value: AuthenticationMode.passwordOnly,
        groupValue: _mode,
        onChanged: (v) => setState(() => _mode = v!),
        title: const Text('Passwort'),
        subtitle: const Text(
          'Das Passwort kann optional sicher auf diesem Gerät gespeichert werden.',
        ),
        secondary: const Icon(Icons.password_outlined),
      ),
      if (_mode == AuthenticationMode.passwordOnly)
        TextFormField(
          controller: _password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'SSH-Passwort',
            helperText: 'Leer lassen: bei jeder Aktion nachfragen.',
          ),
        ),
    ],
  );
  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: number ? TextInputType.number : null,
      validator: (v) =>
          v == null || v.trim().isEmpty ? '$label ist erforderlich.' : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    ),
  );
  Future<void> _importKey() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      final pem = utf8.decode(bytes);
      if (!pem.contains('PRIVATE KEY')) throw const FormatException();
      setState(() => _keyPem = pem);
    } on FormatException {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Die Datei enthält keinen unterstützten privaten SSH-Schlüssel.',
            ),
          ),
        );
    }
  }

  Future<void> _continue() async {
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    if (_step == 3) {
      if (_mode == AuthenticationMode.keyPreferred &&
          _keyPem == null &&
          ref.read(controllerProvider).profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Wähle einen SSH-Schlüssel oder nutze Passwort-Anmeldung.',
            ),
          ),
        );
        return;
      }
      setState(() => _step++);
      return;
    }
    if (!_form.currentState!.validate()) return;
    try {
      final profile = ServerProfile(
        name: _name.text.trim(),
        host: validateHost(_host.text),
        sshPort: validatePort(_sshPort.text, label: 'SSH-Port'),
        username: _user.text.trim(),
        mac: MacAddress.parse(_mac.text),
        broadcast: validateBroadcast(_broadcast.text),
        wolPort: validatePort(_wolPort.text, label: 'UDP-Port'),
        authenticationMode: _mode,
      );
      await ref
          .read(controllerProvider.notifier)
          .saveProfile(
            profile,
            password: _password.text.isEmpty ? null : _password.text,
            privateKeyPem: _keyPem,
          );
      if (mounted) Navigator.pop(context);
    } on ServergyError catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _StepInfo extends StatelessWidget {
  const _StepInfo({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.secondary),
      const SizedBox(width: 12),
      Expanded(child: Text(text)),
    ],
  );
}

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(controllerProvider).diagnostics.reversed.toList();
    final report = events.map((e) => e.toExportLine()).join('\n');
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnose')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Lokales Diagnoseprotokoll',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Es enthält keine Passwörter, Schlüssel, Benutzernamen, Hostadressen oder MAC-Adressen.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: events.isEmpty ? null : () => _export(context, report),
            icon: const Icon(Icons.save_alt_outlined),
            label: const Text('Redigierte Diagnose exportieren'),
          ),
          const SizedBox(height: 16),
          if (events.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Noch keine Diagnoseereignisse vorhanden.'),
              ),
            ),
          for (final event in events)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(
                  event.success
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: event.success
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(event.action.name),
                subtitle: Text('${event.at} · ${event.code}'),
                trailing: Text('${event.duration.inMilliseconds} ms'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, String report) async {
    final path = await FilePicker.saveFile(
      fileName: 'servergy-diagnose.txt',
      bytes: utf8.encode('$report\n'),
    );
    if (context.mounted && path != null)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Diagnose exportiert.')));
  }
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
