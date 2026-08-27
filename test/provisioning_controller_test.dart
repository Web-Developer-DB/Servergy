import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servergy/core/controller.dart';
import 'package:servergy/core/models.dart';
import 'package:servergy/core/services.dart';

void main() {
  test(
    'provisioning verifies SSH before it passes a temporary sudo password',
    () async {
      final ssh = _FakeProvisioningSsh();
      final store = _MemoryStore(password: 'ssh-secret');
      final container = ProviderContainer(
        overrides: [
          controllerProvider.overrideWith(
            () => _ProvisioningController(store: store, ssh: ssh),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(controllerProvider.notifier)
          .provisionPoweroffHelper(
            (_) async => null,
            () async => 'temporary-sudo-secret',
            (_) async => true,
          );

      expect(ssh.testCalls, 1);
      expect(ssh.provisionCalls, 1);
      expect(ssh.receivedSudoPassword, 'temporary-sudo-secret');
      expect(store.passwordReads, greaterThanOrEqualTo(1));
      expect(container.read(controllerProvider).error, isNull);
    },
  );

  test(
    'cancelling the temporary sudo prompt performs no installation',
    () async {
      final ssh = _FakeProvisioningSsh();
      final container = ProviderContainer(
        overrides: [
          controllerProvider.overrideWith(
            () => _ProvisioningController(
              store: _MemoryStore(password: 'ssh'),
              ssh: ssh,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(controllerProvider.notifier)
          .provisionPoweroffHelper(
            (_) async => null,
            () async => null,
            (_) async => true,
          );

      expect(ssh.testCalls, 1);
      expect(ssh.provisionCalls, 0);
      expect(
        container.read(controllerProvider).message,
        contains('abgebrochen'),
      );
    },
  );

  test(
    'helper removal keeps the SSH profile and uses a temporary sudo password',
    () async {
      final ssh = _FakeProvisioningSsh();
      final container = ProviderContainer(
        overrides: [
          controllerProvider.overrideWith(
            () => _ProvisioningController(
              store: _MemoryStore(password: 'ssh'),
              ssh: ssh,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(controllerProvider.notifier).removePoweroffHelper(
        (_) async => null,
        () async => 'temporary-sudo-secret',
        (_) async => true,
      );

      expect(ssh.testCalls, 1);
      expect(ssh.removalCalls, 1);
      expect(ssh.receivedRemovalPassword, 'temporary-sudo-secret');
      expect(container.read(controllerProvider).profile, _profile);
    },
  );
}

const _profile = ServerProfile(
  name: 'Homeserver',
  host: '192.168.0.10',
  sshPort: 22,
  username: 'servergy',
  authenticationMode: AuthenticationMode.passwordOnly,
);

class _ProvisioningController extends ServerController {
  _ProvisioningController({
    required ProfileStore store,
    required _FakeProvisioningSsh ssh,
  }) : super(store: store, ssh: ssh, provisioning: ssh);

  @override
  AppState build() => const AppState(profile: _profile);
}

class _FakeProvisioningSsh implements SshGateway, ServerProvisioningGateway {
  var testCalls = 0;
  var provisionCalls = 0;
  var removalCalls = 0;
  String? receivedSudoPassword;
  String? receivedRemovalPassword;

  @override
  Future<void> test(
    ServerProfile profile,
    SshCredentials credentials, {
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) async {
    testCalls++;
  }

  @override
  Future<void> provisionPoweroffHelper(
    ServerProfile profile,
    SshCredentials credentials, {
    required String sudoPassword,
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
    required bool Function() isCancelled,
  }) async {
    expect(isCancelled(), isFalse);
    provisionCalls++;
    receivedSudoPassword = sudoPassword;
  }

  @override
  Future<void> removePoweroffHelper(
    ServerProfile profile,
    SshCredentials credentials, {
    required String sudoPassword,
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
    required bool Function() isCancelled,
  }) async {
    expect(isCancelled(), isFalse);
    removalCalls++;
    receivedRemovalPassword = sudoPassword;
  }

  @override
  Future<void> poweroff(
    ServerProfile profile,
    SshCredentials credentials, {
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) => throw UnimplementedError();

  @override
  Future<WakeOnLanCandidate> inspectWakeOnLan(
    ServerProfile profile,
    SshCredentials credentials, {
    required String broadcast,
    required Future<bool> Function(String fingerprint) onUnknownHostKey,
  }) => throw UnimplementedError();
}

class _MemoryStore implements ProfileStore {
  _MemoryStore({String? password}) : _storedPassword = password;

  final String? _storedPassword;
  var passwordReads = 0;

  @override
  Future<void> addDiagnostic(DiagnosticEvent event) async {}

  @override
  Future<void> clearHostKey() async {}

  @override
  Future<void> deleteConnection() async {}

  @override
  Future<List<DiagnosticEvent>> diagnostics() async => const [];

  @override
  Future<bool> hasPassword() async => _storedPassword?.isNotEmpty ?? false;

  @override
  Future<HostKeyTrust?> hostKeyFor(ServerProfile profile) async => null;

  @override
  Future<ServerProfile?> loadProfile() async => _profile;

  @override
  Future<String?> password() async {
    passwordReads++;
    return _storedPassword;
  }

  @override
  Future<String?> privateKey() async => null;

  @override
  Future<void> savePrivateKey(String? pem) async {}

  @override
  Future<void> saveProfile(ServerProfile profile) async {}

  @override
  Future<void> trustHostKey(ServerProfile profile, HostKeyTrust trust) async {}

  @override
  Future<void> updatePassword(SecretUpdate update) async {}
}
