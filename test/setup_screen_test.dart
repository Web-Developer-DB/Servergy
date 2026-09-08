import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servergy/core/appearance.dart';
import 'package:servergy/core/app_metadata.dart';
import 'package:servergy/core/controller.dart';
import 'package:servergy/core/language.dart';
import 'package:servergy/core/models.dart';
import 'package:servergy/core/services.dart';
import 'package:servergy/servergy_app.dart';

// Widget-level contract suite for the user-facing flows. Provider overrides
// supply deterministic state so these tests verify interaction, accessibility,
// localization, and route behavior without invoking the real service layer.

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

  testWidgets('password setup uses a clear, accessible reveal control', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 900));
    await tester.pumpWidget(
      _setup(
        profile: const ServerProfile(
          name: 'Homeserver',
          host: '192.168.0.241',
          sshPort: 22,
          username: 'servergy',
          authenticationMode: AuthenticationMode.passwordOnly,
        ),
        initialStep: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(_editableField(tester, 'SSH-Passwort').obscureText, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('field-container-SSH-Passwort')),
        matching: find.byIcon(Icons.password_outlined),
      ),
      findsNothing,
    );
    expect(find.byTooltip('Passwort anzeigen'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('password-visibility-SSH-Passwort')),
    );
    await tester.pump();

    expect(_editableField(tester, 'SSH-Passwort').obscureText, isFalse);
    expect(find.byTooltip('Passwort verbergen'), findsOneWidget);
  });

  testWidgets('secret dialog inputs start hidden and can be revealed', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecretTextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Geheimnis'),
            visibilityToggleKey: const ValueKey(
              'credential-password-visibility',
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );
    expect(find.byTooltip('Passwort anzeigen'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('credential-password-visibility')),
    );
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
    expect(find.byTooltip('Passwort verbergen'), findsOneWidget);
  });

  testWidgets('setup uses one focused step with visible progress', (
    tester,
  ) async {
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

  testWidgets('existing connection opens the requested focused setup step', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 900));
    await tester.pumpWidget(_setup(profile: _profile, initialStep: 4));
    await tester.pumpAndSettle();

    expect(find.text('Schritt 5 von 5'), findsOneWidget);
    expect(find.text('Wake-on-LAN jetzt einrichten'), findsOneWidget);
  });

  testWidgets('settings separate secure shutdown from connection editing', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 1000));
    await tester.pumpWidget(_settings(profile: _profile));
    await tester.pumpAndSettle();

    expect(find.text('Serververbindung'), findsOneWidget);
    await tester.tap(find.text('Sicheres Herunterfahren'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Server vorbereiten'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, 'Installierten Helper entfernen'),
      findsOneWidget,
    );
  });

  testWidgets('settings expose the three persistent appearance choices', (
    tester,
  ) async {
    final appearanceStore = _MemoryAppearanceStore();
    await tester.pumpWidget(_settings(appearanceStore: appearanceStore));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('appearance-setting')), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('appearance-setting')));
    await tester.pumpAndSettle();
    expect(find.text('System'), findsNWidgets(2));
    expect(find.text('Hell'), findsOneWidget);
    expect(find.text('Dunkel'), findsOneWidget);

    await tester.tap(find.text('Dunkel'));
    await tester.pumpAndSettle();
    expect(appearanceStore.saved, AppearancePreference.dark);
    expect(find.text('Dunkel'), findsOneWidget);
  });

  testWidgets('settings expose the persistent language choices', (
    tester,
  ) async {
    final languageStore = _MemoryLanguageStore();
    await tester.pumpWidget(_settings(languageStore: languageStore));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('language-setting')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language-setting')));
    await tester.pumpAndSettle();
    expect(find.text('Deutsch'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(languageStore.saved, LanguagePreference.english);
  });

  testWidgets('root applies the selected appearance mode to MaterialApp', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearanceProvider.overrideWith(
            () => _StaticAppearanceController(AppearancePreference.dark),
          ),
          languageProvider.overrideWith(
            () => _StaticLanguageController(LanguagePreference.german),
          ),
          controllerProvider.overrideWith(() => _StaticServerController(null)),
        ],
        child: const ServergyApp(),
      ),
    );
    await tester.pump();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
  });

  testWidgets('changing appearance immediately updates the app theme', (
    tester,
  ) async {
    final appearanceStore = _MemoryAppearanceStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearanceProvider.overrideWith(
            () => _StaticAppearanceController(AppearancePreference.system),
          ),
          appearanceStoreProvider.overrideWithValue(appearanceStore),
          languageProvider.overrideWith(
            () => _StaticLanguageController(LanguagePreference.german),
          ),
          controllerProvider.overrideWith(() => _StaticServerController(null)),
        ],
        child: const ServergyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dunkel'));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
    expect(appearanceStore.saved, AppearancePreference.dark);
  });

  testWidgets('changing language immediately rebuilds the app locale', (
    tester,
  ) async {
    final languageStore = _MemoryLanguageStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearanceProvider.overrideWith(
            () => _StaticAppearanceController(AppearancePreference.system),
          ),
          languageStoreProvider.overrideWithValue(languageStore),
          controllerProvider.overrideWith(() => _StaticServerController(null)),
        ],
        child: const ServergyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Settings'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.locale, const Locale('de'));
    expect(languageStore.saved, LanguagePreference.german);
    expect(find.text('Einstellungen'), findsOneWidget);
  });

  testWidgets('English settings open the English privacy document', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearanceProvider.overrideWith(
            () => _StaticAppearanceController(AppearancePreference.system),
          ),
          languageStoreProvider.overrideWithValue(_MemoryLanguageStore()),
          controllerProvider.overrideWith(() => _StaticServerController(null)),
        ],
        child: const ServergyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final privacy = find.widgetWithText(ListTile, 'Privacy');
    await tester.scrollUntilVisible(privacy, 160);
    await tester.ensureVisible(privacy);
    await tester.pumpAndSettle();
    await tester.tap(privacy.hitTestable());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Servergy works without a cloud service'),
      findsOneWidget,
    );
  });

  testWidgets('deleting a saved connection requires confirmation in settings', (
    tester,
  ) async {
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

  testWidgets('dashboard exposes no destructive connection action', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 900));
    await tester.pumpWidget(_home(profile: _profile));

    expect(find.byTooltip('Verbindung löschen'), findsNothing);
    expect(find.byTooltip('Ereignisse'), findsOneWidget);
    expect(find.byTooltip('Einstellungen'), findsOneWidget);
  });

  testWidgets('events use a readable list and open technical details', (
    tester,
  ) async {
    final event = DiagnosticEvent(
      at: DateTime.now(),
      action: DiagnosticAction.sshTest,
      success: false,
      code: 'auth_denied',
      duration: const Duration(milliseconds: 250),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          controllerProvider.overrideWith(
            () => _StateServerController(AppState(diagnostics: [event])),
          ),
        ],
        child: const MaterialApp(home: EventsScreen()),
      ),
    );

    expect(find.text('Letzte Aktion braucht Aufmerksamkeit'), findsOneWidget);
    expect(find.text('SSH-Verbindung geprüft'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('SSH-Verbindung geprüft').first);
    await tester.pumpAndSettle();
    expect(find.text('Ereignisdetails'), findsOneWidget);
    expect(find.text('Technische Kennung'), findsOneWidget);
    expect(find.text('auth_denied'), findsOneWidget);
  });

  testWidgets('settings show package-backed version information', (
    tester,
  ) async {
    const metadata = AppMetadata(
      name: 'Servergy',
      version: '0.1.0',
      build: '7',
      releaseChannel: 'Stabil',
      platform: 'android',
    );
    await tester.pumpWidget(_settings(metadata: metadata));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Über Servergy'), 240);
    await tester.pumpAndSettle();

    expect(find.text('Stabil · 0.1.0 (Build 7)'), findsOneWidget);
    expect(find.text('Versionsinformationen kopieren'), findsOneWidget);
  });

  testWidgets('feedback warns before opening an external issue form', (
    tester,
  ) async {
    _setViewport(tester, const Size(400, 1000));
    await tester.pumpWidget(_settings(profile: _profile));
    await tester.pumpAndSettle();

    final feedback = find.text('Feedback geben');
    await tester.scrollUntilVisible(feedback, 160);
    await tester.tap(feedback);
    await tester.pumpAndSettle();

    expect(find.text('Feedback sicher senden'), findsOneWidget);
    expect(
      find.textContaining('Passwörter, privaten Schlüssel'),
      findsOneWidget,
    );
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.text('Feedback sicher senden'), findsNothing);
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

Widget _settings({
  ServerProfile? profile,
  AppMetadata? metadata,
  AppearanceStore? appearanceStore,
  LanguageStore? languageStore,
}) => ProviderScope(
  overrides: [
    controllerProvider.overrideWith(() => _StaticServerController(profile)),
    appearanceStoreProvider.overrideWithValue(
      appearanceStore ?? _MemoryAppearanceStore(),
    ),
    languageStoreProvider.overrideWithValue(
      languageStore ?? _MemoryLanguageStore(),
    ),
    if (metadata != null)
      appMetadataProvider.overrideWithValue(AsyncData(metadata)),
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

EditableText _editableField(WidgetTester tester, String label) => tester.widget(
  find.descendant(
    of: find.byKey(ValueKey('field-$label')),
    matching: find.byType(EditableText),
  ),
);

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

class _StaticAppearanceController extends AppearanceController {
  _StaticAppearanceController(this.preference);

  final AppearancePreference preference;

  @override
  AppearanceState build() =>
      AppearanceState(preference: preference, loaded: true);
}

class _StaticLanguageController extends LanguageController {
  _StaticLanguageController(this.preference);

  final LanguagePreference preference;

  @override
  LanguageState build() => LanguageState(preference: preference, loaded: true);
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

class _MemoryAppearanceStore implements AppearanceStore {
  _MemoryAppearanceStore() : preference = AppearancePreference.system;

  AppearancePreference preference;
  AppearancePreference? saved;

  @override
  Future<AppearancePreference> load() async => preference;

  @override
  Future<void> save(AppearancePreference value) async {
    saved = value;
    preference = value;
  }
}

class _MemoryLanguageStore implements LanguageStore {
  _MemoryLanguageStore() : preference = LanguagePreference.system;

  LanguagePreference preference;
  LanguagePreference? saved;

  @override
  Future<LanguagePreference> load() async => preference;

  @override
  Future<void> save(LanguagePreference value) async {
    saved = value;
    preference = value;
  }
}
