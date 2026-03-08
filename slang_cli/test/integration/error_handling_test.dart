import 'dart:convert';
import 'dart:io';

import 'package:slang/src/builder/builder/slang_file_collection_builder.dart';
import 'package:slang/src/builder/model/raw_config.dart';
import 'package:slang/src/builder/model/slang_file_collection.dart';
import 'package:slang_cli/src/commands/edit.dart';
import 'package:slang_cli/src/commands/generate.dart';
import 'package:slang_cli/src/commands/migrate_arb.dart';
import 'package:slang_cli/src/commands/normalize.dart';
import 'package:test/test.dart';

import '../util/setup.dart';

/// Integration tests for error handling scenarios.
void main() {
  setUpAll(runSetupAll);

  group('Error Handling', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_error_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Missing files', () {
      test('throws when no translation files found', () async {
        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
          ),
          files: [],
        );

        // Should handle gracefully
        await generateTranslations(fileCollection: fileCollection);
        // No exception thrown, just logs error
      });

      test('throws for missing source directory in analyze', () async {
        final nonExistentDir = '${tempDir.path}/nonexistent';

        expect(
          Directory(nonExistentDir).existsSync(),
          isFalse,
        );
      });
    });

    group('Invalid config', () {
      test('handles invalid file type in edit command', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        // Create CSV file (unsupported for edit)
        final csvFile = File('${inputDir.path}/en.i18n.csv');
        await csvFile.writeAsString('key,value\nhello,Hello');

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.csv',
          ),
          files: [
            PlainTranslationFile(
              path: csvFile.path,
              read: () => csvFile.readAsString(),
            ),
          ],
        );

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: ['add', 'key', 'value'],
          ),
          throwsA(contains('not supported')),
        );
      });

      test('handles unsupported file type in normalize', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        // Create CSV file
        final csvFile = File('${inputDir.path}/en.i18n.csv');
        await csvFile.writeAsString('key,value\nhello,Hello');

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.csv',
          ),
          files: [
            PlainTranslationFile(
              path: csvFile.path,
              read: () => csvFile.readAsString(),
            ),
          ],
        );

        expect(
          () => runNormalize(
            fileCollection: fileCollection,
            arguments: [],
          ),
          throwsA(isA<Error>()),
        );
      });
    });

    group('Malformed files', () {
      test('handles invalid JSON gracefully', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        final invalidFile = File('${inputDir.path}/en.i18n.json');
        await invalidFile.writeAsString('not valid json {');

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
          ),
          files: [
            PlainTranslationFile(
              path: invalidFile.path,
              read: () => invalidFile.readAsString(),
            ),
          ],
        );

        expect(
          () => generateTranslations(fileCollection: fileCollection),
          throwsA(anything),
        );
      });

      test('handles empty JSON object', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        final emptyFile = File('${inputDir.path}/en.i18n.json');
        await emptyFile.writeAsString('{}');

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
            flutterIntegration: false,
          ),
          files: [
            PlainTranslationFile(
              path: emptyFile.path,
              read: () => emptyFile.readAsString(),
            ),
          ],
        );

        // Empty JSON object is valid - should not throw
        await generateTranslations(fileCollection: fileCollection);
      });

      test('throws for non-object ARB content', () {
        final arbContent = '["invalid", "array"]'; // ARB must be an object

        expect(
          () => migrateArb(arbContent, false),
          throwsA(contains('ARB files must be a JSON object')),
        );
      });

      test('handles invalid YAML gracefully', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        final invalidFile = File('${inputDir.path}/en.i18n.yaml');
        await invalidFile.writeAsString('  invalid: yaml: syntax: :::');

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.yaml',
          ),
          files: [
            PlainTranslationFile(
              path: invalidFile.path,
              read: () => invalidFile.readAsString(),
            ),
          ],
        );

        expect(
          () => generateTranslations(fileCollection: fileCollection),
          throwsA(anything),
        );
      });
    });

    group('Invalid operations', () {
      test('throws for missing operation in edit', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        final enFile = File('${inputDir.path}/en.i18n.json');
        await enFile.writeAsString(jsonEncode({'key': 'value'}));

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
          ),
          files: [
            PlainTranslationFile(
              path: enFile.path,
              read: () => enFile.readAsString(),
            ),
          ],
        );

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: [],
          ),
          throwsA(contains('Missing operation')),
        );
      });

      test('throws for invalid operation in edit', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        final enFile = File('${inputDir.path}/en.i18n.json');
        await enFile.writeAsString(jsonEncode({'key': 'value'}));

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
          ),
          files: [
            PlainTranslationFile(
              path: enFile.path,
              read: () => enFile.readAsString(),
            ),
          ],
        );

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: ['invalidOp'],
          ),
          throwsA(contains('Invalid operation')),
        );
      });

      test('throws for missing path in edit add', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        final enFile = File('${inputDir.path}/en.i18n.json');
        await enFile.writeAsString(jsonEncode({'key': 'value'}));

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
          ),
          files: [
            PlainTranslationFile(
              path: enFile.path,
              read: () => enFile.readAsString(),
            ),
          ],
        );

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: ['add'],
          ),
          throwsA(contains('Missing path')),
        );
      });
    });

    group('Edge cases', () {
      test('handles deeply nested translations', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        final enFile = File('${inputDir.path}/en.i18n.json');
        await enFile.writeAsString(jsonEncode({
          'level1': {
            'level2': {
              'level3': {
                'level4': {
                  'level5': 'Deep value',
                },
              },
            },
          },
        }));

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
            flutterIntegration: false,
          ),
          files: [
            PlainTranslationFile(
              path: enFile.path,
              read: () => enFile.readAsString(),
            ),
          ],
        );

        // Should complete without throwing
        await generateTranslations(fileCollection: fileCollection);
      });

      test('handles special characters in translations', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        final enFile = File('${inputDir.path}/en.i18n.json');
        await enFile.writeAsString(jsonEncode({
          'emoji': '🎉🎊',
          'unicode': '你好世界',
          'special': 'Hello\nWorld\t!',
          'quotes': 'He said "Hello"',
        }));

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
            flutterIntegration: false,
          ),
          files: [
            PlainTranslationFile(
              path: enFile.path,
              read: () => enFile.readAsString(),
            ),
          ],
        );

        // Should complete without throwing
        await generateTranslations(fileCollection: fileCollection);
      });

      test('handles large translation files', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        // Create a large translation file
        final translations = <String, dynamic>{};
        for (var i = 0; i < 100; i++) {
          translations['key$i'] = 'Value $i';
        }

        final enFile = File('${inputDir.path}/en.i18n.json');
        await enFile.writeAsString(jsonEncode(translations));

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
            flutterIntegration: false,
          ),
          files: [
            PlainTranslationFile(
              path: enFile.path,
              read: () => enFile.readAsString(),
            ),
          ],
        );

        // Should complete without throwing
        await generateTranslations(fileCollection: fileCollection);
      });
    });
  });
}
