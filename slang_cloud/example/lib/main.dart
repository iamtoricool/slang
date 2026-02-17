import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:slang_cloud/slang_cloud.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'i18n/strings.g.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  // Determine the base URL based on the platform.
  // Android emulator needs 10.0.2.2 to access the host machine's localhost.
  String baseUrl = 'http://localhost:3000';
  if (!kIsWeb && Platform.isAndroid) {
    baseUrl = 'http://10.0.2.2:3000';
  }

  runApp(
    CloudTranslationProvider(
      config: SlangCloudConfig(baseUrl: baseUrl),
      // client: DemoMockClient(), // Uncomment to use the mock client instead of the real server
      localeStream: LocaleSettings.getLocaleStream(),
      localeGetter: (context) => LocaleSettings
          .currentLocale
          .languageCode, // Add localeGetter for robustness
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
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch cloud state
    final cloudState = CloudTranslationProvider.of(context);

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(context.t.main.title),
          actions: [
            // Status Indicator
            if (cloudState.status == CloudStatus.checking ||
                cloudState.status == CloudStatus.downloading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else if (cloudState.status == CloudStatus.error)
              const Icon(Icons.error, color: Colors.red),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(context.t.main.description),
              const SizedBox(height: 20),

              // Language Switcher Demo
              ElevatedButton(
                onPressed: () {
                  // This triggers the stream, which triggers CloudTranslationProvider to update
                  LocaleSettings.setLocale(AppLocale.en);
                },
                child: const Text("Set Locale to EN (Trigger Update)"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  // Manual trigger via controller
                  CloudTranslationProvider.get(context).checkForUpdates();
                },
                child: const Text("Force Check Updates"),
              ),
              const SizedBox(height: 10),
              const Divider(),
              const Text("Supported Languages (Server):"),
              if (cloudState.supportedLanguages.isEmpty)
                const Text("Fetching...")
              else
                ...cloudState.supportedLanguages.map(
                  (lang) => ListTile(
                    title: Text(lang.name),
                    subtitle: Text(lang.nativeName ?? ''),
                    trailing: Text(lang.code),
                    onTap: () => LocaleSettings.setLocaleRaw(lang.code),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
