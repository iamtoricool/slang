import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slang_cloud/slang_cloud.dart';
import 'package:crypto/crypto.dart';

void main() {
  group('CloudTranslationController', () {
    late SlangCloudConfig config;
    late InMemorySlangCloudStorage storage;

    setUp(() {
      config = const SlangCloudConfig(
        baseUrl: 'https://api.example.com',
        maxRetries: 0, // Disable retries for controller tests
      );
      storage = InMemorySlangCloudStorage();
    });

    group('initialization', () {
      test('starts in CloudReady state', () {
        final controller = CloudTranslationController(
          config: config,
          storage: storage,
        );

        expect(controller.value, isA<CloudReady>());
        expect(controller.value.currentLocale, isNull);
        expect(controller.value.lastUpdated, isNull);
        expect(controller.value.currentHash, isNull);
        expect(controller.value.isLoading, isFalse);

        controller.dispose();
      });

      test('uses provided storage', () {
        final customStorage = InMemorySlangCloudStorage();
        final controller = CloudTranslationController(
          config: config,
          storage: customStorage,
        );

        expect(controller.storage, customStorage);

        controller.dispose();
      });

      test('creates in-memory storage when not provided', () {
        final controller = CloudTranslationController(config: config);

        expect(controller.storage, isA<InMemorySlangCloudStorage>());

        controller.dispose();
      });
    });

    group('setLanguage', () {
      test('downloads and caches new translation', () async {
        final translations = {'hello': 'world'};
        final jsonContent = jsonEncode(translations);
        final expectedHash = md5.convert(utf8.encode(jsonContent)).toString();

        final controller = CloudTranslationController(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            if (request.method == 'HEAD') {
              return http.Response('', 200, headers: {
                'x-translation-hash': expectedHash,
              });
            } else if (request.method == 'GET') {
              return http.Response(jsonContent, 200);
            }
            return http.Response('Not Found', 404);
          }),
        );

        // Verify initial state
        expect(controller.value.isLoading, isFalse);

        // Set language
        await controller.setLanguage('en');

        // Verify final state
        expect(controller.value, isA<CloudReady>());
        expect(controller.value.currentLocale, 'en');
        expect(controller.value.currentHash, expectedHash);
        expect(controller.value.lastUpdated, isNotNull);
        expect(controller.value.isLoading, isFalse);

        // Verify cached data
        final cachedTranslation = await storage.getTranslation('en');
        expect(cachedTranslation, jsonContent);

        final cachedVersion = await storage.getVersion('en');
        expect(cachedVersion, expectedHash);

        controller.dispose();
      });

      test('sets loading state during operation', () async {
        final content = '{"test": "data"}';
        final expectedHash = md5.convert(utf8.encode(content)).toString();

        final controller = CloudTranslationController(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            await Future.delayed(Duration(milliseconds: 50));
            if (request.method == 'HEAD') {
              return http.Response('', 200, headers: {
                'x-translation-hash': expectedHash,
              });
            }
            return http.Response(content, 200);
          }),
        );

        // Start async operation
        final future = controller.setLanguage('en');

        // Verify loading state
        expect(controller.value, isA<CloudLoading>());
        expect(controller.value.isLoading, isTrue);

        // Wait for completion
        await future;

        // Verify ready state
        expect(controller.value, isA<CloudReady>());
        expect(controller.value.isLoading, isFalse);

        controller.dispose();
      });

      test('uses cached translation when hash matches', () async {
        final existingTranslation = jsonEncode({'existing': 'data'});
        final existingHash = md5.convert(utf8.encode(existingTranslation)).toString();

        await storage.setTranslation('en', existingTranslation);
        await storage.setVersion('en', existingHash);

        var requestCount = 0;
        final controller = CloudTranslationController(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            requestCount++;
            if (request.method == 'HEAD') {
              return http.Response('', 200, headers: {
                'x-translation-hash': existingHash,
              });
            }
            return http.Response('{"new": "data"}', 200);
          }),
        );

        await controller.setLanguage('en');

        // Should only make HEAD request, not GET
        expect(requestCount, 1);
        expect(controller.value.currentLocale, 'en');
        expect(controller.value.currentHash, existingHash);

        // Verify translation wasn't overwritten
        final cachedTranslation = await storage.getTranslation('en');
        expect(cachedTranslation, existingTranslation);

        controller.dispose();
      });

      test('throws SlangCloudHashMismatchException on hash mismatch', () async {
        final content = '{"test": "data"}';
        final actualHash = md5.convert(utf8.encode(content)).toString();

        final controller = CloudTranslationController(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            if (request.method == 'HEAD') {
              return http.Response('', 200, headers: {
                'x-translation-hash': 'wrong_hash',
              });
            }
            return http.Response(content, 200);
          }),
        );

        // Await completion and verify exception
        try {
          await controller.setLanguage('en');
          fail('Should have thrown');
        } on SlangCloudHashMismatchException catch (e) {
          expect(e.expectedHash, 'wrong_hash');
          expect(e.actualHash, actualHash);
          expect(e.locale, 'en');
        }

        // Verify state is restored to ready
        expect(controller.value, isA<CloudReady>());
        expect(controller.value.isLoading, isFalse);

        controller.dispose();
      });

      test('throws SlangCloudException on HTTP errors', () async {
        final controller = CloudTranslationController(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            return http.Response('Not Found', 404);
          }),
        );

        // Await completion and verify exception
        try {
          await controller.setLanguage('en');
          fail('Should have thrown');
        } on SlangCloudException {
          // Expected
        }

        // Verify state is restored
        expect(controller.value, isA<CloudReady>());

        controller.dispose();
      });

      test('preserves previous state on error', () async {
        // First set a language successfully
        final translations = jsonEncode({'hello': 'world'});
        final hash = md5.convert(utf8.encode(translations)).toString();

        final controller = CloudTranslationController(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            if (request.method == 'HEAD') {
              return http.Response('', 200, headers: {
                'x-translation-hash': hash,
              });
            }
            return http.Response(translations, 200);
          }),
        );

        await controller.setLanguage('en');

        final previousLocale = controller.value.currentLocale;
        final previousHash = controller.value.currentHash;
        final previousUpdated = controller.value.lastUpdated;

        controller.dispose();

        // Create new controller with failing client
        final failingController = CloudTranslationController(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            return http.Response('Not Found', 404);
          }),
        );

        // Manually set state to simulate previous success
        failingController.value = CloudReady(
          currentLocale: previousLocale,
          currentHash: previousHash,
          lastUpdated: previousUpdated,
        );

        // Try to set a failing language
        try {
          await failingController.setLanguage('de');
        } catch (_) {}

        // Verify previous state is preserved
        expect(failingController.value.currentLocale, previousLocale);
        expect(failingController.value.currentHash, previousHash);
        expect(failingController.value.lastUpdated, previousUpdated);

        failingController.dispose();
      });

      test('prevents concurrent operations', () async {
        final content = '{"test": "data"}';
        final expectedHash = md5.convert(utf8.encode(content)).toString();

        final controller = CloudTranslationController(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            await Future.delayed(Duration(milliseconds: 100));
            if (request.method == 'HEAD') {
              return http.Response('', 200, headers: {
                'x-translation-hash': expectedHash,
              });
            }
            return http.Response(content, 200);
          }),
        );

        // Start first operation
        final future1 = controller.setLanguage('en');

        // Try to start second operation immediately
        final future2 = controller.setLanguage('de');

        // Second operation should complete immediately without doing anything
        await future2;

        // First operation should still be running
        expect(controller.value, isA<CloudLoading>());

        // Wait for first operation
        await future1;

        // Verify only first language was set
        expect(controller.value.currentLocale, 'en');

        controller.dispose();
      });
    });

    group('getCachedTranslation', () {
      test('returns cached translation', () async {
        await storage.setTranslation('en', '{"test": "data"}');

        final controller = CloudTranslationController(
          config: config,
          storage: storage,
        );

        final result = await controller.getCachedTranslation('en');
        expect(result, '{"test": "data"}');

        controller.dispose();
      });

      test('returns null when no cached translation', () async {
        final controller = CloudTranslationController(
          config: config,
          storage: storage,
        );

        final result = await controller.getCachedTranslation('en');
        expect(result, isNull);

        controller.dispose();
      });
    });

    group('checkForUpdates', () {
      test('silently succeeds when no current locale', () async {
        final controller = CloudTranslationController(
          config: config,
          storage: storage,
        );

        // Should not throw
        await controller.checkForUpdates();

        expect(controller.value, isA<CloudReady>());

        controller.dispose();
      });

      test('checks for updates for current locale', () async {
        final translations = jsonEncode({'hello': 'world'});
        final oldHash = md5.convert(utf8.encode(translations)).toString();

        await storage.setTranslation('en', translations);
        await storage.setVersion('en', oldHash);

        final newTranslations = jsonEncode({'hello': 'updated'});
        final newHash = md5.convert(utf8.encode(newTranslations)).toString();

        final controller = CloudTranslationController(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            if (request.method == 'HEAD') {
              return http.Response('', 200, headers: {
                'x-translation-hash': newHash,
              });
            }
            return http.Response(newTranslations, 200);
          }),
        );

        // Set initial state
        controller.value = CloudReady(
          currentLocale: 'en',
          currentHash: oldHash,
          lastUpdated: DateTime.now(),
        );

        await controller.checkForUpdates();

        expect(controller.value.currentHash, newHash);

        final cachedTranslation = await storage.getTranslation('en');
        expect(cachedTranslation, newTranslations);

        controller.dispose();
      });

      test('silently fails on error', () async {
        await storage.setTranslation('en', '{"test": "data"}');
        await storage.setVersion('en', 'hash');

        final controller = CloudTranslationController(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            return http.Response('Server Error', 500);
          }),
        );

        controller.value = CloudReady(
          currentLocale: 'en',
          currentHash: 'hash',
          lastUpdated: DateTime.now(),
        );

        // Should not throw
        await controller.checkForUpdates();

        // State should remain unchanged
        expect(controller.value.currentLocale, 'en');
        expect(controller.value.currentHash, 'hash');

        controller.dispose();
      });
    });

    group('dispose', () {
      test('disposes internal client', () {
        final controller = CloudTranslationController(
          config: config,
          storage: storage,
        );

        // Should not throw
        controller.dispose();

        // Controller is disposed, but we can't easily test that
        expect(true, isTrue);
      });
    });
  });
}
