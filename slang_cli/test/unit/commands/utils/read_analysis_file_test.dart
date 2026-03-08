import 'dart:convert';
import 'dart:io';

import 'package:slang/src/builder/model/i18n_locale.dart';
import 'package:slang_cli/src/commands/apply.dart';
import 'package:slang_cli/src/commands/utils/read_analysis_file.dart';
import 'package:test/test.dart';

void main() {
  group('readAnalysis', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_analysis_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should read JSON unused translations file', () async {
      final analysisFile = File('${tempDir.path}/_unused_translations_en.json');
      await analysisFile.writeAsString(jsonEncode({
        'unusedKey1': 'value1',
        'unusedKey2': 'value2',
      }));

      final result = readAnalysis(
        type: AnalysisType.unusedTranslations,
        files: [analysisFile],
        targetLocales: null,
      );

      expect(result.length, 1);
      final enLocale = I18nLocale.fromString('en');
      expect(result[enLocale]!['unusedKey1'], 'value1');
      expect(result[enLocale]!['unusedKey2'], 'value2');
    });

    test('should read YAML unused translations file', () async {
      final analysisFile = File('${tempDir.path}/_unused_translations_de.yaml');
      await analysisFile.writeAsString('''
unusedKey1: value1
unusedKey2: value2
''');

      final result = readAnalysis(
        type: AnalysisType.unusedTranslations,
        files: [analysisFile],
        targetLocales: null,
      );

      expect(result.length, 1);
      final deLocale = I18nLocale.fromString('de');
      expect(result[deLocale]!['unusedKey1'], 'value1');
      expect(result[deLocale]!['unusedKey2'], 'value2');
    });

    test('should read JSON missing translations file', () async {
      final analysisFile = File('${tempDir.path}/_missing_translations_fr.json');
      await analysisFile.writeAsString(jsonEncode({
        'missingKey1': 'value1',
      }));

      final result = readAnalysis(
        type: AnalysisType.missingTranslations,
        files: [analysisFile],
        targetLocales: null,
      );

      expect(result.length, 1);
      final frLocale = I18nLocale.fromString('fr');
      expect(result[frLocale]!['missingKey1'], 'value1');
    });

    test('should filter by target locales', () async {
      final enFile = File('${tempDir.path}/_unused_translations_en.json');
      await enFile.writeAsString(jsonEncode({'key': 'enValue'}));

      final deFile = File('${tempDir.path}/_unused_translations_de.json');
      await deFile.writeAsString(jsonEncode({'key': 'deValue'}));

      final result = readAnalysis(
        type: AnalysisType.unusedTranslations,
        files: [enFile, deFile],
        targetLocales: [I18nLocale.fromString('en')],
      );

      expect(result.length, 1);
      expect(result.containsKey(I18nLocale.fromString('en')), isTrue);
      expect(result.containsKey(I18nLocale.fromString('de')), isFalse);
    });

    test('should skip files not matching analysis type', () async {
      final unusedFile = File('${tempDir.path}/_unused_translations_en.json');
      await unusedFile.writeAsString(jsonEncode({'unusedKey': 'value'}));

      final missingFile = File('${tempDir.path}/_missing_translations_en.json');
      await missingFile.writeAsString(jsonEncode({'missingKey': 'value'}));

      final result = readAnalysis(
        type: AnalysisType.unusedTranslations,
        files: [unusedFile, missingFile],
        targetLocales: null,
      );

      expect(result.length, 1);
      final enLocale = I18nLocale.fromString('en');
      expect(result[enLocale]!['unusedKey'], 'value');
      expect(result[enLocale]!.containsKey('missingKey'), isFalse);
    });

    test('should throw for unsupported file type', () async {
      final analysisFile = File('${tempDir.path}/_unused_translations_en.csv');
      await analysisFile.writeAsString('key,value\nunusedKey,value1');

      expect(
        () => readAnalysis(
          type: AnalysisType.unusedTranslations,
          files: [analysisFile],
          targetLocales: null,
        ),
        throwsA(isA<FileTypeNotSupportedError>()),
      );
    });

    test('should handle file with info key', () async {
      final analysisFile = File('${tempDir.path}/_unused_translations_en.json');
      await analysisFile.writeAsString(jsonEncode({
        '@@info': {'timestamp': '2024-01-01'},
        'unusedKey': 'value',
      }));

      final result = readAnalysis(
        type: AnalysisType.unusedTranslations,
        files: [analysisFile],
        targetLocales: null,
      );

      final enLocale = I18nLocale.fromString('en');
      expect(result[enLocale]!['unusedKey'], 'value');
      expect(result[enLocale]!.containsKey('@@info'), isFalse);
    });

    test('should return empty map when no files match', () async {
      final result = readAnalysis(
        type: AnalysisType.unusedTranslations,
        files: [],
        targetLocales: null,
      );

      expect(result, isEmpty);
    });
  });
}
