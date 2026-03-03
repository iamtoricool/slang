import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'cached_translations.dart';
import 'exception.dart';
import 'storage.dart';

/// Callback to apply translations to the app.
/// [locale] is the locale code (e.g., 'en', 'de')
/// [map] is the parsed translation map
/// [isFlatMap] indicates if the map uses flat keys (e.g., 'main.title')
typedef ApplyTranslationsCallback = Future<void> Function(
  String locale,
  Map<String, dynamic> map,
  bool isFlatMap,
);

/// Callback to set the fallback locale.
/// Called when cloud translations fail to load.
typedef SetFallbackCallback = Future<void> Function();

/// Client for downloading and managing cloud translations.
class SlangCloudClient {
  final String baseUrl;
  final SlangCloudStorage storage;
  final String hashHeader;
  final Duration timeout;
  final bool isFlatMap;
  final ApplyTranslationsCallback applyTranslations;
  final SetFallbackCallback setFallback;
  final http.Client _client;

  // In-memory cache
  String? _currentLocale;
  String? _currentHash;

  SlangCloudClient._({
    required this.baseUrl,
    required this.storage,
    required this.hashHeader,
    required this.timeout,
    required this.isFlatMap,
    required this.applyTranslations,
    required this.setFallback,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Factory constructor that initializes and loads cached translations.
  static Future<SlangCloudClient> create({
    required String baseUrl,
    required ApplyTranslationsCallback applyTranslations,
    required SetFallbackCallback setFallback,
    SlangCloudStorage? storage,
    String hashHeader = 'X-Translation-Hash',
    Duration timeout = const Duration(seconds: 30),
    bool isFlatMap = false,
    http.Client? httpClient,
  }) async {
    final client = SlangCloudClient._(
      baseUrl: baseUrl,
      storage: storage ?? InMemorySlangCloudStorage(),
      hashHeader: hashHeader,
      timeout: timeout,
      isFlatMap: isFlatMap,
      applyTranslations: applyTranslations,
      setFallback: setFallback,
      client: httpClient,
    );

    try {
      final cached = await client.storage.getCached();
      if (cached != null) {
        client._currentLocale = cached.locale;
        client._currentHash = cached.hash;
        await client.applyTranslations(
          cached.locale,
          cached.translations,
          client.isFlatMap,
        );
      } else {
        // No cache - use fallback
        await setFallback();
      }
    } catch (e) {
      // Cache load failed - use fallback
      debugPrint('SlangCloud: Failed to load cache: $e');
      await setFallback();
    }

    return client;
  }

  /// The currently active locale (from cache or fallback).
  String? get currentLocale => _currentLocale;

  /// The hash of the currently cached translations.
  String? get currentHash => _currentHash;

  /// Download and set a new language.
  ///
  /// Downloads from server, caches to storage, and applies to app.
  /// Throws [SlangCloudException] on failure.
  Future<void> setLanguage(String locale) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/translations/$locale')).timeout(timeout);

      if (response.statusCode == 200) {
        final serverHash = response.headers[hashHeader.toLowerCase()] ?? '';
        final map = jsonDecode(response.body) as Map<String, dynamic>;

        final cached = CachedTranslations(
          locale: locale,
          hash: serverHash,
          translations: map,
        );

        await storage.setCached(cached);
        await applyTranslations(locale, map, isFlatMap);

        _currentLocale = locale;
        _currentHash = serverHash;
      } else {
        throw SlangCloudException('Failed to download translations: ${response.statusCode}');
      }
    } on TimeoutException {
      throw SlangCloudException('Request timed out');
    } on FormatException catch (e) {
      throw SlangCloudException('Invalid response format: $e');
    } catch (e) {
      throw SlangCloudException('Failed to set language: $e');
    }
  }

  /// Check if an update is available for the current locale.
  Future<bool> hasUpdate() async {
    if (_currentLocale == null || _currentHash == null) return true;

    try {
      final response = await _client.head(Uri.parse('$baseUrl/translations/$_currentLocale')).timeout(timeout);

      if (response.statusCode == 200) {
        final serverHash = response.headers[hashHeader.toLowerCase()];
        return serverHash != _currentHash;
      }
      return true;
    } catch (e) {
      // On error, assume update needed
      return true;
    }
  }

  /// Update the current locale if an update is available.
  ///
  /// Returns true if updated, false if no update needed.
  /// Throws [SlangCloudException] on failure.
  Future<bool> updateIfAvailable() async {
    if (!await hasUpdate()) return false;

    if (_currentLocale == null) {
      throw SlangCloudException('No current locale set');
    }

    await setLanguage(_currentLocale!);
    return true;
  }

  /// Reload translations from cache.
  Future<void> reload() async {
    try {
      final cached = await storage.getCached();
      if (cached != null) {
        await applyTranslations(
          cached.locale,
          cached.translations,
          isFlatMap,
        );
        _currentLocale = cached.locale;
        _currentHash = cached.hash;
      }
    } catch (e) {
      debugPrint('SlangCloud: Failed to reload: $e');
    }
  }

  /// Clear the cached translations.
  Future<void> clearCache() async {
    await storage.clear();
    _currentLocale = null;
    _currentHash = null;
  }
}
