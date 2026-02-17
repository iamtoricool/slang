import 'package:flutter_test/flutter_test.dart';
import 'package:slang_cloud/slang_cloud.dart';
import 'package:example/main.dart';
import 'package:example/i18n/strings.g.dart';

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

    // Initial state (Local translation)
    expect(find.text('Slang Cloud Demo (Local)'), findsOneWidget);

    // Wait for async update (Mock client delay simulation if needed, or pumpAndSettle)
    await tester.pump(); // Trigger build
    await tester.pump(
      const Duration(milliseconds: 100),
    ); // Allow future to complete

    // Verify updated state (Cloud translation)
    // Note: Since DemoMockClient returns immediately, pump() might be enough.
    // However, if overrideTranslationsFromMap is async, we need to wait.
    expect(find.text('Slang Cloud Demo (UPDATED)'), findsOneWidget);
  });
}
