import 'dart:async';
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

        await SlangCloudClient.create(
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

      group('stale response handling', () {
        test('ignores response when locale changed during download', () async {
          final completers = <String, Completer<http.Response>>{
            'de': Completer(),
            'fr': Completer(),
          };

          final mockClient = MockClient((request) async {
            final locale = request.url.pathSegments.last;
            return completers[locale]!.future;
          });

          var appliedLocales = <String>[];
          final client = await SlangCloudClient.create(
            baseUrl: 'https://api.example.com',
            applyTranslations: (locale, map, isFlatMap) async {
              appliedLocales.add(locale);
            },
            setFallback: () async {},
            storage: storage,
            httpClient: mockClient,
          );

          // Start downloading 'de' but don't complete it
          final deFuture = client.setLanguage('de');

          // Switch to 'fr' before 'de' completes
          final frFuture = client.setLanguage('fr');

          // Complete 'fr' first
          completers['fr']!.complete(http.Response(
            jsonEncode({'hello': 'fr'}),
            200,
            headers: {'x-translation-hash': 'fr-hash'},
          ));
          await frFuture;

          // Complete 'de' response - should be ignored since 'fr' was requested after
          completers['de']!.complete(http.Response(
            jsonEncode({'hello': 'de'}),
            200,
            headers: {'x-translation-hash': 'de-hash'},
          ));
          await deFuture;

          // Only 'fr' should be applied (plus initial create)
          expect(appliedLocales, ['fr']); // create doesn't apply anything when no cache
          expect(client.currentLocale, 'fr');
          expect(client.currentHash, 'fr-hash');
        });

        test('does not throw timeout when locale changed', () async {
          final completers = <String, Completer<http.Response>>{
            'de': Completer(),
            'fr': Completer(),
          };

          final mockClient = MockClient((request) async {
            final locale = request.url.pathSegments.last;
            return completers[locale]!.future;
          });

          var errorThrown = false;
          final client = await SlangCloudClient.create(
            baseUrl: 'https://api.example.com',
            applyTranslations: (locale, map, isFlatMap) async {},
            setFallback: () async {},
            storage: storage,
            httpClient: mockClient,
            timeout: const Duration(milliseconds: 50),
          );

          // Start slow 'de' request that will timeout
          final deFuture = client.setLanguage('de').catchError((e) {
            errorThrown = true;
            return null;
          });

          // Small delay to ensure 'de' starts first
          await Future.delayed(const Duration(milliseconds: 10));

          // Switch to 'fr' before 'de' times out
          final frFuture = client.setLanguage('fr');

          // Complete 'fr' successfully
          completers['fr']!.complete(http.Response(
            jsonEncode({'hello': 'fr'}),
            200,
            headers: {'x-translation-hash': 'fr-hash'},
          ));
          await frFuture;

          // Let 'de' timeout
          await Future.delayed(const Duration(milliseconds: 100));

          // Complete 'de' with timeout
          completers['de']!.completeError(TimeoutException('timeout'));

          try {
            await deFuture;
          } catch (_) {}

          // No error should be thrown for the stale 'de' request
          expect(errorThrown, false);
          expect(client.currentLocale, 'fr');
        });

        test('does not throw format error when locale changed', () async {
          final completers = <String, Completer<http.Response>>{
            'de': Completer(),
            'fr': Completer(),
          };

          final mockClient = MockClient((request) async {
            final locale = request.url.pathSegments.last;
            return completers[locale]!.future;
          });

          var errorThrown = false;
          final client = await SlangCloudClient.create(
            baseUrl: 'https://api.example.com',
            applyTranslations: (locale, map, isFlatMap) async {},
            setFallback: () async {},
            storage: storage,
            httpClient: mockClient,
          );

          // Start 'de' request
          final deFuture = client.setLanguage('de').catchError((e) {
            errorThrown = true;
            return null;
          });

          // Small delay then switch to 'fr'
          await Future.delayed(Duration.zero);
          final frFuture = client.setLanguage('fr');

          // Complete 'fr' successfully
          completers['fr']!.complete(http.Response(
            jsonEncode({'hello': 'fr'}),
            200,
            headers: {'x-translation-hash': 'fr-hash'},
          ));
          await frFuture;

          // Complete 'de' with invalid JSON - should be ignored
          completers['de']!.complete(http.Response('invalid json', 200));

          try {
            await deFuture;
          } catch (_) {}

          // No error should be thrown for the stale 'de' request
          expect(errorThrown, false);
          expect(client.currentLocale, 'fr');
        });

        test('handles multiple rapid locale switches', () async {
          final responses = <String, Completer<http.Response>>{
            'de': Completer(),
            'fr': Completer(),
            'es': Completer(),
          };

          final mockClient = MockClient((request) async {
            final locale = request.url.pathSegments.last;
            return responses[locale]!.future;
          });

          var lastAppliedLocale = '';
          final client = await SlangCloudClient.create(
            baseUrl: 'https://api.example.com',
            applyTranslations: (locale, map, isFlatMap) async {
              lastAppliedLocale = locale;
            },
            setFallback: () async {},
            storage: storage,
            httpClient: mockClient,
          );

          // Start all three requests
          unawaited(client.setLanguage('de'));
          unawaited(client.setLanguage('fr'));
          unawaited(client.setLanguage('es'));

          // Complete in reverse order
          responses['de']!.complete(http.Response(
            jsonEncode({'hello': 'de'}),
            200,
            headers: {'x-translation-hash': 'de-hash'},
          ));

          responses['fr']!.complete(http.Response(
            jsonEncode({'hello': 'fr'}),
            200,
            headers: {'x-translation-hash': 'fr-hash'},
          ));

          responses['es']!.complete(http.Response(
            jsonEncode({'hello': 'es'}),
            200,
            headers: {'x-translation-hash': 'es-hash'},
          ));

          // Wait for all to complete
          await Future.delayed(const Duration(milliseconds: 50));

          // Only 'es' should be applied (the last one)
          expect(lastAppliedLocale, 'es');
          expect(client.currentLocale, 'es');
          expect(client.currentHash, 'es-hash');
        });

        test('still throws error when locale has not changed', () async {
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
