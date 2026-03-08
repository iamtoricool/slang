import 'package:slang_cli/src/commands/utils/dart_analysis_ext.dart';
import 'package:test/test.dart';

void main() {
  group('DartAnalysisExt.sanitizeDartFileForAnalysis', () {
    test('removes single-line comments', () {
      final code = '''
void main() {
  // This is a comment
  print('hello');
}
''';
      final result = code.sanitizeDartFileForAnalysis(removeSpaces: false);
      expect(result.contains('//'), isFalse);
      expect(result.contains('This is a comment'), isFalse);
      expect(result.contains("print('hello')"), isTrue);
    });

    test('removes multi-line comments', () {
      final code = '''
void main() {
  /* This is a
     multi-line comment */
  print('hello');
}
''';
      final result = code.sanitizeDartFileForAnalysis(removeSpaces: false);
      expect(result.contains('/*'), isFalse);
      expect(result.contains('*/'), isFalse);
      expect(result.contains('multi-line comment'), isFalse);
      expect(result.contains("print('hello')"), isTrue);
    });

    test('removes spaces when removeSpaces is true', () {
      final code = 'void main() { print("hello"); }';
      final result = code.sanitizeDartFileForAnalysis(removeSpaces: true);
      expect(result.contains(' '), isFalse);
      expect(result, 'voidmain(){print("hello");}');
    });

    test('preserves spaces when removeSpaces is false', () {
      final code = 'void main() { print("hello"); }';
      final result = code.sanitizeDartFileForAnalysis(removeSpaces: false);
      expect(result.contains(' '), isTrue);
      expect(result, 'void main() { print("hello"); }');
    });

    test('handles code without comments', () {
      final code = 'void main() {}';
      final result = code.sanitizeDartFileForAnalysis(removeSpaces: true);
      expect(result, 'voidmain(){}');
    });

    test('handles empty string', () {
      final result = ''.sanitizeDartFileForAnalysis(removeSpaces: false);
      expect(result, '');
    });

    test('removes multiple comments', () {
      final code = '''
// First comment
void main() {
  // Second comment
  print('hello'); // Third comment
}
/* Multi-line
   comment */
''';
      final result = code.sanitizeDartFileForAnalysis(removeSpaces: false);
      expect(result.contains('//'), isFalse);
      expect(result.contains('/*'), isFalse);
      expect(result.contains('First comment'), isFalse);
      expect(result.contains('Second comment'), isFalse);
      expect(result.contains('Third comment'), isFalse);
      expect(result.contains('Multi-line'), isFalse);
    });

    test('handles complex nested structures', () {
      final code = '''
class MyClass {
  /* Comment about method */
  void myMethod() {
    // Inner comment
    final x = 1;
  }
}
''';
      final result = code.sanitizeDartFileForAnalysis(removeSpaces: true);
      expect(result.contains('/*'), isFalse);
      expect(result.contains('//'), isFalse);
      expect(result.contains('Comment'), isFalse);
      expect(result.contains(' '), isFalse);
    });
  });
}
