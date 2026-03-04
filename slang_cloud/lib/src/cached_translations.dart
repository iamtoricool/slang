/// Data class representing cached translations with metadata.
class CachedTranslations {
  /// The locale code (e.g., 'en', 'de')
  final String locale;

  /// The hash/version of these translations
  final String hash;

  /// The translation map
  final Map<String, dynamic> translations;

  const CachedTranslations({
    required this.locale,
    required this.hash,
    required this.translations,
  });

  /// Serialize to JSON-compatible map for storage
  Map<String, dynamic> toJson() => {
        'locale': locale,
        'hash': hash,
        'translations': translations,
      };

  /// Deserialize from JSON-compatible map from storage
  factory CachedTranslations.fromJson(Map<String, dynamic> json) => CachedTranslations(
        locale: json['locale'] as String,
        hash: json['hash'] as String,
        translations: json['translations'] as Map<String, dynamic>,
      );
}
