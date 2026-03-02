import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:slang_cloud/src/config.dart';
import 'package:slang_cloud/src/exception.dart';
import 'package:slang_cloud/src/storage.dart';

/// Handles communication with the Slang Cloud backend.
///
/// Flow:
/// 1. HEAD request to check for updates (hash in header)
/// 2. GET request to download (stream for large files)
/// 3. Content-Type detection: JSON vs file download
/// 4. Automatic retry with exponential backoff for retryable errors
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
  ///
  /// Throws [SlangCloudException] on failure.
  Future<String?> checkForUpdate(String locale) async {
    return _withRetry(
      () => _checkForUpdate(locale),
      locale,
      'check for updates',
    );
  }

  /// Internal check for updates without retry logic.
  Future<String?> _checkForUpdate(String locale) async {
    final url = Uri.parse(config.buildUrl(locale));

    try {
      final request = http.Request('HEAD', url)..headers.addAll(config.headers);

      final streamedResponse = await _client.send(request).timeout(config.timeout);

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        final serverHash = streamedResponse.headers[config.hashHeader.toLowerCase()];
        if (serverHash == null) {
          throw SlangCloudInvalidResponseException(
            'Missing ${config.hashHeader} header in HEAD response',
            locale: locale,
          );
        }

        final cachedHash = await storage.getVersion(locale);
        if (cachedHash != serverHash) {
          return serverHash;
        }
        return null; // Up to date
      }

      throw _createExceptionFromStatusCode(
        streamedResponse.statusCode,
        'HEAD request failed',
        locale: locale,
      );
    } on SlangCloudException {
      rethrow;
    } on TimeoutException {
      throw SlangCloudTimeoutException(
        'Request timed out while checking for updates',
        timeout: config.timeout,
        locale: locale,
      );
    } on SocketException catch (e) {
      throw SlangCloudNetworkException(
        'Network error while checking for updates',
        locale: locale,
        originalError: e,
      );
    } catch (e) {
      throw SlangCloudNetworkException(
        'Failed to check for updates: $e',
        locale: locale,
        originalError: e,
      );
    }
  }

  /// Downloads translation using stream (supports large files).
  /// Returns a record with content and hash from server header.
  ///
  /// Supports:
  /// - JSON response (Content-Type: application/json)
  /// - File download (any other Content-Type)
  ///
  /// Throws [SlangCloudException] on failure.
  Future<({String content, String hash})> downloadTranslation(String locale) async {
    return _withRetry(
      () => _downloadTranslation(locale),
      locale,
      'download translation',
    );
  }

  /// Internal download without retry logic.
  Future<({String content, String hash})> _downloadTranslation(String locale) async {
    final url = Uri.parse(config.buildDownloadUrl(locale));

    try {
      final request = http.Request('GET', url)..headers.addAll(config.headers);

      final streamedResponse = await _client.send(request).timeout(config.timeout);

      final bytes = await streamedResponse.stream.toBytes();
      final responseBody = utf8.decode(bytes);

      if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
        throw _createExceptionFromStatusCode(
          streamedResponse.statusCode,
          'Download request failed',
          locale: locale,
          responseBody: responseBody,
        );
      }

      // Extract hash from response headers
      final hash = streamedResponse.headers[config.hashHeader.toLowerCase()];
      if (hash == null) {
        throw SlangCloudInvalidResponseException(
          'Missing ${config.hashHeader} header in GET response',
          locale: locale,
        );
      }

      final contentType = streamedResponse.headers['content-type']?.toLowerCase() ?? '';

      // Validate JSON if content-type indicates JSON
      if (contentType.contains('application/json')) {
        try {
          jsonDecode(responseBody);
        } catch (e) {
          throw SlangCloudInvalidResponseException(
            'Invalid JSON response from server',
            locale: locale,
            originalError: e,
            responseBody: responseBody,
          );
        }
      }

      return (content: responseBody, hash: hash);
    } on SlangCloudException {
      rethrow;
    } on TimeoutException {
      throw SlangCloudTimeoutException(
        'Request timed out while downloading translation',
        timeout: config.timeout,
        locale: locale,
      );
    } on SocketException catch (e) {
      throw SlangCloudNetworkException(
        'Network error while downloading translation',
        locale: locale,
        originalError: e,
      );
    } catch (e) {
      throw SlangCloudNetworkException(
        'Failed to download translation: $e',
        locale: locale,
        originalError: e,
      );
    }
  }

  /// Wraps an operation with retry logic using exponential backoff.
  Future<T> _withRetry<T>(
    Future<T> Function() operation,
    String locale,
    String operationName,
  ) async {
    SlangCloudException? lastError;

    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      try {
        return await operation();
      } on SlangCloudException catch (e) {
        lastError = e;

        // Check if this exception is retryable
        if (!config.isRetryableException(e) || attempt == config.maxRetries) {
          rethrow;
        }

        // Calculate exponential backoff delay: 500ms, 1000ms, 2000ms
        final delay = config.retryBaseDelay * (1 << attempt);

        debugPrint(
          'SlangCloud: $operationName failed for $locale (attempt ${attempt + 1}/${config.maxRetries + 1}), '
          'retrying in ${delay.inMilliseconds}ms...',
        );

        await Future.delayed(delay);
      }
    }

    // Should never reach here, but just in case
    throw lastError ?? StateError('Retry loop exited unexpectedly');
  }

  /// Creates the appropriate exception based on HTTP status code.
  SlangCloudException _createExceptionFromStatusCode(
    int statusCode,
    String message, {
    required String? locale,
    String? responseBody,
  }) {
    switch (statusCode) {
      case 401:
        return SlangCloudUnauthorizedException(
          '$message: Unauthorized (401)',
          locale: locale,
          responseBody: responseBody,
        );
      case 403:
        return SlangCloudForbiddenException(
          '$message: Forbidden (403)',
          locale: locale,
          responseBody: responseBody,
        );
      case 404:
        return SlangCloudNotFoundException(
          '$message: Language not found (404)',
          locale: locale,
          responseBody: responseBody,
        );
      default:
        if (statusCode >= 500) {
          return SlangCloudServerException(
            '$message: Server error ($statusCode)',
            statusCode: statusCode,
            locale: locale,
            responseBody: responseBody,
          );
        }
        return SlangCloudInvalidResponseException(
          '$message: Unexpected status code ($statusCode)',
          locale: locale,
          responseBody: responseBody,
        );
    }
  }
}
