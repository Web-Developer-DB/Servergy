import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's display preference is deliberately independent from the server
/// profile. It contains no endpoint, credential, or diagnostic information.
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

abstract interface class AppearanceStore {
  Future<AppearancePreference> load();
  Future<void> save(AppearancePreference preference);
}

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

final appearanceStoreProvider = Provider<AppearanceStore>(
  (ref) => PreferencesAppearanceStore(),
);

final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
      AppearanceController.new,
    );

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
