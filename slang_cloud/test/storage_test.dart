import 'package:flutter_test/flutter_test.dart';
import 'package:slang_cloud/src/storage.dart';

void main() {
  group('InMemorySlangCloudStorage', () {
    late InMemorySlangCloudStorage storage;

    setUp(() {
      storage = InMemorySlangCloudStorage();
    });

    group('getTranslation', () {
      test('returns null when no translation stored', () async {
        final result = await storage.getTranslation('en');
        expect(result, isNull);
      });

      test('returns stored translation', () async {
        await storage.setTranslation('en', '{"hello": "world"}');

        final result = await storage.getTranslation('en');
        expect(result, '{"hello": "world"}');
      });

      test('returns different translations for different locales', () async {
        await storage.setTranslation('en', '{"hello": "world"}');
        await storage.setTranslation('de', '{"hello": "welt"}');

        final enResult = await storage.getTranslation('en');
        final deResult = await storage.getTranslation('de');

        expect(enResult, '{"hello": "world"}');
        expect(deResult, '{"hello": "welt"}');
      });

      test('returns null for unknown locale', () async {
        await storage.setTranslation('en', '{"hello": "world"}');

        final result = await storage.getTranslation('unknown');
        expect(result, isNull);
      });
    });

    group('setTranslation', () {
      test('stores translation', () async {
        await storage.setTranslation('en', '{"test": "data"}');

        final result = await storage.getTranslation('en');
        expect(result, '{"test": "data"}');
      });

      test('overwrites existing translation', () async {
        await storage.setTranslation('en', '{"version": 1}');
        await storage.setTranslation('en', '{"version": 2}');

        final result = await storage.getTranslation('en');
        expect(result, '{"version": 2}');
      });
    });

    group('getVersion', () {
      test('returns null when no version stored', () async {
        final result = await storage.getVersion('en');
        expect(result, isNull);
      });

      test('returns stored version', () async {
        await storage.setVersion('en', 'abc123');

        final result = await storage.getVersion('en');
        expect(result, 'abc123');
      });

      test('returns different versions for different locales', () async {
        await storage.setVersion('en', 'hash_en');
        await storage.setVersion('de', 'hash_de');

        final enResult = await storage.getVersion('en');
        final deResult = await storage.getVersion('de');

        expect(enResult, 'hash_en');
        expect(deResult, 'hash_de');
      });
    });

    group('setVersion', () {
      test('stores version', () async {
        await storage.setVersion('en', 'abc123');

        final result = await storage.getVersion('en');
        expect(result, 'abc123');
      });

      test('overwrites existing version', () async {
        await storage.setVersion('en', 'hash1');
        await storage.setVersion('en', 'hash2');

        final result = await storage.getVersion('en');
        expect(result, 'hash2');
      });
    });

    group('translations and versions are independent', () {
      test('can store translation without version', () async {
        await storage.setTranslation('en', '{"test": "data"}');

        final translation = await storage.getTranslation('en');
        final version = await storage.getVersion('en');

        expect(translation, '{"test": "data"}');
        expect(version, isNull);
      });

      test('can store version without translation', () async {
        await storage.setVersion('en', 'abc123');

        final translation = await storage.getTranslation('en');
        final version = await storage.getVersion('en');

        expect(translation, isNull);
        expect(version, 'abc123');
      });

      test('clearing translation does not affect version', () async {
        await storage.setTranslation('en', '{"test": "data"}');
        await storage.setVersion('en', 'abc123');

        // Set translation to empty string (simulating clear)
        await storage.setTranslation('en', '');

        final translation = await storage.getTranslation('en');
        final version = await storage.getVersion('en');

        expect(translation, '');
        expect(version, 'abc123');
      });
    });

    group('multiple locales', () {
      test('handles many locales independently', () async {
        final locales = ['en', 'de', 'fr', 'es', 'it'];

        for (var i = 0; i < locales.length; i++) {
          await storage.setTranslation(locales[i], '{"index": $i}');
          await storage.setVersion(locales[i], 'hash_$i');
        }

        for (var i = 0; i < locales.length; i++) {
          final translation = await storage.getTranslation(locales[i]);
          final version = await storage.getVersion(locales[i]);

          expect(translation, '{"index": $i}');
          expect(version, 'hash_$i');
        }
      });
    });
  });
}
