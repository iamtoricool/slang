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
        // 1. Get Languages (GET /languages)
        if (request.method == 'GET' && request.url.path == '/languages') {
          return http.Response(
            jsonEncode([
              {'code': 'en', 'name': 'English', 'nativeName': 'English'},
              {'code': 'de', 'name': 'German', 'nativeName': 'Deutsch'},
            ]),
            200,
          );
        }

        // 2. Check Version (HEAD /translations/en)
        if (request.method == 'HEAD' &&
            request.url.path.contains('/translations/en')) {
          print('[MockClient] Checking for updates...');
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

        // 3. Fetch Translation (GET /translations/en)
        if (request.method == 'GET' &&
            request.url.path.contains('/translations/en')) {
          print('[MockClient] Fetching new translations...');
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

    await tester.pumpWidget(
      CloudTranslationProvider(
        config: SlangCloudConfig(baseUrl: 'https://fake-api.com'),
        client: DemoMockClient(),
        overrideCallback:
            ({required locale, required isFlatMap, required map}) async {
              final appLocale = AppLocaleUtils.parse(locale);
              await LocaleSettings.instance.overrideTranslationsFromMap(
                locale: appLocale,
                isFlatMap: isFlatMap,
                map: map,
              );
            },
        child: TranslationProvider(child: const MainApp()),
      ),
    );

    // Initial state (Local translation)
    expect(find.text('Slang Cloud Demo (Local)'), findsOneWidget);

    // Wait for async update (Mock client delay simulation if needed, or pumpAndSettle)
    await tester.pump(); // Trigger build
    // The mock client uses Durations.extralong4 (which is 1s). We wait a bit longer to be safe.
    await tester.pump(const Duration(seconds: 2));

    // Verify updated state (Cloud translation)
    // Note: Since DemoMockClient returns immediately, pump() might be enough.
    // However, if overrideTranslationsFromMap is async, we need to wait.
    expect(find.text('Slang Cloud Demo (UPDATED)'), findsOneWidget);
  });
}
