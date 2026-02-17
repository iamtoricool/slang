import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slang_cloud/slang_cloud.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SlangCloudClient', () {
    late SlangCloudConfig config;
    late InMemorySlangCloudStorage storage;

    setUp(() {
      config = SlangCloudConfig(baseUrl: 'https://api.example.com');
      storage = InMemorySlangCloudStorage();
    });

    test('checkForUpdate returns new hash if different from storage', () async {
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

    test('checkForUpdate returns null if hash matches storage', () async {
      final client = SlangCloudClient(
        config: config,
        storage: storage,
        client: MockClient((request) async {
          if (request.method == 'HEAD' && request.url.toString() == 'https://api.example.com/translations/en') {
            return http.Response('', 200, headers: {'x-translation-hash': 'same_hash'});
          }
          return http.Response('Not Found', 404);
        }),
      );

      await storage.setVersion('en', 'same_hash');
      final result = await client.checkForUpdate('en');

      expect(result, isNull);
    });

    test('fetchTranslation returns body on success', () async {
      final client = SlangCloudClient(
        config: config,
        storage: storage,
        client: MockClient((request) async {
          if (request.method == 'GET' && request.url.toString() == 'https://api.example.com/translations/en') {
            return http.Response('{"hello": "world"}', 200);
          }
          return http.Response('Not Found', 404);
        }),
      );

      final result = await client.fetchTranslation('en');
      expect(result, '{"hello": "world"}');
    });
  });
}
