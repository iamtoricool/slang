import 'dart:convert';
import 'dart:io';

import 'package:slang/src/builder/builder/slang_file_collection_builder.dart';
import 'package:slang/src/builder/model/enums.dart';
import 'package:slang/src/builder/model/raw_config.dart';
import 'package:slang/src/builder/model/slang_file_collection.dart';
import 'package:slang_cli/src/commands/clean.dart';
import 'package:test/test.dart';

import '../../util/setup.dart';

void main() {
  setUpAll(runSetupAll);

  group('runClean', () {
    late Directory tempDir;
    late SlangFileCollection fileCollection;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_clean_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> createTranslationFilesAndCollection({
      required Map<String, dynamic> enTranslations,
      Map<String, dynamic>? deTranslations,
      FileType fileType = FileType.json,
    }) async {
      final inputDir = Directory('${tempDir.path}/i18n');
      await inputDir.create(recursive: true);

      // Create EN translations
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

    Future<void> createUnusedTranslationsFile({
      required Map<String, dynamic> unusedTranslations,
      FileType fileType = FileType.json,
    }) async {
      final analysisFile = File('${tempDir.path}/_unused_translations_en.${fileType.name}');
      if (fileType == FileType.json) {
        await analysisFile.writeAsString(_prettyJson(unusedTranslations));
      } else {
        await analysisFile.writeAsString(_yamlEncode(unusedTranslations));
      }
    }

    test('should remove unused translations from single locale', () async {
      await createTranslationFilesAndCollection(
        enTranslations: {
          'keep': 'Keep This',
          'remove': 'Remove This',
          'alsoKeep': 'Also Keep',
        },
      );

      await createUnusedTranslationsFile(
        unusedTranslations: {
          'remove': 'Remove This',
        },
      );

      await runClean(
        fileCollection: fileCollection,
        arguments: ['--outdir=${tempDir.path}'],
      );

      final content = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
      final map = _parseJson(content);

      expect(map['keep'], 'Keep This');
      expect(map['alsoKeep'], 'Also Keep');
      expect(map.containsKey('remove'), isFalse);
    });

    test('should remove multiple unused keys', () async {
      await createTranslationFilesAndCollection(
        enTranslations: {
          'used1': 'Used 1',
          'unused1': 'Unused 1',
          'used2': 'Used 2',
          'unused2': 'Unused 2',
        },
      );

      await createUnusedTranslationsFile(
        unusedTranslations: {
          'unused1': 'Unused 1',
          'unused2': 'Unused 2',
        },
      );

      await runClean(
        fileCollection: fileCollection,
        arguments: ['--outdir=${tempDir.path}'],
      );

      final content = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
      final map = _parseJson(content);

      expect(map['used1'], 'Used 1');
      expect(map['used2'], 'Used 2');
      expect(map.containsKey('unused1'), isFalse);
      expect(map.containsKey('unused2'), isFalse);
    });

    test('should remove nested unused keys', () async {
      await createTranslationFilesAndCollection(
        enTranslations: {
          'section': {
            'keep': 'Keep',
            'remove': 'Remove',
            'alsoKeep': 'Also Keep',
          },
        },
      );

      await createUnusedTranslationsFile(
        unusedTranslations: {
          'section': {
            'remove': 'Remove',
          },
        },
      );

      await runClean(
        fileCollection: fileCollection,
        arguments: ['--outdir=${tempDir.path}'],
      );

      final content = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
      final map = _parseJson(content);

      expect(map['section']['keep'], 'Keep');
      expect(map['section']['alsoKeep'], 'Also Keep');
      expect(map['section'].containsKey('remove'), isFalse);
    });

    test('should handle empty unused translations file', () async {
      await createTranslationFilesAndCollection(
        enTranslations: {
          'key1': 'Value 1',
          'key2': 'Value 2',
        },
      );

      await createUnusedTranslationsFile(
        unusedTranslations: {},
      );

      await runClean(
        fileCollection: fileCollection,
        arguments: ['--outdir=${tempDir.path}'],
      );

      final content = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
      final map = _parseJson(content);

      expect(map['key1'], 'Value 1');
      expect(map['key2'], 'Value 2');
    });

    test('should throw when input directory is not specified', () async {
      await createTranslationFilesAndCollection(
        enTranslations: {'key': 'Value'},
      );

      // Create a file collection with a config that doesn't have inputDirectory set
      // The clean command will look for analysis files in inputDirectory
      final testDir = Directory('${tempDir.path}/no_input_dir_test');
      await testDir.create();
      final noInputDirCollection = SlangFileCollectionBuilder.fromFileModel(
        config: RawConfig.defaultConfig,
        files: [],
      );

      expect(
        () => runClean(
          fileCollection: noInputDirCollection,
          arguments: [],
        ),
        throwsA(contains('input_directory')),
      );
    });

    group('YAML support', () {
      test('should remove unused translations from YAML files', () async {
        await createTranslationFilesAndCollection(
          enTranslations: {
            'keep': 'Keep This',
            'remove': 'Remove This',
          },
          fileType: FileType.yaml,
        );

        await createUnusedTranslationsFile(
          unusedTranslations: {
            'remove': 'Remove This',
          },
          fileType: FileType.yaml,
        );

        await runClean(
          fileCollection: fileCollection,
          arguments: ['--outdir=${tempDir.path}'],
        );

        final content = await File('${tempDir.path}/i18n/en.i18n.yaml').readAsString();
        expect(content.contains('keep:'), isTrue);
        expect(content.contains('remove:'), isFalse);
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
