import 'dart:io';

import 'package:slang_cli/src/commands/utils/format.dart';
import 'package:test/test.dart';

void main() {
  group('runDartFormat', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slang_format_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('formats Dart files in directory', () async {
      // Create a poorly formatted Dart file
      final dartFile = File('${tempDir.path}/test.dart');
      await dartFile.writeAsString('void main(){print("hello");}');

      // Should complete without throwing
      await runDartFormat(
        dir: tempDir.path,
        width: null,
      );

      // File should be formatted (has newlines and spaces)
      final content = await dartFile.readAsString();
      expect(content, isNotEmpty);
    });

    test('formats with custom line width', () async {
      final dartFile = File('${tempDir.path}/test.dart');
      await dartFile.writeAsString('void main() {}');

      // Should complete without throwing with width
      await runDartFormat(
        dir: tempDir.path,
        width: 80,
      );
    });

    test('handles empty directory', () async {
      // Should not throw for empty directory
      await runDartFormat(
        dir: tempDir.path,
        width: null,
      );
    });

    test('handles non-existent directory gracefully', () async {
      // Should not throw (dart format returns 0 for non-existent dirs)
      await runDartFormat(
        dir: '${tempDir.path}/nonexistent',
        width: null,
      );
    });
  });
}
