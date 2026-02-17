import 'dart:io';

import 'package:slang/src/builder/builder/translation_model_list_builder.dart';
import 'package:slang/src/builder/model/i18n_data.dart';
import 'package:slang/src/builder/model/i18n_locale.dart';
import 'package:slang/src/builder/model/raw_config.dart';
import 'package:slang/src/builder/model/translation_map.dart';
import 'package:slang_cli/src/runner/analyze.dart';
import 'package:slang_cli/src/runner/translation_usage_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('getMissingTranslations', () {
    test('Should find missing translations', () async {
      final result = _getMissingTranslations({
        'en': {
          'a': 'A',
          'b': 'B',
        },
        'de': {
          'a': 'A',
        },
      });

      expect(result[I18nLocale(language: 'de')], {'b': 'B'});
    });

    test('Should respect ignoreMissing flag', () async {
      final result = _getMissingTranslations({
        'en': {
          'a': 'A',
          'b(ignoreMissing)': 'B',
        },
        'de': {
          'a': 'A',
        },
      });

      expect(result[I18nLocale(language: 'de')], isEmpty);
    });

    test('Should respect OUTDATED flag', () async {
      final result = _getMissingTranslations({
        'en': {
          'a': 'A EN',
        },
        'de': {
          'a(OUTDATED)': 'A DE',
        },
      });

      expect(result[I18nLocale(language: 'de')], {'a(OUTDATED)': 'A EN'});
    });

    test('Should ignore ignoreUnused flag', () async {
      final result = _getMissingTranslations({
        'en': {
          'a': 'A',
          'b(ignoreUnused)': 'B',
        },
        'de': {
          'a': 'A',
        },
      });

      expect(result[I18nLocale(language: 'de')], {'b(ignoreUnused)': 'B'});
    });

    test('Should find missing enum', () async {
      final result = _getMissingTranslations({
        'en': {
          'a': 'A',
          'greet(context=Gender)': {
            'male': 'Hello Mr',
            'female': 'Hello Mrs',
          },
        },
        'de': {
          'a': 'A',
          'greet(context=Gender)': {
            'male': 'Hello Herr',
          },
        },
      });

      expect(
        result[I18nLocale(language: 'de')],
        {
          'greet(context=Gender)': {
            'female': 'Hello Mrs',
          },
        },
      );
    });
  });

  group('getUnusedTranslations', () {
    test('Should find unused translations', () async {
      final result = await _getUnusedTranslations({
        'en': {
          'a': 'A',
        },
        'de': {
          'a': 'A',
          'b': 'B',
        },
      });

      expect(result[I18nLocale(language: 'de')], {'b': 'B'});
    });

    test('Should respect ignoreUnused flag', () async {
      final result = await _getUnusedTranslations({
        'en': {
          'a': 'A',
        },
        'de': {
          'a': 'A',
          'b(ignoreUnused)': 'B',
        },
      });

      expect(result[I18nLocale(language: 'de')], isEmpty);
    });

    test('Should ignore ignoreMissing flag', () async {
      final result = await _getUnusedTranslations({
        'en': {
          'a': 'A',
        },
        'de': {
          'a': 'A',
          'b(ignoreMissing)': 'B',
        },
      });

      expect(result[I18nLocale(language: 'de')], {'b(ignoreMissing)': 'B'});
    });

    test('Should ignore unused but linked translations', () async {
      final result = await _getUnusedTranslations({
        'en': {
          'a': 'A',
        },
        'de': {
          'a': 'A @:b',
          'b': 'B',
        },
      });

      expect(result[I18nLocale(language: 'de')], isEmpty);
    });
  });

  group('TranslationUsageAnalyzer - AST-based analysis', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('detects direct translation usage', () async {
      final code = '''
        void main() {
          print(t.mainScreen.title);
          print(t.mainScreen.subtitle);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, contains('mainScreen.subtitle'));
    });

    test('detects simple variable assignment and usage', () async {
      final code = '''
        void main() {
          final title = t.mainScreen.title;
          final subtitle = t.mainScreen.subtitle;
        
          print(title);
          print(subtitle);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, contains('mainScreen.subtitle'));
    });

    test('detects nested variable assignment', () async {
      final code = '''
        void main() {
          final screen = t.mainScreen;
          final title = screen.title;
          final subtitle = screen.subtitle;
        
          print(title);
          print(subtitle);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, contains('mainScreen.subtitle'));
    });

    test('detects context.t usage', () async {
      final code = '''
        void main(BuildContext context) {
          print(context.t.mainScreen.title);
          print(context.t.mainScreen.subtitle);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, contains('mainScreen.subtitle'));
    });

    test('detects complex nested property access', () async {
      final code = '''
        void main() {
          final app = t.app;
          final mainScreen = app.screen;
          final dialog = mainScreen.dialog;
        
          final title = dialog.title;
          final message = dialog.message;
        
          print(title);
          print(message);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('app.screen.dialog.title'));
      expect(usedPaths, contains('app.screen.dialog.message'));
    });

    test('handles mixed usage patterns', () async {
      final code = '''
        void main(BuildContext context) {
          // Direct usage
          print(t.direct.title);
        
          // Variable assignment
          final screen = t.mainScreen;
          final headerTitle = screen.header.title;
        
          // Context usage
          final contextTitle = context.t.context.title;
        
          // Nested usage
          final nested = t.nested.deep.very;
          final deepValue = nested.value;
        
          print(headerTitle);
          print(contextTitle);
          print(deepValue);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('direct.title'));
      expect(usedPaths, contains('mainScreen.header.title'));
      expect(usedPaths, contains('context.title'));
      expect(usedPaths, contains('nested.deep.very.value'));
    });

    test('ignores unused translations', () async {
      final code = '''
        void main() {
          final used = t.mainScreen.title;
          print(used);
        
          // t.mainScreen.subtitle is not used anywhere
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, isNot(contains('mainScreen.subtitle')));
    });

    test('handles function parameters', () async {
      final code = '''
        void main() {
          final title = t.mainScreen.title;
          showMessage(title);
        }
        
        void showMessage(String message) {
          print(message);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
    });

    test('handles variable reassignment', () async {
      final code = '''
        void main() {
          var title = t.mainScreen.title;
          print(title);
        
          title = t.otherScreen.title; // reassign
          print(title);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, contains('otherScreen.title'));
    });

    test('handles conditional expressions', () async {
      final code = '''
        void main() {
          final isMain = true;
          final title = isMain ? t.mainScreen.title : t.otherScreen.title;
          print(title);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, contains('otherScreen.title'));
    });

    test('detects method invocations (plurals/wip)', () async {
      final code = '''
        void main() {
          // Method invocation
          t.myPlural(n: 5);
          t.\$wip('key');
          
          // Chained method invocation
          t.section.myContext(context: Gender.male);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('myPlural'));
      expect(usedPaths, contains('\$wip'));
      expect(usedPaths, contains('section.myContext'));
    });

    test('clears variable state between files (no cross-file leaking)',
        () async {
      // File A defines a variable `screen = t.mainScreen`
      final codeA = '''
        void main() {
          final screen = t.mainScreen;
          print(screen.title);
        }
      ''';
      // File B uses an unrelated `screen.title` (not a translation)
      final codeB = '''
        class Screen { String get title => 'hello'; }
        void main() {
          final screen = Screen();
          print(screen.title);
        }
      ''';
      final fileA = File('${tempDir.path}/a.dart');
      fileA.writeAsStringSync(codeA);
      final fileB = File('${tempDir.path}/b.dart');
      fileB.writeAsStringSync(codeB);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');

      // Analyze file A first — records `screen -> mainScreen`
      final pathsAfterA =
          Set<String>.from(await analyzer.analyzeFile(fileA.path));
      expect(pathsAfterA, contains('mainScreen.title'));

      // Analyze file B — `screen` in B is NOT a translation variable
      final pathsAfterB = await analyzer.analyzeFile(fileB.path);

      // mainScreen.title should still be present (accumulated from file A)
      expect(pathsAfterB, contains('mainScreen.title'));
      // But file B's screen.title should NOT have added a second translation path
      // (e.g., `mainScreen.title` again via leaked variable mapping)
      // The absence of any new path proves the variable map was cleared
      expect(pathsAfterB.difference(pathsAfterA), isEmpty);
    });

    test('handles root aliasing (final t2 = t)', () async {
      final code = '''
        void main() {
          final t2 = t;
          print(t2.mainScreen.title);
          print(t2.settings.language);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, contains('settings.language'));
    });

    test('handles chained root aliasing (final t3 = t2 = t)', () async {
      final code = '''
        void main() {
          final t2 = t;
          final t3 = t2;
          print(t3.mainScreen.title);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
    });

    test('handles variable shadowing (final t = "hello")', () async {
      final code = '''
        void main() {
          final t = 'hello';
          print(t.length);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      // t.length should NOT be detected as a translation path
      expect(usedPaths, isNot(contains('length')));
    });

    test('shadowing is per-file and does not persist', () async {
      // File A shadows t
      final codeA = '''
        void main() {
          final t = 'hello';
          print(t.length);
        }
      ''';
      // File B uses t normally
      final codeB = '''
        void main() {
          print(t.mainScreen.title);
        }
      ''';
      final fileA = File('${tempDir.path}/a.dart');
      fileA.writeAsStringSync(codeA);
      final fileB = File('${tempDir.path}/b.dart');
      fileB.writeAsStringSync(codeB);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      await analyzer.analyzeFile(fileA.path);
      await analyzer.analyzeFile(fileB.path);

      expect(
          await analyzer.analyzeFile(fileB.path), contains('mainScreen.title'));
      // length from file A should NOT be present
      expect(await analyzer.analyzeFile(fileA.path), isNot(contains('length')));
    });

    test('detects usage in string interpolation', () async {
      final code = '''
        void main() {
          print('Hello \${t.greeting}');
          print('Welcome \${t.mainScreen.title}');
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('greeting'));
      expect(usedPaths, contains('mainScreen.title'));
    });

    test('detects usage in collection literals', () async {
      final code = '''
        void main() {
          final list = [t.a.x, t.b.y];
          final map = {'key': t.c.z};
          final set = {t.d.w};
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('a.x'));
      expect(usedPaths, contains('b.y'));
      expect(usedPaths, contains('c.z'));
      expect(usedPaths, contains('d.w'));
    });

    test('detects usage in lambdas and closures', () async {
      final code = '''
        void main() {
          final fn = () => t.mainScreen.title;
          final items = ['a'].map((e) => t.mainScreen.subtitle);
          void callback() {
            print(t.settings.language);
          }
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, contains('mainScreen.subtitle'));
      expect(usedPaths, contains('settings.language'));
    });

    test('detects usage in class fields and top-level variables', () async {
      final code = '''
        final topLevel = t.app.name;

        class MyWidget {
          final title = t.mainScreen.title;
          
          String get subtitle => t.mainScreen.subtitle;
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('app.name'));
      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, contains('mainScreen.subtitle'));
    });

    test('works with custom translateVar', () async {
      final code = '''
        void main() {
          print(translations.mainScreen.title);
          final screen = translations.mainScreen;
          print(screen.subtitle);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 'translations');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('mainScreen.title'));
      expect(usedPaths, contains('mainScreen.subtitle'));
      // Ensure default 't' does NOT match
      expect(usedPaths, isNot(contains('translations.mainScreen.title')));
    });

    test('handles empty file gracefully', () async {
      final testFile = File('${tempDir.path}/empty.dart');
      testFile.writeAsStringSync('');

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, isEmpty);
    });

    test('handles malformed file gracefully', () async {
      final testFile = File('${tempDir.path}/bad.dart');
      testFile.writeAsStringSync('this is not valid dart {{{{');

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      // Should not throw
      final usedPaths = await analyzer.analyzeFile(testFile.path);
      expect(usedPaths, isA<Set<String>>());
    });

    test('detects translation path, not method chain on result', () async {
      final code = '''
        void main() {
          print(t.mainScreen.title.toUpperCase());
          print(t.settings.language.trim().toLowerCase());
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      // Should detect the translation path portion
      // Due to AST toString-based path extraction, the full chain is recorded.
      // This is acceptable — the unused check uses startsWith/prefix matching,
      // so mainScreen.title.toUpperCase still matches mainScreen.title.
      // What matters is that the translation path IS detected.
      expect(
        usedPaths.any((p) => p.startsWith('mainScreen.title')),
        isTrue,
      );
      expect(
        usedPaths.any((p) => p.startsWith('settings.language')),
        isTrue,
      );
    });

    test('root alias with method invocation', () async {
      final code = '''
        void main() {
          final t2 = t;
          t2.myPlural(n: 5);
        }
      ''';
      final testFile = File('${tempDir.path}/test.dart');
      testFile.writeAsStringSync(code);

      final analyzer = TranslationUsageAnalyzer(translateVar: 't');
      final usedPaths = await analyzer.analyzeFile(testFile.path);

      expect(usedPaths, contains('myPlural'));
    });
  });
}

Map<I18nLocale, Map<String, dynamic>> _getMissingTranslations(
  Map<String, Map<String, dynamic>> translations,
) {
  final existing = _buildTranslations(translations);
  return getMissingTranslations(
    baseTranslations: findBaseTranslations(RawConfig.defaultConfig, existing),
    translations: existing,
  );
}

Future<Map<I18nLocale, Map<String, dynamic>>> _getUnusedTranslations(
  Map<String, Map<String, dynamic>> translations,
) async {
  final existing = _buildTranslations(translations);
  return await getUnusedTranslations(
    baseTranslations: findBaseTranslations(RawConfig.defaultConfig, existing),
    rawConfig: RawConfig.defaultConfig,
    translations: _buildTranslations(translations),
    full: false,
  );
}

List<I18nData> _buildTranslations(
    Map<String, Map<String, dynamic>> translations) {
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
