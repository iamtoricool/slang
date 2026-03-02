import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:slang_cloud/src/client.dart';
import 'package:slang_cloud/src/config.dart';
import 'package:slang_cloud/src/exception.dart';
import 'package:slang_cloud/src/model.dart';
import 'package:slang_cloud/src/storage.dart';

/// Controller that manages cloud translation downloads and state.
///
/// Non-singleton - create and manage instance yourself.
///
/// Usage:
/// ```dart
/// final controller = CloudTranslationController(
///   config: SlangCloudConfig(baseUrl: 'https://api.example.com'),
/// );
///
/// // Set language (handles check + download)
/// try {
///   await controller.setLanguage('de');
/// } catch (e) {
///   // Handle error on app-side (show snackbar)
/// }
/// ```
class CloudTranslationController extends ValueNotifier<CloudState> {
  final SlangCloudConfig config;
  final SlangCloudStorage _storage;
  late final SlangCloudClient _client;
  bool _isProcessing = false;

  /// Gets the storage instance used by this controller.
  SlangCloudStorage get storage => _storage;

  /// Creates a new controller instance.
  ///
  /// [storage] is optional - defaults to in-memory storage.
  /// [client] is optional - for testing purposes only.
  CloudTranslationController({
    required this.config,
    SlangCloudStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? InMemorySlangCloudStorage(),
        super(const CloudReady()) {
    _client = SlangCloudClient(config: config, storage: _storage, client: client);
  }

  /// Gets cached translation JSON for the given locale.
  Future<String?> getCachedTranslation(String locale) async {
    return _storage.getTranslation(locale);
  }

  /// Sets the language by downloading translations if needed.
  ///
  /// Flow:
  /// 1. HEAD request to check if update needed (compare hash)
  /// 2. If update needed, GET request to download
  /// 3. Cache and update state on success
  ///
  /// If [force] is true, bypasses the cache check and always downloads
  /// the latest translation from the server.
  ///
  /// Throws on error - handle on app-side (show snackbar).
  /// On error, previous locale stays active.
  Future<void> setLanguage(String locale, {bool force = false}) async {
    // Prevent concurrent operations
    if (_isProcessing) {
      return;
    }
    _isProcessing = true;

    try {
      // Set loading state (preserve current locale)
      value = CloudLoading(
        currentLocale: value.currentLocale,
        lastUpdated: value.lastUpdated,
        currentHash: value.currentHash,
      );

      String? newHash;
      if (!force) {
        // Check for update
        newHash = await _client.checkForUpdate(locale);
      }

      String currentHash;
      if (newHash != null || force) {
        // Download new translation and get server hash from response
        final result = await _client.downloadTranslation(locale);
        final jsonContent = result.content;
        final serverHash = result.hash;

        // Determine expected hash:
        // - If we did HEAD request: use that hash
        // - If force refresh (skipped HEAD): use hash from GET response
        final expectedHash = newHash ?? serverHash;

        // Verify hash if user provided a hash function
        if (config.hashFunction != null) {
          final calculatedHash = config.hashFunction!(jsonContent);
          if (calculatedHash != expectedHash) {
            // Clear the stale cache so next attempt will be treated as fresh
            await _storage.clearVersion(locale);
            await _storage.clearTranslation(locale);

            throw SlangCloudHashMismatchException(
              'Hash verification failed: downloaded content may be corrupted. '
              'Local cache has been cleared. Retry to download fresh.',
              expectedHash: expectedHash,
              actualHash: calculatedHash,
              locale: locale,
            );
          }
        }
        // If no hash function provided, we trust the server hash (no verification)

        // Cache the translation
        await _storage.setTranslation(locale, jsonContent);
        await _storage.setVersion(locale, expectedHash);
        currentHash = expectedHash;
      } else {
        // No update needed, use cached hash
        currentHash = await _storage.getVersion(locale) ?? '';
      }

      // Success - update to ready state with new locale and hash
      value = CloudReady(
        currentLocale: locale,
        lastUpdated: DateTime.now(),
        currentHash: currentHash,
      );
    } on SlangCloudHashMismatchException {
      // Revert to ready state (preserve previous locale and hash)
      value = CloudReady(
        currentLocale: value.currentLocale,
        lastUpdated: value.lastUpdated,
        currentHash: value.currentHash,
      );
      rethrow;
    } catch (e, stackTrace) {
      // Error - revert to ready state (preserve previous locale and hash)
      value = CloudReady(
        currentLocale: value.currentLocale,
        lastUpdated: value.lastUpdated,
        currentHash: value.currentHash,
      );
      debugPrint('SlangCloud Error: $e\n$stackTrace');
      rethrow;
    } finally {
      _isProcessing = false;
    }
  }

  /// Checks for updates for the current locale without switching.
  /// Silently fails (does not throw).
  Future<void> checkForUpdates() async {
    final currentLocale = value.currentLocale;
    if (currentLocale == null) return;

    try {
      await setLanguage(currentLocale);
    } catch (e) {
      // Silently ignore errors for background check
      debugPrint('SlangCloud: Background update check failed: $e');
    }
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
}
