import 'package:flutter_test/flutter_test.dart';
import 'package:slang_cloud/src/config.dart';
import 'package:slang_cloud/src/exception.dart';

void main() {
  group('SlangCloudConfig', () {
    test('uses default values', () {
      const config = SlangCloudConfig(baseUrl: 'https://api.example.com');

      expect(config.baseUrl, 'https://api.example.com');
      expect(config.endpoint, '/translations/{locale}');
      expect(config.downloadEndpoint, '/translations/{locale}');
      expect(config.hashHeader, 'X-Translation-Hash');
      expect(config.headers, isEmpty);
      expect(config.timeout, Duration(seconds: 30));
      expect(config.isFlatMap, false);
      expect(config.maxRetries, 3);
      expect(config.retryBaseDelay, Duration(milliseconds: 500));
      expect(config.hashFunction, isNull);
    });

    test('accepts custom values', () {
      String customHashFunction(String content) => 'custom_$content';

      final config = SlangCloudConfig(
        baseUrl: 'https://custom.example.com',
        endpoint: '/custom/{locale}',
        downloadEndpoint: '/custom/{locale}/download',
        hashHeader: 'Custom-Hash',
        hashFunction: customHashFunction,
        headers: {'Authorization': 'Bearer token'},
        timeout: Duration(seconds: 60),
        isFlatMap: true,
        maxRetries: 5,
        retryBaseDelay: Duration(milliseconds: 1000),
      );

      expect(config.baseUrl, 'https://custom.example.com');
      expect(config.endpoint, '/custom/{locale}');
      expect(config.downloadEndpoint, '/custom/{locale}/download');
      expect(config.hashHeader, 'Custom-Hash');
      expect(config.hashFunction, isNotNull);
      expect(config.headers, {'Authorization': 'Bearer token'});
      expect(config.timeout, Duration(seconds: 60));
      expect(config.isFlatMap, true);
      expect(config.maxRetries, 5);
      expect(config.retryBaseDelay, Duration(milliseconds: 1000));
    });

    test('downloadEndpoint defaults to endpoint when not specified', () {
      const config = SlangCloudConfig(
        baseUrl: 'https://api.example.com',
        endpoint: '/api/{locale}',
      );

      expect(config.downloadEndpoint, '/api/{locale}');
    });

    group('buildUrl', () {
      test('replaces {locale} placeholder', () {
        const config = SlangCloudConfig(
          baseUrl: 'https://api.example.com',
          endpoint: '/translations/{locale}',
        );

        expect(config.buildUrl('en'), 'https://api.example.com/translations/en');
        expect(config.buildUrl('de'), 'https://api.example.com/translations/de');
      });

      test('works with complex paths', () {
        const config = SlangCloudConfig(
          baseUrl: 'https://api.example.com',
          endpoint: '/api/v1/translations/{locale}/check',
        );

        expect(
          config.buildUrl('fr'),
          'https://api.example.com/api/v1/translations/fr/check',
        );
      });
    });

    group('buildDownloadUrl', () {
      test('replaces {locale} placeholder', () {
        const config = SlangCloudConfig(
          baseUrl: 'https://api.example.com',
          downloadEndpoint: '/api/{locale}/download',
        );

        expect(
          config.buildDownloadUrl('en'),
          'https://api.example.com/api/en/download',
        );
      });

      test('uses endpoint when downloadEndpoint is not set', () {
        const config = SlangCloudConfig(
          baseUrl: 'https://api.example.com',
          endpoint: '/translations/{locale}',
        );

        expect(
          config.buildDownloadUrl('en'),
          'https://api.example.com/translations/en',
        );
      });
    });

    group('isRetryableException', () {
      const config = SlangCloudConfig(baseUrl: 'https://api.example.com');

      test('returns true for SlangCloudNetworkException', () {
        final exception = SlangCloudNetworkException('Network error');
        expect(config.isRetryableException(exception), isTrue);
      });

      test('returns true for SlangCloudTimeoutException', () {
        final exception = SlangCloudTimeoutException('Timeout');
        expect(config.isRetryableException(exception), isTrue);
      });

      test('returns true for SlangCloudServerException with 5xx status', () {
        final exception500 = SlangCloudServerException(
          'Server error',
          statusCode: 500,
        );
        final exception502 = SlangCloudServerException(
          'Bad Gateway',
          statusCode: 502,
        );
        final exception503 = SlangCloudServerException(
          'Service Unavailable',
          statusCode: 503,
        );

        expect(config.isRetryableException(exception500), isTrue);
        expect(config.isRetryableException(exception502), isTrue);
        expect(config.isRetryableException(exception503), isTrue);
      });

      test('returns false for SlangCloudServerException with 4xx status', () {
        // This shouldn't happen in practice as 4xx are handled separately,
        // but we test it for completeness
        final exception400 = SlangCloudServerException(
          'Bad Request',
          statusCode: 400,
        );

        expect(config.isRetryableException(exception400), isFalse);
      });

      test('returns false for SlangCloudNotFoundException', () {
        final exception = SlangCloudNotFoundException('Not found');
        expect(config.isRetryableException(exception), isFalse);
      });

      test('returns false for SlangCloudUnauthorizedException', () {
        final exception = SlangCloudUnauthorizedException('Unauthorized');
        expect(config.isRetryableException(exception), isFalse);
      });

      test('returns false for SlangCloudForbiddenException', () {
        final exception = SlangCloudForbiddenException('Forbidden');
        expect(config.isRetryableException(exception), isFalse);
      });

      test('returns false for SlangCloudHashMismatchException', () {
        final exception = SlangCloudHashMismatchException(
          'Hash mismatch',
          expectedHash: 'abc',
          actualHash: 'def',
        );
        expect(config.isRetryableException(exception), isFalse);
      });

      test('returns false for SlangCloudInvalidResponseException', () {
        final exception = SlangCloudInvalidResponseException('Invalid response');
        expect(config.isRetryableException(exception), isFalse);
      });

      test('returns false for SlangCloudCancelledException', () {
        final exception = SlangCloudCancelledException('Cancelled');
        expect(config.isRetryableException(exception), isFalse);
      });
    });
  });
}
