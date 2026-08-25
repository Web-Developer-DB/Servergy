// ignore_for_file: curly_braces_in_flow_control_structures, prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'services.dart';

final controllerProvider = NotifierProvider<ServerController, AppState>(
  ServerController.new,
);

class AppState {
  const AppState({
    this.profile,
    this.status = ServerStatus.unknown,
    this.message,
    this.error,
    this.busy = false,
    this.diagnostics = const [],
  });

  final ServerProfile? profile;
  final ServerStatus status;
  final String? message;
  final String? error;
  final bool busy;
  final List<DiagnosticEvent> diagnostics;

  AppState copyWith({
    ServerProfile? profile,
    ServerStatus? status,
    String? message,
    String? error,
    bool? busy,
    List<DiagnosticEvent>? diagnostics,
    bool clearMessage = false,
    bool clearError = false,
  }) => AppState(
    profile: profile ?? this.profile,
    status: status ?? this.status,
    message: clearMessage ? null : message ?? this.message,
    error: clearError ? null : error ?? this.error,
    busy: busy ?? this.busy,
    diagnostics: diagnostics ?? this.diagnostics,
  );
}

typedef CredentialPrompter =
    Future<SshCredentials?> Function(CredentialRequest request);
typedef HostKeyPrompter = Future<bool> Function(String fingerprint);

enum CredentialRequest { password, keyPassphrase }

/// Coordinates operations and makes all blocking I/O replaceable in tests.
class ServerController extends Notifier<AppState> {
  ServerController({
    ProfileStore? store,
    NetworkGateway? network,
    SshGateway? ssh,
  }) : _store = store ?? SettingsStore(),
       _network = network ?? NetworkService(),
       _ssh = ssh;

  final ProfileStore _store;
  final NetworkGateway _network;
  SshGateway? _ssh;
  var _operation = 0;

  SshGateway get _sshService => _ssh ??= SshService(_store);

  @override
  AppState build() {
    unawaited(_load());
    return const AppState();
  }

  Future<void> _load() async {
    final watch = Stopwatch()..start();
    final profile = await _store.loadProfile();
    final diagnostics = await _store.diagnostics();
    if (!ref.mounted) return;
    state = state.copyWith(profile: profile, diagnostics: diagnostics);
    await _record(DiagnosticAction.load, true, 'ok', watch.elapsed);
    if (profile != null) await refresh();
  }

  Future<void> saveProfile(
    ServerProfile profile, {
    String? password,
    String? privateKeyPem,
  }) async {
    final watch = Stopwatch()..start();
    try {
      await _store.saveProfile(profile);
      if (password != null) await _store.savePassword(password);
      if (privateKeyPem != null) await _store.savePrivateKey(privateKeyPem);
      if (!ref.mounted) return;
      state = state.copyWith(
        profile: profile,
        message: 'Einstellungen gespeichert. Prüfe jetzt die SSH-Verbindung.',
        clearError: true,
      );
      await _record(DiagnosticAction.configuration, true, 'ok', watch.elapsed);
      await refresh();
    } on ServergyError catch (error) {
      _fail(error, DiagnosticAction.configuration, watch.elapsed);
    }
  }

  Future<void> refresh() async {
    final profile = state.profile;
    if (profile == null || state.busy) return;
    final watch = Stopwatch()..start();
    state = state.copyWith(status: ServerStatus.checking, clearError: true);
    final online = await _network.isReachable(profile);
    if (!ref.mounted) return;
    state = state.copyWith(
      status: online ? ServerStatus.online : ServerStatus.offline,
    );
    await _record(
      DiagnosticAction.refresh,
      true,
      online ? 'online' : 'offline',
      watch.elapsed,
    );
  }

  void cancelOperation() {
    if (!state.busy) return;
    _operation++;
    state = state.copyWith(
      busy: false,
      status: ServerStatus.unknown,
      message: 'Aktion abgebrochen. Aktualisiere den Status bei Bedarf.',
      clearError: true,
    );
  }

  Future<void> wake() async {
    final profile = state.profile;
    if (profile == null || state.busy) return;
    final token = ++_operation;
    final watch = Stopwatch()..start();
    state = state.copyWith(
      busy: true,
      status: ServerStatus.waking,
      clearError: true,
    );
    try {
      if (await _network.isReachable(profile)) {
        _complete(token, ServerStatus.online, 'Der Server läuft bereits.');
        await _record(
          DiagnosticAction.wake,
          true,
          'already_online',
          watch.elapsed,
        );
        return;
      }
      await _network.wake(profile);
      if (!_active(token)) return;
      state = state.copyWith(
        message: 'Startsignal gesendet – warte auf den Server …',
      );
      for (var attempt = 0; attempt < 45; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!_active(token)) return;
        if (await _network.isReachable(profile)) {
          _complete(token, ServerStatus.online, 'Server ist erreichbar.');
          await _record(DiagnosticAction.wake, true, 'online', watch.elapsed);
          return;
        }
      }
      throw const ServergyError(
        'Startsignal gesendet, aber der Server ist nach 90 Sekunden nicht erreichbar. Prüfe Broadcast-Adresse und WOL.',
        code: 'wake_timeout',
      );
    } on ServergyError catch (error) {
      if (_active(token)) _fail(error, DiagnosticAction.wake, watch.elapsed);
    } on SocketException {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Das Netzwerk ist nicht erreichbar. Verbinde dich mit Heimnetz oder VPN.',
            code: 'network_unavailable',
          ),
          DiagnosticAction.wake,
          watch.elapsed,
        );
      }
    }
  }

  Future<void> testSsh(CredentialPrompter credentials, HostKeyPrompter trust) =>
      _sshAction(false, credentials, trust);

  Future<void> shutdown(
    CredentialPrompter credentials,
    HostKeyPrompter trust,
  ) => _sshAction(true, credentials, trust);

  Future<void> _sshAction(
    bool shutdown,
    CredentialPrompter prompt,
    HostKeyPrompter trust,
  ) async {
    final profile = state.profile;
    if (profile == null || state.busy) return;
    final token = ++_operation;
    final action = shutdown
        ? DiagnosticAction.shutdown
        : DiagnosticAction.sshTest;
    final watch = Stopwatch()..start();
    state = state.copyWith(
      busy: true,
      status: shutdown ? ServerStatus.shuttingDown : ServerStatus.checking,
      clearError: true,
    );
    try {
      if (shutdown && !await _network.isReachable(profile)) {
        _complete(
          token,
          ServerStatus.offline,
          'Der Server ist bereits ausgeschaltet.',
        );
        await _record(action, true, 'already_offline', watch.elapsed);
        return;
      }
      var auth = await _readCredentials(profile, prompt);
      if (auth == null || !_active(token)) {
        if (_active(token))
          _complete(token, ServerStatus.unknown, 'Aktion abgebrochen.');
        return;
      }
      try {
        if (shutdown) {
          await _sshService.poweroff(profile, auth, onUnknownHostKey: trust);
        } else {
          await _sshService.test(profile, auth, onUnknownHostKey: trust);
        }
      } on SSHAuthFailError {
        // Only a key-only attempt may ask for the password after an auth reject.
        if (!auth.hasKey || auth.hasPassword) rethrow;
        final fallback = await prompt(CredentialRequest.password);
        if (fallback == null || !fallback.hasPassword) rethrow;
        auth = SshCredentials(
          privateKeyPem: auth.privateKeyPem,
          keyPassphrase: auth.keyPassphrase,
          password: fallback.password,
        );
        if (shutdown) {
          await _sshService.poweroff(profile, auth, onUnknownHostKey: trust);
        } else {
          await _sshService.test(profile, auth, onUnknownHostKey: trust);
        }
      }
      if (!_active(token)) return;
      if (!shutdown) {
        _complete(
          token,
          ServerStatus.online,
          'SSH-Verbindung erfolgreich getestet.',
        );
        await _record(action, true, 'ok', watch.elapsed);
        return;
      }
      for (var attempt = 0; attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!_active(token)) return;
        if (!await _network.isReachable(profile)) {
          _complete(
            token,
            ServerStatus.offline,
            'Server wurde heruntergefahren.',
          );
          await _record(action, true, 'offline', watch.elapsed);
          return;
        }
      }
      throw const ServergyError(
        'Der Server ist weiterhin erreichbar. Prüfe ihn manuell und die sudoers-Regel.',
        code: 'shutdown_timeout',
      );
    } on ServergyError catch (error) {
      if (_active(token)) _fail(error, action, watch.elapsed);
    } on SSHAuthFailError {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Die SSH-Anmeldung wurde abgelehnt. Prüfe Schlüssel oder Passwort.',
            code: 'auth_denied',
          ),
          action,
          watch.elapsed,
        );
      }
    } on SocketException {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Der Server ist über SSH nicht erreichbar. Prüfe Heimnetz oder VPN.',
            code: 'ssh_unreachable',
          ),
          action,
          watch.elapsed,
        );
      }
    } catch (_) {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Die SSH-Aktion ist fehlgeschlagen. Öffne die Diagnose für Details.',
            code: 'ssh_failed',
          ),
          action,
          watch.elapsed,
        );
      }
    }
  }

  Future<SshCredentials?> _readCredentials(
    ServerProfile profile,
    CredentialPrompter prompt,
  ) async {
    final key = await _store.privateKey();
    final password = await _store.password();
    if (profile.authenticationMode == AuthenticationMode.keyPreferred &&
        key != null) {
      String? passphrase;
      if (SSHKeyPair.isEncryptedPem(key)) {
        passphrase = (await prompt(
          CredentialRequest.keyPassphrase,
        ))?.keyPassphrase;
        if (passphrase == null || passphrase.isEmpty) return null;
      }
      return SshCredentials(
        privateKeyPem: key,
        keyPassphrase: passphrase,
        password: password,
      );
    }
    if (password != null && password.isNotEmpty)
      return SshCredentials(password: password);
    return prompt(CredentialRequest.password);
  }

  bool _active(int token) => ref.mounted && token == _operation;

  void _complete(int token, ServerStatus status, String message) {
    if (!_active(token)) return;
    state = state.copyWith(
      busy: false,
      status: status,
      message: message,
      clearError: true,
    );
  }

  void clearNotice() =>
      state = state.copyWith(clearMessage: true, clearError: true);

  void _fail(ServergyError error, DiagnosticAction action, Duration elapsed) {
    state = state.copyWith(
      busy: false,
      error: error.message,
      clearMessage: true,
    );
    unawaited(_record(action, false, error.code, elapsed));
  }

  Future<void> _record(
    DiagnosticAction action,
    bool success,
    String code,
    Duration duration,
  ) async {
    final event = DiagnosticEvent(
      at: DateTime.now(),
      action: action,
      success: success,
      code: code,
      duration: duration,
    );
    await _store.addDiagnostic(event);
    if (ref.mounted)
      state = state.copyWith(diagnostics: await _store.diagnostics());
  }
}
