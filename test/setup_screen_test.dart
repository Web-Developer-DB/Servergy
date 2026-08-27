import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servergy/core/app_metadata.dart';
import 'package:servergy/core/controller.dart';
import 'package:servergy/core/models.dart';
import 'package:servergy/core/services.dart';
import 'package:servergy/servergy_app.dart';

void main() {
  const candidate = DiscoveredServer(
    host: '192.168.0.241',
    port: 22,
    banner: 'SSH-2.0-OpenSSH_10.0p2',
    sources: {DiscoverySource.portScan},
  );

  testWidgets('selecting a discovered server visibly applies its address', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 1200));
    await tester.pumpWidget(_setup(candidates: const [candidate]));

    await tester.tap(find.widgetWithText(FilledButton, 'Weiter').hitTestable());
    await tester.pumpAndSettle();

    final selectButton = find
        .widgetWithText(OutlinedButton, 'Übernehmen')
        .hitTestable();
    expect(selectButton, findsOneWidget);
    await tester.tap(selectButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Serveradresse übernommen'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Serveradresse und SSH-Port wurden übernommen. Ergänze jetzt den SSH-Benutzernamen.',
      ),
      findsOneWidget,
    );
    expect(
      _field(tester, 'Hostname oder IP-Adresse').controller!.text,
      candidate.host,
    );
    expect(_field(tester, 'SSH-Port').controller!.text, '${candidate.port}');
  });

  testWidgets(
    'candidate and navigation button labels remain centered on narrow screens',
    (tester) async {
      _setViewport(tester, const Size(320, 1200), textScale: 1.3);

      await tester.pumpWidget(_setup(candidates: const [candidate]));
      final continueButton = find
          .widgetWithText(FilledButton, 'Weiter')
          .hitTestable();
      final continueLabel = find.descendant(
        of: continueButton,
        matching: find.text('Weiter'),
      );
      expect(tester.getSize(continueButton).height, greaterThanOrEqualTo(48));
      expect(
        (tester.getCenter(continueLabel).dy -
                tester.getCenter(continueButton).dy)
            .abs(),
        lessThan(2),
      );

      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      final selectButton = find.widgetWithText(OutlinedButton, 'Übernehmen');
      await tester.ensureVisible(selectButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final selectLabel = find.descendant(
        of: selectButton,
        matching: find.text('Übernehmen'),
      );
      expect(
        (tester.getCenter(selectLabel).dy - tester.getCenter(selectButton).dy)
            .abs(),
        lessThan(2),
      );
    },
  );

  testWidgets('server fields keep their labels inside one visual card', (
    tester,
  ) async {
    _setViewport(tester, const Size(320, 1200), textScale: 1.3);
    await tester.pumpWidget(_setup());
    await tester.tap(find.widgetWithText(FilledButton, 'Weiter').hitTestable());
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('field-container-Anzeigename'));
    final input = find.byKey(const ValueKey('field-Anzeigename'));
    final label = find.text('Anzeigename');

    expect(card, findsOneWidget);
    expect(input, findsOneWidget);
    expect(tester.getRect(card).contains(tester.getCenter(label)), isTrue);
    expect(tester.getRect(card).contains(tester.getCenter(input)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('setup uses one focused step with visible progress', (tester) async {
    _setViewport(tester, const Size(400, 900));
    await tester.pumpWidget(_setup());

    expect(find.text('Schritt 1 von 5'), findsOneWidget);
    expect(find.text('Dein Netzwerk'), findsOneWidget);
    expect(find.byType(Stepper), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Weiter').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Schritt 2 von 5'), findsOneWidget);
    expect(find.text('Server finden'), findsOneWidget);
  });

  testWidgets('existing connection opens the requested focused setup step', (tester) async {
    _setViewport(tester, const Size(400, 900));
    await tester.pumpWidget(_setup(profile: _profile, initialStep: 4));
    await tester.pumpAndSettle();

    expect(find.text('Schritt 5 von 5'), findsOneWidget);
    expect(find.text('Wake-on-LAN jetzt einrichten'), findsOneWidget);
  });

  testWidgets('settings separate secure shutdown from connection editing', (tester) async {
    _setViewport(tester, const Size(400, 1000));
    await tester.pumpWidget(_settings(profile: _profile));
    await tester.pumpAndSettle();

    expect(find.text('Serververbindung'), findsOneWidget);
    await tester.tap(find.text('Sicheres Herunterfahren'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Server vorbereiten'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Installierten Helper entfernen'), findsOneWidget);
  });

  testWidgets('deleting a saved connection requires confirmation in settings', (tester) async {
    _setViewport(tester, const Size(400, 1000));
    await tester.pumpWidget(_settings(profile: _profile));
    await tester.pumpAndSettle();

    final delete = find.text('Verbindung löschen');
    await tester.scrollUntilVisible(delete, 160);
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('Verbindung löschen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.text('Verbindung löschen?'), findsNothing);
  });

  testWidgets('dashboard exposes no destructive connection action', (tester) async {
    _setViewport(tester, const Size(400, 900));
    await tester.pumpWidget(_home(profile: _profile));

    expect(find.byTooltip('Verbindung löschen'), findsNothing);
    expect(find.byTooltip('Ereignisse'), findsOneWidget);
    expect(find.byTooltip('Einstellungen'), findsOneWidget);
  });

  testWidgets('events use a readable list and open technical details', (tester) async {
    final event = DiagnosticEvent(
      at: DateTime.now(),
      action: DiagnosticAction.sshTest,
      success: false,
      code: 'auth_denied',
      duration: const Duration(milliseconds: 250),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        controllerProvider.overrideWith(
          () => _StateServerController(AppState(diagnostics: [event])),
        ),
      ],
      child: const MaterialApp(home: EventsScreen()),
    ));

    expect(find.text('Letzte Aktion braucht Aufmerksamkeit'), findsOneWidget);
    expect(find.text('SSH-Verbindung geprüft'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('SSH-Verbindung geprüft').first);
    await tester.pumpAndSettle();
    expect(find.text('Ereignisdetails'), findsOneWidget);
    expect(find.text('Technische Kennung'), findsOneWidget);
    expect(find.text('auth_denied'), findsOneWidget);
  });

  testWidgets('settings show package-backed version information', (tester) async {
    const metadata = AppMetadata(
      name: 'Servergy',
      version: '0.1.0-alpha.2',
      build: '2',
      releaseChannel: 'Alpha',
      platform: 'android',
    );
    await tester.pumpWidget(_settings(metadata: metadata));
    await tester.pumpAndSettle();

    expect(find.text('Alpha · 0.1.0-alpha.2 (Build 2)'), findsOneWidget);
    expect(find.text('Versionsinformationen kopieren'), findsOneWidget);
  });

  test(
    'controller clears the active profile after deleting its connection',
    () async {
      final store = _MemoryProfileStore();
      final container = ProviderContainer(
        overrides: [
          controllerProvider.overrideWith(
            () => _StaticServerController(_profile, store: store),
          ),
        ],
      );
      addTearDown(container.dispose);

      final deleted = await container
          .read(controllerProvider.notifier)
          .deleteConnection();

      expect(deleted, isTrue);
      expect(store.connectionDeleted, isTrue);
      expect(container.read(controllerProvider).profile, isNull);
    },
  );
}

const _profile = ServerProfile(
  name: 'Homeserver',
  host: '192.168.0.241',
  sshPort: 22,
  username: 'servergy',
);

Widget _setup({
  ServerProfile? profile,
  List<DiscoveredServer> candidates = const [],
  int initialStep = 0,
}) => ProviderScope(
  overrides: [
    controllerProvider.overrideWith(() => _StaticServerController(profile)),
    discoveryProvider.overrideWith(
      () => _StaticDiscoveryController(candidates),
    ),
  ],
  child: MaterialApp(home: SetupScreen(initialStep: initialStep)),
);

Widget _home({ServerProfile? profile}) => ProviderScope(
  overrides: [
    controllerProvider.overrideWith(() => _StaticServerController(profile)),
  ],
  child: const MaterialApp(home: HomeScreen()),
);

Widget _settings({ServerProfile? profile, AppMetadata? metadata}) => ProviderScope(
  overrides: [
    controllerProvider.overrideWith(() => _StaticServerController(profile)),
    if (metadata != null)
      appMetadataProvider.overrideWith((ref) async => metadata),
  ],
  child: const MaterialApp(home: SettingsScreen()),
);

void _setViewport(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

TextFormField _field(WidgetTester tester, String label) =>
    tester.widget(find.byKey(ValueKey('field-$label')));

class _StaticServerController extends ServerController {
  _StaticServerController(this.profile, {ProfileStore? store})
    : super(store: store ?? _MemoryProfileStore());

  final ServerProfile? profile;

  @override
  AppState build() => AppState(profile: profile);
}

class _StateServerController extends ServerController {
  _StateServerController(this.appState) : super(store: _MemoryProfileStore());
  final AppState appState;

  @override
  AppState build() => appState;
}

class _StaticDiscoveryController extends DiscoveryController {
  _StaticDiscoveryController(this.candidates);

  final List<DiscoveredServer> candidates;

  @override
  DiscoveryState build() =>
      DiscoveryState(status: DiscoveryStatus.completed, candidates: candidates);
}

/// Keeps UI tests independent from platform secure-storage plugins. The setup
/// screen only reads the profile here, but the complete contract prevents any
/// accidental platform I/O from being hidden by the test double.
class _MemoryProfileStore implements ProfileStore {
  var connectionDeleted = false;

  @override
  Future<void> deleteConnection() async => connectionDeleted = true;

  @override
  Future<void> addDiagnostic(DiagnosticEvent event) async {}

  @override
  Future<void> clearHostKey() async {}

  @override
  Future<List<DiagnosticEvent>> diagnostics() async => const [];

  @override
  Future<bool> hasPassword() async => false;

  @override
  Future<HostKeyTrust?> hostKeyFor(ServerProfile profile) async => null;

  @override
  Future<ServerProfile?> loadProfile() async => null;

  @override
  Future<String?> password() async => null;

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
