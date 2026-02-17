/// Abstract storage interface for caching translations and versions.
/// Implement this using Hive, SharedPreferences, SecureStorage, or any other persistence layer.
abstract class SlangCloudStorage {
  /// Get the stored translation JSON for the given [locale].
  Future<String?> getTranslation(String locale);

  /// Save the translation JSON for the given [locale].
  Future<void> setTranslation(String locale, String content);

  /// Get the stored version/hash for the given [locale].
  Future<String?> getVersion(String locale);

  /// Save the version/hash for the given [locale].
  Future<void> setVersion(String locale, String version);
}

/// A simple in-memory storage implementation (useful for testing).
class InMemorySlangCloudStorage implements SlangCloudStorage {
  final Map<String, String> _translations = {};
  final Map<String, String> _versions = {};

  @override
  Future<String?> getTranslation(String locale) async => _translations[locale];

  @override
  Future<void> setTranslation(String locale, String content) async => _translations[locale] = content;

  @override
  Future<String?> getVersion(String locale) async => _versions[locale];

  @override
  Future<void> setVersion(String locale, String version) async => _versions[locale] = version;
}
