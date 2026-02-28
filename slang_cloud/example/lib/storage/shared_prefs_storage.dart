import 'package:shared_preferences/shared_preferences.dart';
import 'package:slang_cloud/slang_cloud.dart';

/// SharedPreferences implementation of SlangCloudStorage.
/// Persists translations, versions, and active locale to device storage.
class SharedPreferencesSlangCloudStorage implements SlangCloudStorage {
  static const String _translationsPrefix = 'slang_cloud_translations_';
  static const String _versionsPrefix = 'slang_cloud_versions_';
  static const String _activeLocaleKey = 'slang_cloud_active_locale';

  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> getTranslation(String locale) async {
    await _init();
    return _prefs!.getString('$_translationsPrefix$locale');
  }

  @override
  Future<void> setTranslation(String locale, String content) async {
    await _init();
    await _prefs!.setString('$_translationsPrefix$locale', content);
  }

  @override
  Future<String?> getVersion(String locale) async {
    await _init();
    return _prefs!.getString('$_versionsPrefix$locale');
  }

  @override
  Future<void> setVersion(String locale, String version) async {
    await _init();
    await _prefs!.setString('$_versionsPrefix$locale', version);
  }

  /// Get the last active locale from storage.
  Future<String?> getActiveLocale() async {
    await _init();
    return _prefs!.getString(_activeLocaleKey);
  }

  /// Set the active locale in storage.
  Future<void> setActiveLocale(String? locale) async {
    await _init();
    if (locale != null) {
      await _prefs!.setString(_activeLocaleKey, locale);
    } else {
      await _prefs!.remove(_activeLocaleKey);
    }
  }

  /// Clear all stored data (for testing/reset).
  Future<void> clearAll() async {
    await _init();
    final keys = _prefs!.getKeys().where(
      (key) => key.startsWith(_translationsPrefix) || key.startsWith(_versionsPrefix) || key == _activeLocaleKey,
    );
    for (final key in keys) {
      await _prefs!.remove(key);
    }
  }
}
