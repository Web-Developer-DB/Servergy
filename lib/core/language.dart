import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language choice is deliberately independent from the server profile.
/// System mode follows German system locales and otherwise uses English.
/// Persisted app-language choice. `system` maps German system locales to
/// German and all other locales to English in the app's locale resolver.
enum LanguagePreference {
  system,
  german,
  english;

  static LanguagePreference fromStorage(String? value) => switch (value) {
    'german' => LanguagePreference.german,
    'english' => LanguagePreference.english,
    _ => LanguagePreference.system,
  };

  Locale? get locale => switch (this) {
    LanguagePreference.system => null,
    LanguagePreference.german => const Locale('de'),
    LanguagePreference.english => const Locale('en'),
  };
}

/// Immutable view state for language loading and persistence feedback.
class LanguageState {
  const LanguageState({
    this.preference = LanguagePreference.system,
    this.loaded = false,
    this.saving = false,
    this.error,
  });

  final LanguagePreference preference;
  final bool loaded;
  final bool saving;
  final String? error;

  LanguageState copyWith({
    LanguagePreference? preference,
    bool? loaded,
    bool? saving,
    String? error,
    bool clearError = false,
  }) => LanguageState(
    preference: preference ?? this.preference,
    loaded: loaded ?? this.loaded,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
  );
}

/// Small persistence contract that keeps [LanguageController] testable.
abstract interface class LanguageStore {
  Future<LanguagePreference> load();
  Future<void> save(LanguagePreference preference);
}

/// Production implementation for the one non-sensitive language preference.
class PreferencesLanguageStore implements LanguageStore {
  PreferencesLanguageStore({this.preferences});

  static const key = 'servergy.language.v1';
  final SharedPreferencesAsync? preferences;

  SharedPreferencesAsync get _store => preferences ?? SharedPreferencesAsync();

  @override
  Future<LanguagePreference> load() async =>
      LanguagePreference.fromStorage(await _store.getString(key));

  @override
  Future<void> save(LanguagePreference preference) =>
      _store.setString(key, preference.name);
}

/// Injectable language persistence used by the controller.
final languageStoreProvider = Provider<LanguageStore>(
  (ref) => PreferencesLanguageStore(),
);

/// Reactive state observed by the root app and settings UI.
final languageProvider = NotifierProvider<LanguageController, LanguageState>(
  LanguageController.new,
);

/// Handles asynchronous language loading and an optimistic, reversible save.
///
/// `_selectionMade` avoids a common async race: a slow initial read must not
/// replace a setting the user has already selected in the current session.
class LanguageController extends Notifier<LanguageState> {
  var _selectionMade = false;
  var _saveToken = 0;

  @override
  LanguageState build() {
    final store = ref.watch(languageStoreProvider);
    _load(store);
    return const LanguageState();
  }

  Future<void> _load(LanguageStore store) async {
    try {
      final preference = await store.load();
      if (!ref.mounted || _selectionMade) return;
      state = state.copyWith(preference: preference, loaded: true);
    } catch (_) {
      if (!ref.mounted || _selectionMade) return;
      state = state.copyWith(loaded: true);
    }
  }

  /// Applies the choice immediately and restores the preceding choice on error.
  Future<void> select(LanguagePreference preference) async {
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
      await ref.read(languageStoreProvider).save(preference);
      if (!ref.mounted || token != _saveToken) return;
      state = state.copyWith(saving: false);
    } catch (_) {
      if (!ref.mounted || token != _saveToken) return;
      state = state.copyWith(
        preference: previous,
        saving: false,
        error: 'Die Sprache konnte nicht gespeichert werden.',
      );
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}
