// RadioGroup is not yet available in the project's supported Flutter SDK;
// the current RadioListTile API remains compatible with Android, Linux, Windows.
// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/app_metadata.dart';
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
  const navy = Color(0xff092a3d);
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: navy, brightness: brightness)
      .copyWith(
        primary: dark ? const Color(0xff4ee29a) : const Color(0xff007a43),
        onPrimary: dark ? navy : Colors.white,
        secondary: dark ? const Color(0xff75d6f4) : const Color(0xff006782),
        onSecondary: dark ? navy : Colors.white,
        tertiary: dark ? const Color(0xff8ec8ff) : const Color(0xff185c81),
        surface: dark ? const Color(0xff101d27) : const Color(0xfff6f8fb),
        surfaceContainerLow: dark
            ? const Color(0xff172934)
            : const Color(0xffffffff),
        surfaceContainerHighest: dark
            ? const Color(0xff263a46)
            : const Color(0xffeaf0f5),
      );
  const cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: Typography.material2021().black.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      shape: cardShape,
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
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: cardShape,
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
            tooltip: 'Ereignisse',
            onPressed: () => _open(context, const EventsScreen()),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: () => _open(context, const SettingsScreen()),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  profile == null ? 'Dein Homeserver.' : 'Guten Tag.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile == null
                      ? 'Lokal steuern – im Heimnetz oder über dein VPN.'
                      : 'Deine Verbindung auf einen Blick.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                _StatusCard(state: state),
                const SizedBox(height: 28),
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
    final lastCheck = _lastRelevantEvent(state.diagnostics);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          title,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
              const SizedBox(height: 20),
              Text(detail, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              Text(
                lastCheck == null
                    ? 'Noch nicht geprüft'
                    : 'Zuletzt geprüft: ${_formatMoment(lastCheck.at)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (state.profile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 2),
                    leading: const Icon(Icons.dns_outlined),
                    title: const Text('Verbindungsdetails'),
                    subtitle: const Text('Adresse und SSH-Port'),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(
                          '${state.profile!.host}:${state.profile!.sshPort}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
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
      ),
    );
  }
}

class _SetupCallout extends StatelessWidget {
  const _SetupCallout();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.rocket_launch_outlined,
            color: Theme.of(context).colorScheme.secondary,
            size: 28,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 22),
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
        const _SectionHeading(
          title: 'Schnellaktionen',
          subtitle: 'Steuere deinen Server sicher von diesem Gerät.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: state.busy
              ? null
              : profile.canWake
              ? controller.wake
              : () => _open(context, const SetupScreen(initialStep: 4)),
          icon: Icon(
            profile.canWake
                ? Icons.keyboard_double_arrow_up_rounded
                : Icons.add_link_rounded,
          ),
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
        Card(
          child: ListTile(
            leading: Icon(
              Icons.verified_user_outlined,
              color: scheme.secondary,
            ),
            title: const Text('SSH-Verbindung testen'),
            subtitle: const Text('Zugang und Serveridentität prüfen'),
            trailing: const Icon(Icons.chevron_right_rounded),
            enabled: !state.busy,
            onTap: () => controller.testSsh(
              (request) => _askCredentials(context, request),
              (fingerprint) => _confirmTrust(context, fingerprint),
            ),
          ),
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
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

DiagnosticEvent? _lastRelevantEvent(List<DiagnosticEvent> events) {
  final matching = events.where(
    (event) =>
        event.action == DiagnosticAction.refresh ||
        event.action == DiagnosticAction.sshTest ||
        event.action == DiagnosticAction.load,
  );
  return matching.isEmpty ? null : matching.last;
}

String _formatMoment(DateTime time) {
  final now = DateTime.now();
  final sameDay =
      now.year == time.year && now.month == time.month && now.day == time.day;
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return sameDay
      ? 'heute, $hour:$minute'
      : '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.$hour:$minute';
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
    final showManualSetup = _needsManualPoweroffSetup(controller.lastErrorCode);
    if (notice != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notice)));
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

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(controllerProvider);
    final profile = state.profile;
    final controller = ref.read(controllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const _SectionHeading(
            title: 'Dein Servergy',
            subtitle: 'Verbindung, Steuerung und Produktinformationen.',
          ),
          const SizedBox(height: 20),
          if (profile == null) ...[
            _SettingsGroup(
              title: 'Homeserver',
              children: [
                ListTile(
                  leading: const Icon(Icons.add_home_outlined),
                  title: const Text('Homeserver einrichten'),
                  subtitle: const Text(
                    'Starte den sicheren Einrichtungsassistenten.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _open(context, const SetupScreen()),
                ),
              ],
            ),
          ] else ...[
            _SettingsGroup(
              title: 'Verbindung',
              children: [
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Serververbindung'),
                  subtitle: Text(
                    '${profile.name} · ${profile.host}:${profile.sshPort}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      _open(context, const SetupScreen(initialStep: 1)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsGroup(
              title: 'Steuerung',
              children: [
                ListTile(
                  leading: const Icon(Icons.wifi_tethering_rounded),
                  title: const Text('Wake-on-LAN'),
                  subtitle: Text(
                    profile.canWake
                        ? 'Für diesen Server eingerichtet'
                        : 'Noch nicht eingerichtet',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      _open(context, const SetupScreen(initialStep: 4)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Sicheres Herunterfahren'),
                  subtitle: const Text(
                    'Servergy-Helper auf dem Server verwalten',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _open(
                    context,
                    _PoweroffSettingsScreen(controller: controller),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'Datenschutz & Diagnose',
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Ereignisse'),
                subtitle: const Text(
                  'Lokales, redigiertes Aktivitätsprotokoll',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(context, const EventsScreen()),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Beta-Feedback geben'),
                subtitle: const Text(
                  'Öffnet die Servergy-Issue-Vorlagen auf GitHub',
                ),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => _showFeedbackNotice(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _AboutServergySection(),
          if (profile != null) ...[
            const SizedBox(height: 20),
            _SettingsGroup(
              title: 'Gefahrenbereich',
              children: [
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Verbindung löschen',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: const Text(
                    'Profil und lokale Zugangsdaten entfernen',
                  ),
                  enabled: !state.busy,
                  onTap: () async {
                    if (!await _confirmConnectionDeletion(context) ||
                        !context.mounted)
                      return;
                    await controller.deleteConnection();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

final _feedbackUri = Uri.parse(
  'https://github.com/Web-Developer-DB/Servergy/issues/new/choose',
);

Future<void> _showFeedbackNotice(BuildContext context) async {
  final continueToGithub = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.privacy_tip_outlined),
      title: const Text('Beta-Feedback sicher senden'),
      content: const Text(
        'GitHub wird in deinem Browser geöffnet. Reiche keine Passwörter, privaten Schlüssel, vollständigen IP-Adressen oder MAC-Adressen ein. Ein Diagnoseexport ist bereits redigiert und kann bei Bedarf bewusst angehängt werden.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialog, true),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('GitHub öffnen'),
        ),
      ],
    ),
  );
  if (continueToGithub != true) return;
  final opened = await launchUrl(
    _feedbackUri,
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'GitHub konnte nicht geöffnet werden. Prüfe deine Browser-Einstellungen.',
        ),
      ),
    );
  }
}

class _PoweroffSettingsScreen extends StatelessWidget {
  const _PoweroffSettingsScreen({required this.controller});
  final ServerController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sicheres Herunterfahren')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _StepInfo(
          icon: Icons.shield_outlined,
          text:
              'Der eingeschränkte Servergy-Helper erlaubt ausschließlich das sichere Herunterfahren. Das sudo-Passwort wird nie gespeichert.',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _offerServerPreparation(context, controller),
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: const Text('Server vorbereiten'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _offerHelperRemoval(context, controller),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Installierten Helper entfernen'),
        ),
      ],
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      Card(child: Column(children: children)),
    ],
  );
}

class _AboutServergySection extends ConsumerWidget {
  const _AboutServergySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(appMetadataProvider);
    return _SettingsGroup(
      title: 'Über Servergy',
      children: [
        ListTile(
          leading: const ServergyMark(),
          title: const Text('Servergy'),
          subtitle: Text(
            metadata.when(
              data: (value) =>
                  '${value.releaseChannel} · ${value.versionLabel}',
              loading: () => 'Produktinformationen werden geladen',
              error: (_, _) => 'Produktinformationen nicht verfügbar',
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Text(
            'Wake-on-LAN und sichere SSH-Steuerung für deinen Homeserver.',
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Datenschutz'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _open(
            context,
            const DocumentScreen(
              title: 'Datenschutz',
              asset: 'docs/privacy.md',
            ),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: const Text('Serveranleitung'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _open(
            context,
            const DocumentScreen(
              title: 'Serveranleitung',
              asset: 'docs/server-setup.md',
            ),
          ),
        ),
        metadata.maybeWhen(
          data: (value) => Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value.supportText));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Versionsinformationen kopiert.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Versionsinformationen kopieren'),
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class DocumentScreen extends StatelessWidget {
  const DocumentScreen({super.key, required this.title, required this.asset});
  final String title;
  final String asset;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: FutureBuilder<String>(
      future: rootBundle.loadString(asset),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Dieses Dokument konnte nicht geladen werden.'),
            ),
          );
        }
        return SelectionArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                snapshot.requireData,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, this.initialStep = 0});
  final int initialStep;
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
  // The focused setup flow keeps one step visible at a time. The controller
  // preserves a stable scroll position while discovery results expand.
  final _stepScrollController = ScrollController();
  var _step = 0;
  // A new setup must be completed in order. Existing profiles unlock every
  // step and are opened from the dedicated settings overview.
  var _furthestUnlockedStep = 0;
  var _mode = AuthenticationMode.keyPreferred;
  var _configureWake = false;
  var _connectionVerified = false;
  String? _keyPem;
  String? _selectedCandidateKey;
  DiscoveredServer? _selectedCandidate;
  WakeOnLanCandidate? _wakeCandidate;

  @override
  void initState() {
    super.initState();
    final p = ref.read(controllerProvider).profile;
    if (p != null) {
      _furthestUnlockedStep = 4;
      _connectionVerified = true;
      _step = widget.initialStep.clamp(0, 4);
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
  Widget build(BuildContext context) {
    final existing = ref.read(controllerProvider).profile != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          existing ? 'Verbindung bearbeiten' : 'Homeserver einrichten',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: Column(
            children: [
              _SetupProgress(step: _step),
              Expanded(
                child: SingleChildScrollView(
                  controller: _stepScrollController,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: _stepContent(),
                ),
              ),
              _setupControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepContent() {
    final (title, description, content) = switch (_step) {
      0 => (
        'Dein Netzwerk',
        'Lege zuerst die sichere Grundlage für die Verbindung.',
        const _StepInfo(
          icon: Icons.home_outlined,
          text:
              'Für die Ersteinrichtung muss dein Homeserver eingeschaltet und im Heimnetz erreichbar sein. Servergy arbeitet im Heimnetz oder über ein vorhandenes VPN. Die automatische Suche prüft nur dein aktuelles lokales Netz; VPN-Ziele trägst du manuell ein.',
        ),
      ),
      1 => (
        'Server finden',
        'Suche im Heimnetz oder trage deine Daten manuell ein.',
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
      2 => (
        'SSH-Zugang',
        'Wähle, wie Servergy sich sicher anmelden soll.',
        _authStep(),
      ),
      3 => (
        'Verbindung prüfen',
        'Bestätige die Identität deines Servers vor dem Speichern.',
        const _StepInfo(
          icon: Icons.verified_user_outlined,
          text:
              'Prüfe jetzt SSH-Zugang und Serveridentität. Beim ersten Kontakt auf diesem Gerät wird Schlüsseltyp und SHA-256-Fingerprint angezeigt. Vergleiche ihn direkt am Server, bevor du vertraust.',
        ),
      ),
      _ => (
        'Server später starten',
        'Wake-on-LAN ist optional und kann jederzeit geändert werden.',
        _wakeStep(),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        content,
      ],
    );
  }

  Widget _setupControls() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _continue,
            child: Text(switch (_step) {
              3 => 'Verbindung prüfen und speichern',
              4 => 'Einrichtung abschließen',
              _ => 'Weiter',
            }),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _step == 0
                ? () => Navigator.pop(context)
                : () => _goToStep(_step - 1),
            child: Text(_step == 0 ? 'Abbrechen' : 'Zurück'),
          ),
        ],
      ),
    ),
  );

  bool _isStepUnlocked(int target) => target <= _furthestUnlockedStep;

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
      // The focused page may grow when discovery results arrive. The rendered
      // on-screen position remains reliable while that happens.
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
}

class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.step});
  final int step;

  static const _labels = ['Netzwerk', 'Server', 'Zugang', 'Prüfung', 'Starten'];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schritt ${step + 1} von ${_labels.length}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(
            _labels.length,
            (index) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == _labels.length - 1 ? 0 : 5,
                ),
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: index <= step
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _labels[step],
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
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

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(controllerProvider).diagnostics.reversed.toList();
    final report = events.map((e) => e.toExportLine()).join('\n');
    final latest = events.isEmpty ? null : events.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Ereignisse')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const _SectionHeading(
            title: 'Aktivität',
            subtitle: 'Lokale Ereignisse ohne sensible Verbindungsdaten.',
          ),
          const SizedBox(height: 20),
          _EventSummary(event: latest, total: events.length),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: events.isEmpty ? null : () => _export(context, report),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Redigierte Diagnose exportieren'),
          ),
          const SizedBox(height: 28),
          if (events.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Noch keine Ereignisse vorhanden. Aktionen und Prüfungen erscheinen hier automatisch.',
                ),
              ),
            ),
          for (final entry in events.indexed) ...[
            if (entry.$1 == 0 ||
                !_isSameDay(events[entry.$1 - 1].at, entry.$2.at))
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  _formatDay(entry.$2.at),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            _EventRow(event: entry.$2),
            const SizedBox(height: 8),
          ],
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

class _EventSummary extends StatelessWidget {
  const _EventSummary({required this.event, required this.total});
  final DiagnosticEvent? event;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = event;
    final success = current?.success ?? true;
    final color = success ? scheme.primary : scheme.error;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_rounded : Icons.priority_high_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current == null
                      ? 'Noch keine Aktivität'
                      : success
                      ? 'Letzte Aktion erfolgreich'
                      : 'Letzte Aktion braucht Aufmerksamkeit',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  current == null
                      ? 'Starte eine Prüfung oder richte deinen Server ein.'
                      : '${_eventActionLabel(current.action)} · ${_formatMoment(current.at)} · $total Einträge',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final DiagnosticEvent event;

  @override
  Widget build(BuildContext context) {
    final color = event.success
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Card(
      child: ListTile(
        leading: Icon(
          event.success
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          color: color,
        ),
        title: Text(_eventActionLabel(event.action)),
        subtitle: Text(
          '${event.success ? 'Erfolgreich' : 'Nicht erfolgreich'} · ${_formatMoment(event.at)}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _open(context, EventDetailScreen(event: event)),
      ),
    );
  }
}

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.event});
  final DiagnosticEvent event;

  @override
  Widget build(BuildContext context) {
    final success = event.success;
    final color = success
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Ereignisdetails')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: color,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _eventActionLabel(event.action),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            success
                ? 'Die Aktion wurde erfolgreich abgeschlossen.'
                : 'Die Aktion konnte nicht abgeschlossen werden.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          _DetailRow(label: 'Zeitpunkt', value: _formatFullMoment(event.at)),
          _DetailRow(
            label: 'Dauer',
            value: '${event.duration.inMilliseconds} ms',
          ),
          _DetailRow(
            label: 'Ergebnis',
            value: success ? 'Erfolgreich' : 'Nicht erfolgreich',
          ),
          _DetailRow(label: 'Technische Kennung', value: event.code),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

bool _isSameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDay(DateTime date) {
  final now = DateTime.now();
  if (_isSameDay(now, date)) return 'Heute';
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(yesterday, date)) return 'Gestern';
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

String _formatFullMoment(DateTime time) =>
    '${_formatDay(time)}, ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

String _eventActionLabel(DiagnosticAction action) => switch (action) {
  DiagnosticAction.load => 'App-Status geladen',
  DiagnosticAction.refresh => 'Serverstatus geprüft',
  DiagnosticAction.wake => 'Startsignal gesendet',
  DiagnosticAction.sshTest => 'SSH-Verbindung geprüft',
  DiagnosticAction.shutdown => 'Herunterfahren angefordert',
  DiagnosticAction.provisioning => 'Server vorbereitet',
  DiagnosticAction.helperRemoval => 'Servergy-Helper entfernt',
  DiagnosticAction.configuration => 'Einstellungen gespeichert',
  DiagnosticAction.discovery => 'Server im Netzwerk gesucht',
};

class ServergyMark extends StatelessWidget {
  const ServergyMark({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: const _ServergyMarkPainter()),
    ),
  );
}

/// The in-app mark mirrors the launcher asset without requiring an SVG
/// renderer at runtime. It stays crisp at compact app-bar and settings sizes.
class _ServergyMarkPainter extends CustomPainter {
  const _ServergyMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 34;
    final background = Paint()..color = const Color(0xff092a3d);
    final surface = Paint()..color = const Color(0xfff6f8fb);
    final green = Paint()..color = const Color(0xff4ee29a);
    final cyan = Paint()..color = const Color(0xff75d6f4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(9 * scale)),
      background,
    );
    for (final top in [7.5, 14.5, 21.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(7 * scale, top * scale, 20 * scale, 5 * scale),
          Radius.circular(1.7 * scale),
        ),
        surface,
      );
      canvas.drawCircle(
        Offset(22 * scale, (top + 2.5) * scale),
        1 * scale,
        green,
      );
      canvas.drawCircle(
        Offset(24.5 * scale, (top + 2.5) * scale),
        1 * scale,
        cyan,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ServergyMarkPainter oldDelegate) => false;
}
