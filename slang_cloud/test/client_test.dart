import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slang_cloud/slang_cloud.dart';

void main() {
  group('SlangCloudClient', () {
    late InMemorySlangCloudStorage storage;

    setUp(() {
      storage = InMemorySlangCloudStorage();
    });

    group('create', () {
      test('loads cached translations on initialization', () async {
        final translations = {'hello': 'world'};
        await storage.setCached(CachedTranslations(
          locale: 'en',
          hash: 'hash123',
          translations: translations,
        ));

        String? appliedLocale;
        Map<String, dynamic>? appliedTranslations;

        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {
            appliedLocale = locale;
            appliedTranslations = map;
          },
          setFallback: () async {},
          storage: storage,
        );

        expect(client.currentLocale, 'en');
        expect(client.currentHash, 'hash123');
        expect(appliedLocale, 'en');
        expect(appliedTranslations, translations);
      });

      test('uses fallback when no cache exists', () async {
        var fallbackCalled = false;

        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {
            fallbackCalled = true;
          },
          storage: storage,
        );

        expect(client.currentLocale, isNull);
        expect(client.currentHash, isNull);
        expect(fallbackCalled, true);
      });

      test('uses fallback when cache load fails', () async {
        // Create a storage that throws on getCached
        final failingStorage = _FailingStorage();
        var fallbackCalled = false;

        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {
            fallbackCalled = true;
          },
          storage: failingStorage,
        );

        expect(fallbackCalled, true);
      });
    });

    group('setLanguage', () {
      test('downloads and applies translations', () async {
        final translations = {'hello': 'world'};
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode(translations),
            200,
            headers: {'x-translation-hash': 'server-hash'},
          );
        });

        String? appliedLocale;
        Map<String, dynamic>? appliedTranslations;

        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {
            appliedLocale = locale;
            appliedTranslations = map;
          },
          setFallback: () async {},
          storage: storage,
          httpClient: mockClient,
        );

        await client.setLanguage('de');

        expect(client.currentLocale, 'de');
        expect(client.currentHash, 'server-hash');
        expect(appliedLocale, 'de');
        expect(appliedTranslations, translations);

        // Verify cached
        final cached = await storage.getCached();
        expect(cached?.locale, 'de');
        expect(cached?.hash, 'server-hash');
      });

      test('throws on HTTP error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {},
          storage: storage,
          httpClient: mockClient,
        );

        expect(
          () => client.setLanguage('de'),
          throwsA(isA<SlangCloudException>()),
        );
      });

      test('throws on timeout', () async {
        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {},
          storage: storage,
          timeout: const Duration(milliseconds: 1),
        );

        expect(
          () => client.setLanguage('de'),
          throwsA(isA<SlangCloudException>()),
        );
      });
    });

    group('hasUpdate', () {
      test('returns true when no cache exists', () async {
        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {},
          storage: storage,
        );

        expect(await client.hasUpdate(), true);
      });

      test('returns true when server hash differs', () async {
        await storage.setCached(CachedTranslations(
          locale: 'en',
          hash: 'old-hash',
          translations: {'hello': 'world'},
        ));

        final mockClient = MockClient((request) async {
          return http.Response('', 200, headers: {
            'x-translation-hash': 'new-hash',
          });
        });

        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {},
          storage: storage,
          httpClient: mockClient,
        );

        expect(await client.hasUpdate(), true);
      });

      test('returns false when server hash matches', () async {
        await storage.setCached(CachedTranslations(
          locale: 'en',
          hash: 'same-hash',
          translations: {'hello': 'world'},
        ));

        final mockClient = MockClient((request) async {
          return http.Response('', 200, headers: {
            'x-translation-hash': 'same-hash',
          });
        });

        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {},
          storage: storage,
          httpClient: mockClient,
        );

        expect(await client.hasUpdate(), false);
      });
    });

    group('updateIfAvailable', () {
      test('updates when available', () async {
        await storage.setCached(CachedTranslations(
          locale: 'en',
          hash: 'old-hash',
          translations: {'hello': 'world'},
        ));

        final translations = {'hello': 'updated'};
        final mockClient = MockClient((request) async {
          if (request.method == 'HEAD') {
            return http.Response('', 200, headers: {
              'x-translation-hash': 'new-hash',
            });
          }
          return http.Response(
            jsonEncode(translations),
            200,
            headers: {'x-translation-hash': 'new-hash'},
          );
        });

        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {},
          storage: storage,
          httpClient: mockClient,
        );

        final updated = await client.updateIfAvailable();

        expect(updated, true);
        expect(client.currentHash, 'new-hash');
      });

      test('does not update when not available', () async {
        await storage.setCached(CachedTranslations(
          locale: 'en',
          hash: 'same-hash',
          translations: {'hello': 'world'},
        ));

        final mockClient = MockClient((request) async {
          return http.Response('', 200, headers: {
            'x-translation-hash': 'same-hash',
          });
        });

        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {},
          storage: storage,
          httpClient: mockClient,
        );

        final updated = await client.updateIfAvailable();

        expect(updated, false);
      });

      test('throws when no current locale', () async {
        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {},
          storage: storage,
        );

        expect(
          () => client.updateIfAvailable(),
          throwsA(isA<SlangCloudException>()),
        );
      });
    });

    group('reload', () {
      test('reloads from cache', () async {
        final translations = {'hello': 'world'};
        await storage.setCached(CachedTranslations(
          locale: 'en',
          hash: 'hash123',
          translations: translations,
        ));

        var applyCount = 0;
        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {
            applyCount++;
          },
          setFallback: () async {},
          storage: storage,
        );

        // Called once during create
        expect(applyCount, 1);

        await client.reload();

        // Called again during reload
        expect(applyCount, 2);
      });
    });

    group('clearCache', () {
      test('clears cache and resets state', () async {
        await storage.setCached(CachedTranslations(
          locale: 'en',
          hash: 'hash123',
          translations: {'hello': 'world'},
        ));

        final client = await SlangCloudClient.create(
          baseUrl: 'https://api.example.com',
          applyTranslations: (locale, map, isFlatMap) async {},
          setFallback: () async {},
          storage: storage,
        );

        expect(client.currentLocale, 'en');

        await client.clearCache();

        expect(client.currentLocale, isNull);
        expect(client.currentHash, isNull);
        expect(await storage.getCached(), isNull);
      });
    });
  });

  group('SlangCloudProvider', () {
    testWidgets('provides client to descendants', (WidgetTester tester) async {
      final client = await SlangCloudClient.create(
        baseUrl: 'https://api.example.com',
        applyTranslations: (locale, map, isFlatMap) async {},
        setFallback: () async {},
      );

      SlangCloudClient? retrievedClient;

      await tester.pumpWidget(
        MaterialApp(
          home: SlangCloudProvider(
            client: client,
            child: Builder(
              builder: (context) {
                retrievedClient = SlangCloudProvider.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(retrievedClient, client);
    });

    testWidgets('throws when provider not found', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                () => SlangCloudProvider.of(context),
                throwsA(isA<AssertionError>()),
              );
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('calls onError when provided', (WidgetTester tester) async {
      final client = await SlangCloudClient.create(
        baseUrl: 'https://api.example.com',
        applyTranslations: (locale, map, isFlatMap) async {},
        setFallback: () async {},
      );

      SlangCloudException? capturedError;

      await tester.pumpWidget(
        MaterialApp(
          home: SlangCloudProvider(
            client: client,
            onError: (error) {
              capturedError = error;
            },
            child: Builder(
              builder: (context) {
                // Simulate an error
                SlangCloudProvider.reportError(
                  context,
                  SlangCloudException('Test error'),
                );
                return Container();
              },
            ),
          ),
        ),
      );

      expect(capturedError?.message, 'Test error');
    });
  });
}

/// A storage implementation that always throws on getCached
class _FailingStorage implements SlangCloudStorage {
  @override
  Future<CachedTranslations?> getCached() async {
    throw Exception('Storage error');
  }

  @override
  Future<void> setCached(CachedTranslations cached) async {}

  @override
  Future<void> clear() async {}
}
