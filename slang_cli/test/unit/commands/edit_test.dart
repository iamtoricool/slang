import 'dart:convert';
import 'dart:io';

import 'package:slang/src/builder/builder/slang_file_collection_builder.dart';
import 'package:slang/src/builder/model/enums.dart';
import 'package:slang/src/builder/model/raw_config.dart';
import 'package:slang/src/builder/model/slang_file_collection.dart';
import 'package:slang_cli/src/commands/edit.dart';
import 'package:test/test.dart';

import '../../util/setup.dart';

void main() {
  setUpAll(runSetupAll);

  group('runEdit', () {
    late Directory tempDir;
    late SlangFileCollection fileCollection;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_edit_test_');
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

      // Create slang.yaml config
      final configFile = File('${tempDir.path}/slang.yaml');
      await configFile.writeAsString('''
base_locale: en
input_directory: i18n
input_file_pattern: .i18n.{fileType}
'''.replaceAll('{fileType}', fileType.name));

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

      // Build file collection
      fileCollection = SlangFileCollectionBuilder.fromFileModel(
        config: RawConfig.defaultConfig.copyWith(
          inputFilePattern: '.i18n.${fileType.name}',
        ),
        files: [
          PlainTranslationFile(
            path: enFile.path,
            read: () => enFile.readAsString(),
          ),
          if (deTranslations != null)
            PlainTranslationFile(
              path: '${inputDir.path}/de.i18n.${fileType.name}',
              read: () => File('${inputDir.path}/de.i18n.${fileType.name}').readAsString(),
            ),
        ],
      );
    }

    group('add operation', () {
      test('should add translation to all locales', () async {
        await createTranslationFiles(
          enTranslations: {'hello': 'Hello'},
          deTranslations: {'hello': 'Hallo'},
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['add', 'newKey', 'New Value'],
        );

        final enContent = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
        final enMap = _parseJson(enContent);
        expect(enMap['newKey'], 'New Value');
        expect(enMap['hello'], 'Hello'); // Original preserved

        final deContent = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
        final deMap = _parseJson(deContent);
        expect(deMap['newKey'], 'New Value');
        expect(deMap['hello'], 'Hallo'); // Original preserved
      });

      test('should add translation to specific locale only', () async {
        await createTranslationFiles(
          enTranslations: {'hello': 'Hello'},
          deTranslations: {'hello': 'Hallo'},
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['add', 'en', 'newKey', 'English Only'],
        );

        final enContent = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
        final enMap = _parseJson(enContent);
        expect(enMap['newKey'], 'English Only');

        final deContent = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
        final deMap = _parseJson(deContent);
        expect(deMap.containsKey('newKey'), isFalse); // Not added to DE
      });

      test('should add nested translation', () async {
        await createTranslationFiles(
          enTranslations: {'section': {'title': 'Title'}},
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['add', 'section.subtitle', 'Subtitle'],
        );

        final content = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
        final map = _parseJson(content);
        expect(map['section']['title'], 'Title');
        expect(map['section']['subtitle'], 'Subtitle');
      });

      test('should throw when path is missing', () async {
        await createTranslationFiles(enTranslations: {});

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: ['add'],
          ),
          throwsA(contains('Missing path')),
        );
      });

      test('should throw when value is missing', () async {
        await createTranslationFiles(enTranslations: {});

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: ['add', 'someKey'],
          ),
          throwsA(contains('Missing value')),
        );
      });
    });

    group('delete operation', () {
      test('should delete translation from all locales', () async {
        await createTranslationFiles(
          enTranslations: {'keep': 'Keep', 'remove': 'Remove'},
          deTranslations: {'keep': 'Behalten', 'remove': 'Entfernen'},
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['delete', 'remove'],
        );

        final enContent = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
        final enMap = _parseJson(enContent);
        expect(enMap['keep'], 'Keep');
        expect(enMap.containsKey('remove'), isFalse);

        final deContent = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
        final deMap = _parseJson(deContent);
        expect(deMap['keep'], 'Behalten');
        expect(deMap.containsKey('remove'), isFalse);
      });

      test('should delete nested translation', () async {
        await createTranslationFiles(
          enTranslations: {
            'section': {'keep': 'Keep', 'remove': 'Remove'}
          },
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['delete', 'section.remove'],
        );

        final content = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
        final map = _parseJson(content);
        expect(map['section']['keep'], 'Keep');
        expect(map['section'].containsKey('remove'), isFalse);
      });

      test('should throw when path is missing', () async {
        await createTranslationFiles(enTranslations: {});

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: ['delete'],
          ),
          throwsA(contains('Missing path')),
        );
      });
    });

    group('move operation', () {
      test('should move translation to new path', () async {
        await createTranslationFiles(
          enTranslations: {'oldKey': 'Value'},
          deTranslations: {'oldKey': 'Wert'},
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['move', 'oldKey', 'newKey'],
        );

        final enContent = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
        final enMap = _parseJson(enContent);
        expect(enMap.containsKey('oldKey'), isFalse);
        expect(enMap['newKey'], 'Value');

        final deContent = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
        final deMap = _parseJson(deContent);
        expect(deMap.containsKey('oldKey'), isFalse);
        expect(deMap['newKey'], 'Wert');
      });

      test('should rename nested translation', () async {
        await createTranslationFiles(
          enTranslations: {
            'section': {'oldName': 'Value'}
          },
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['move', 'section.oldName', 'section.newName'],
        );

        final content = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
        final map = _parseJson(content);
        expect(map['section'].containsKey('oldName'), isFalse);
        expect(map['section']['newName'], 'Value');
      });

      test('should throw when destination is missing', () async {
        await createTranslationFiles(enTranslations: {'key': 'Value'});

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: ['move', 'key'],
          ),
          throwsA(contains('Missing destination')),
        );
      });
    });

    group('copy operation', () {
      test('should copy translation to new path', () async {
        await createTranslationFiles(
          enTranslations: {'source': 'Value'},
          deTranslations: {'source': 'Wert'},
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['copy', 'source', 'destination'],
        );

        final enContent = await File('${tempDir.path}/i18n/en.i18n.json').readAsString();
        final enMap = _parseJson(enContent);
        expect(enMap['source'], 'Value'); // Original preserved
        expect(enMap['destination'], 'Value'); // Copy created

        final deContent = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
        final deMap = _parseJson(deContent);
        expect(deMap['source'], 'Wert');
        expect(deMap['destination'], 'Wert');
      });

      test('should throw when destination is missing', () async {
        await createTranslationFiles(enTranslations: {'key': 'Value'});

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: ['copy', 'key'],
          ),
          throwsA(contains('Missing destination')),
        );
      });
    });

    group('outdated operation', () {
      test('should mark translation as outdated', () async {
        await createTranslationFiles(
          enTranslations: {'key': 'Value'},
          deTranslations: {'key': 'Wert'},
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['outdated', 'key'],
        );

        final content = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
        final map = _parseJson(content);
        expect(map.containsKey('key(OUTDATED)'), isTrue);
        expect(map['key(OUTDATED)'], 'Wert');
      });

      test('should mark nested translation as outdated', () async {
        await createTranslationFiles(
          enTranslations: {'section': {'title': 'Title'}},
          deTranslations: {'section': {'title': 'Titel'}},
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['outdated', 'section.title'],
        );

        final content = await File('${tempDir.path}/i18n/de.i18n.json').readAsString();
        final map = _parseJson(content);
        expect(map['section'].containsKey('title(OUTDATED)'), isTrue);
      });
    });

    group('error handling', () {
      test('should throw for unsupported file type', () async {
        await createTranslationFiles(
          enTranslations: {'key': 'Value'},
          fileType: FileType.csv,
        );

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: ['add', 'key', 'value'],
          ),
          throwsA(contains('not supported')),
        );
      });

      test('should throw for invalid operation', () async {
        await createTranslationFiles(enTranslations: {});

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: ['invalidOp'],
          ),
          throwsA(contains('Invalid operation')),
        );
      });

      test('should throw when operation is missing', () async {
        await createTranslationFiles(enTranslations: {});

        expect(
          () => runEdit(
            fileCollection: fileCollection,
            arguments: [],
          ),
          throwsA(contains('Missing operation')),
        );
      });
    });

    group('YAML support', () {
      test('should add translation to YAML file', () async {
        await createTranslationFiles(
          enTranslations: {'hello': 'Hello'},
          fileType: FileType.yaml,
        );

        await runEdit(
          fileCollection: fileCollection,
          arguments: ['add', 'newKey', 'New Value'],
        );

        final content = await File('${tempDir.path}/i18n/en.i18n.yaml').readAsString();
        expect(content.contains('newKey: New Value'), isTrue);
        expect(content.contains('hello: Hello'), isTrue);
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
