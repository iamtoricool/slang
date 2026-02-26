import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slang_cloud/slang_cloud.dart';
import 'package:example/main.dart';
import 'package:example/i18n/strings.g.dart';

/// A Mock Client that simulates the Slang Cloud backend.
class DemoMockClient extends MockClient {
  DemoMockClient()
    : super((request) async {
        // 1. Check Version (HEAD /translations/en)
        if (request.method == 'HEAD' &&
            request.url.path.contains('/translations/en')) {
          // Simulating a newer version (hash: v2)
          return Future.delayed(
            Durations.extralong4,
            () => http.Response(
              '',
              200,
              headers: {'x-translation-hash': 'v2_hash_12345'},
            ),
          );
        }

        // 2. Fetch Translation (GET /translations/en)
        if (request.method == 'GET' &&
            request.url.path.contains('/translations/en')) {
          final newTranslations = {
            "main": {
              "title": "Slang Cloud Demo (UPDATED)",
              "description": "This text was fetched from the cloud!",
              "button": "Updated Successfully",
            },
          };
          return Future.delayed(
            Durations.extralong4,
            () => http.Response(jsonEncode(newTranslations), 200),
          );
        }

        return http.Response('Not Found', 404);
      });
}

void main() {
  testWidgets('CloudTranslationProvider updates translations', (
    WidgetTester tester,
  ) async {
    // Initialize slang
    LocaleSettings.useDeviceLocale();

    // Create controller with mock client
    final controller = CloudTranslationController(
      config: SlangCloudConfig(baseUrl: 'https://fake-api.com'),
    );

    // For testing, we need to inject the mock client
    // In real implementation, we'd need a way to inject the client
    // For now, this test demonstrates the API usage

    await tester.pumpWidget(
      CloudTranslationProvider(
        controller: controller,
        onTranslationsReceived: (locale, translations, isFlatMap) async {
          final appLocale = AppLocaleUtils.parse(locale);
          await LocaleSettings.instance.overrideTranslationsFromMap(
            locale: appLocale,
            map: translations,
            isFlatMap: isFlatMap,
          );
        },
        child: TranslationProvider(child: const MainApp()),
      ),
    );

    // Initial state (Local translation)
    expect(find.text('Slang Cloud Demo (Local)'), findsOneWidget);

    // Wait for async update
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Verify updated state (Cloud translation)
    expect(find.text('Slang Cloud Demo (UPDATED)'), findsOneWidget);
  });
}
