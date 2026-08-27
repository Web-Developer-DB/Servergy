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

final discoveryProvider = NotifierProvider<DiscoveryController, DiscoveryState>(
  DiscoveryController.new,
);

enum DiscoveryStatus {
  idle,
  preparing,
  searching,
  completed,
  cancelled,
  failed,
}

class DiscoveryState {
  const DiscoveryState({
    this.status = DiscoveryStatus.idle,
    this.scope,
    this.candidates = const [],
    this.error,
  });

  final DiscoveryStatus status;
  final NetworkScope? scope;
  final List<DiscoveredServer> candidates;
  final String? error;

  bool get isSearching =>
      status == DiscoveryStatus.preparing ||
      status == DiscoveryStatus.searching;
}

/// Owns a short-lived, user-triggered discovery run. It intentionally has its
/// own state so searching never locks the power-control buttons on the home UI.
class DiscoveryController extends Notifier<DiscoveryState> {
  DiscoveryController({DiscoveryGateway? discovery})
    : _discovery = discovery ?? DiscoveryService();

  final DiscoveryGateway _discovery;
  final LocalNetworkAccess _localAccess = LocalNetworkAccess();
  var _run = 0;

  @override
  DiscoveryState build() => const DiscoveryState();

  Future<void> search(int port) async {
    if (state.isSearching) return;
    final token = ++_run;
    state = const DiscoveryState(status: DiscoveryStatus.preparing);
    try {
      if (!await _localAccess.ensureAllowed()) {
        throw const ServergyError(
          'Die Freigabe für das lokale Netzwerk wurde nicht erteilt. Du kannst den Server weiterhin manuell eintragen.',
          code: 'local_network_permission_denied',
        );
      }
      final scope = await _discovery.currentScope();
      if (!_active(token)) return;
      state = DiscoveryState(status: DiscoveryStatus.searching, scope: scope);
      final candidates = <String, DiscoveredServer>{};
      await for (final candidate in _discovery.discover(
        scope,
        port: port,
        isCancelled: () => !_active(token),
      )) {
        if (!_active(token)) return;
        final key = '${candidate.host}:${candidate.port}';
        candidates[key] = candidate;
        state = DiscoveryState(
          status: DiscoveryStatus.searching,
          scope: scope,
          candidates: candidates.values.toList(growable: false),
        );
      }
      if (_active(token)) {
        state = DiscoveryState(
          status: DiscoveryStatus.completed,
          scope: scope,
          candidates: candidates.values.toList(growable: false),
        );
      }
    } on ServergyError catch (error) {
      if (_active(token)) {
        state = DiscoveryState(
          status: DiscoveryStatus.failed,
          error: error.message,
        );
      }
    } catch (_) {
      if (_active(token)) {
        state = const DiscoveryState(
          status: DiscoveryStatus.failed,
          error:
              'Die Serversuche konnte nicht gestartet werden. Gib die Adresse manuell ein.',
        );
      }
    }
  }

  void cancel() {
    if (!state.isSearching) return;
    _run++;
    state = DiscoveryState(
      status: DiscoveryStatus.cancelled,
      scope: state.scope,
      candidates: state.candidates,
    );
  }

  bool _active(int token) => ref.mounted && token == _run;
}

class AppState {
  const AppState({
    this.profile,
    this.status = ServerStatus.unknown,
    this.message,
    this.error,
    this.errorCode,
    this.busy = false,
    this.diagnostics = const [],
  });

  final ServerProfile? profile;
  final ServerStatus status;
  final String? message;
  final String? error;

  /// A redacted, stable code lets the UI offer a safe remediation without
  /// parsing German error text or exposing remote stderr.
  final String? errorCode;
  final bool busy;
  final List<DiagnosticEvent> diagnostics;

  AppState copyWith({
    ServerProfile? profile,
    ServerStatus? status,
    String? message,
    String? error,
    String? errorCode,
    bool? busy,
    List<DiagnosticEvent>? diagnostics,
    bool clearMessage = false,
    bool clearError = false,
    bool clearErrorCode = false,
  }) => AppState(
    profile: profile ?? this.profile,
    status: status ?? this.status,
    message: clearMessage ? null : message ?? this.message,
    error: clearError ? null : error ?? this.error,
    errorCode: clearErrorCode ? null : errorCode ?? this.errorCode,
    busy: busy ?? this.busy,
    diagnostics: diagnostics ?? this.diagnostics,
  );
}

typedef CredentialPrompter =
    Future<SshCredentials?> Function(CredentialRequest request);
typedef HostKeyPrompter = Future<bool> Function(String fingerprint);
typedef SudoPasswordPrompter = Future<String?> Function();

enum CredentialRequest { password, keyPassphrase }

/// Coordinates operations and makes all blocking I/O replaceable in tests.
class ServerController extends Notifier<AppState> {
  ServerController({
    ProfileStore? store,
    NetworkGateway? network,
    NetworkScopeGateway? networkScope,
    SshGateway? ssh,
    ServerProvisioningGateway? provisioning,
  }) : _store = store ?? SettingsStore(),
       _network = network ?? NetworkService(),
       _networkScope = networkScope ?? DiscoveryService(),
       _ssh = ssh,
       _provisioning = provisioning;

  final ProfileStore _store;
  final NetworkGateway _network;
  final NetworkScopeGateway _networkScope;
  final LocalNetworkAccess _localAccess = LocalNetworkAccess();
  SshGateway? _ssh;
  ServerProvisioningGateway? _provisioning;
  var _operation = 0;

  SshGateway get _sshService => _ssh ??= SshService(_store);
  ServerProvisioningGateway get _provisioningService =>
      _provisioning ??= _sshService is ServerProvisioningGateway
      ? _sshService as ServerProvisioningGateway
      : SshService(_store);

  /// Exposes only the redacted code needed by the UI to offer a safe recovery
  /// action; widgets must not inspect notifier state directly.
  String? get lastErrorCode => state.errorCode;

  /// The currently pending, user-safe message. A route that initiated an
  /// action can display it itself instead of letting an inactive background
  /// route attempt to show a Snackbar during a dialog transition.
  String? get lastNotice => state.error ?? state.message;

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
    SecretUpdate passwordUpdate = const SecretUpdate.keep(),
    String? privateKeyPem,
  }) async {
    final watch = Stopwatch()..start();
    try {
      if (profile.authenticationMode == AuthenticationMode.passwordOnly &&
          passwordUpdate.kind != SecretUpdateKind.replace &&
          !await _store.hasPassword()) {
        throw const ServergyError(
          'Lege ein SSH-Passwort fest, damit die App die Verbindung später herstellen kann.',
          code: 'password_required',
        );
      }
      await _store.saveProfile(profile);
      await _store.updatePassword(
        profile.authenticationMode == AuthenticationMode.keyPreferred
            ? const SecretUpdate.delete()
            : passwordUpdate,
      );
      if (privateKeyPem != null) await _store.savePrivateKey(privateKeyPem);
      if (!ref.mounted) return;
      state = state.copyWith(
        profile: profile,
        message: 'Einstellungen gespeichert. Teste jetzt die SSH-Verbindung.',
        clearError: true,
      );
      await _record(DiagnosticAction.configuration, true, 'ok', watch.elapsed);
      await refresh();
    } on ServergyError catch (error) {
      _fail(error, DiagnosticAction.configuration, watch.elapsed);
    }
  }

  /// Deletes the single configured server without touching the redacted local
  /// diagnostics. The caller has to ask for confirmation before invoking it.
  Future<bool> deleteConnection() async {
    if (state.profile == null || state.busy) return false;
    final watch = Stopwatch()..start();
    state = state.copyWith(
      busy: true,
      status: ServerStatus.unknown,
      clearError: true,
    );
    try {
      await _store.deleteConnection();
      if (!ref.mounted) return false;
      // Construct a fresh state instead of copyWith: a nullable profile value
      // in copyWith means "keep the old one" and must not resurrect it here.
      state = AppState(
        status: ServerStatus.unknown,
        message: 'Die Verbindung wurde von diesem Gerät gelöscht.',
        diagnostics: state.diagnostics,
      );
      await _record(
        DiagnosticAction.configuration,
        true,
        'connection_deleted',
        watch.elapsed,
      );
      return true;
    } catch (_) {
      if (ref.mounted) {
        _fail(
          const ServergyError(
            'Die Verbindung konnte nicht vollständig gelöscht werden. Versuche es erneut.',
            code: 'connection_delete_failed',
          ),
          DiagnosticAction.configuration,
          watch.elapsed,
        );
      }
      return false;
    }
  }

  /// Reads the MAC address only after the profile, credentials, and host key
  /// have already passed the normal SSH verification flow.
  Future<WakeOnLanCandidate?> detectWakeOnLan(
    CredentialPrompter credentials,
    HostKeyPrompter trust,
  ) async {
    final profile = state.profile;
    if (profile == null || state.busy) return null;
    final watch = Stopwatch()..start();
    final token = ++_operation;
    state = state.copyWith(
      busy: true,
      status: ServerStatus.checking,
      clearError: true,
      clearErrorCode: true,
    );
    try {
      if (!await _localAccess.ensureAllowed()) {
        throw const ServergyError(
          'Die Freigabe für das lokale Netzwerk fehlt. Wake-on-LAN kann weiterhin manuell eingerichtet werden.',
          code: 'local_network_permission_denied',
        );
      }
      final auth = await _readCredentials(profile, credentials);
      if (auth == null || !_active(token)) {
        if (_active(token))
          _complete(token, ServerStatus.online, 'WOL-Erkennung abgebrochen.');
        return null;
      }
      final scope = await _networkScope.currentScope();
      if (!_active(token)) return null;
      final candidate = await _sshService.inspectWakeOnLan(
        profile,
        auth,
        broadcast: scope.broadcast,
        onUnknownHostKey: trust,
      );
      if (!_active(token)) return null;
      _complete(
        token,
        ServerStatus.online,
        'Wake-on-LAN-Daten wurden erkannt. Prüfe sie vor dem Speichern.',
      );
      await _record(
        DiagnosticAction.configuration,
        true,
        'wol_detected',
        watch.elapsed,
      );
      return candidate;
    } on ServergyError catch (error) {
      if (_active(token))
        _fail(error, DiagnosticAction.configuration, watch.elapsed);
      return null;
    } on SSHAuthFailError {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Die SSH-Anmeldung wurde abgelehnt. Prüfe Schlüssel oder Passwort.',
            code: 'auth_denied',
          ),
          DiagnosticAction.configuration,
          watch.elapsed,
        );
      }
      return null;
    } on SocketException {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Der Server ist über SSH nicht erreichbar. Wake-on-LAN kann manuell eingerichtet werden.',
            code: 'ssh_unreachable',
          ),
          DiagnosticAction.configuration,
          watch.elapsed,
        );
      }
      return null;
    } catch (_) {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Die Wake-on-LAN-Daten konnten nicht erkannt werden. Richte sie manuell ein.',
            code: 'wol_detection_failed',
          ),
          DiagnosticAction.configuration,
          watch.elapsed,
        );
      }
      return null;
    }
  }

  /// Updates only the optional WOL part of an already verified profile.
  Future<bool> saveWakeOnLanSettings(WakeOnLanSettings? settings) async {
    final profile = state.profile;
    if (profile == null || state.busy) return false;
    final watch = Stopwatch()..start();
    final updated = ServerProfile(
      name: profile.name,
      host: profile.host,
      sshPort: profile.sshPort,
      username: profile.username,
      authenticationMode: profile.authenticationMode,
      wakeOnLan: settings,
    );
    try {
      await _store.saveProfile(updated);
      if (!ref.mounted) return false;
      state = state.copyWith(
        profile: updated,
        message: settings == null
            ? 'Wake-on-LAN wurde nicht eingerichtet.'
            : 'Wake-on-LAN-Einstellungen gespeichert.',
        clearError: true,
      );
      await _record(
        DiagnosticAction.configuration,
        true,
        settings == null ? 'wol_skipped' : 'wol_saved',
        watch.elapsed,
      );
      return true;
    } on ServergyError catch (error) {
      if (ref.mounted)
        _fail(error, DiagnosticAction.configuration, watch.elapsed);
      return false;
    }
  }

  /// Tests a draft before its credentials are committed to secure storage.
  ///
  /// This prevents a mistyped first password from becoming the saved state. The
  /// host-key callback remains user-controlled, so a discovered IP can never
  /// silently become a trusted server.
  Future<bool> verifyAndSave(
    ServerProfile profile, {
    required SecretUpdate passwordUpdate,
    required String? privateKeyPem,
    required CredentialPrompter credentials,
    required HostKeyPrompter trust,
  }) async {
    if (state.busy) return false;
    final watch = Stopwatch()..start();
    final token = ++_operation;
    state = state.copyWith(
      busy: true,
      status: ServerStatus.checking,
      clearError: true,
      clearErrorCode: true,
    );
    try {
      final auth = await _draftCredentials(
        profile,
        passwordUpdate: passwordUpdate,
        privateKeyPem: privateKeyPem,
        prompt: credentials,
      );
      if (auth == null || !_active(token)) {
        if (_active(token))
          _complete(token, ServerStatus.unknown, 'Prüfung abgebrochen.');
        return false;
      }
      await _sshService.test(profile, auth, onUnknownHostKey: trust);
      if (!_active(token)) return false;
      await _persistProfile(
        profile,
        passwordUpdate: passwordUpdate,
        privateKeyPem: privateKeyPem,
      );
      if (!_active(token)) return false;
      // Make the freshly verified draft immediately visible on the dashboard.
      state = state.copyWith(profile: profile);
      _complete(
        token,
        ServerStatus.online,
        'SSH-Verbindung geprüft und Einstellungen sicher gespeichert.',
      );
      await _record(
        DiagnosticAction.configuration,
        true,
        'verified',
        watch.elapsed,
      );
      return true;
    } on ServergyError catch (error) {
      if (_active(token))
        _fail(error, DiagnosticAction.configuration, watch.elapsed);
      return false;
    } on SSHAuthFailError {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Die SSH-Anmeldung wurde abgelehnt. Prüfe Benutzername und Passwort oder Schlüssel.',
            code: 'auth_denied',
          ),
          DiagnosticAction.configuration,
          watch.elapsed,
        );
      }
      return false;
    } catch (_) {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Die SSH-Verbindung konnte nicht geprüft werden. Prüfe Heimnetz, VPN und Serveradresse.',
            code: 'setup_ssh_failed',
          ),
          DiagnosticAction.configuration,
          watch.elapsed,
        );
      }
      return false;
    }
  }

  Future<void> _persistProfile(
    ServerProfile profile, {
    required SecretUpdate passwordUpdate,
    required String? privateKeyPem,
  }) async {
    await _store.saveProfile(profile);
    await _store.updatePassword(
      profile.authenticationMode == AuthenticationMode.keyPreferred
          ? const SecretUpdate.delete()
          : passwordUpdate,
    );
    if (privateKeyPem != null) await _store.savePrivateKey(privateKeyPem);
  }

  Future<void> refresh() async {
    final profile = state.profile;
    if (profile == null || state.busy) return;
    final watch = Stopwatch()..start();
    if (!await _localAccess.ensureAllowed()) {
      state = state.copyWith(
        status: ServerStatus.unknown,
        error:
            'Die Freigabe für das lokale Netzwerk fehlt. Erlaube sie in Android und aktualisiere danach erneut.',
        clearMessage: true,
      );
      await _record(
        DiagnosticAction.refresh,
        false,
        'local_network_permission_denied',
        watch.elapsed,
      );
      return;
    }
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
      clearErrorCode: true,
    );
    try {
      if (!await _localAccess.ensureAllowed()) {
        throw const ServergyError(
          'Die Freigabe für das lokale Netzwerk fehlt. Erlaube sie in Android und versuche den Start erneut.',
          code: 'local_network_permission_denied',
        );
      }
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

  /// Performs the one deliberate server-side setup flow. A sudo password is
  /// requested only after SSH and host-key verification have succeeded and is
  /// passed straight to the gateway; ProfileStore never receives it.
  Future<void> provisionPoweroffHelper(
    CredentialPrompter credentials,
    SudoPasswordPrompter sudoPassword,
    HostKeyPrompter trust,
  ) async {
    final profile = state.profile;
    if (profile == null || state.busy) return;
    final token = ++_operation;
    final watch = Stopwatch()..start();
    state = state.copyWith(
      busy: true,
      status: ServerStatus.checking,
      clearError: true,
      clearErrorCode: true,
    );
    try {
      if (!await _localAccess.ensureAllowed()) {
        throw const ServergyError(
          'Die Freigabe für das lokale Netzwerk fehlt. Erlaube sie in Android und versuche die Servervorbereitung erneut.',
          code: 'local_network_permission_denied',
        );
      }
      final auth = await _readCredentials(profile, credentials);
      if (auth == null || !_active(token)) {
        if (_active(token)) {
          _complete(
            token,
            ServerStatus.unknown,
            'Servervorbereitung abgebrochen.',
          );
        }
        return;
      }
      // Establish the SSH session and make the host-key decision before the
      // user enters a privileged password. Provisioning reconnects afterwards
      // because its gateway owns the short-lived sudo session.
      await _sshService.test(profile, auth, onUnknownHostKey: trust);
      if (!_active(token)) return;
      final temporaryPassword = await sudoPassword();
      if (temporaryPassword == null ||
          temporaryPassword.isEmpty ||
          !_active(token)) {
        if (_active(token)) {
          _complete(
            token,
            ServerStatus.online,
            'Servervorbereitung abgebrochen.',
          );
        }
        return;
      }
      await _provisioningService.provisionPoweroffHelper(
        profile,
        auth,
        sudoPassword: temporaryPassword,
        onUnknownHostKey: trust,
        isCancelled: () => !_active(token),
      );
      if (!_active(token)) return;
      _complete(
        token,
        ServerStatus.online,
        'Der sichere Servergy-Ausschalt-Helper wurde vorbereitet. Der erste echte Ausschaltvorgang prüft die Einrichtung.',
      );
      await _record(
        DiagnosticAction.provisioning,
        true,
        'provisioned',
        watch.elapsed,
      );
    } on ServergyError catch (error) {
      if (_active(token))
        _fail(error, DiagnosticAction.provisioning, watch.elapsed);
    } on SSHAuthFailError {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Die SSH-Anmeldung wurde abgelehnt. Die Servervorbereitung wurde nicht gestartet.',
            code: 'auth_denied',
          ),
          DiagnosticAction.provisioning,
          watch.elapsed,
        );
      }
    } on SocketException {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Der Server ist über SSH nicht erreichbar. Verbinde dich mit Heimnetz oder VPN und versuche es erneut.',
            code: 'ssh_unreachable',
          ),
          DiagnosticAction.provisioning,
          watch.elapsed,
        );
      }
    } catch (_) {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Die Servervorbereitung ist fehlgeschlagen. Öffne die manuelle Serveranleitung für Details.',
            code: 'provision_failed',
          ),
          DiagnosticAction.provisioning,
          watch.elapsed,
        );
      }
    }
  }

  /// Removes only the server-side shutdown helper, systemd unit, and narrow
  /// sudoers entry. SSH access, Wake-on-LAN, and the local app profile remain
  /// untouched so the user can reconfigure the connection afterwards.
  Future<void> removePoweroffHelper(
    CredentialPrompter credentials,
    SudoPasswordPrompter sudoPassword,
    HostKeyPrompter trust,
  ) async {
    final profile = state.profile;
    if (profile == null || state.busy) return;
    final token = ++_operation;
    final watch = Stopwatch()..start();
    state = state.copyWith(
      busy: true,
      status: ServerStatus.checking,
      clearError: true,
      clearErrorCode: true,
    );
    try {
      if (!await _localAccess.ensureAllowed()) {
        throw const ServergyError(
          'Die Freigabe für das lokale Netzwerk fehlt. Erlaube sie in Android und versuche die Entfernung erneut.',
          code: 'local_network_permission_denied',
        );
      }
      final auth = await _readCredentials(profile, credentials);
      if (auth == null || !_active(token)) {
        if (_active(token)) {
          _complete(
            token,
            ServerStatus.unknown,
            'Entfernung der Servergy-Dateien abgebrochen.',
          );
        }
        return;
      }
      // As with installation, trust the current SSH identity before asking for
      // a privileged password or changing anything on the remote machine.
      await _sshService.test(profile, auth, onUnknownHostKey: trust);
      if (!_active(token)) return;
      final temporaryPassword = await sudoPassword();
      if (temporaryPassword == null ||
          temporaryPassword.isEmpty ||
          !_active(token)) {
        if (_active(token)) {
          _complete(
            token,
            ServerStatus.online,
            'Entfernung der Servergy-Dateien abgebrochen.',
          );
        }
        return;
      }
      await _provisioningService.removePoweroffHelper(
        profile,
        auth,
        sudoPassword: temporaryPassword,
        onUnknownHostKey: trust,
        isCancelled: () => !_active(token),
      );
      if (!_active(token)) return;
      _complete(
        token,
        ServerStatus.online,
        'Die Servergy-Ausschaltdateien wurden vom Server entfernt. SSH und Wake-on-LAN bleiben eingerichtet.',
      );
      await _record(
        DiagnosticAction.helperRemoval,
        true,
        'removed',
        watch.elapsed,
      );
    } on ServergyError catch (error) {
      if (_active(token))
        _fail(error, DiagnosticAction.helperRemoval, watch.elapsed);
    } on SSHAuthFailError {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Die SSH-Anmeldung wurde abgelehnt. Die Servergy-Dateien wurden nicht verändert.',
            code: 'auth_denied',
          ),
          DiagnosticAction.helperRemoval,
          watch.elapsed,
        );
      }
    } on SocketException {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Der Server ist über SSH nicht erreichbar. Die Servergy-Dateien wurden nicht verändert.',
            code: 'ssh_unreachable',
          ),
          DiagnosticAction.helperRemoval,
          watch.elapsed,
        );
      }
    } catch (_) {
      if (_active(token)) {
        _fail(
          const ServergyError(
            'Die Servergy-Dateien konnten nicht vollständig entfernt werden. Prüfe die Anleitung im README.',
            code: 'removal_failed',
          ),
          DiagnosticAction.helperRemoval,
          watch.elapsed,
        );
      }
    }
  }

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
      clearErrorCode: true,
    );
    try {
      if (!await _localAccess.ensureAllowed()) {
        throw const ServergyError(
          'Die Freigabe für das lokale Netzwerk fehlt. Erlaube sie in Android und versuche die SSH-Aktion erneut.',
          code: 'local_network_permission_denied',
        );
      }
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
      if (shutdown) {
        await _sshService.poweroff(profile, auth, onUnknownHostKey: trust);
      } else {
        await _sshService.test(profile, auth, onUnknownHostKey: trust);
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
    if (profile.authenticationMode == AuthenticationMode.keyPreferred &&
        key != null) {
      String? passphrase;
      if (SSHKeyPair.isEncryptedPem(key)) {
        passphrase = (await prompt(
          CredentialRequest.keyPassphrase,
        ))?.keyPassphrase;
        if (passphrase == null || passphrase.isEmpty) return null;
      }
      return SshCredentials(privateKeyPem: key, keyPassphrase: passphrase);
    }
    if (profile.authenticationMode == AuthenticationMode.keyPreferred) {
      throw const ServergyError(
        'Der gespeicherte SSH-Schlüssel fehlt. Importiere ihn erneut in den Einstellungen.',
        code: 'key_missing',
      );
    }
    final password = await _store.password();
    if (password != null && password.isNotEmpty)
      return SshCredentials(password: password);
    throw const ServergyError(
      'Das gespeicherte SSH-Passwort fehlt. Hinterlege es erneut in den Einstellungen.',
      code: 'password_missing',
    );
  }

  Future<SshCredentials?> _draftCredentials(
    ServerProfile profile, {
    required SecretUpdate passwordUpdate,
    required String? privateKeyPem,
    required CredentialPrompter prompt,
  }) async {
    if (profile.authenticationMode == AuthenticationMode.passwordOnly) {
      final password = passwordUpdate.kind == SecretUpdateKind.replace
          ? passwordUpdate.value
          : await _store.password();
      if (password == null || password.isEmpty) {
        throw const ServergyError(
          'Gib ein SSH-Passwort ein, damit die Verbindung geprüft werden kann.',
          code: 'password_required',
        );
      }
      return SshCredentials(password: password);
    }
    final key = privateKeyPem ?? await _store.privateKey();
    if (key == null || key.isEmpty) {
      throw const ServergyError(
        'Wähle einen privaten SSH-Schlüssel aus.',
        code: 'key_missing',
      );
    }
    String? passphrase;
    if (SSHKeyPair.isEncryptedPem(key)) {
      passphrase = (await prompt(
        CredentialRequest.keyPassphrase,
      ))?.keyPassphrase;
      if (passphrase == null || passphrase.isEmpty) return null;
    }
    return SshCredentials(privateKeyPem: key, keyPassphrase: passphrase);
  }

  bool _active(int token) => ref.mounted && token == _operation;

  void _complete(int token, ServerStatus status, String message) {
    if (!_active(token)) return;
    state = state.copyWith(
      busy: false,
      status: status,
      message: message,
      clearError: true,
      clearErrorCode: true,
    );
  }

  void clearNotice() =>
      state = state.copyWith(clearMessage: true, clearError: true);

  void _fail(ServergyError error, DiagnosticAction action, Duration elapsed) {
    state = state.copyWith(
      busy: false,
      error: error.message,
      errorCode: error.code,
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
    // The storage read is asynchronous as well. Check mount status only after
    // it completes so a late diagnostics write can never update a disposed
    // controller (for example when a setup route is closed after an error).
    final diagnostics = await _store.diagnostics();
    if (ref.mounted) state = state.copyWith(diagnostics: diagnostics);
  }
}
