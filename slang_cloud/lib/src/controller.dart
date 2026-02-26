import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:slang_cloud/src/client.dart';
import 'package:slang_cloud/src/config.dart';
import 'package:slang_cloud/src/model.dart';
import 'package:slang_cloud/src/storage.dart';
import 'package:crypto/crypto.dart';

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

  /// Creates a new controller instance.
  ///
  /// [storage] is optional - defaults to in-memory storage.
  CloudTranslationController({
    required this.config,
    SlangCloudStorage? storage,
  })  : _storage = storage ?? InMemorySlangCloudStorage(),
        super(const CloudReady()) {
    _client = SlangCloudClient(config: config, storage: _storage);
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
  /// Throws on error - handle on app-side (show snackbar).
  /// On error, previous locale stays active.
  Future<void> setLanguage(String locale) async {
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
      );

      // Check for update
      final newHash = await _client.checkForUpdate(locale);

      if (newHash != null) {
        // Download new translation
        final jsonContent = await _client.downloadTranslation(locale);

        if (jsonContent == null) {
          throw Exception('Failed to download translation for $locale');
        }

        // Verify hash
        final downloadedHash = md5.convert(utf8.encode(jsonContent)).toString();
        if (downloadedHash != newHash) {
          debugPrint(
            'SlangCloud: Hash mismatch for $locale. Expected $newHash, got $downloadedHash',
          );
          throw Exception('Hash verification failed: downloaded content may be corrupted');
        }

        // Cache the translation
        await _storage.setTranslation(locale, jsonContent);
        await _storage.setVersion(locale, newHash);
      }

      // Success - update to ready state with new locale
      value = CloudReady(
        currentLocale: locale,
        lastUpdated: DateTime.now(),
      );
    } catch (e, stackTrace) {
      // Error - revert to ready state (preserve previous locale)
      value = CloudReady(
        currentLocale: value.currentLocale,
        lastUpdated: value.lastUpdated,
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
