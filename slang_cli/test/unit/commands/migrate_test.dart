import 'dart:convert';
import 'dart:io';

import 'package:slang_cli/src/commands/migrate.dart';
import 'package:test/test.dart';

void main() {
  group('runMigrate', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_migrate_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('throws when less than 3 arguments provided', () async {
      expect(
        () => runMigrate(['arb']),
        throwsA(contains('3 arguments')),
      );

      expect(
        () => runMigrate(['arb', 'source']),
        throwsA(contains('3 arguments')),
      );
    });

    test('throws for unknown migration type', () async {
      expect(
        () => runMigrate(['unknown', 'source', 'dest']),
        throwsA(contains('Unknown migration type')),
      );
    });

    test('delegates ARB migration correctly', () async {
      // Create a source ARB file
      final sourceFile = File('${tempDir.path}/app_en.arb');
      await sourceFile.writeAsString(jsonEncode({
        '@@locale': 'en',
        'hello': 'Hello',
      }));

      final destFile = File('${tempDir.path}/output.json');

      // Should complete without throwing
      await runMigrate([
        'arb',
        sourceFile.path,
        destFile.path,
      ]);

      // Verify output was created
      expect(await destFile.exists(), isTrue);

      final content = await destFile.readAsString();
      final json = jsonDecode(content);
      expect(json['@@locale'], 'en');
    });

    test('handles empty ARB file', () async {
      final sourceFile = File('${tempDir.path}/empty.arb');
      await sourceFile.writeAsString(jsonEncode({}));

      final destFile = File('${tempDir.path}/empty_output.json');

      await runMigrate([
        'arb',
        sourceFile.path,
        destFile.path,
      ]);

      expect(await destFile.exists(), isTrue);
    });

    test('throws for non-existent source file', () async {
      final destFile = File('${tempDir.path}/output.json');

      expect(
        () => runMigrate([
          'arb',
          '${tempDir.path}/nonexistent.arb',
          destFile.path,
        ]),
        throwsA(anything),
      );
    });
  });
}
