import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's display preference is deliberately independent from the server
/// profile. It contains no endpoint, credential, or diagnostic information.
/// Persisted theme choice. `system` deliberately stores a preference rather
/// than a resolved brightness so an OS theme change is reflected immediately.
enum AppearancePreference {
  system,
  light,
  dark;

  static AppearancePreference fromStorage(String? value) => switch (value) {
    'light' => AppearancePreference.light,
    'dark' => AppearancePreference.dark,
    _ => AppearancePreference.system,
  };
}

/// Immutable view state for the appearance setting row.
///
/// `loaded` distinguishes the initial asynchronous read from the default
/// value, while `saving` lets the UI prevent overlapping changes.
class AppearanceState {
  const AppearanceState({
    this.preference = AppearancePreference.system,
    this.loaded = false,
    this.saving = false,
    this.error,
  });

  final AppearancePreference preference;
  final bool loaded;
  final bool saving;
  final String? error;

  AppearanceState copyWith({
    AppearancePreference? preference,
    bool? loaded,
    bool? saving,
    String? error,
    bool clearError = false,
  }) => AppearanceState(
    preference: preference ?? this.preference,
    loaded: loaded ?? this.loaded,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
  );
}

/// Storage seam used by [AppearanceController] and in-memory test doubles.
abstract interface class AppearanceStore {
  Future<AppearancePreference> load();
  Future<void> save(AppearancePreference preference);
}

/// Production implementation backed by one non-sensitive preferences key.
class PreferencesAppearanceStore implements AppearanceStore {
  PreferencesAppearanceStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const key = 'servergy.appearance.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<AppearancePreference> load() async =>
      AppearancePreference.fromStorage(await _preferences.getString(key));

  @override
  Future<void> save(AppearancePreference preference) =>
      _preferences.setString(key, preference.name);
}

/// Dependency-injection point. Tests override this provider instead of using
/// device preferences.
final appearanceStoreProvider = Provider<AppearanceStore>(
  (ref) => PreferencesAppearanceStore(),
);

/// Reactive state used by [ServergyApp] and the settings screen.
final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
      AppearanceController.new,
    );

/// Loads and persists appearance choices without touching connection state.
///
/// The two tokens prevent late reads/writes from overwriting a newer selection
/// when storage operations complete out of order.
class AppearanceController extends Notifier<AppearanceState> {
  var _selectionMade = false;
  var _saveToken = 0;

  @override
  AppearanceState build() {
    final store = ref.watch(appearanceStoreProvider);
    _load(store);
    return const AppearanceState();
  }

  Future<void> _load(AppearanceStore store) async {
    try {
      final preference = await store.load();
      if (!ref.mounted || _selectionMade) return;
      state = state.copyWith(preference: preference, loaded: true);
    } catch (_) {
      // System mode is a safe fallback when a platform preference backend is
      // unavailable (for example during a first start or a widget test).
      if (!ref.mounted || _selectionMade) return;
      state = state.copyWith(loaded: true);
    }
  }

  /// Optimistically applies a new preference, then rolls back on write error.
  Future<void> select(AppearancePreference preference) async {
    final previous = state.preference;
    final token = ++_saveToken;
    _selectionMade = true;
    state = state.copyWith(
      preference: preference,
      loaded: true,
      saving: true,
      clearError: true,
    );
    try {
      await ref.read(appearanceStoreProvider).save(preference);
      if (!ref.mounted || token != _saveToken) return;
      state = state.copyWith(saving: false);
    } catch (_) {
      if (!ref.mounted || token != _saveToken) return;
      state = state.copyWith(
        preference: previous,
        saving: false,
        error: 'Darstellung konnte nicht gespeichert werden.',
      );
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}
