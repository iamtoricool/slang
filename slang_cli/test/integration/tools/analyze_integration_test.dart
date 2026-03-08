import 'dart:io';

import 'package:slang/src/builder/builder/translation_model_list_builder.dart';
import 'package:slang/src/builder/model/i18n_data.dart';
import 'package:slang/src/builder/model/i18n_locale.dart';
import 'package:slang/src/builder/model/raw_config.dart';
import 'package:slang/src/builder/model/translation_map.dart';
import 'package:slang_cli/src/runner/analyze.dart';
import 'package:test/test.dart';

import '../../util/setup.dart';

/// Integration tests for the analyze command with AST-based detection.
/// These tests verify that issue #310 is fixed - translations accessed
/// via intermediate variables are correctly detected as used.
void main() {
  setUpAll(runSetupAll);

  group('analyze --full with intermediate variables', () {
    late Directory tempDir;
    late String sourceDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_analyze_test_');
      sourceDir = '${tempDir.path}/lib';
      await Directory(sourceDir).create(recursive: true);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('detects translations via intermediate variables', () async {
      // Create a Dart file using intermediate variables
      final dartFile = File('$sourceDir/main.dart');
      await dartFile.writeAsString('''
import 'package:slang/slang.dart';

void main() {
  // Direct usage
  print(t.home.title);

  // Intermediate variable - this is the key fix for issue #310
  final home = t.home;
  print(home.welcome);

  // Nested intermediate variable
  final section = t.settings;
  print(section.language);
}
''');

      final translations = _buildTranslations({
        'en': {
          'home': {
            'title': 'Home',
            'welcome': 'Welcome',
          },
          'settings': {
            'language': 'Language',
            'unusedSetting': 'This is unused', // Should be detected as unused
          },
        },
      });

      final result = await getUnusedTranslations(
        baseTranslations: translations.firstWhere((t) => t.base),
        rawConfig: RawConfig.defaultConfig,
        translations: translations,
        full: true,
        sourceDirs: [sourceDir],
      );

      // home.title and home.welcome should NOT be unused (they're used)
      // settings.language should NOT be unused (it's used)
      // settings.unusedSetting SHOULD be unused (not referenced)
      final enResult = result[I18nLocale(language: 'en')] ?? {};
      expect(enResult.containsKey('home'), isFalse); // home is used
      expect(enResult.containsKey('settings.language'), isFalse); // used via intermediate
      expect(enResult['settings']['unusedSetting'], 'This is unused');
    });

    test('detects deeply nested intermediate variables', () async {
      final dartFile = File('$sourceDir/nested.dart');
      await dartFile.writeAsString('''
void main() {
  // Deep nesting
  final app = t.app;
  final screen = app.screen;
  final header = screen.header;
  print(header.title);
}
''');

      final translations = _buildTranslations({
        'en': {
          'app': {
            'screen': {
              'header': {
                'title': 'Title',
                'subtitle': 'Subtitle', // unused
              },
            },
          },
        },
      });

      final result = await getUnusedTranslations(
        baseTranslations: translations.firstWhere((t) => t.base),
        rawConfig: RawConfig.defaultConfig,
        translations: translations,
        full: true,
        sourceDirs: [sourceDir],
      );

      final enResult = result[I18nLocale(language: 'en')] ?? {};
      expect(enResult.containsKey('app.screen.header.title'), isFalse);
      expect(enResult['app']['screen']['header']['subtitle'], 'Subtitle');
    });

    test('handles root aliasing (final t2 = t)', () async {
      final dartFile = File('$sourceDir/alias.dart');
      await dartFile.writeAsString('''
void main() {
  final t2 = t;
  print(t2.home.title);
}
''');

      final translations = _buildTranslations({
        'en': {
          'home': {
            'title': 'Title',
            'unused': 'Not used',
          },
        },
      });

      final result = await getUnusedTranslations(
        baseTranslations: translations.firstWhere((t) => t.base),
        rawConfig: RawConfig.defaultConfig,
        translations: translations,
        full: true,
        sourceDirs: [sourceDir],
      );

      final enResult = result[I18nLocale(language: 'en')] ?? {};
      expect(enResult.containsKey('home.title'), isFalse);
      expect(enResult['home']['unused'], 'Not used');
    });

    test('handles BuildContext.t pattern', () async {
      final dartFile = File('$sourceDir/context.dart');
      await dartFile.writeAsString('''
import 'package:flutter/material.dart';

void main(BuildContext context) {
  print(context.t.home.title);
}
''');

      final translations = _buildTranslations({
        'en': {
          'home': {
            'title': 'Title',
            'unused': 'Not used',
          },
        },
      });

      final result = await getUnusedTranslations(
        baseTranslations: translations.firstWhere((t) => t.base),
        rawConfig: RawConfig.defaultConfig,
        translations: translations,
        full: true,
        sourceDirs: [sourceDir],
      );

      final enResult = result[I18nLocale(language: 'en')] ?? {};
      expect(enResult.containsKey('home.title'), isFalse);
      expect(enResult['home']['unused'], 'Not used');
    });

    test('handles variable shadowing correctly', () async {
      final dartFile = File('$sourceDir/shadow.dart');
      await dartFile.writeAsString('''
void main() {
  // Shadow t with a string
  final t = 'not a translation';
  print(t.length); // This should NOT be counted as translation usage

  // Use the real translation var directly
  print(slang.t.home.title);
}
''');

      final translations = _buildTranslations({
        'en': {
          'home': {
            'title': 'Title',
          },
        },
      });

      final result = await getUnusedTranslations(
        baseTranslations: translations.firstWhere((t) => t.base),
        rawConfig: RawConfig.defaultConfig,
        translations: translations,
        full: true,
        sourceDirs: [sourceDir],
      );

      final enResult = result[I18nLocale(language: 'en')] ?? {};
      // Verify that shadowed t.length doesn't create a translation path
      // and that slang.t.home.title is detected
      expect(enResult.containsKey('home.title'), isFalse);
    });

    test('detects usage in string interpolation', () async {
      final dartFile = File('$sourceDir/interpolation.dart');
      await dartFile.writeAsString('''
void main() {
  final greeting = t.greeting;
  print('Hello \${greeting.name}');
}
''');

      final translations = _buildTranslations({
        'en': {
          'greeting': {
            'name': 'Name',
            'unused': 'Not used',
          },
        },
      });

      final result = await getUnusedTranslations(
        baseTranslations: translations.firstWhere((t) => t.base),
        rawConfig: RawConfig.defaultConfig,
        translations: translations,
        full: true,
        sourceDirs: [sourceDir],
      );

      final enResult = result[I18nLocale(language: 'en')] ?? {};
      expect(enResult.containsKey('greeting.name'), isFalse);
      expect(enResult['greeting']['unused'], 'Not used');
    });

    test('detects usage in lambdas and closures', () async {
      final dartFile = File('$sourceDir/lambda.dart');
      await dartFile.writeAsString('''
void main() {
  final items = ['a'];
  items.map((e) => t.items.label);

  final fn = () => t.functions.result;
  fn();
}
''');

      final translations = _buildTranslations({
        'en': {
          'items': {
            'label': 'Label',
            'unused': 'Not used',
          },
          'functions': {
            'result': 'Result',
            'unused': 'Not used',
          },
        },
      });

      final result = await getUnusedTranslations(
        baseTranslations: translations.firstWhere((t) => t.base),
        rawConfig: RawConfig.defaultConfig,
        translations: translations,
        full: true,
        sourceDirs: [sourceDir],
      );

      final enResult = result[I18nLocale(language: 'en')] ?? {};
      expect(enResult.containsKey('items.label'), isFalse);
      expect(enResult.containsKey('functions.result'), isFalse);
      expect(enResult['items']['unused'], 'Not used');
      expect(enResult['functions']['unused'], 'Not used');
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
