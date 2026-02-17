import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:slang_cloud/src/config.dart';
import 'package:slang_cloud/src/storage.dart';
import 'package:slang_cloud/src/model.dart';

/// Handles communication with the Slang Cloud backend.
class SlangCloudClient {
  final SlangCloudConfig config;
  final SlangCloudStorage storage;
  final http.Client _client;

  SlangCloudClient({
    required this.config,
    required this.storage,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Checks for updates for the given [locale].
  /// Returns the new version hash if an update is available, null otherwise.
  Future<String?> checkForUpdate(String locale) async {
    final url = Uri.parse('${config.baseUrl}${config.translationEndpoint.replaceAll('{locale}', locale)}');
    final method = config.versionCheckViaHead ? 'HEAD' : 'GET';

    try {
      final response = await _client.send(http.Request(method, url)..headers.addAll(config.headers));

      if (response.statusCode == 200) {
        final serverHash = response.headers[config.versionHeader.toLowerCase()];
        if (serverHash == null) {
          // If the header is missing, we assume no update is possible via hash check.
          // Or should we throw? Let's log/print for now and return null.
          debugPrint('Warning: Missing version header ${config.versionHeader} in response from $url');
          return null;
        }

        final localHash = await storage.getVersion(locale);
        if (localHash != serverHash) {
          return serverHash;
        }
      }
    } catch (e) {
      // Network error, ignore update check
      debugPrint('SlangCloud: Failed to check for updates: $e');
    }
    return null;
  }

  /// Fetches the translation JSON for the given [locale].
  Future<String?> fetchTranslation(String locale) async {
    final url = Uri.parse('${config.baseUrl}${config.translationEndpoint.replaceAll('{locale}', locale)}');

    try {
      final response = await _client.get(url, headers: config.headers);
      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('SlangCloud: Failed to fetch translation: $e');
    }
    return null;
  }

  /// Fetches the list of supported languages.
  Future<List<SlangLanguage>> fetchLanguages() async {
    final url = Uri.parse('${config.baseUrl}${config.languagesEndpoint}');
    try {
      final response = await _client.get(url, headers: config.headers);
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        return list.map((e) => SlangLanguage.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('SlangCloud: Failed to fetch languages: $e');
    }
    return [];
  }
}
