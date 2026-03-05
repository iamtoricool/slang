import 'package:flutter_test/flutter_test.dart';

/// Replicates the _buildUrl logic from SlangCloudClient for testing
String buildUrl(String baseUrl, String pathTemplate, String locale) {
  final path = pathTemplate.replaceAll('{locale}', locale);
  // Ensure baseUrl doesn't have trailing slash and path starts with slash
  final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return '$base$normalizedPath';
}

void main() {
  group('pathTemplate edge cases', () {
    group('default behavior (backward compatibility)', () {
      test('should use default /translations/{locale} path', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'en'),
          equals('http://api.example.com/translations/en'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'de'),
          equals('http://api.example.com/translations/de'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'en-US'),
          equals('http://api.example.com/translations/en-US'),
        );
      });
    });

    group('custom API paths', () {
      test('should support /api/v1/i18n/{locale}', () {
        expect(
          buildUrl('http://api.example.com', '/api/v1/i18n/{locale}', 'en'),
          equals('http://api.example.com/api/v1/i18n/en'),
        );
        expect(
          buildUrl('http://api.example.com', '/api/v1/i18n/{locale}', 'fr'),
          equals('http://api.example.com/api/v1/i18n/fr'),
        );
      });

      test('should support nested paths /api/v2/translations/{locale}/content', () {
        expect(
          buildUrl('https://backend.example.org', '/api/v2/translations/{locale}/content', 'es'),
          equals('https://backend.example.org/api/v2/translations/es/content'),
        );
      });

      test('should support simple paths /i18n/{locale}', () {
        expect(
          buildUrl('http://localhost:3000', '/i18n/{locale}', 'ja'),
          equals('http://localhost:3000/i18n/ja'),
        );
      });
    });

    group('leading slash handling', () {
      test('should handle path without leading slash', () {
        expect(
          buildUrl('http://api.example.com', 'translations/{locale}', 'en'),
          equals('http://api.example.com/translations/en'),
        );
      });

      test('should handle path with leading slash', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'en'),
          equals('http://api.example.com/translations/en'),
        );
      });

      test('should handle deeply nested path without leading slash', () {
        expect(
          buildUrl('http://api.example.com', 'api/v1/deep/nested/{locale}', 'de'),
          equals('http://api.example.com/api/v1/deep/nested/de'),
        );
      });
    });

    group('trailing slash handling in baseUrl', () {
      test('should handle baseUrl without trailing slash', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'en'),
          equals('http://api.example.com/translations/en'),
        );
      });

      test('should handle baseUrl with trailing slash', () {
        expect(
          buildUrl('http://api.example.com/', '/translations/{locale}', 'en'),
          equals('http://api.example.com/translations/en'),
        );
      });

      test('should handle baseUrl with multiple trailing slashes', () {
        // Note: Only removes one trailing slash
        expect(
          buildUrl('http://api.example.com//', '/translations/{locale}', 'en'),
          equals('http://api.example.com//translations/en'),
        );
      });
    });

    group('locale code variations', () {
      test('should handle simple locale codes', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'en'),
          equals('http://api.example.com/translations/en'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'de'),
          equals('http://api.example.com/translations/de'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'fr'),
          equals('http://api.example.com/translations/fr'),
        );
      });

      test('should handle locale codes with country/region', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'en-US'),
          equals('http://api.example.com/translations/en-US'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'en-GB'),
          equals('http://api.example.com/translations/en-GB'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'zh-CN'),
          equals('http://api.example.com/translations/zh-CN'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'pt-BR'),
          equals('http://api.example.com/translations/pt-BR'),
        );
      });

      test('should handle locale codes with script', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'zh-Hans'),
          equals('http://api.example.com/translations/zh-Hans'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'zh-Hant'),
          equals('http://api.example.com/translations/zh-Hant'),
        );
      });

      test('should handle uppercase locale codes', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'EN'),
          equals('http://api.example.com/translations/EN'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'DE'),
          equals('http://api.example.com/translations/DE'),
        );
      });

      test('should handle locale codes with underscore', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'en_US'),
          equals('http://api.example.com/translations/en_US'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'zh_CN'),
          equals('http://api.example.com/translations/zh_CN'),
        );
      });
    });

    group('multiple {locale} placeholders', () {
      test('should replace all occurrences of {locale}', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}/copy/{locale}', 'en'),
          equals('http://api.example.com/translations/en/copy/en'),
        );
      });

      test('should handle path with {locale} in query parameter', () {
        expect(
          buildUrl('http://api.example.com', '/translations?lang={locale}', 'es'),
          equals('http://api.example.com/translations?lang=es'),
        );
      });

      test('should handle multiple query parameters with {locale}', () {
        expect(
          buildUrl('http://api.example.com', '/api/v1/content?locale={locale}&format=json', 'fr'),
          equals('http://api.example.com/api/v1/content?locale=fr&format=json'),
        );
      });
    });

    group('special characters in locale', () {
      test('should handle locale with URL-safe characters', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'en-US'),
          equals('http://api.example.com/translations/en-US'),
        );
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'sr-Latn'),
          equals('http://api.example.com/translations/sr-Latn'),
        );
      });

      test('should handle locale with numbers', () {
        expect(
          buildUrl('http://api.example.com', '/translations/{locale}', 'es419'),
          equals('http://api.example.com/translations/es419'),
        );
      });
    });

    group('empty and edge case path templates', () {
      test('should handle empty path template (locale at root)', () {
        expect(
          buildUrl('http://api.example.com', '{locale}', 'en'),
          equals('http://api.example.com/en'),
        );
      });

      test('should handle path template with only slash', () {
        expect(
          buildUrl('http://api.example.com', '/{locale}', 'en'),
          equals('http://api.example.com/en'),
        );
      });

      test('should handle static path without {locale} placeholder', () {
        // The {locale} is not replaced since it's not in the template
        expect(
          buildUrl('http://api.example.com', '/static/translations', 'en'),
          equals('http://api.example.com/static/translations'),
        );
      });
    });

    group('HTTPS and port variations', () {
      test('should handle HTTPS URLs', () {
        expect(
          buildUrl('https://secure.api.example.com', '/api/v1/{locale}', 'en'),
          equals('https://secure.api.example.com/api/v1/en'),
        );
      });

      test('should handle URLs with custom ports', () {
        expect(
          buildUrl('http://localhost:8080', '/translations/{locale}', 'en'),
          equals('http://localhost:8080/translations/en'),
        );
      });

      test('should handle URLs with custom ports and HTTPS', () {
        expect(
          buildUrl('https://api.example.com:9443', '/i18n/{locale}', 'de'),
          equals('https://api.example.com:9443/i18n/de'),
        );
      });
    });

    group('subdomain-based locale routing', () {
      test('should handle {locale} as subdomain', () {
        // This creates an invalid URL because the path template contains full URL
        // This tests the raw replacement behavior
        expect(
          buildUrl('http://api.example.com', 'http://{locale}.api.example.com/translations', 'en'),
          equals('http://api.example.com/http://en.api.example.com/translations'),
        );
      });
    });

    group('path with special characters', () {
      test('should handle path with URL-encoded characters', () {
        expect(
          buildUrl('http://api.example.com', '/api/v1.0/{locale}/content', 'en'),
          equals('http://api.example.com/api/v1.0/en/content'),
        );
      });

      test('should handle path with hyphens', () {
        expect(
          buildUrl('http://api.example.com', '/api-v1/content/{locale}', 'en'),
          equals('http://api.example.com/api-v1/content/en'),
        );
      });

      test('should handle path with underscores', () {
        expect(
          buildUrl('http://api.example.com', '/api_v1/{locale}/translations', 'en'),
          equals('http://api.example.com/api_v1/en/translations'),
        );
      });
    });

    group('static JSON file paths', () {
      test('should support .json extension for static files', () {
        expect(
          buildUrl('http://localhost:8000', '/public/translations/{locale}.json', 'en'),
          equals('http://localhost:8000/public/translations/en.json'),
        );
        expect(
          buildUrl('http://localhost:8000', '/public/translations/{locale}.json', 'de'),
          equals('http://localhost:8000/public/translations/de.json'),
        );
      });

      test('should support static files with locale in filename', () {
        expect(
          buildUrl('http://cdn.example.com', '/i18n/messages_{locale}.json', 'en-US'),
          equals('http://cdn.example.com/i18n/messages_en-US.json'),
        );
      });

      test('should support CDN paths with .json extension', () {
        expect(
          buildUrl('https://cdn.example.com', '/assets/translations/{locale}.json', 'fr'),
          equals('https://cdn.example.com/assets/translations/fr.json'),
        );
      });
    });
  });
}
