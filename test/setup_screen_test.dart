import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      expect(tester.getSize(continueButton).height, greaterThanOrEqualTo(54));
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

  testWidgets('only reached steps are directly selectable in a new setup', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 1200));
    await tester.pumpWidget(_setup());
    await tester.tap(find.widgetWithText(FilledButton, 'Weiter').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Netzwerkgrenze').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('Für die Ersteinrichtung'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('SSH-Zugang', skipOffstage: false).first,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('SSH-Zugang').hitTestable());
    await tester.pump();
    expect(find.textContaining('Für die Ersteinrichtung'), findsOneWidget);
  });

  testWidgets('all steps are selectable when editing an existing profile', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 1200));
    await tester.pumpWidget(_setup(profile: _profile));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Server später starten', skipOffstage: false).first,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Server später starten').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Wake-on-LAN jetzt einrichten'), findsOneWidget);
  });

  testWidgets('settings expose the explicit server preparation action', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 1200));
    await tester.pumpWidget(_setup(profile: _profile));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Server später starten', skipOffstage: false).first,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Server später starten').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Server vorbereiten'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.widgetWithText(OutlinedButton, 'Server vorbereiten'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Installierten Helper entfernen'),
      findsOneWidget,
    );
    expect(
      find.textContaining('sudo-Passwort wird nur während der Einrichtung'),
      findsOneWidget,
    );
  });

  testWidgets('server preparation offers a copyable manual Debian path', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 1200));
    await tester.pumpWidget(_setup(profile: _profile));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Server später starten', skipOffstage: false).first,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Server später starten').hitTestable());
    await tester.pumpAndSettle();
    final prepare = find.widgetWithText(OutlinedButton, 'Server vorbereiten');
    await tester.scrollUntilVisible(
      prepare,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(prepare);
    await tester.pumpAndSettle();

    expect(
      find.text('Server für sicheres Herunterfahren vorbereiten?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Manuell einrichten'));
    await tester.pumpAndSettle();

    expect(find.text('Manuelle Debian-Einrichtung'), findsOneWidget);
    expect(find.text('Kopieren'), findsOneWidget);
  });

  testWidgets('deleting a saved connection requires explicit confirmation', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 1200));
    await tester.pumpWidget(_setup(profile: _profile));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Server später starten', skipOffstage: false).first,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Server später starten').hitTestable());
    await tester.pumpAndSettle();
    final deleteButton = find.widgetWithText(
      OutlinedButton,
      'Verbindung löschen',
    );
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Verbindung löschen?'), findsOneWidget);
    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.text('Verbindung löschen?'), findsNothing);
    expect(find.text('Verbindung löschen'), findsOneWidget);
  });

  testWidgets('dashboard exposes connection deletion directly', (tester) async {
    _setViewport(tester, const Size(400, 900));
    await tester.pumpWidget(_home(profile: _profile));

    await tester.tap(find.byTooltip('Verbindung löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Verbindung löschen?'), findsOneWidget);
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
}) => ProviderScope(
  overrides: [
    controllerProvider.overrideWith(() => _StaticServerController(profile)),
    discoveryProvider.overrideWith(
      () => _StaticDiscoveryController(candidates),
    ),
  ],
  child: const MaterialApp(home: SetupScreen()),
);

Widget _home({ServerProfile? profile}) => ProviderScope(
  overrides: [
    controllerProvider.overrideWith(() => _StaticServerController(profile)),
  ],
  child: const MaterialApp(home: HomeScreen()),
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
