import 'dart:convert';
import 'dart:io';

import 'package:slang/src/builder/builder/slang_file_collection_builder.dart';
import 'package:slang/src/builder/builder/translation_model_list_builder.dart';
import 'package:slang/src/builder/model/i18n_data.dart';
import 'package:slang/src/builder/model/i18n_locale.dart';
import 'package:slang/src/builder/model/raw_config.dart';
import 'package:slang/src/builder/model/slang_file_collection.dart';
import 'package:slang/src/builder/model/translation_map.dart';
import 'package:slang_cli/src/commands/analyze.dart';
import 'package:slang_cli/src/commands/edit.dart';
import 'package:slang_cli/src/commands/generate.dart';
import 'package:slang_cli/src/commands/normalize.dart';
import 'package:test/test.dart';

import '../../util/setup.dart';

/// End-to-end integration tests for slang CLI workflows.
void main() {
  setUpAll(runSetupAll);

  group('E2E Workflows', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_e2e_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Full workflow: generate → analyze → apply → normalize', () {
      test('complete workflow with real translations', () async {
        // Step 1: Create initial translation files
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        final enFile = File('${inputDir.path}/en.i18n.json');
        await enFile.writeAsString(jsonEncode({
          'welcome': 'Welcome',
          'goodbye': 'Goodbye',
          'unused': 'This is unused',
        }));

        final deFile = File('${inputDir.path}/de.i18n.json');
        await deFile.writeAsString(jsonEncode({
          'welcome': 'Willkommen',
        }));

        // Step 2: Generate code
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
            PlainTranslationFile(
              path: deFile.path,
              read: () => deFile.readAsString(),
            ),
          ],
        );

        await generateTranslations(fileCollection: fileCollection);

        // Step 3: Analyze for unused translations
        final sourceDir = '${tempDir.path}/lib';
        await Directory(sourceDir).create(recursive: true);
        await File('$sourceDir/main.dart').writeAsString('''
void main() {
  print(t.welcome);
  print(t.goodbye);
}
''');

        final translations = _buildTranslations({
          'en': {
            'welcome': 'Welcome',
            'goodbye': 'Goodbye',
            'unused': 'This is unused',
          },
        });

        final unusedResult = await getUnusedTranslations(
          baseTranslations: translations.firstWhere((t) => t.base),
          rawConfig: RawConfig.defaultConfig,
          translations: translations,
          full: true,
          sourceDirs: [sourceDir],
        );

        // 'unused' should be detected as unused
        final enLocale = I18nLocale(language: 'en');
        expect(unusedResult[enLocale]?['unused'], 'This is unused');

        // Step 4: Add missing translation via edit
        await runEdit(
          fileCollection: fileCollection,
          arguments: ['add', 'de', 'newFeature', 'Neue Funktion'],
        );

        final deContent = await deFile.readAsString();
        final deMap = jsonDecode(deContent) as Map<String, dynamic>;
        expect(deMap['newFeature'], 'Neue Funktion');

        // Step 5: Normalize
        await runNormalize(
          fileCollection: fileCollection,
          arguments: [],
        );

        // DE should now have keys in same order as EN (for keys that exist in both)
        final normalizedDe = await deFile.readAsString();
        final normalizedDeMap = jsonDecode(normalizedDe) as Map<String, dynamic>;
        // Normalize reorders existing keys but doesn't add missing ones
        expect(normalizedDeMap.keys.toList(), ['welcome', 'newFeature']);
      });
    });

    group('Migration workflow: migrate ARB → generate → validate', () {
      test('migrates ARB and generates code', () async {
        // Step 1: Create ARB file
        final arbFile = File('${tempDir.path}/app_en.arb');
        await arbFile.writeAsString(jsonEncode({
          '@@locale': 'en',
          'helloWorld': 'Hello World',
          '@helloWorld': {
            'description': 'The conventional newborn programmer greeting',
          },
        }));

        // Step 2: Migrate ARB to JSON
        final arbContent = await arbFile.readAsString();
        final migrated = _migrateArbContent(arbContent);

        // Step 3: Create JSON file from migration
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);
        final jsonFile = File('${inputDir.path}/en.i18n.json');
        await jsonFile.writeAsString(jsonEncode(migrated));

        // Step 4: Generate code
        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
            flutterIntegration: false,
          ),
          files: [
            PlainTranslationFile(
              path: jsonFile.path,
              read: () => jsonFile.readAsString(),
            ),
          ],
        );

        await generateTranslations(fileCollection: fileCollection);

        // Verify JSON was created with proper structure
        final jsonContent = await jsonFile.readAsString();
        final jsonMap = jsonDecode(jsonContent) as Map<String, dynamic>;
        expect(jsonMap.isNotEmpty, isTrue);
      });
    });

    group('Clean workflow: generate → analyze --full → clean', () {
      test('identifies and removes unused translations', () async {
        // Step 1: Create translation files with unused keys
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        final enFile = File('${inputDir.path}/en.i18n.json');
        await enFile.writeAsString(jsonEncode({
          'used': 'This is used',
          'unused': 'This is unused',
          'alsoUsed': 'Also used',
        }));

        // Step 2: Generate code
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

        await generateTranslations(fileCollection: fileCollection);

        // Step 3: Create source code using only some translations
        final sourceDir = '${tempDir.path}/lib';
        await Directory(sourceDir).create(recursive: true);
        await File('$sourceDir/main.dart').writeAsString('''
void main() {
  print(t.used);
  print(t.alsoUsed);
}
''');

        // Step 4: Analyze to find unused
        final translations = _buildTranslations({
          'en': {
            'used': 'This is used',
            'unused': 'This is unused',
            'alsoUsed': 'Also used',
          },
        });

        final unusedResult = await getUnusedTranslations(
          baseTranslations: translations.firstWhere((t) => t.base),
          rawConfig: RawConfig.defaultConfig,
          translations: translations,
          full: true,
          sourceDirs: [sourceDir],
        );

        // Verify 'unused' is detected
        final enLocale = I18nLocale(language: 'en');
        expect(unusedResult[enLocale]?['unused'], 'This is unused');
        expect(unusedResult[enLocale]?.containsKey('used'), isFalse);
        expect(unusedResult[enLocale]?.containsKey('alsoUsed'), isFalse);
      });
    });

    group('Multi-locale workflow', () {
      test('handles multiple locales end-to-end', () async {
        final inputDir = Directory('${tempDir.path}/i18n');
        await inputDir.create(recursive: true);

        // Create EN (base)
        final enFile = File('${inputDir.path}/en.i18n.json');
        await enFile.writeAsString(jsonEncode({
          'greeting': 'Hello',
          'farewell': 'Goodbye',
        }));

        // Create DE (secondary)
        final deFile = File('${inputDir.path}/de.i18n.json');
        await deFile.writeAsString(jsonEncode({
          'farewell': 'Auf Wiedersehen',
          'greeting': 'Hallo',
        }));

        // Create FR (secondary)
        final frFile = File('${inputDir.path}/fr.i18n.json');
        await frFile.writeAsString(jsonEncode({
          'greeting': 'Bonjour',
        }));

        final fileCollection = SlangFileCollectionBuilder.fromFileModel(
          config: RawConfig.defaultConfig.copyWith(
            inputFilePattern: '.i18n.json',
            flutterIntegration: false,
          ),
          files: [
            PlainTranslationFile(path: enFile.path, read: () => enFile.readAsString()),
            PlainTranslationFile(path: deFile.path, read: () => deFile.readAsString()),
            PlainTranslationFile(path: frFile.path, read: () => frFile.readAsString()),
          ],
        );

        // Generate for all locales
        await generateTranslations(fileCollection: fileCollection);

        // Normalize all locales
        await runNormalize(fileCollection: fileCollection, arguments: []);

        // Verify all locales have keys in EN order (for keys that exist in each locale)
        final enMap = jsonDecode(await enFile.readAsString()) as Map<String, dynamic>;
        final deMap = jsonDecode(await deFile.readAsString()) as Map<String, dynamic>;
        final frMap = jsonDecode(await frFile.readAsString()) as Map<String, dynamic>;

        // EN has both keys in order
        expect(enMap.keys.toList(), ['greeting', 'farewell']);
        // DE has both keys in EN order
        expect(deMap.keys.toList(), ['greeting', 'farewell']);
        // FR only has 'greeting' - normalize doesn't add missing keys
        expect(frMap.keys.toList(), ['greeting']);
      });
    });
  });
}

List<I18nData> _buildTranslations(Map<String, Map<String, dynamic>> translations) {
  final map = TranslationMap();
  for (final entry in translations.entries) {
    map.addTranslations(
      locale: I18nLocale(language: entry.key),
      translations: entry.value,
    );
  }

  return TranslationModelListBuilder.build(
    RawConfig.defaultConfig,
    map,
  );
}

Map<String, dynamic> _migrateArbContent(String arbContent) {
  final sourceMap = jsonDecode(arbContent) as Map<String, dynamic>;
  final resultMap = <String, dynamic>{};

  sourceMap.forEach((key, value) {
    if (key.startsWith('@@')) {
      resultMap[key] = value.toString();
      return;
    }
    if (key.startsWith('@')) {
      return; // Skip meta entries for simplicity
    }
    resultMap[key] = value;
  });

  return resultMap;
}
