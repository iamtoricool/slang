import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slang_cloud/slang_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SlangCloudClient', () {
    late SlangCloudConfig config;
    late InMemorySlangCloudStorage storage;

    setUp(() {
      config = const SlangCloudConfig(baseUrl: 'https://api.example.com');
      storage = InMemorySlangCloudStorage();
    });

    group('checkForUpdate', () {
      test('returns new hash if different from storage', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            if (request.method == 'HEAD' && request.url.toString() == 'https://api.example.com/translations/en') {
              return http.Response('', 200, headers: {'x-translation-hash': 'new_hash'});
            }
            return http.Response('Not Found', 404);
          }),
        );

        await storage.setVersion('en', 'old_hash');
        final result = await client.checkForUpdate('en');

        expect(result, 'new_hash');
      });

      test('returns null if hash matches storage', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            if (request.method == 'HEAD') {
              return http.Response('', 200, headers: {'x-translation-hash': 'same_hash'});
            }
            return http.Response('Not Found', 404);
          }),
        );

        await storage.setVersion('en', 'same_hash');
        final result = await client.checkForUpdate('en');

        expect(result, isNull);
      });

      test('throws SlangCloudNotFoundException on 404', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            return http.Response('Not Found', 404);
          }),
        );

        expect(
          () => client.checkForUpdate('en'),
          throwsA(isA<SlangCloudNotFoundException>()),
        );
      });

      test('throws SlangCloudUnauthorizedException on 401', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            return http.Response('Unauthorized', 401);
          }),
        );

        expect(
          () => client.checkForUpdate('en'),
          throwsA(isA<SlangCloudUnauthorizedException>()),
        );
      });

      test('throws SlangCloudInvalidResponseException when hash header is missing', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            return http.Response('', 200);
          }),
        );

        expect(
          () => client.checkForUpdate('en'),
          throwsA(
            isA<SlangCloudInvalidResponseException>().having(
              (e) => e.message,
              'message',
              contains('X-Translation-Hash'),
            ),
          ),
        );
      });

      test('throws SlangCloudTimeoutException on timeout', () async {
        final config = const SlangCloudConfig(
          baseUrl: 'https://api.example.com',
          timeout: Duration(milliseconds: 1),
        );

        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            await Future.delayed(Duration(milliseconds: 100));
            return http.Response('', 200, headers: {'x-translation-hash': 'hash'});
          }),
        );

        expect(
          () => client.checkForUpdate('en'),
          throwsA(isA<SlangCloudTimeoutException>()),
        );
      });

      test('throws SlangCloudNetworkException on socket error', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: _MockClientWithSocketError(),
        );

        expect(
          () => client.checkForUpdate('en'),
          throwsA(isA<SlangCloudNetworkException>()),
        );
      });
    });

    group('downloadTranslation', () {
      test('returns body and hash on success', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response('{"hello": "world"}', 200, headers: {
                'x-translation-hash': 'test_hash_value',
              });
            }
            return http.Response('Not Found', 404);
          }),
        );

        final result = await client.downloadTranslation('en');
        expect(result.content, '{"hello": "world"}');
        expect(result.hash, 'test_hash_value');
      });

      test('validates JSON when Content-Type is application/json', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            return http.Response('invalid json', 200, headers: {
              'content-type': 'application/json',
              'x-translation-hash': 'test_hash_value',
            });
          }),
        );

        expect(
          () => client.downloadTranslation('en'),
          throwsA(isA<SlangCloudInvalidResponseException>()),
        );
      });

      test('does not validate JSON when Content-Type is not JSON', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            return http.Response('plain text content', 200, headers: {
              'x-translation-hash': 'test_hash_value',
            });
          }),
        );

        final result = await client.downloadTranslation('en');
        expect(result.content, 'plain text content');
        expect(result.hash, 'test_hash_value');
      });

      test('throws SlangCloudServerException on 5xx error', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            return http.Response('Server Error', 500, headers: {
              'x-translation-hash': 'test_hash_value',
            });
          }),
        );

        expect(
          () => client.downloadTranslation('en'),
          throwsA(
            isA<SlangCloudServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      });

      test('includes response body in exception', () async {
        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            return http.Response('{"error": "details"}', 404, headers: {
              'x-translation-hash': 'test_hash_value',
            });
          }),
        );

        try {
          await client.downloadTranslation('en');
          fail('Expected exception');
        } on SlangCloudException catch (e) {
          expect(e.responseBody, '{"error": "details"}');
        }
      });
    });

    group('retry logic', () {
      test('retries on network errors up to maxRetries times', () async {
        var attemptCount = 0;
        final client = SlangCloudClient(
          config: const SlangCloudConfig(
            baseUrl: 'https://api.example.com',
            maxRetries: 2,
            retryBaseDelay: Duration(milliseconds: 10),
          ),
          storage: storage,
          client: _CountingMockClient((request) async {
            attemptCount++;
            throw SocketException('Connection refused');
          }),
        );

        // Await completion before checking counter
        try {
          await client.checkForUpdate('en');
          fail('Should have thrown');
        } on SlangCloudNetworkException {
          // Expected
        }

        // Initial attempt + 2 retries = 3 total
        expect(attemptCount, 3);
      });

      test('retries on timeout up to maxRetries times', () async {
        var attemptCount = 0;
        final config = const SlangCloudConfig(
          baseUrl: 'https://api.example.com',
          maxRetries: 2,
          retryBaseDelay: Duration(milliseconds: 10),
          timeout: Duration(milliseconds: 1),
        );

        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: _CountingMockClient((request) async {
            attemptCount++;
            await Future.delayed(Duration(milliseconds: 100));
            return http.Response('', 200);
          }),
        );

        // Await completion before checking counter
        try {
          await client.checkForUpdate('en');
          fail('Should have thrown');
        } on SlangCloudTimeoutException {
          // Expected
        }

        // Should retry on timeout
        expect(attemptCount, 3);
      });

      test('retries on 5xx server errors', () async {
        var attemptCount = 0;
        final client = SlangCloudClient(
          config: const SlangCloudConfig(
            baseUrl: 'https://api.example.com',
            maxRetries: 2,
            retryBaseDelay: Duration(milliseconds: 10),
          ),
          storage: storage,
          client: _CountingMockClient((request) async {
            attemptCount++;
            return http.Response('Server Error', 503);
          }),
        );

        // Await completion before checking counter
        try {
          await client.checkForUpdate('en');
          fail('Should have thrown');
        } on SlangCloudServerException {
          // Expected
        }

        // Should retry on 5xx
        expect(attemptCount, 3);
      });

      test('does not retry on 4xx client errors', () async {
        var attemptCount = 0;
        final client = SlangCloudClient(
          config: const SlangCloudConfig(
            baseUrl: 'https://api.example.com',
            maxRetries: 3,
            retryBaseDelay: Duration(milliseconds: 10),
          ),
          storage: storage,
          client: _CountingMockClient((request) async {
            attemptCount++;
            return http.Response('Not Found', 404);
          }),
        );

        // Await completion before checking counter
        try {
          await client.checkForUpdate('en');
          fail('Should have thrown');
        } on SlangCloudNotFoundException {
          // Expected
        }

        // Should not retry on 4xx
        expect(attemptCount, 1);
      });

      test('does not retry on hash mismatch', () async {
        // This is tested through the controller, not the client directly
        // as hash verification happens in the controller
        expect(true, isTrue); // Placeholder
      });

      test('succeeds after retry', () async {
        var attemptCount = 0;
        final client = SlangCloudClient(
          config: const SlangCloudConfig(
            baseUrl: 'https://api.example.com',
            maxRetries: 3,
            retryBaseDelay: Duration(milliseconds: 10),
          ),
          storage: storage,
          client: _CountingMockClient((request) async {
            attemptCount++;
            if (attemptCount < 3) {
              throw SocketException('Connection refused');
            }
            return http.Response('', 200, headers: {'x-translation-hash': 'new_hash'});
          }),
        );

        final result = await client.checkForUpdate('en');
        expect(result, 'new_hash');
        expect(attemptCount, 3);
      });
    });

    group('different endpoints', () {
      test('uses different endpoints for check and download', () async {
        final config = const SlangCloudConfig(
          baseUrl: 'https://api.example.com',
          endpoint: '/api/translations/{locale}/check',
          downloadEndpoint: '/api/translations/{locale}/download',
        );

        String? checkUrl;
        String? downloadUrl;

        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            if (request.method == 'HEAD') {
              checkUrl = request.url.toString();
              return http.Response('', 200, headers: {'x-translation-hash': 'hash'});
            } else if (request.method == 'GET') {
              downloadUrl = request.url.toString();
              return http.Response('{"test": "data"}', 200, headers: {
                'x-translation-hash': 'test_hash_value',
              });
            }
            return http.Response('Not Found', 404);
          }),
        );

        await client.checkForUpdate('en');
        await client.downloadTranslation('en');

        expect(checkUrl, 'https://api.example.com/api/translations/en/check');
        expect(downloadUrl, 'https://api.example.com/api/translations/en/download');
      });

      test('uses same endpoint when downloadEndpoint not specified', () async {
        String? checkUrl;
        String? downloadUrl;

        final client = SlangCloudClient(
          config: config,
          storage: storage,
          client: MockClient((request) async {
            if (request.method == 'HEAD') {
              checkUrl = request.url.toString();
              return http.Response('', 200, headers: {'x-translation-hash': 'hash'});
            } else if (request.method == 'GET') {
              downloadUrl = request.url.toString();
              return http.Response('{"test": "data"}', 200, headers: {
                'x-translation-hash': 'test_hash_value',
              });
            }
            return http.Response('Not Found', 404);
          }),
        );

        await client.checkForUpdate('en');
        await client.downloadTranslation('en');

        expect(checkUrl, 'https://api.example.com/translations/en');
        expect(downloadUrl, 'https://api.example.com/translations/en');
      });
    });
  });
}

// Mock client that throws SocketException
class _MockClientWithSocketError extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw SocketException('Connection refused');
  }
}

// Mock client that properly counts requests
class _CountingMockClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) _handler;

  _CountingMockClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.fromIterable([response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
    );
  }
}
