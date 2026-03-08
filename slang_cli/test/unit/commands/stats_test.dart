import 'dart:convert';
import 'dart:io';

import 'package:slang/src/builder/builder/slang_file_collection_builder.dart';
import 'package:slang/src/builder/model/enums.dart';
import 'package:slang/src/builder/model/i18n_locale.dart';
import 'package:slang/src/builder/model/raw_config.dart';
import 'package:slang/src/builder/model/slang_file_collection.dart';
import 'package:slang_cli/src/commands/stats.dart';
import 'package:test/test.dart';

import '../../util/setup.dart';

void main() {
  setUpAll(runSetupAll);

  group('getStats', () {
    late Directory tempDir;
    late SlangFileCollection fileCollection;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_stats_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> createTranslationFiles({
      required Map<String, dynamic> enTranslations,
      Map<String, dynamic>? deTranslations,
      Map<String, dynamic>? frTranslations,
      FileType fileType = FileType.json,
    }) async {
      final inputDir = Directory('${tempDir.path}/i18n');
      await inputDir.create(recursive: true);

      // Create EN translations (base locale)
      final enFile = File('${inputDir.path}/en.i18n.${fileType.name}');
      if (fileType == FileType.json) {
        await enFile.writeAsString(_prettyJson(enTranslations));
      } else {
        await enFile.writeAsString(_yamlEncode(enTranslations));
      }

      // Create DE translations if provided
      if (deTranslations != null) {
        final deFile = File('${inputDir.path}/de.i18n.${fileType.name}');
        if (fileType == FileType.json) {
          await deFile.writeAsString(_prettyJson(deTranslations));
        } else {
          await deFile.writeAsString(_yamlEncode(deTranslations));
        }
      }

      // Create FR translations if provided
      if (frTranslations != null) {
        final frFile = File('${inputDir.path}/fr.i18n.${fileType.name}');
        if (fileType == FileType.json) {
          await frFile.writeAsString(_prettyJson(frTranslations));
        } else {
          await frFile.writeAsString(_yamlEncode(frTranslations));
        }
      }

      final files = <PlainTranslationFile>[
        PlainTranslationFile(
          path: enFile.path,
          read: () => enFile.readAsString(),
        ),
      ];

      if (deTranslations != null) {
        files.add(PlainTranslationFile(
          path: '${inputDir.path}/de.i18n.${fileType.name}',
          read: () => File('${inputDir.path}/de.i18n.${fileType.name}').readAsString(),
        ));
      }

      if (frTranslations != null) {
        files.add(PlainTranslationFile(
          path: '${inputDir.path}/fr.i18n.${fileType.name}',
          read: () => File('${inputDir.path}/fr.i18n.${fileType.name}').readAsString(),
        ));
      }

      fileCollection = SlangFileCollectionBuilder.fromFileModel(
        config: RawConfig.defaultConfig.copyWith(
          inputFilePattern: '.i18n.${fileType.name}',
        ),
        files: files,
      );
    }

    group('basic statistics', () {
      test('should count keys and translations for single locale', () async {
        await createTranslationFiles(
          enTranslations: {
            'hello': 'Hello',
            'world': 'World',
          },
        );

        final result = await getStats(fileCollection: fileCollection);

        expect(result.localeStats.length, 1);
        final enLocale = I18nLocale.fromString('en');
        expect(result.localeStats.keys.first, enLocale);
        expect(result.localeStats[enLocale]!.keyCount, 2);
        expect(result.localeStats[enLocale]!.translationCount, 2);
      });

      test('should count keys for multiple locales', () async {
        await createTranslationFiles(
          enTranslations: {
            'hello': 'Hello',
            'world': 'World',
          },
          deTranslations: {
            'hello': 'Hallo',
            'world': 'Welt',
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');
        final deLocale = I18nLocale.fromString('de');

        expect(result.localeStats.length, 2);
        expect(result.localeStats[enLocale]!.keyCount, 2);
        expect(result.localeStats[deLocale]!.keyCount, 2);
      });

      test('should count intermediate keys correctly', () async {
        await createTranslationFiles(
          enTranslations: {
            'section': {
              'title': 'Title',
              'subtitle': 'Subtitle',
            },
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // section (1) + section.title (1) + section.subtitle (1) = 3 keys
        expect(result.localeStats[enLocale]!.keyCount, 3);
        // Only leaf nodes: section.title + section.subtitle = 2 translations
        expect(result.localeStats[enLocale]!.translationCount, 2);
      });

      test('should handle empty translations', () async {
        await createTranslationFiles(
          enTranslations: {},
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        expect(result.localeStats[enLocale]!.keyCount, 0);
        expect(result.localeStats[enLocale]!.translationCount, 0);
        expect(result.localeStats[enLocale]!.wordCount, 0);
        expect(result.localeStats[enLocale]!.characterCount, 0);
      });
    });

    group('word and character counting', () {
      test('should count words correctly', () async {
        await createTranslationFiles(
          enTranslations: {
            'simple': 'Hello',
            'multiWord': 'Hello World Foo Bar',
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        expect(result.localeStats[enLocale]!.wordCount, 5); // 1 + 4
      });

      test('should count characters excluding special chars', () async {
        await createTranslationFiles(
          enTranslations: {
            'simple': 'Hello',
            'withPunctuation': 'Hello World', // no special chars
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // 'Hello' = 5 chars
        // 'Hello World' = 11 chars
        expect(result.localeStats[enLocale]!.characterCount, 5 + 11);
      });

      test('should handle translations with newlines and spaces', () async {
        await createTranslationFiles(
          enTranslations: {
            'multiline': 'Line 1\nLine 2\nLine 3',
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // Multiline splits by whitespace: 'Line', '1', 'Line', '2', 'Line', '3' = 6 words
        expect(result.localeStats[enLocale]!.wordCount, 6);
      });
    });

    group('nested structures', () {
      test('should handle deeply nested objects', () async {
        await createTranslationFiles(
          enTranslations: {
            'level1': {
              'level2': {
                'level3': {
                  'value': 'Deep Value',
                },
              },
            },
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // level1 + level1.level2 + level1.level2.level3 + level1.level2.level3.value = 4 keys
        expect(result.localeStats[enLocale]!.keyCount, 4);
        // Only leaf: 1 translation
        expect(result.localeStats[enLocale]!.translationCount, 1);
      });

      test('should handle mixed nested structures', () async {
        await createTranslationFiles(
          enTranslations: {
            'simple': 'Value',
            'section': {
              'title': 'Title',
              'content': 'Content here',
            },
            'another': 'Another value',
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // simple + section + section.title + section.content + another = 5 keys
        expect(result.localeStats[enLocale]!.keyCount, 5);
        expect(result.localeStats[enLocale]!.translationCount, 4);
      });
    });

    group('lists', () {
      test('should handle list entries', () async {
        await createTranslationFiles(
          enTranslations: {
            'items': ['First', 'Second', 'Third'],
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // items + items[0] + items[1] + items[2] = 4 keys
        expect(result.localeStats[enLocale]!.keyCount, 4);
        // 3 leaf items
        expect(result.localeStats[enLocale]!.translationCount, 3);
      });

      test('should handle nested lists and objects', () async {
        await createTranslationFiles(
          enTranslations: {
            'data': [
              {'name': 'First'},
              {'name': 'Second'},
            ],
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // data + data[0] + data[0].name + data[1] + data[1].name = 5 keys
        expect(result.localeStats[enLocale]!.keyCount, 5);
        expect(result.localeStats[enLocale]!.translationCount, 2);
      });
    });

    group('pluralization', () {
      test('should handle plural translations', () async {
        await createTranslationFiles(
          enTranslations: {
            'itemCount': {
              'zero': 'No items',
              'one': 'One item',
              'other': '{count} items',
            },
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // itemCount + zero + one + other = 4 keys
        expect(result.localeStats[enLocale]!.keyCount, 4);
        // 3 plural forms (leaves)
        expect(result.localeStats[enLocale]!.translationCount, 3);
      });

      test('should count words in plural forms', () async {
        await createTranslationFiles(
          enTranslations: {
            'itemCount': {
              'zero': 'No items',
              'one': 'One item',
              'two': 'Two items',
              'few': 'Few items here',
              'many': 'Many items',
              'other': '{count} items',
            },
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // All plural forms combined word count
        expect(result.localeStats[enLocale]!.wordCount, greaterThan(0));
      });
    });

    group('context (gender) translations', () {
      test('should handle context translations', () async {
        await createTranslationFiles(
          enTranslations: {
            'welcome': {
              'male': 'Welcome sir',
              'female': 'Welcome madam',
              'other': 'Welcome',
            },
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // welcome + male + female + other = 4 keys
        expect(result.localeStats[enLocale]!.keyCount, 4);
        // 3 context forms (leaves)
        expect(result.localeStats[enLocale]!.translationCount, 3);
      });
    });

    group('global stats', () {
      test('should calculate global totals across locales', () async {
        await createTranslationFiles(
          enTranslations: {
            'hello': 'Hello World',
            'goodbye': 'Goodbye',
          },
          deTranslations: {
            'hello': 'Hallo Welt',
            'goodbye': 'Auf Wiedersehen',
          },
          frTranslations: {
            'hello': 'Bonjour le monde',
            'goodbye': 'Au revoir',
          },
        );

        final result = await getStats(fileCollection: fileCollection);

        expect(result.globalStats.keyCount, 6); // 2 * 3 locales
        expect(result.globalStats.translationCount, 6);
        // All words across all locales
        expect(result.globalStats.wordCount, greaterThan(0));
      });
    });

    group('StatsResult', () {
      test('printResult should not throw', () async {
        await createTranslationFiles(
          enTranslations: {
            'hello': 'Hello',
          },
          deTranslations: {
            'hello': 'Hallo',
          },
        );

        final result = await getStats(fileCollection: fileCollection);

        // Should not throw
        expect(() => result.printResult(), returnsNormally);
      });
    });

    group('YAML support', () {
      test('should calculate stats for YAML files', () async {
        await createTranslationFiles(
          enTranslations: {
            'hello': 'Hello',
            'nested': {
              'value': 'Nested Value',
            },
          },
          deTranslations: {
            'hello': 'Hallo',
            'nested': {
              'value': 'Verschachtelter Wert',
            },
          },
          fileType: FileType.yaml,
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');
        final deLocale = I18nLocale.fromString('de');

        expect(result.localeStats.length, 2);
        expect(result.localeStats[enLocale]!.keyCount, 3); // hello + nested + nested.value
        expect(result.localeStats[deLocale]!.keyCount, 3);
      });
    });

    group('edge cases', () {
      test('should handle single character translations', () async {
        await createTranslationFiles(
          enTranslations: {
            'a': 'A',
            'b': 'B',
            'c': 'C',
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        expect(result.localeStats[enLocale]!.keyCount, 3);
        expect(result.localeStats[enLocale]!.translationCount, 3);
        expect(result.localeStats[enLocale]!.wordCount, 3);
        expect(result.localeStats[enLocale]!.characterCount, 3);
      });

      test('should handle translations with only punctuation', () async {
        await createTranslationFiles(
          enTranslations: {
            'punctuation': ',.?!',
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        // Word count: all punctuation is filtered, so empty strings = 1 word
        expect(result.localeStats[enLocale]!.wordCount, 1);
        // Character count: all punctuation excluded = 0
        expect(result.localeStats[enLocale]!.characterCount, 0);
      });

      test('should handle unicode characters', () async {
        await createTranslationFiles(
          enTranslations: {
            'emoji': '🎉🎊',
            'chinese': '你好世界',
            'arabic': 'مرحبا',
          },
        );

        final result = await getStats(fileCollection: fileCollection);
        final enLocale = I18nLocale.fromString('en');

        expect(result.localeStats[enLocale]!.keyCount, 3);
        expect(result.localeStats[enLocale]!.translationCount, 3);
        // Characters should be counted (excluding only specific punctuation)
        expect(result.localeStats[enLocale]!.characterCount, greaterThan(0));
      });
    });
  });
}

// Helper functions
String _prettyJson(Map<String, dynamic> map) {
  return const JsonEncoder.withIndent('  ').convert(map);
}

String _yamlEncode(Map<String, dynamic> map) {
  final buffer = StringBuffer();
  _writeYamlMap(map, buffer, 0);
  return buffer.toString();
}

void _writeYamlMap(Map<String, dynamic> map, StringBuffer buffer, int indent) {
  final spaces = '  ' * indent;
  for (final entry in map.entries) {
    if (entry.value is Map<String, dynamic>) {
      buffer.writeln('$spaces${entry.key}:');
      _writeYamlMap(entry.value as Map<String, dynamic>, buffer, indent + 1);
    } else if (entry.value is List) {
      buffer.writeln('$spaces${entry.key}:');
      for (final item in entry.value as List) {
        if (item is Map<String, dynamic>) {
          buffer.writeln('$spaces  -');
          _writeYamlMap(item, buffer, indent + 2);
        } else {
          buffer.writeln('$spaces  - $item');
        }
      }
    } else {
      buffer.writeln('$spaces${entry.key}: ${entry.value}');
    }
  }
}
