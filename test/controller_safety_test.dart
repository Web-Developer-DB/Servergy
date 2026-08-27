import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servergy/core/controller.dart';
import 'package:servergy/core/models.dart';
import 'package:servergy/core/services.dart';

void main() {
  test(
    'a rejected draft login never persists a profile or its password',
    () async {
      final store = _AuditStore();
      final ssh = _AuditSsh(testError: SSHAuthFailError('denied'));
      final container = _container(store: store, ssh: ssh);
      addTearDown(container.dispose);

      final saved = await container
          .read(controllerProvider.notifier)
          .verifyAndSave(
            _passwordProfile,
            passwordUpdate: const SecretUpdate.replace('not-persisted'),
            privateKeyPem: null,
            credentials: (_) async => null,
            trust: (_) async => true,
          );

      expect(saved, isFalse);
      expect(ssh.testCalls, 1);
      expect(store.savedProfiles, isEmpty);
      expect(store.passwordUpdates, isEmpty);
      expect(container.read(controllerProvider).errorCode, 'auth_denied');
    },
  );

  test(
    'a verified draft is persisted only after its SSH check succeeds',
    () async {
      final timeline = <String>[];
      final store = _AuditStore(timeline: timeline);
      final ssh = _AuditSsh(timeline: timeline);
      final container = _container(store: store, ssh: ssh);
      addTearDown(container.dispose);

      final saved = await container
          .read(controllerProvider.notifier)
          .verifyAndSave(
            _passwordProfile,
            passwordUpdate: const SecretUpdate.replace(
              'stored-after-verification',
            ),
            privateKeyPem: null,
            credentials: (_) async => null,
            trust: (_) async => true,
          );

      expect(saved, isTrue);
      expect(timeline, ['ssh-test', 'save-profile', 'update-password']);
      expect(store.savedProfiles, [_passwordProfile]);
      expect(store.passwordUpdates.single.kind, SecretUpdateKind.replace);
      expect(container.read(controllerProvider).status, ServerStatus.online);
    },
  );

  test('cancelling an SSH test suppresses its late success result', () async {
    final completedSsh = Completer<void>();
    final store = _AuditStore(storedPassword: 'saved-secret');
    final ssh = _AuditSsh(testGate: completedSsh);
    final container = _container(
      store: store,
      ssh: ssh,
      initialProfile: _passwordProfile,
    );
    addTearDown(container.dispose);

    final action = container
        .read(controllerProvider.notifier)
        .testSsh((_) async => null, (_) async => true);
    await _waitFor(() => ssh.testCalls == 1);
    expect(container.read(controllerProvider).busy, isTrue);

    container.read(controllerProvider.notifier).cancelOperation();
    completedSsh.complete();
    await action;

    final state = container.read(controllerProvider);
    expect(state.busy, isFalse);
    expect(state.status, ServerStatus.unknown);
    expect(state.message, contains('abgebrochen'));
    expect(state.message, isNot(contains('erfolgreich')));
  });

  test(
    'shutdown does not open SSH when the server is already offline',
    () async {
      final store = _AuditStore(storedPassword: 'saved-secret');
      final network = _AuditNetwork(online: false);
      final ssh = _AuditSsh();
      final container = _container(
        store: store,
        network: network,
        ssh: ssh,
        initialProfile: _passwordProfile,
      );
      addTearDown(container.dispose);

      await container
          .read(controllerProvider.notifier)
          .shutdown((_) async => null, (_) async => true);

      final state = container.read(controllerProvider);
      expect(network.reachabilityChecks, 1);
      expect(ssh.poweroffCalls, 0);
      expect(state.status, ServerStatus.offline);
      expect(state.message, 'Der Server ist bereits ausgeschaltet.');
      expect(store.events.last.code, 'already_offline');
    },
  );
}

const _passwordProfile = ServerProfile(
  name: 'Homeserver',
  host: '192.168.0.10',
  sshPort: 22,
  username: 'servergy',
  authenticationMode: AuthenticationMode.passwordOnly,
);

ProviderContainer _container({
  required _AuditStore store,
  required _AuditSsh ssh,
  NetworkGateway? network,
  ServerProfile? initialProfile,
}) => ProviderContainer(
  overrides: [
    controllerProvider.overrideWith(
      () => _AuditController(
        store: store,
        network: network ?? _AuditNetwork(),
        ssh: ssh,
        initialProfile: initialProfile,
      ),
    ),
  ],
);

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('The asynchronous test operation did not start.');
}

class _AuditController extends ServerController {
  _AuditController({
    required ProfileStore store,
    required NetworkGateway network,
    required SshGateway ssh,
    this.initialProfile,
  }) : super(store: store, network: network, ssh: ssh);

  final ServerProfile? initialProfile;

  @override
  AppState build() => AppState(profile: initialProfile);
}

class _AuditNetwork implements NetworkGateway {
  _AuditNetwork({this.online = true});

  final bool online;
  var reachabilityChecks = 0;

  @override
  Future<bool> isReachable(ServerProfile profile) async {
    reachabilityChecks++;
    return online;
  }

  @override
  Future<void> wake(ServerProfile profile) async {}
}

class _AuditSsh implements SshGateway {
  _AuditSsh({this.testError, this.testGate, List<String>? timeline})
    : timeline = timeline ?? <String>[];

  final Object? testError;
  final Completer<void>? testGate;
  final List<String> timeline;
  var testCalls = 0;
  var poweroffCalls = 0;

  @override
  Future<void> test(
    ServerProfile profile,
    SshCredentials credentials, {
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) async {
    testCalls++;
    timeline.add('ssh-test');
    final gate = testGate;
    if (gate != null) await gate.future;
    final error = testError;
    if (error != null) throw error;
  }

  @override
  Future<void> poweroff(
    ServerProfile profile,
    SshCredentials credentials, {
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) async {
    poweroffCalls++;
  }

  @override
  Future<WakeOnLanCandidate> inspectWakeOnLan(
    ServerProfile profile,
    SshCredentials credentials, {
    required String broadcast,
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) async => throw UnimplementedError();
}

class _AuditStore implements ProfileStore {
  _AuditStore({this.storedPassword, List<String>? timeline})
    : timeline = timeline ?? <String>[];

  String? storedPassword;
  final List<String> timeline;
  final List<ServerProfile> savedProfiles = [];
  final List<SecretUpdate> passwordUpdates = [];
  final List<DiagnosticEvent> events = [];

  @override
  Future<void> addDiagnostic(DiagnosticEvent event) async => events.add(event);

  @override
  Future<void> clearHostKey() async {}

  @override
  Future<void> deleteConnection() async {}

  @override
  Future<List<DiagnosticEvent>> diagnostics() async => List.of(events);

  @override
  Future<bool> hasPassword() async =>
      storedPassword != null && storedPassword!.isNotEmpty;

  @override
  Future<HostKeyTrust?> hostKeyFor(ServerProfile profile) async => null;

  @override
  Future<ServerProfile?> loadProfile() async =>
      savedProfiles.isEmpty ? null : savedProfiles.last;

  @override
  Future<String?> password() async => storedPassword;

  @override
  Future<String?> privateKey() async => null;

  @override
  Future<void> savePrivateKey(String? pem) async {}

  @override
  Future<void> saveProfile(ServerProfile profile) async {
    timeline.add('save-profile');
    savedProfiles.add(profile);
  }

  @override
  Future<void> trustHostKey(ServerProfile profile, HostKeyTrust trust) async {}

  @override
  Future<void> updatePassword(SecretUpdate update) async {
    timeline.add('update-password');
    passwordUpdates.add(update);
    if (update.kind == SecretUpdateKind.replace) storedPassword = update.value;
    if (update.kind == SecretUpdateKind.delete) storedPassword = null;
  }
}
