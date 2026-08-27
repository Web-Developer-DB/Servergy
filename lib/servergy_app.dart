// RadioGroup is not yet available in the project's supported Flutter SDK;
// the current RadioListTile API remains compatible with Android, Linux, Windows.
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

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
      // Home remains mounted below Settings. Do not show a Snackbar from that
      // inactive route while a modal dialog belongs to the foreground route:
      // Flutter would deactivate inherited dialog dependencies mid-transition.
      if (notice != null && (ModalRoute.of(context)?.isCurrent ?? true)) {
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
          if (profile != null)
            IconButton(
              tooltip: 'Verbindung löschen',
              onPressed: state.busy
                  ? null
                  : () => _deleteConnectionFromHome(context, ref),
              icon: const Icon(Icons.delete_outline_rounded),
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

/// Keeps the destructive action discoverable on the dashboard as well as in
/// settings, while always requiring the same explicit confirmation.
Future<void> _deleteConnectionFromHome(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!await _confirmConnectionDeletion(context)) return;
  await ref.read(controllerProvider.notifier).deleteConnection();
}

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
          onPressed: state.busy || !profile.canWake ? null : controller.wake,
          icon: const Icon(Icons.keyboard_double_arrow_up_rounded),
          label: Text(
            profile.canWake ? 'Server starten' : 'Wake-on-LAN noch einrichten',
          ),
        ),
        if (!profile.canWake) ...[
          const SizedBox(height: 8),
          Text(
            'Hinterlege MAC-Adresse und Broadcast-Adresse in den Einstellungen, um den ausgeschalteten Server starten zu können.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
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
  if (context.mounted && _canPrepareServer(controller.lastErrorCode)) {
    await _offerServerPreparation(context, controller);
  }
}

bool _canPrepareServer(String? code) => switch (code) {
  'poweroff_sudo_password_required' ||
  'poweroff_helper_missing' ||
  'poweroff_invalid_acknowledgement' ||
  'poweroff_not_acknowledged' => true,
  _ => false,
};

/// This is deliberately an explicit second confirmation. The normal shutdown
/// action must never be able to change files or sudoers rules as a side effect.
Future<void> _offerServerPreparation(
  BuildContext context,
  ServerController controller,
) async {
  final choice = await showDialog<_PreparationChoice>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.admin_panel_settings_outlined),
      title: const Text('Server für sicheres Herunterfahren vorbereiten?'),
      content: const Text(
        'Servergy installiert einmalig einen root-eigenen Ausschalt-Helper, eine systemd-Unit und eine eng begrenzte sudoers-Regel für deinen SSH-Benutzer. Dafür wird jetzt einmalig dein sudo-Passwort benötigt. Es wird nicht gespeichert. Der Server wird dabei nicht heruntergefahren.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, _PreparationChoice.manual),
          child: const Text('Manuell einrichten'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, _PreparationChoice.install),
          child: const Text('Server vorbereiten'),
        ),
      ],
    ),
  );
  if (choice == _PreparationChoice.manual && context.mounted) {
    await _showManualPoweroffSetup(context);
    return;
  }
  if (choice == _PreparationChoice.install) {
    await controller.provisionPoweroffHelper(
      (request) => _askCredentials(context, request),
      () => _askSudoPassword(context),
      (fingerprint) => _confirmTrust(context, fingerprint),
    );
    if (!context.mounted) return;
    // This Settings route started the operation, so it owns the final notice.
    // Keeping it here avoids a background HomeScreen Snackbar competing with
    // the just-dismissed password dialog.
    final notice = controller.lastNotice;
    final showManualSetup = _needsManualPoweroffSetup(
      controller.lastErrorCode,
    );
    if (notice != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
      controller.clearNotice();
    }
    if (showManualSetup && context.mounted) {
      await _showManualPoweroffSetup(context);
    }
  }
}

/// The removal path is separate from connection deletion: it changes exactly
/// three remote Servergy files, while the local SSH profile and WOL data stay
/// available for a later setup.
Future<void> _offerHelperRemoval(
  BuildContext context,
  ServerController controller,
) async {
  final remove = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: Theme.of(dialog).colorScheme.error,
      ),
      title: const Text('Servergy-Ausschalt-Helper entfernen?'),
      content: const Text(
        'Dadurch werden der Servergy-Helper, seine systemd-Unit und die dazugehörige sudoers-Regel vom Server entfernt. SSH, Wake-on-LAN und deine gespeicherte Verbindung bleiben erhalten. Danach kann Servergy den Server erst nach einer erneuten Vorbereitung wieder herunterfahren.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialog).colorScheme.error,
            foregroundColor: Theme.of(dialog).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Vom Server entfernen'),
        ),
      ],
    ),
  );
  if (remove != true) return;
  await controller.removePoweroffHelper(
    (request) => _askCredentials(context, request),
    () => _askSudoPassword(context),
    (fingerprint) => _confirmTrust(context, fingerprint),
  );
  if (!context.mounted) return;
  final notice = controller.lastNotice;
  if (notice != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
    controller.clearNotice();
  }
}

enum _PreparationChoice { install, manual }

bool _needsManualPoweroffSetup(String? code) => switch (code) {
  'provision_sudo_denied' ||
  'provision_sudo_missing' ||
  'provision_sudo_tty_required' ||
  'provision_systemd_unavailable' => true,
  _ => false,
};

const _manualPoweroffSetup =
    '''# Auf dem Debian-Server als Administrator ausführen.
sudo install -o root -g root -m 0644 /dev/stdin /etc/systemd/system/servergy-poweroff.service <<'EOF'
[Unit]
Description=Power off this host after a Servergy request

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 2
ExecStart=/usr/bin/systemctl poweroff --no-block
EOF
sudo install -o root -g root -m 0755 /dev/stdin /usr/local/sbin/servergy-poweroff <<'EOF'
#!/bin/sh
set -eu
/usr/bin/systemctl start --no-block servergy-poweroff.service
printf '%s\\n' 'servergy-poweroff-accepted'
EOF
sudo systemctl daemon-reload
# SSH-BENUTZER durch den in Servergy eingetragenen Namen ersetzen:
echo 'SSH-BENUTZER ALL=(root) NOPASSWD: /usr/local/sbin/servergy-poweroff' | sudo tee /etc/sudoers.d/servergy >/dev/null
sudo chmod 0440 /etc/sudoers.d/servergy
sudo visudo -cf /etc/sudoers.d/servergy''';

Future<void> _showManualPoweroffSetup(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Manuelle Debian-Einrichtung'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: SelectableText(
            'Führe diesen festen Ablauf an der Serverkonsole aus. Ersetze ausschließlich SSH-BENUTZER; gib keine eigenen Befehle in Servergy ein.\n\n$_manualPoweroffSetup',
            style: Theme.of(
              dialog,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(text: _manualPoweroffSetup),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Anleitung wurde kopiert.')),
              );
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Kopieren'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Fertig'),
        ),
      ],
    ),
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

Future<String?> _askSudoPassword(BuildContext context) async {
  final input = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.admin_panel_settings_outlined),
      title: const Text('Einmaliges sudo-Passwort'),
      content: TextField(
        controller: input,
        autofocus: true,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.pop(dialog, value),
        decoration: const InputDecoration(
          labelText: 'sudo-Passwort',
          helperText: 'Wird nur für diese Servervorbereitung verwendet.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, input.text),
          child: const Text('Vorbereiten'),
        ),
      ],
    ),
  );
  input.dispose();
  return value == null || value.isEmpty ? null : value;
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
  // Reveal the values that a selection just filled in. This prevents long
  // search results from hiding the next required field on small phones.
  final _hostFieldKey = GlobalKey();
  final _macFieldKey = GlobalKey();
  // Stepper manages a long form on small phones. Keeping the controller here
  // lets Flutter retain a stable scroll position during rebuilds.
  final _stepScrollController = ScrollController();
  var _step = 0;
  // A new setup must be completed in order. Existing profiles already contain
  // all values, so their settings can be opened at any step straight away.
  var _furthestUnlockedStep = 0;
  var _mode = AuthenticationMode.keyPreferred;
  var _configureWake = false;
  var _connectionVerified = false;
  // Only an already saved profile is being edited in Settings. A profile that
  // was just verified during first-run setup should not immediately offer a
  // destructive action before the user has even finished the assistant.
  var _editingExistingConnection = false;
  String? _keyPem;
  String? _selectedCandidateKey;
  DiscoveredServer? _selectedCandidate;
  WakeOnLanCandidate? _wakeCandidate;

  @override
  void initState() {
    super.initState();
    final p = ref.read(controllerProvider).profile;
    if (p != null) {
      _editingExistingConnection = true;
      _furthestUnlockedStep = 4;
      _connectionVerified = true;
      _name.text = p.name;
      _host.text = p.host;
      _sshPort.text = '${p.sshPort}';
      _user.text = p.username;
      _configureWake = p.canWake;
      if (p.wakeOnLan case final wol?) {
        _mac.text = '${wol.mac}';
        _broadcast.text = wol.broadcast;
        _wolPort.text = '${wol.port}';
      }
      _mode = p.authenticationMode;
    }
  }

  @override
  void dispose() {
    _stepScrollController.dispose();
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
      actions: [
        if (_editingExistingConnection)
          IconButton(
            tooltip: 'Verbindung löschen',
            onPressed: ref.watch(controllerProvider).busy
                ? null
                : _deleteConnection,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Form(
        key: _form,
        child: Stepper(
          controller: _stepScrollController,
          physics: const ClampingScrollPhysics(),
          // The default Stepper margin is generous on tablets but makes the
          // content too narrow on phones. A small, explicit margin works from
          // compact phones through desktop windows without touching the rail.
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 28),
          clipBehavior: Clip.none,
          currentStep: _step,
          onStepTapped: _goToStep,
          onStepCancel: _step == 0
              ? () => Navigator.pop(context)
              : () => _goToStep(_step - 1),
          onStepContinue: _continue,
          controlsBuilder: (context, details) => _stepControls(details),
          steps: [
            Step(
              title: const Text('Netzwerkgrenze'),
              isActive: _isStepUnlocked(0),
              state: _stepState(0),
              content: _stepContent(
                const _StepInfo(
                  icon: Icons.home_outlined,
                  text:
                      'Für die Ersteinrichtung muss dein Homeserver eingeschaltet und im Heimnetz erreichbar sein. Servergy arbeitet im Heimnetz oder über ein vorhandenes VPN. Die automatische Suche prüft nur dein aktuelles lokales Netz; VPN-Ziele trägst du manuell ein.',
                ),
              ),
            ),
            Step(
              title: const Text('Server finden'),
              isActive: _isStepUnlocked(1),
              state: _stepState(1),
              content: _stepContent(
                Column(
                  children: [
                    _field(
                      _name,
                      'Anzeigename',
                      Icons.badge_outlined,
                      onChanged: _markConnectionUnverified,
                    ),
                    _field(
                      _sshPort,
                      'SSH-Port',
                      Icons.settings_ethernet_rounded,
                      number: true,
                      onChanged: _markConnectionUnverified,
                    ),
                    _discoveryCard(),
                    const SizedBox(height: 12),
                    _field(
                      _host,
                      'Hostname oder IP-Adresse',
                      Icons.lan_outlined,
                      containerKey: _hostFieldKey,
                      onChanged: _markConnectionUnverified,
                    ),
                    _field(
                      _user,
                      'SSH-Benutzername',
                      Icons.person_outline_rounded,
                      onChanged: _markConnectionUnverified,
                    ),
                  ],
                ),
              ),
            ),
            Step(
              title: const Text('SSH-Zugang'),
              isActive: _isStepUnlocked(2),
              state: _stepState(2),
              content: _stepContent(_authStep()),
            ),
            Step(
              title: const Text('Verbindung prüfen'),
              isActive: _isStepUnlocked(3),
              state: _stepState(3),
              content: _stepContent(
                const _StepInfo(
                  icon: Icons.verified_user_outlined,
                  text:
                      'Prüfe jetzt SSH-Zugang und Serveridentität. Beim ersten Kontakt auf diesem Gerät wird Schlüsseltyp und SHA-256-Fingerprint angezeigt. Vergleiche ihn direkt am Server, bevor du vertraust.',
                ),
              ),
            ),
            Step(
              title: const Text('Server später starten'),
              isActive: _isStepUnlocked(4),
              state: _stepState(4),
              content: _stepContent(_wakeStep()),
            ),
          ],
        ),
      ),
    ),
  );

  /// Adds breathing room above every step's first child. Floating field labels
  /// can otherwise be clipped by the Stepper's expanding/collapsing viewport.
  Widget _stepContent(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 4), child: child);

  /// Keeps the labels in their hit areas even with large system fonts. The
  /// stacked layout is deliberately used at every width: the Stepper's rail
  /// leaves little space on phones, and this avoids resolution-dependent rows.
  Widget _stepControls(ControlsDetails details) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: details.onStepContinue,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(switch (_step) {
            3 => 'Verbindung prüfen und speichern',
            4 => 'Fertig',
            _ => 'Weiter',
          }, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: details.onStepCancel,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          child: Text(
            _step == 0 ? 'Abbrechen' : 'Zurück',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );

  bool _isStepUnlocked(int target) => target <= _furthestUnlockedStep;

  StepState _stepState(int target) =>
      _isStepUnlocked(target) ? StepState.indexed : StepState.disabled;

  void _goToStep(int target) {
    if (!_isStepUnlocked(target)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dieser Schritt wird nach dem vorherigen Schritt freigeschaltet.',
          ),
        ),
      );
      return;
    }
    if (target == _step) return;
    setState(() => _step = target);
  }

  Widget _authStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RadioListTile<AuthenticationMode>(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        value: AuthenticationMode.keyPreferred,
        groupValue: _mode,
        onChanged: (v) => setState(() {
          _mode = v!;
          _connectionVerified = false;
        }),
        title: const Text('SSH-Schlüssel (empfohlen)'),
        subtitle: Text(
          _keyPem == null
              ? 'Importiere einen privaten OpenSSH-, RSA- oder EC-Schlüssel.'
              : 'Schlüssel ist für den Import ausgewählt.',
        ),
        secondary: const Icon(Icons.key_outlined),
      ),
      if (_mode == AuthenticationMode.keyPreferred)
        Padding(
          // Keep the button's rounded border clear of the Stepper rail on
          // narrow displays. It also leaves room for focus and touch effects.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: OutlinedButton.icon(
            onPressed: _importKey,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(
              _keyPem == null
                  ? 'Schlüsseldatei auswählen'
                  : 'Schlüsseldatei ändern',
            ),
          ),
        ),
      RadioListTile<AuthenticationMode>(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        value: AuthenticationMode.passwordOnly,
        groupValue: _mode,
        onChanged: (v) => setState(() {
          _mode = v!;
          _connectionVerified = false;
        }),
        title: const Text('Passwort'),
        subtitle: const Text(
          'Das Passwort wird nach dem Speichern sicher auf diesem Gerät hinterlegt.',
        ),
        secondary: const Icon(Icons.password_outlined),
      ),
      if (_mode == AuthenticationMode.passwordOnly)
        _field(
          _password,
          'SSH-Passwort',
          Icons.password_outlined,
          obscureText: true,
          helperText: 'Leer: vorhandenes gespeichertes Passwort beibehalten.',
          onChanged: _markConnectionUnverified,
        ),
    ],
  );

  Widget _wakeStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Nach der sicheren SSH-Prüfung kann Servergy den aktiven Debian-Netzwerkadapter erkennen und passende WOL-Werte vorschlagen.',
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _connectionVerified && !ref.watch(controllerProvider).busy
            ? _detectWakeOnLan
            : null,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('WOL automatisch erkennen'),
      ),
      if (!_connectionVerified)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Prüfe und speichere zuerst die SSH-Verbindung im vorherigen Schritt.',
          ),
        ),
      if (_wakeCandidate case final candidate?) ...[
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Automatisch erkannt'),
                const SizedBox(height: 6),
                Text('Netzwerkadapter: ${candidate.interfaceName}'),
                Text('MAC-Adresse: ${candidate.settings.mac}'),
                Text('Broadcast: ${candidate.settings.broadcast}'),
                Text('UDP-Port: ${candidate.settings.port}'),
              ],
            ),
          ),
        ),
      ],
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _configureWake,
        onChanged: (value) {
          setState(() => _configureWake = value);
          if (value) _scrollTo(_macFieldKey);
        },
        title: const Text('Wake-on-LAN jetzt einrichten'),
        subtitle: const Text(
          'Du kannst Werte prüfen oder manuell ergänzen. Dieser Schritt bleibt optional.',
        ),
      ),
      if (_configureWake) ...[
        _field(
          _mac,
          'MAC-Adresse',
          Icons.memory_rounded,
          containerKey: _macFieldKey,
        ),
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
        const _StepInfo(
          icon: Icons.info_outline_rounded,
          text:
              'Wake-on-LAN startet einen ausgeschalteten Server später wieder. Ein echter Starttest erfolgt erst, nachdem der Server heruntergefahren wurde.',
        ),
      ] else
        const _StepInfo(
          icon: Icons.schedule_outlined,
          text:
              'Kein Problem: Wake-on-LAN kannst du später in den Einstellungen ergänzen.',
        ),
      if (_editingExistingConnection) ...[
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Sicheres Herunterfahren',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Installiert einmalig den eingeschränkten Servergy-Helper. Das sudo-Passwort wird nur während der Einrichtung verwendet und nicht gespeichert.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: ref.watch(controllerProvider).busy
              ? null
              : () => _offerServerPreparation(
                  context,
                  ref.read(controllerProvider.notifier),
                ),
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: const Text('Server vorbereiten', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: ref.watch(controllerProvider).busy
              ? null
              : () => _offerHelperRemoval(
                  context,
                  ref.read(controllerProvider.notifier),
                ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text(
            'Installierten Helper entfernen',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Verbindung entfernen',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Löscht das Serverprofil sowie gespeicherte Zugangsdaten und den bestätigten SSH-Fingerprint von diesem Gerät.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: ref.watch(controllerProvider).busy
              ? null
              : _deleteConnection,
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(color: Theme.of(context).colorScheme.error),
            minimumSize: const Size.fromHeight(52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Verbindung löschen', textAlign: TextAlign.center),
        ),
      ],
    ],
  );

  Widget _discoveryCard() {
    final discovery = ref.watch(discoveryProvider);
    final searching = discovery.isSearching;
    if (_selectedCandidate case final candidate?) {
      return Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: const Icon(Icons.check_circle_outline_rounded),
          title: const Text('Serveradresse übernommen'),
          subtitle: Text(
            '${candidate.host}:${candidate.port} · Ergänze jetzt den SSH-Benutzernamen.',
          ),
          trailing: TextButton(
            onPressed: () => setState(() {
              _selectedCandidateKey = null;
              _selectedCandidate = null;
            }),
            child: const Text('Ändern'),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Server im Netzwerk suchen',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sucht nur mögliche SSH-Server im aktuellen Heimnetz. Ein Treffer ist noch keine Identitätsbestätigung.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: searching
                  ? ref.read(discoveryProvider.notifier).cancel
                  : () {
                      // A fresh scan must not make an old result look like it
                      // was selected in the newly returned result list.
                      setState(() {
                        _selectedCandidateKey = null;
                        _selectedCandidate = null;
                      });
                      try {
                        ref
                            .read(discoveryProvider.notifier)
                            .search(
                              validatePort(_sshPort.text, label: 'SSH-Port'),
                            );
                      } on ServergyError catch (error) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error.message)));
                      }
                    },
              icon: Icon(
                searching ? Icons.close_rounded : Icons.search_rounded,
              ),
              label: Text(searching ? 'Suche abbrechen' : 'Server suchen'),
            ),
            if (discovery.scope != null) ...[
              const SizedBox(height: 8),
              Text('Geprüfter Bereich: ${discovery.scope!.label}'),
            ],
            if (searching) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (discovery.error != null) ...[
              const SizedBox(height: 12),
              Text(
                discovery.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            for (final candidate in discovery.candidates) ...[
              const Divider(height: 24),
              _discoveredServerCandidate(candidate),
            ],
            if (discovery.status == DiscoveryStatus.completed &&
                discovery.candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Keine SSH-Server gefunden. Gib Hostname oder IP-Adresse manuell ein.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Displays a result without putting an action into ListTile.trailing. A
  /// trailing text was too narrow on real phones and did not look clickable.
  Widget _discoveredServerCandidate(DiscoveredServer candidate) {
    final selected = _selectedCandidateKey == _candidateKey(candidate);
    final summary = [
      if (candidate.serviceName != null) candidate.serviceName!,
      if (candidate.banner.isNotEmpty) candidate.banner,
    ].join('\n');
    return Semantics(
      container: true,
      liveRegion: selected,
      label: selected
          ? 'Serveradresse und SSH-Port wurden übernommen.'
          : 'Gefundener möglicher SSH-Server ${candidate.host} auf Port ${candidate.port}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dns_outlined),
            title: Text('${candidate.host}:${candidate.port}'),
            subtitle: summary.isEmpty ? null : Text(summary),
            onTap: () => _applyCandidate(candidate),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _applyCandidate(candidate),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: Icon(
              selected
                  ? Icons.check_circle_outline_rounded
                  : Icons.download_rounded,
            ),
            label: Text(
              selected ? 'Übernommen' : 'Übernehmen',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _candidateKey(DiscoveredServer candidate) =>
      '${candidate.host}:${candidate.port}';

  void _applyCandidate(DiscoveredServer candidate) {
    setState(() {
      _host.text = candidate.host;
      _sshPort.text = '${candidate.port}';
      _selectedCandidateKey = _candidateKey(candidate);
      _selectedCandidate = candidate;
    });
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Serveradresse und SSH-Port wurden übernommen. Ergänze jetzt den SSH-Benutzernamen.',
          ),
        ),
      );
    _scrollTo(_hostFieldKey);
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool number = false,
    bool obscureText = false,
    String? helperText,
    Key? containerKey,
    ValueChanged<String>? onChanged,
  }) => Padding(
    // The label is part of the same card as its value. This avoids the visual
    // break created by Material's floating labels above filled input fields.
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
    child: Semantics(
      container: true,
      label: label,
      child: Container(
        key: containerKey ?? ValueKey('field-container-$label'),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: .52),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('field-$label'),
                      controller: controller,
                      keyboardType: number ? TextInputType.number : null,
                      obscureText: obscureText,
                      enableSuggestions: !obscureText,
                      autocorrect: !obscureText,
                      textAlignVertical: TextAlignVertical.center,
                      style: Theme.of(context).textTheme.titleMedium,
                      onChanged: onChanged,
                      validator: (v) {
                        final required = switch (label) {
                          'MAC-Adresse' ||
                          'Broadcast-Adresse' ||
                          'UDP-Port' => _configureWake,
                          _ => true,
                        };
                        return required && (v == null || v.trim().isEmpty)
                            ? '$label ist erforderlich.'
                            : null;
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
              if (helperText != null) ...[
                const SizedBox(height: 6),
                Text(
                  helperText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> _importKey() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      final pem = utf8.decode(bytes);
      if (!pem.contains('PRIVATE KEY')) throw const FormatException();
      setState(() {
        _keyPem = pem;
        _connectionVerified = false;
      });
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
      if (_step == 2 &&
          _mode == AuthenticationMode.passwordOnly &&
          _password.text.isEmpty &&
          ref.read(controllerProvider).profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gib ein SSH-Passwort ein.')),
        );
        return;
      }
      if (_step == 2 &&
          _mode == AuthenticationMode.keyPreferred &&
          _keyPem == null &&
          ref.read(controllerProvider).profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wähle einen privaten SSH-Schlüssel aus.'),
          ),
        );
        return;
      }
      setState(() {
        _step++;
        _furthestUnlockedStep = math.max(_furthestUnlockedStep, _step);
      });
      return;
    }
    if (_step == 3) {
      await _verifyAndSaveSsh();
      return;
    }
    await _finishSetup();
  }

  void _markConnectionUnverified(String _) {
    if (_connectionVerified) setState(() => _connectionVerified = false);
  }

  ServerProfile _connectionProfile() {
    final existing = ref.read(controllerProvider).profile;
    final host = validateHost(_host.text);
    final port = validatePort(_sshPort.text, label: 'SSH-Port');
    final username = _user.text.trim();
    if (username.isEmpty) {
      throw const ServergyError(
        'SSH-Benutzername ist erforderlich.',
        code: 'username_required',
      );
    }
    final keepWake =
        existing != null && existing.host == host && existing.sshPort == port;
    return ServerProfile(
      name: _name.text.trim().isEmpty ? 'Homeserver' : _name.text.trim(),
      host: host,
      sshPort: port,
      username: username,
      wakeOnLan: keepWake ? existing.wakeOnLan : null,
      authenticationMode: _mode,
    );
  }

  SecretUpdate _passwordUpdate() => _mode == AuthenticationMode.keyPreferred
      ? const SecretUpdate.delete()
      : _password.text.isEmpty
      ? const SecretUpdate.keep()
      : SecretUpdate.replace(_password.text);

  Future<void> _verifyAndSaveSsh() async {
    try {
      final profile = _connectionProfile();
      final saved = await ref
          .read(controllerProvider.notifier)
          .verifyAndSave(
            profile,
            passwordUpdate: _passwordUpdate(),
            privateKeyPem: _keyPem,
            credentials: (request) => _askCredentials(context, request),
            trust: (fingerprint) => _confirmTrust(context, fingerprint),
          );
      if (saved && mounted) {
        setState(() {
          _connectionVerified = true;
          _configureWake = profile.canWake;
          if (profile.wakeOnLan case final wake?) {
            _mac.text = '${wake.mac}';
            _broadcast.text = wake.broadcast;
            _wolPort.text = '${wake.port}';
          }
          _step = 4;
          _furthestUnlockedStep = 4;
        });
      }
    } on ServergyError catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _detectWakeOnLan() async {
    final candidate = await ref
        .read(controllerProvider.notifier)
        .detectWakeOnLan(
          (request) => _askCredentials(context, request),
          (fingerprint) => _confirmTrust(context, fingerprint),
        );
    if (candidate == null || !mounted) return;
    setState(() {
      _wakeCandidate = candidate;
      _configureWake = true;
      _mac.text = '${candidate.settings.mac}';
      _broadcast.text = candidate.settings.broadcast;
      _wolPort.text = '${candidate.settings.port}';
    });
    _scrollTo(_macFieldKey);
  }

  void _scrollTo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext?.findRenderObject();
      if (target is! RenderBox ||
          !mounted ||
          !_stepScrollController.hasClients) {
        return;
      }
      final position = _stepScrollController.position;
      // Stepper expands and collapses between frames, so its internal child
      // offsets are not stable. The rendered on-screen position is reliable:
      // move just far enough to place the fresh field below the app bar.
      final targetOffset =
          position.pixels +
          target.localToGlobal(Offset.zero).dy -
          kToolbarHeight -
          24;
      final offset = targetOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      position.animateTo(
        offset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _finishSetup() async {
    if (!_connectionVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prüfe und speichere zuerst die SSH-Verbindung.'),
        ),
      );
      return;
    }
    WakeOnLanSettings? settings;
    try {
      if (_configureWake) {
        settings = WakeOnLanSettings(
          mac: MacAddress.parse(_mac.text),
          broadcast: validateBroadcast(_broadcast.text),
          port: validatePort(_wolPort.text, label: 'UDP-Port'),
        );
      }
    } on ServergyError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    final saved = await ref
        .read(controllerProvider.notifier)
        .saveWakeOnLanSettings(settings);
    if (saved && mounted) Navigator.pop(context);
  }

  Future<void> _deleteConnection() async {
    if (!await _confirmConnectionDeletion(context) || !mounted) return;
    final deleted = await ref
        .read(controllerProvider.notifier)
        .deleteConnection();
    if (deleted && mounted) Navigator.pop(context);
  }
}

Future<bool> _confirmConnectionDeletion(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Verbindung löschen?'),
        content: const Text(
          'Das Serverprofil, das gespeicherte SSH-Passwort oder der importierte Schlüssel sowie der bestätigte SSH-Fingerprint werden von diesem Gerät gelöscht. Dieser Schritt kann nicht rückgängig gemacht werden. Das redigierte Diagnoseprotokoll bleibt erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialog).colorScheme.error,
              foregroundColor: Theme.of(dialog).colorScheme.onError,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    ) ??
    false;

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
