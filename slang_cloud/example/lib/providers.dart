import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:example/models/language_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:slang_cloud/slang_cloud.dart';

import 'i18n/strings.g.dart';

/// Creates a Laravel-compatible cloud client
Future<SlangCloudClient> createLaravelClient(
  SlangCloudStorage storage,
) async {
  return SlangCloudClient.create(
    baseUrl: 'http://10.0.2.2:8000/api',
    hashHeader: 'X-Translation-Hash',
    isFlatMap: false,
    storage: storage,
    applyTranslations: (locale, translations, isFlatMap) async {
      await LocaleSettings.instance.overrideTranslationsFromMap(
        locale: AppLocaleUtils.parse(locale),
        map: translations,
        isFlatMap: isFlatMap,
      );
    },
    setFallback: () async {
      await LocaleSettings.setLocale(LocaleSettings.currentLocale);
    },
  );
}

/// Creates a Hono-compatible cloud client
Future<SlangCloudClient> createHonoClient(
  SlangCloudStorage storage,
) async {
  return SlangCloudClient.create(
    baseUrl: 'http://10.0.2.2:3000',
    hashHeader: 'X-Translation-Hash',
    isFlatMap: false,
    storage: storage,
    applyTranslations: (locale, translations, isFlatMap) async {
      await LocaleSettings.instance.overrideTranslationsFromMap(
        locale: AppLocaleUtils.parse(locale),
        map: translations,
        isFlatMap: isFlatMap,
      );
    },
    setFallback: () async {
      await LocaleSettings.setLocale(LocaleSettings.currentLocale);
    },
  );
}

/// Creates a client for static JSON files (e.g., served by web server)
///
/// This is useful when translations are served as static files from a CDN
/// or web server directory (e.g., Laravel's public/translations/).
/// Hashes are computed from file content since static files don't have
/// custom hash headers.
///
/// Note: The app must add `crypto` package as a dependency to use this.
Future<SlangCloudClient> createStaticFileClient(
  SlangCloudStorage storage,
) async {
  return SlangCloudClient.create(
    baseUrl: 'http://10.0.2.2:8000',
    pathTemplate: '/public/translations/{locale}.json',
    hashHeader: 'X-Translation-Hash',
    isFlatMap: false,
    storage: storage,
    // Compute hash from content for static files (no hash header)
    computeHash: (body) => md5.convert(utf8.encode(body)).toString(),
    applyTranslations: (locale, translations, isFlatMap) async {
      await LocaleSettings.instance.overrideTranslationsFromMap(
        locale: AppLocaleUtils.parse(locale),
        map: translations,
        isFlatMap: isFlatMap,
      );
    },
    setFallback: () async {
      await LocaleSettings.setLocale(LocaleSettings.currentLocale);
    },
  );
}

/// Fetches languages from Laravel backend
Future<List<LanguageModel>> fetchLaravelLanguages() async {
  final response = await http.get(Uri.parse('http://10.0.2.2:8000/api/languages'));

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => LanguageModel.fromJson(e)).toList();
  } else {
    throw Exception('Failed to load languages: ${response.statusCode}');
  }
}

/// Fetches languages from Hono backend
Future<List<LanguageModel>> fetchHonoLanguages() async {
  final response = await http.get(Uri.parse('http://10.0.2.2:3000/languages'));

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => LanguageModel.fromJson(e)).toList();
  } else {
    throw Exception('Failed to load languages: ${response.statusCode}');
  }
}

/// Provider for the language list
final languageListProvider = FutureProvider<List<LanguageModel>>((ref) async {
  // This will be overridden in main.dart
  throw UnimplementedError('Override this provider with the appropriate language fetcher');
});
