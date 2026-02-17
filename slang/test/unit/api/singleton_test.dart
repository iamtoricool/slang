import 'package:slang/src/api/locale.dart';
import 'package:slang/src/api/singleton.dart';
import 'package:test/test.dart';

class AppLocaleUtils
    extends BaseAppLocaleUtils<FakeAppLocale, FakeTranslations> {
  AppLocaleUtils({
    required super.baseLocale,
    required super.locales,
    super.dynamicBuilder,
  });
}

void main() {
  final nlBE = FakeAppLocale(languageCode: 'nl', countryCode: 'BE');
  final deAu = FakeAppLocale(languageCode: 'de', countryCode: 'AU');
  final deDe = FakeAppLocale(languageCode: 'de', countryCode: 'DE');
  final deCh = FakeAppLocale(languageCode: 'de', countryCode: 'CH');
  final esEs = FakeAppLocale(languageCode: 'es', countryCode: 'ES');
  final zhCN = FakeAppLocale(languageCode: 'zh', countryCode: 'CN');
  final zhHK = FakeAppLocale(languageCode: 'zh', countryCode: 'HK');
  final zhTW = FakeAppLocale(languageCode: 'zh', countryCode: 'TW');

  group('parseLocaleParts', () {
    test('should match exactly', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [
          esEs,
          deAu,
          deDe,
          deCh,
        ],
      );

      expect(
        utils.parseLocaleParts(languageCode: 'de', countryCode: 'DE'),
        deDe,
      );
    });

    test('should match language', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [
          nlBE,
          esEs,
          deDe,
          zhCN,
          zhHK,
        ],
      );

      expect(
        utils.parseLocaleParts(languageCode: 'de', countryCode: 'CH'),
        deDe,
      );
    });

    test('should match first language when there is no country code', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [
          esEs,
          zhCN,
          zhTW,
        ],
      );

      expect(
        utils.parseLocaleParts(languageCode: 'zh', scriptCode: 'Hans'),
        zhCN,
      );
    });

    test('should match first language when there is a country code', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [
          deDe,
          deAu,
        ],
      );

      expect(
        utils.parseLocaleParts(languageCode: 'de', countryCode: 'CH'),
        deDe,
      );
    });

    test('should match country', () {
      final utils = AppLocaleUtils(
        baseLocale: deDe,
        locales: [
          deDe,
          nlBE,
          esEs,
          zhCN,
        ],
      );

      expect(
        utils.parseLocaleParts(languageCode: 'fr', countryCode: 'BE'),
        nlBE,
      );
    });

    test('should match language and country', () {
      final utils = AppLocaleUtils(
        baseLocale: deDe,
        locales: [
          deDe,
          nlBE,
          zhCN,
          zhTW,
          zhHK,
        ],
      );

      expect(
        utils.parseLocaleParts(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
        zhTW,
      );
    });

    test('should fallback to base locale', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [
          esEs,
          deDe,
          nlBE,
          zhCN,
        ],
      );

      expect(
        utils.parseLocaleParts(languageCode: 'fr', countryCode: 'FR'),
        esEs,
      );
    });

    test('should fallback to base locale when no dynamicBuilder', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [esEs, deDe],
      );

      final result = utils.parseLocaleParts(languageCode: 'ja');
      expect(result, esEs);
      expect(utils.locales.length, 2); // no new locale added
    });
  });

  group('dynamic locales', () {
    test('should create new locale via dynamicBuilder', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [esEs, deDe],
        dynamicBuilder: ({
          required String languageCode,
          String? scriptCode,
          String? countryCode,
        }) =>
            FakeAppLocale(
          languageCode: languageCode,
          scriptCode: scriptCode,
          countryCode: countryCode,
        ),
      );

      final result = utils.parseLocaleParts(languageCode: 'ja');
      expect(result.languageCode, 'ja');
      expect(result.scriptCode, isNull);
      expect(result.countryCode, isNull);
      // Should NOT be the base locale
      expect(result, isNot(equals(esEs)));
    });

    test('should add dynamic locale to locales list', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [esEs, deDe],
        dynamicBuilder: ({
          required String languageCode,
          String? scriptCode,
          String? countryCode,
        }) =>
            FakeAppLocale(
          languageCode: languageCode,
          scriptCode: scriptCode,
          countryCode: countryCode,
        ),
      );

      expect(utils.locales.length, 2);
      utils.parseLocaleParts(languageCode: 'ja');
      expect(utils.locales.length, 3);
      expect(utils.locales.last.languageCode, 'ja');
    });

    test('should return existing dynamic locale on subsequent parse', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [esEs, deDe],
        dynamicBuilder: ({
          required String languageCode,
          String? scriptCode,
          String? countryCode,
        }) =>
            FakeAppLocale(
          languageCode: languageCode,
          scriptCode: scriptCode,
          countryCode: countryCode,
        ),
      );

      final first =
          utils.parseLocaleParts(languageCode: 'ja', countryCode: 'JP');
      final second =
          utils.parseLocaleParts(languageCode: 'ja', countryCode: 'JP');

      // Should return the same instance (exact match on second call)
      expect(identical(first, second), isTrue);
      // Should not have created a duplicate
      expect(utils.locales.length, 3);
    });

    test('should preserve scriptCode and countryCode in dynamic locale', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [esEs],
        dynamicBuilder: ({
          required String languageCode,
          String? scriptCode,
          String? countryCode,
        }) =>
            FakeAppLocale(
          languageCode: languageCode,
          scriptCode: scriptCode,
          countryCode: countryCode,
        ),
      );

      final result = utils.parseLocaleParts(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'MO',
      );

      expect(result.languageCode, 'zh');
      expect(result.scriptCode, 'Hant');
      expect(result.countryCode, 'MO');
    });

    test('should use parse() to create dynamic locale from raw string', () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [esEs],
        dynamicBuilder: ({
          required String languageCode,
          String? scriptCode,
          String? countryCode,
        }) =>
            FakeAppLocale(
          languageCode: languageCode,
          scriptCode: scriptCode,
          countryCode: countryCode,
        ),
      );

      final result = utils.parse('fr-FR');
      expect(result.languageCode, 'fr');
      expect(result.countryCode, 'FR');
      expect(utils.locales.length, 2);
    });

    test('should not use dynamicBuilder when language matches existing locale',
        () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [esEs, deDe],
        dynamicBuilder: ({
          required String languageCode,
          String? scriptCode,
          String? countryCode,
        }) =>
            FakeAppLocale(
          languageCode: languageCode,
          scriptCode: scriptCode,
          countryCode: countryCode,
        ),
      );

      // 'de' matches deDe by language code
      final result =
          utils.parseLocaleParts(languageCode: 'de', countryCode: 'AT');
      expect(result, deDe); // should match existing, not create new
      expect(utils.locales.length, 2);
    });

    test('should not use dynamicBuilder when country matches existing locale',
        () {
      final utils = AppLocaleUtils(
        baseLocale: esEs,
        locales: [esEs, nlBE],
        dynamicBuilder: ({
          required String languageCode,
          String? scriptCode,
          String? countryCode,
        }) =>
            FakeAppLocale(
          languageCode: languageCode,
          scriptCode: scriptCode,
          countryCode: countryCode,
        ),
      );

      // 'fr' with country 'BE' should match nlBE by country
      final result =
          utils.parseLocaleParts(languageCode: 'fr', countryCode: 'BE');
      expect(result, nlBE);
      expect(utils.locales.length, 2);
    });
  });
}
