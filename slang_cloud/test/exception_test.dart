import 'package:flutter_test/flutter_test.dart';
import 'package:slang_cloud/src/exception.dart';

void main() {
  group('SlangCloudException', () {
    test('base exception can be instantiated and has correct toString', () {
      final exception = _TestSlangCloudException('Test message', locale: 'en');

      expect(exception.message, 'Test message');
      expect(exception.locale, 'en');
      expect(exception.toString(), 'SlangCloudException: Test message (locale: en)');
    });

    test('base exception works without locale', () {
      final exception = _TestSlangCloudException('Test message');

      expect(exception.message, 'Test message');
      expect(exception.locale, null);
      expect(exception.toString(), 'SlangCloudException: Test message');
    });

    test('base exception includes originalError', () {
      final originalError = Exception('Original');
      final exception = _TestSlangCloudException(
        'Test message',
        locale: 'en',
        originalError: originalError,
      );

      expect(exception.originalError, originalError);
    });
  });

  group('SlangCloudNetworkException', () {
    test('can be instantiated', () {
      final exception = SlangCloudNetworkException('Network failed', locale: 'de');

      expect(exception.message, 'Network failed');
      expect(exception.locale, 'de');
      expect(exception, isA<SlangCloudException>());
    });
  });

  group('SlangCloudTimeoutException', () {
    test('can be instantiated with timeout', () {
      final exception = SlangCloudTimeoutException(
        'Request timed out',
        timeout: Duration(seconds: 30),
        locale: 'fr',
      );

      expect(exception.message, 'Request timed out');
      expect(exception.timeout, Duration(seconds: 30));
      expect(exception.locale, 'fr');
      expect(exception, isA<SlangCloudException>());
    });

    test('can be instantiated without timeout', () {
      final exception = SlangCloudTimeoutException('Request timed out');

      expect(exception.timeout, null);
    });
  });

  group('SlangCloudNotFoundException', () {
    test('can be instantiated', () {
      final exception = SlangCloudNotFoundException('Language not found', locale: 'es');

      expect(exception.message, 'Language not found');
      expect(exception.locale, 'es');
      expect(exception, isA<SlangCloudException>());
    });
  });

  group('SlangCloudUnauthorizedException', () {
    test('can be instantiated', () {
      final exception = SlangCloudUnauthorizedException('Unauthorized', locale: 'it');

      expect(exception.message, 'Unauthorized');
      expect(exception.locale, 'it');
      expect(exception, isA<SlangCloudException>());
    });
  });

  group('SlangCloudForbiddenException', () {
    test('can be instantiated', () {
      final exception = SlangCloudForbiddenException('Forbidden', locale: 'pt');

      expect(exception.message, 'Forbidden');
      expect(exception.locale, 'pt');
      expect(exception, isA<SlangCloudException>());
    });
  });

  group('SlangCloudServerException', () {
    test('can be instantiated with status code', () {
      final exception = SlangCloudServerException(
        'Server error',
        statusCode: 500,
        locale: 'ja',
      );

      expect(exception.message, 'Server error');
      expect(exception.statusCode, 500);
      expect(exception.locale, 'ja');
      expect(exception, isA<SlangCloudException>());
    });

    test('can be instantiated with different status codes', () {
      final exception502 = SlangCloudServerException(
        'Bad Gateway',
        statusCode: 502,
        locale: 'zh',
      );

      expect(exception502.statusCode, 502);
    });
  });

  group('SlangCloudHashMismatchException', () {
    test('can be instantiated with expected and actual hashes', () {
      final exception = SlangCloudHashMismatchException(
        'Hash mismatch',
        expectedHash: 'abc123',
        actualHash: 'def456',
        locale: 'en',
      );

      expect(exception.message, 'Hash mismatch');
      expect(exception.expectedHash, 'abc123');
      expect(exception.actualHash, 'def456');
      expect(exception.locale, 'en');
      expect(exception, isA<SlangCloudException>());
    });

    test('toString includes hash information', () {
      final exception = SlangCloudHashMismatchException(
        'Hash mismatch',
        expectedHash: 'expected',
        actualHash: 'actual',
        locale: 'de',
      );

      expect(
        exception.toString(),
        'SlangCloudHashMismatchException: Hash mismatch (expected: expected, actual: actual, locale: de)',
      );
    });

    test('toString works without locale', () {
      final exception = SlangCloudHashMismatchException(
        'Hash mismatch',
        expectedHash: 'expected',
        actualHash: 'actual',
      );

      expect(
        exception.toString(),
        'SlangCloudHashMismatchException: Hash mismatch (expected: expected, actual: actual, locale: null)',
      );
    });
  });

  group('SlangCloudInvalidResponseException', () {
    test('can be instantiated', () {
      final exception = SlangCloudInvalidResponseException(
        'Invalid JSON',
        locale: 'ru',
        responseBody: '{invalid}',
      );

      expect(exception.message, 'Invalid JSON');
      expect(exception.locale, 'ru');
      expect(exception.responseBody, '{invalid}');
      expect(exception, isA<SlangCloudException>());
    });
  });

  group('SlangCloudCancelledException', () {
    test('can be instantiated', () {
      final exception = SlangCloudCancelledException('Request cancelled', locale: 'ko');

      expect(exception.message, 'Request cancelled');
      expect(exception.locale, 'ko');
      expect(exception, isA<SlangCloudException>());
    });
  });
}

// Test implementation of the abstract base class
class _TestSlangCloudException extends SlangCloudException {
  _TestSlangCloudException(super.message, {super.locale, super.originalError});
}
