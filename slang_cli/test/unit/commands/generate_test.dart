import 'dart:convert';
import 'dart:io';

import 'package:slang/src/builder/builder/slang_file_collection_builder.dart';
import 'package:slang/src/builder/model/enums.dart';
import 'package:slang/src/builder/model/raw_config.dart';
import 'package:slang/src/builder/model/slang_file_collection.dart';
import 'package:slang_cli/src/commands/generate.dart';
import 'package:test/test.dart';

import '../../util/setup.dart';

void main() {
  setUpAll(runSetupAll);

  group('generateTranslations', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_generate_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<SlangFileCollection> createFileCollection({
      required Map<String, dynamic> enTranslations,
      Map<String, dynamic>? deTranslations,
      FileType fileType = FileType.json,
    }) async {
      final inputDir = Directory('${tempDir.path}/i18n');
      await inputDir.create(recursive: true);

      final enFile = File('${inputDir.path}/en.i18n.${fileType.name}');
      if (fileType == FileType.json) {
        await enFile.writeAsString(_prettyJson(enTranslations));
      } else {
        await enFile.writeAsString(_yamlEncode(enTranslations));
      }

      final files = <PlainTranslationFile>[
        PlainTranslationFile(
          path: enFile.path,
          read: () => enFile.readAsString(),
        ),
      ];

      if (deTranslations != null) {
        final deFile = File('${inputDir.path}/de.i18n.${fileType.name}');
        if (fileType == FileType.json) {
          await deFile.writeAsString(_prettyJson(deTranslations));
        } else {
          await deFile.writeAsString(_yamlEncode(deTranslations));
        }
        files.add(PlainTranslationFile(
          path: deFile.path,
          read: () => deFile.readAsString(),
        ));
      }

      return SlangFileCollectionBuilder.fromFileModel(
        config: RawConfig.defaultConfig.copyWith(
          inputFilePattern: '.i18n.${fileType.name}',
          flutterIntegration: false,
        ),
        files: files,
      );
    }

    test('should generate Dart code from JSON translations', () async {
      final fileCollection = await createFileCollection(
        enTranslations: {
          'hello': 'Hello',
          'world': 'World',
        },
      );

      // Should complete without throwing
      await generateTranslations(fileCollection: fileCollection);

      // Output is generated to a path determined by the file collection config
      // The main output file path is determined by determineOutputPath()
    });

    test('should handle empty translation files', () async {
      final fileCollection = await createFileCollection(
        enTranslations: {},
      );

      // Should not throw
      await generateTranslations(fileCollection: fileCollection);
    });

    test('should generate with multiple locales', () async {
      final fileCollection = await createFileCollection(
        enTranslations: {
          'hello': 'Hello',
        },
        deTranslations: {
          'hello': 'Hallo',
        },
      );

      // Should complete without throwing for multiple locales
      await generateTranslations(fileCollection: fileCollection);
    });

    test('should handle nested translation objects', () async {
      final fileCollection = await createFileCollection(
        enTranslations: {
          'section': {
            'title': 'Title',
            'description': 'Description',
          },
        },
      );

      // Should complete without throwing for nested objects
      await generateTranslations(fileCollection: fileCollection);
    });

    test('should handle list translations', () async {
      final fileCollection = await createFileCollection(
        enTranslations: {
          'items': ['First', 'Second', 'Third'],
        },
      );

      // Should complete without throwing for list translations
      await generateTranslations(fileCollection: fileCollection);
    });

    test('should generate from YAML files', () async {
      final fileCollection = await createFileCollection(
        enTranslations: {
          'hello': 'Hello',
          'world': 'World',
        },
        fileType: FileType.yaml,
      );

      // Should complete without throwing for YAML files
      await generateTranslations(fileCollection: fileCollection);
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
        buffer.writeln('$spaces  - $item');
      }
    } else {
      buffer.writeln('$spaces${entry.key}: ${entry.value}');
    }
  }
}
