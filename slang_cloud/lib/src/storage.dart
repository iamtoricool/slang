import 'cached_translations.dart';

/// Abstract storage interface for caching translations.
///
/// Implementations handle serialization internally. For example:
/// - In-memory: Store Map directly
/// - SharedPreferences: Convert to JSON string
/// - Hive: Store as object
abstract class SlangCloudStorage {
  /// Get the cached translations with metadata.
  Future<CachedTranslations?> getCached();

  /// Save the cached translations with metadata.
  Future<void> setCached(CachedTranslations cached);

  /// Clear all cached data.
  Future<void> clear();
}

/// A simple in-memory storage implementation (useful for testing).
class InMemorySlangCloudStorage implements SlangCloudStorage {
  CachedTranslations? _data;

  @override
  Future<CachedTranslations?> getCached() async => _data;

  @override
  Future<void> setCached(CachedTranslations cached) async {
    _data = cached;
  }

  @override
  Future<void> clear() async {
    _data = null;
  }
}
