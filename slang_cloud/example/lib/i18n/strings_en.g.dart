///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	/// [AppLocaleUtils.buildWithOverrides] is recommended for overriding.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final TranslationsMainEn main = TranslationsMainEn.internal(_root);
}

// Path: main
class TranslationsMainEn {
	TranslationsMainEn.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Slang Cloud Demo (Local)'
	String get title => TranslationOverrides.string(_root.$meta, 'main.title', {}) ?? 'Slang Cloud Demo (Local)';

	/// en: 'This text is from the local bundle.'
	String get description => TranslationOverrides.string(_root.$meta, 'main.description', {}) ?? 'This text is from the local bundle.';

	/// en: 'Check for Updates'
	String get button => TranslationOverrides.string(_root.$meta, 'main.button', {}) ?? 'Check for Updates';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'main.title' => TranslationOverrides.string(_root.$meta, 'main.title', {}) ?? 'Slang Cloud Demo (Local)',
			'main.description' => TranslationOverrides.string(_root.$meta, 'main.description', {}) ?? 'This text is from the local bundle.',
			'main.button' => TranslationOverrides.string(_root.$meta, 'main.button', {}) ?? 'Check for Updates',
			_ => null,
		};
	}
}
