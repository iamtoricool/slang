import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:slang_cloud/slang_cloud.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'i18n/strings.g.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  runApp(
    CloudTranslationProvider(
      config: SlangCloudConfig(baseUrl: 'https://fake-api.com'),
      client: DemoMockClient(), // Injects the fake server response
      overrideCallback: (locale, isFlatMap, map) async {
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
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text(context.t.main.title)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(context.t.main.description),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Manually check for updates logic can be added here if exposed via Provider/Context
                  // For this demo, update happens on start.
                  // We could use a key to rebuild the provider to force a re-check.
                },
                child: Text(context.t.main.button),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A Mock Client that simulates the Slang Cloud backend.
class DemoMockClient extends MockClient {
  DemoMockClient()
    : super((request) async {
        // 1. Check Version (HEAD /translations/en)
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

        // 2. Fetch Translation (GET /translations/en)
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
