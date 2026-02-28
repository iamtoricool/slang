import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:slang_cloud/src/config.dart';
import 'package:slang_cloud/src/storage.dart';

/// Handles communication with the Slang Cloud backend.
///
/// Flow:
/// 1. HEAD request to check for updates (hash in header)
/// 2. GET request to download (stream for large files)
/// 3. Content-Type detection: JSON vs file download
class SlangCloudClient {
  final SlangCloudConfig config;
  final SlangCloudStorage storage;
  final http.Client _client;

  SlangCloudClient({
    required this.config,
    required this.storage,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Disposes the internal HTTP client.
  void dispose() {
    _client.close();
  }

  /// Checks for updates using HEAD request.
  /// Returns the server hash if different from cached, null if up-to-date.
  Future<String?> checkForUpdate(String locale) async {
    final url = Uri.parse(config.buildUrl(locale));

    try {
      final request = http.Request('HEAD', url)..headers.addAll(config.headers);

      final streamedResponse = await _client.send(request).timeout(config.timeout);

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final serverHash = streamedResponse.headers[config.hashHeader.toLowerCase()];
        if (serverHash == null) {
          debugPrint('SlangCloud: Missing ${config.hashHeader} header in HEAD response');
          return null;
        }

        final cachedHash = await storage.getVersion(locale);
        if (cachedHash != serverHash) {
          return serverHash;
        }
      }
    } on TimeoutException {
      debugPrint('SlangCloud: HEAD request timed out for $locale');
    } catch (e) {
      debugPrint('SlangCloud: Failed to check for updates: $e');
    }
    return null;
  }

  /// Downloads translation using stream (supports large files).
  /// Returns the content as string.
  ///
  /// Supports:
  /// - JSON response (Content-Type: application/json)
  /// - File download (any other Content-Type)
  Future<String?> downloadTranslation(String locale) async {
    final url = Uri.parse(config.buildDownloadUrl(locale));

    try {
      final request = http.Request('GET', url)..headers.addAll(config.headers);

      final streamedResponse = await _client.send(request).timeout(config.timeout);

      if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
        debugPrint('SlangCloud: Download failed with status ${streamedResponse.statusCode}');
        return null;
      }

      final contentType = streamedResponse.headers['content-type']?.toLowerCase() ?? '';

      // Stream download to handle large files
      final bytes = await streamedResponse.stream.toBytes();

      // Try to decode as UTF-8 (works for both JSON and text files)
      try {
        final content = utf8.decode(bytes);

        // Validate JSON if content-type indicates JSON
        if (contentType.contains('application/json')) {
          try {
            jsonDecode(content); // Validate JSON structure
          } catch (e) {
            debugPrint('SlangCloud: Invalid JSON response: $e');
            return null;
          }
        }

        return content;
      } catch (e) {
        debugPrint('SlangCloud: Failed to decode response as UTF-8: $e');
        return null;
      }
    } on TimeoutException {
      debugPrint('SlangCloud: Download request timed out for $locale');
      return null;
    } catch (e) {
      debugPrint('SlangCloud: Failed to download translation: $e');
      return null;
    }
  }
}
