import 'package:slang/src/api/locale.dart';
import 'package:slang/src/api/singleton.dart';
import 'package:slang/src/api/state.dart';
import 'package:slang/src/builder/model/build_model_config.dart';
import 'package:slang/src/builder/model/enums.dart';
import 'package:slang/src/builder/model/sanitization_config.dart';
import 'package:test/test.dart';

void main() {
  group('setPluralResolver', () {
    setUp(() {
      GlobalLocaleState.instance.setLocale(_baseLocale);
    });

    test('should set overrides to null when it is previously empty', () {
      final localeSettings = _LocaleSettings();

      localeSettings.setPluralResolver(
        language: 'und',
        cardinalResolver: (n, {zero, one, two, few, many, other}) {
          return other!;
        },
      );

      expect(localeSettings.currentTranslations.providedNullOverrides, true);
    });

    test('should keep overrides when calling setPluralResolver', () async {
      final localeSettings = _LocaleSettings();

      await localeSettings.overrideTranslationsFromMap(
        locale: _baseLocale,
        isFlatMap: false,
        map: {'hello': 'hi'},
      );

      await localeSettings.setPluralResolver(
        language: 'und',
        cardinalResolver: (n, {zero, one, two, few, many, other}) {
          return other!;
        },
      );

      expect(localeSettings.currentTranslations.providedNullOverrides, false);
      expect(
        localeSettings.currentTranslations.$meta.overrides.keys,
        ['hello'],
      );
    });

    test('should initialize locale when overriding', () async {
      final localeSettings = _LocaleSettings();

      await localeSettings.overrideTranslations(
        locale: _localeA,
        fileType: FileType.yaml,
        content: 'keyA: valueA',
      );

      expect(
        localeSettings.translationMap[_localeA]!.$meta.overrides.keys,
        ['keyA'],
      );

      await localeSettings.overrideTranslationsFromMap(
        locale: _localeB,
        isFlatMap: false,
        map: {'keyB': 'valueB'},
      );

      expect(
        localeSettings.translationMap[_localeB]!.$meta.overrides.keys,
        ['keyB'],
      );
    });

    test('should keep plural resolver when overriding', () async {
      final localeSettings = _LocaleSettings();

      await localeSettings.setPluralResolver(
        locale: _localeA,
        cardinalResolver: (n, {zero, one, two, few, many, other}) {
          return 'CUSTOM-CARDINAL';
        },
      );

      await localeSettings.overrideTranslations(
        locale: _localeA,
        fileType: FileType.yaml,
        content: 'keyA: valueA',
      );

      expect(
        localeSettings.translationMap[_localeA]!.$meta.overrides.keys,
        ['keyA'],
      );

      expect(
        localeSettings.translationMap[_localeA]!.$meta.cardinalResolver!(
          1,
          zero: 'zero',
          one: 'one',
          two: 'two',
          few: 'few',
          many: 'many',
          other: 'other',
        ),
        'CUSTOM-CARDINAL',
      );
    });
  });

  group('dynamic locale interactions', () {
    setUp(() {
      GlobalLocaleState.instance.setLocale(_baseLocale);
    });

    test('should load a dynamically created locale', () async {
      final dynamicUtils = _AppLocaleUtils(
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
      final localeSettings = _LocaleSettings(utils: dynamicUtils);

      // Parse a locale that doesn't exist — dynamicBuilder creates it
      final dynamicLocale = dynamicUtils.parse('fr-FR');
      expect(dynamicLocale.languageCode, 'fr');
      expect(dynamicLocale.countryCode, 'FR');

      // Load the dynamic locale
      await localeSettings.loadLocale(dynamicLocale);
      expect(localeSettings.translationMap.containsKey(dynamicLocale), isTrue);
    });

    test('should override translations for a dynamic locale', () async {
      final dynamicUtils = _AppLocaleUtils(
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
      final localeSettings = _LocaleSettings(utils: dynamicUtils);

      final dynamicLocale = dynamicUtils.parse('fr-FR');

      await localeSettings.overrideTranslationsFromMap(
        locale: dynamicLocale,
        isFlatMap: false,
        map: {'hello': 'bonjour'},
      );

      expect(localeSettings.translationMap.containsKey(dynamicLocale), isTrue);
      expect(
        localeSettings.translationMap[dynamicLocale]!.$meta.overrides.keys,
        ['hello'],
      );
    });
  });
}

final _baseLocale = FakeAppLocale(languageCode: 'und');
final _localeA = FakeAppLocale(languageCode: 'aa');
final _localeB = FakeAppLocale(languageCode: 'bb');

class _AppLocaleUtils
    extends BaseAppLocaleUtils<FakeAppLocale, FakeTranslations> {
  _AppLocaleUtils({super.dynamicBuilder})
      : super(
          baseLocale: _baseLocale,
          locales: [_baseLocale, _localeA, _localeB],
          buildConfig: BuildModelConfig(
            fallbackStrategy: FallbackStrategy.none,
            keyCase: null,
            keyMapCase: null,
            paramCase: null,
            sanitization: SanitizationConfig(
              enabled: true,
              prefix: 'k',
              caseStyle: CaseStyle.camel,
            ),
            stringInterpolation: StringInterpolation.braces,
            maps: [],
            pluralAuto: PluralAuto.cardinal,
            pluralParameter: 'n',
            pluralCardinal: [],
            pluralOrdinal: [],
            contexts: [],
            interfaces: [],
            generateEnum: true,
          ),
        );
}

class _LocaleSettings
    extends BaseLocaleSettings<FakeAppLocale, FakeTranslations> {
  _LocaleSettings({_AppLocaleUtils? utils})
      : super(utils: utils ?? _AppLocaleUtils(), lazy: true);
}
