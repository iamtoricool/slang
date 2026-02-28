import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slang_cloud/slang_cloud.dart';

void main() {
  group('CloudTranslationProvider', () {
    late CloudTranslationController controller;
    late InMemorySlangCloudStorage storage;

    setUp(() {
      storage = InMemorySlangCloudStorage();
      controller = CloudTranslationController(
        config: const SlangCloudConfig(baseUrl: 'https://api.example.com'),
        storage: storage,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('provides controller to descendants', (WidgetTester tester) async {
      CloudTranslationController? retrievedController;

      await tester.pumpWidget(
        MaterialApp(
          home: CloudTranslationProvider(
            controller: controller,
            onTranslationsReceived: (locale, translations, isFlatMap) async {},
            child: Builder(
              builder: (context) {
                retrievedController = CloudTranslationProvider.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(retrievedController, controller);
    });

    testWidgets('throws when provider not found', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                () => CloudTranslationProvider.of(context),
                throwsA(isA<AssertionError>()),
              );
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('calls onTranslationsReceived when translations ready', (WidgetTester tester) async {
      final translations = {'hello': 'world'};
      final jsonStr = jsonEncode(translations);

      await storage.setTranslation('en', jsonStr);
      await storage.setVersion('en', 'hash123');

      String? receivedLocale;
      Map<String, dynamic>? receivedTranslations;
      bool? receivedIsFlatMap;

      await tester.pumpWidget(
        MaterialApp(
          home: CloudTranslationProvider(
            controller: controller,
            onTranslationsReceived: (locale, translations, isFlatMap) async {
              receivedLocale = locale;
              receivedTranslations = translations;
              receivedIsFlatMap = isFlatMap;
            },
            child: Container(),
          ),
        ),
      );

      // Simulate ready state with translations
      controller.value = const CloudReady(
        currentLocale: 'en',
        currentHash: 'hash123',
      );

      await tester.pump();

      expect(receivedLocale, 'en');
      expect(receivedTranslations, translations);
      expect(receivedIsFlatMap, false);
    });

    testWidgets('does not call callback when locale unchanged', (WidgetTester tester) async {
      final translations = {'hello': 'world'};
      await storage.setTranslation('en', jsonEncode(translations));

      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CloudTranslationProvider(
            controller: controller,
            onTranslationsReceived: (locale, translations, isFlatMap) async {
              callCount++;
            },
            child: Container(),
          ),
        ),
      );

      // First state change
      controller.value = const CloudReady(
        currentLocale: 'en',
        currentHash: 'hash1',
      );
      await tester.pump();

      // Same locale, same hash - should not trigger again
      controller.value = const CloudReady(
        currentLocale: 'en',
        currentHash: 'hash1',
      );
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('calls callback when hash changes for same locale', (WidgetTester tester) async {
      final translations1 = {'hello': 'world'};
      final translations2 = {'hello': 'updated'};

      await storage.setTranslation('en', jsonEncode(translations1));

      var callCount = 0;
      String? lastLocale;

      await tester.pumpWidget(
        MaterialApp(
          home: CloudTranslationProvider(
            controller: controller,
            onTranslationsReceived: (locale, translations, isFlatMap) async {
              callCount++;
              lastLocale = locale;
            },
            child: Container(),
          ),
        ),
      );

      // First download
      controller.value = const CloudReady(
        currentLocale: 'en',
        currentHash: 'hash1',
      );
      await tester.pump();

      // Update translation in storage
      await storage.setTranslation('en', jsonEncode(translations2));

      // Same locale, different hash - should trigger again
      controller.value = const CloudReady(
        currentLocale: 'en',
        currentHash: 'hash2',
      );
      await tester.pump();

      expect(callCount, 2);
      expect(lastLocale, 'en');
    });

    testWidgets('handles error in onTranslationsReceived gracefully', (WidgetTester tester) async {
      final translations = {'hello': 'world'};
      await storage.setTranslation('en', jsonEncode(translations));

      await tester.pumpWidget(
        MaterialApp(
          home: CloudTranslationProvider(
            controller: controller,
            onTranslationsReceived: (locale, translations, isFlatMap) async {
              throw Exception('Callback error');
            },
            child: Container(),
          ),
        ),
      );

      // Should not throw - error is caught internally
      controller.value = const CloudReady(
        currentLocale: 'en',
        currentHash: 'hash1',
      );
      await tester.pump();

      // Widget should still be mounted
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('does not call callback when no locale set', (WidgetTester tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CloudTranslationProvider(
            controller: controller,
            onTranslationsReceived: (locale, translations, isFlatMap) async {
              callCount++;
            },
            child: Container(),
          ),
        ),
      );

      // Ready but no locale
      controller.value = const CloudReady();
      await tester.pump();

      expect(callCount, 0);
    });

    testWidgets('handles missing translation gracefully', (WidgetTester tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CloudTranslationProvider(
            controller: controller,
            onTranslationsReceived: (locale, translations, isFlatMap) async {
              callCount++;
            },
            child: Container(),
          ),
        ),
      );

      // State says we have translations but storage is empty
      controller.value = const CloudReady(
        currentLocale: 'en',
        currentHash: 'hash1',
      );
      await tester.pump();

      // Should not call callback if no translation in storage
      expect(callCount, 0);
    });

    testWidgets('removes listener on dispose', (WidgetTester tester) async {
      final translations = {'hello': 'world'};
      await storage.setTranslation('en', jsonEncode(translations));

      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CloudTranslationProvider(
            controller: controller,
            onTranslationsReceived: (locale, translations, isFlatMap) async {
              callCount++;
            },
            child: Container(),
          ),
        ),
      );

      // Trigger once
      controller.value = const CloudReady(
        currentLocale: 'en',
        currentHash: 'hash1',
      );
      await tester.pump();

      expect(callCount, 1);

      // Dispose by replacing widget
      await tester.pumpWidget(
        MaterialApp(
          home: Container(),
        ),
      );

      // Change state after dispose
      controller.value = const CloudReady(
        currentLocale: 'de',
        currentHash: 'hash2',
      );
      await tester.pump();

      // Should not have been called again
      expect(callCount, 1);
    });

    testWidgets('respects isFlatMap config option', (WidgetTester tester) async {
      final flatController = CloudTranslationController(
        config: const SlangCloudConfig(
          baseUrl: 'https://api.example.com',
          isFlatMap: true,
        ),
        storage: storage,
      );

      final translations = {'main.title': 'Hello'};
      await storage.setTranslation('en', jsonEncode(translations));

      bool? receivedIsFlatMap;

      await tester.pumpWidget(
        MaterialApp(
          home: CloudTranslationProvider(
            controller: flatController,
            onTranslationsReceived: (locale, translations, isFlatMap) async {
              receivedIsFlatMap = isFlatMap;
            },
            child: Container(),
          ),
        ),
      );

      flatController.value = const CloudReady(
        currentLocale: 'en',
        currentHash: 'hash1',
      );
      await tester.pump();

      expect(receivedIsFlatMap, true);

      flatController.dispose();
    });

    testWidgets('handles flat map translations', (WidgetTester tester) async {
      final flatController = CloudTranslationController(
        config: const SlangCloudConfig(
          baseUrl: 'https://api.example.com',
          isFlatMap: true,
        ),
        storage: storage,
      );

      final flatTranslations = {
        'main.title': 'Welcome',
        'main.description': 'Hello World',
        'common.save': 'Save',
      };

      await storage.setTranslation('en', jsonEncode(flatTranslations));

      Map<String, dynamic>? receivedTranslations;

      await tester.pumpWidget(
        MaterialApp(
          home: CloudTranslationProvider(
            controller: flatController,
            onTranslationsReceived: (locale, translations, isFlatMap) async {
              receivedTranslations = translations;
            },
            child: Container(),
          ),
        ),
      );

      flatController.value = const CloudReady(
        currentLocale: 'en',
        currentHash: 'hash1',
      );
      await tester.pump();

      expect(receivedTranslations, flatTranslations);

      flatController.dispose();
    });
  });
}
