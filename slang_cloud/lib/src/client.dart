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

/// Callback to compute a hash from response content.
/// Used when the server doesn't provide a hash header (e.g., static files).
/// Return null to skip hash-based caching for this response.
typedef ComputeHashCallback = String? Function(String responseBody);

/// Client for downloading and managing cloud translations.
class SlangCloudClient {
  final String baseUrl;
  final String pathTemplate;
  final SlangCloudStorage storage;
  final String hashHeader;
  final Duration timeout;
  final bool isFlatMap;
  final ApplyTranslationsCallback applyTranslations;
  final SetFallbackCallback setFallback;
  final ComputeHashCallback? computeHash;
  final http.Client _client;

  // In-memory cache
  String? _currentLocale;
  String? _currentHash;

  // Counter to track the most recent setLanguage request.
  // Used to ignore stale responses when user switches locales rapidly.
  int _requestId = 0;

  SlangCloudClient._({
    required this.baseUrl,
    required this.pathTemplate,
    required this.storage,
    required this.hashHeader,
    required this.timeout,
    required this.isFlatMap,
    required this.applyTranslations,
    required this.setFallback,
    this.computeHash,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Builds the full URL by replacing {locale} in the path template.
  String _buildUrl(String locale) {
    final path = pathTemplate.replaceAll('{locale}', locale);
    // Ensure baseUrl doesn't have trailing slash and path starts with slash
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$base$normalizedPath';
  }

  /// Factory constructor that initializes and loads cached translations.
  ///
  /// [baseUrl] - The base URL of the translation server (e.g., 'https://api.example.com')
  /// [pathTemplate] - URL path template with {locale} placeholder (default: '/translations/{locale}')
  /// [applyTranslations] - Callback to apply downloaded translations to your app
  /// [setFallback] - Callback to set fallback locale when cloud translations fail
  /// [storage] - Storage implementation for caching (default: in-memory)
  /// [hashHeader] - Header name for translation hash (default: 'X-Translation-Hash')
  /// [timeout] - Request timeout duration (default: 30 seconds)
  /// [isFlatMap] - Whether translations use flat keys like 'main.title'
  /// [httpClient] - Custom http client instance
  /// [computeHash] - Optional callback to compute hash from response body.
  ///   Use this for static files when the server doesn't provide a hash header.
  ///   Return null to skip hash-based caching.
  static Future<SlangCloudClient> create({
    required String baseUrl,
    required ApplyTranslationsCallback applyTranslations,
    required SetFallbackCallback setFallback,
    String pathTemplate = '/translations/{locale}',
    SlangCloudStorage? storage,
    String hashHeader = 'X-Translation-Hash',
    Duration timeout = const Duration(seconds: 30),
    bool isFlatMap = false,
    http.Client? httpClient,
    ComputeHashCallback? computeHash,
  }) async {
    final client = SlangCloudClient._(
      baseUrl: baseUrl,
      pathTemplate: pathTemplate,
      storage: storage ?? InMemorySlangCloudStorage(),
      hashHeader: hashHeader,
      timeout: timeout,
      isFlatMap: isFlatMap,
      applyTranslations: applyTranslations,
      setFallback: setFallback,
      computeHash: computeHash,
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
  /// If the user switches locales while downloading, the stale response
  /// is silently ignored.
  /// Throws [SlangCloudException] on failure.
  Future<void> setLanguage(String locale) async {
    // Increment counter and capture the request ID for this call.
    // If another setLanguage call happens while this one is in flight,
    // the counter will increase, and we can detect this request is stale.
    final requestId = ++_requestId;

    // Helper to check if this request is still the most recent one.
    bool isStale() => _requestId != requestId;

    try {
      final response = await _client.get(Uri.parse(_buildUrl(locale))).timeout(timeout);

      // Ignore if user switched to different locale while downloading
      if (isStale()) {
        return;
      }

      if (response.statusCode == 200) {
        final body = response.body;
        // Use header hash if available, otherwise use computeHash callback if provided
        // This supports both API endpoints with hash headers and static JSON files
        final serverHash = response.headers[hashHeader.toLowerCase()] ?? computeHash?.call(body) ?? '';
        final map = jsonDecode(body) as Map<String, dynamic>;

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
      // Only throw if this is still the most recent request
      if (!isStale()) {
        throw SlangCloudException('Request timed out');
      }
    } on FormatException catch (e) {
      // Only throw if this is still the most recent request
      if (!isStale()) {
        throw SlangCloudException('Invalid response format: $e');
      }
    } catch (e) {
      // Only throw if this is still the most recent request
      if (!isStale()) {
        throw SlangCloudException('Failed to set language: $e');
      }
    }
  }

  /// Check if an update is available for the current locale.
  ///
  /// Always uses the configured hashHeader. This is mandatory per backend spec.
  /// Returns true if the hash header is missing or differs from cached hash.
  Future<bool> hasUpdate() async {
    if (_currentLocale == null || _currentHash == null) return true;

    try {
      final response = await _client.head(Uri.parse(_buildUrl(_currentLocale!))).timeout(timeout);

      if (response.statusCode == 200) {
        final serverHash = response.headers[hashHeader.toLowerCase()];
        if (serverHash != null) {
          return serverHash != _currentHash;
        }
        // Hash header missing, assume update needed
        return true;
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

  /// Dispose the client and release resources.
  ///
  /// Closes the underlying HTTP client. After calling dispose,
  /// the client should not be used anymore.
  void dispose() {
    _client.close();
  }
}
