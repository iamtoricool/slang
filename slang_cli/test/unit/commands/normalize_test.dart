import 'dart:convert';
import 'dart:io';

import 'package:slang/src/builder/builder/slang_file_collection_builder.dart';
import 'package:slang/src/builder/model/enums.dart';
import 'package:slang/src/builder/model/raw_config.dart';
import 'package:slang/src/builder/model/slang_file_collection.dart';
import 'package:slang_cli/src/commands/apply.dart';
import 'package:slang_cli/src/commands/normalize.dart';
import 'package:test/test.dart';

import '../../util/setup.dart';

void main() {
  setUpAll(runSetupAll);

  group('runNormalize', () {
    late Directory tempDir;
    late SlangFileCollection fileCollection;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_normalize_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> createTranslationFiles({
      required Map<String, dynamic> enTranslations,
      Map<String, dynamic>? deTranslations,
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

      final files = <PlainTranslationFile>[
        PlainTranslationFile(
          path: enFile.path,
          read: () => enFile.readAsString(),
        ),
        if (deTranslations != null)
          PlainTranslationFile(
            path: '${inputDir.path}/de.i18n.${fileType.name}',
            read: () => File('${inputDir.path}/de.i18n.${fileType.name}').readAsString(),
          ),
      ];

      fileCollection = SlangFileCollectionBuilder.fromFileModel(
        config: RawConfig.defaultConfig.copyWith(
          inputFilePattern: '.i18n.${fileType.name}',
        ),
        files: files,
      );
    }

    test('should normalize keys to match base locale order', () async {
      await createTranslationFiles(
        enTranslations: {
          'a': 'A',
          'b': 'B',
          'c': 'C',
        },
        deTranslations: {
          'c': 'C_DE',
          'a': 'A_DE',
          'b': 'B_DE',
        },
      );

      await runNormalize(
        fileCollection: fileCollection,
        arguments: [],
      );

      final content = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
      final map = _parseJson(content);

      // Keys should be ordered according to base locale (a, b, c)
      expect(map.keys.toList(), ['a', 'b', 'c']);
      expect(map['a'], 'A_DE');
      expect(map['b'], 'B_DE');
      expect(map['c'], 'C_DE');
    });

    test('should reorder existing keys to match base locale order', () async {
      await createTranslationFiles(
        enTranslations: {
          'a': 'A',
          'b': 'B',
          'c': 'C',
        },
        deTranslations: {
          'a': 'A_DE',
          'c': 'C_DE',
        },
      );

      await runNormalize(
        fileCollection: fileCollection,
        arguments: [],
      );

      final content = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
      final map = _parseJson(content);

      // Existing keys should be reordered to match base locale
      expect(map.containsKey('a'), isTrue);
      expect(map.containsKey('c'), isTrue);
      // Key 'b' was never in DE, so it won't be added
      expect(map.containsKey('b'), isFalse);
    });

    test('should normalize specific locale only when --locale is provided', () async {
      await createTranslationFiles(
        enTranslations: {
          'a': 'A',
          'b': 'B',
        },
        deTranslations: {
          'b': 'B_DE',
          'a': 'A_DE',
        },
      );

      await runNormalize(
        fileCollection: fileCollection,
        arguments: ['--locale=de'],
      );

      final content = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
      final map = _parseJson(content);

      expect(map.keys.toList(), ['a', 'b']);
    });

    test('should normalize nested structures', () async {
      await createTranslationFiles(
        enTranslations: {
          'section': {
            'a': 'A',
            'b': 'B',
          },
        },
        deTranslations: {
          'section': {
            'b': 'B_DE',
            'a': 'A_DE',
          },
        },
      );

      await runNormalize(
        fileCollection: fileCollection,
        arguments: [],
      );

      final content = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
      final map = _parseJson(content);

      expect((map['section'] as Map).keys.toList(), ['a', 'b']);
    });

    test('should handle empty secondary locale', () async {
      await createTranslationFiles(
        enTranslations: {
          'a': 'A',
          'b': 'B',
        },
        deTranslations: {},
      );

      await runNormalize(
        fileCollection: fileCollection,
        arguments: [],
      );

      final content = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
      final map = _parseJson(content);

      // Empty locale stays empty (normalize doesn't add keys)
      expect(map.isEmpty, isTrue);
    });

    test('should throw for unsupported file type', () async {
      final inputDir = Directory('${tempDir.path}/i18n');
      await inputDir.create(recursive: true);

      // Create a CSV file (not supported by normalize)
      final csvFile = File('${inputDir.path}/en.i18n.csv');
      await csvFile.writeAsString('key,value\na,A');

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

      // Create a destination file for the test
      final deFile = File('${inputDir.path}/de.i18n.csv');
      await deFile.writeAsString('key,value\nb,B');

      expect(
        () => runNormalize(
          fileCollection: fileCollection,
          arguments: [],
        ),
        throwsA(isA<FileTypeNotSupportedError>()),
      );
    });

    group('YAML support', () {
      test('should normalize YAML files', () async {
        await createTranslationFiles(
          enTranslations: {
            'a': 'A',
            'b': 'B',
          },
          deTranslations: {
            'b': 'B_DE',
            'a': 'A_DE',
          },
          fileType: FileType.yaml,
        );

        await runNormalize(
          fileCollection: fileCollection,
          arguments: [],
        );

        final content = await File('${tempDir.path}/i18n/de.i18n.yaml').readAsString();
        // Check that 'a' comes before 'b' in the file
        final aIndex = content.indexOf('a:');
        final bIndex = content.indexOf('b:');
        expect(aIndex, lessThan(bIndex));
      });
    });
  });
}

// Helper functions
String _prettyJson(Map<String, dynamic> map) {
  return const JsonEncoder.withIndent('  ').convert(map);
}

Map<String, dynamic> _parseJson(String content) {
  return jsonDecode(content) as Map<String, dynamic>;
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
    } else {
      buffer.writeln('$spaces${entry.key}: ${entry.value}');
    }
  }
}
