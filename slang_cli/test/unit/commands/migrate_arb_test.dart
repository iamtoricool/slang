import 'package:slang_cli/src/commands/migrate_arb.dart';
import 'package:test/test.dart';

void main() {
  group('migrateArb', () {
    test('should migrate simple ARB file', () {
      final arbContent = '''
{
  "@@locale": "en",
  "hello": "Hello",
  "world": "World"
}
''';

      final result = migrateArb(arbContent, false);

      expect(result['hello'], 'Hello');
      expect(result['world'], 'World');
    });

    test('should convert placeholders to slang format', () {
      final arbContent = '''
{
  "greeting": "Hello {name}!",
  "@greeting": {
    "description": "A greeting message",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  }
}
''';

      final result = migrateArb(arbContent, false);

      expect(result['greeting'], 'Hello {name}!');
    });

    test('should handle plural translations', () {
      final arbContent = '''
{
  "itemCount": "{count, plural, =0{No items} =1{One item} other{{count} items}}",
  "@itemCount": {
    "description": "Number of items"
  }
}
''';

      final result = migrateArb(arbContent, false);

      // ARB keys are split by camelCase: "itemCount" -> "item" + "count"
      // Plurals are stored under (param=variable) sub-key
      expect(result['item']['count(param=count)']['zero'], 'No items');
      expect(result['item']['count(param=count)']['one'], 'One item');
      expect(result['item']['count(param=count)']['other'], '{count} items');
    });

    test('should handle select/context translations', () {
      final arbContent = '''
{
  "gender": "{gender, select, male{He} female{She} other{They}}",
  "@gender": {
    "description": "Gender selector"
  }
}
''';

      final result = migrateArb(arbContent, false);

      // 'gender' is not camelCase, so it stays as 'gender'
      expect(result['gender(param=gender)']['male'], 'He');
      expect(result['gender(param=gender)']['female'], 'She');
      expect(result['gender(param=gender)']['other'], 'They');
    });

    test('should preserve meta entries (@@ prefixed)', () {
      final arbContent = '''
{
  "@@locale": "en",
  "@@author": "Test Author",
  "hello": "Hello"
}
''';

      final result = migrateArb(arbContent, false);

      expect(result['@@locale'], 'en');
      expect(result['@@author'], 'Test Author');
      expect(result['hello'], 'Hello');
    });

    test('should convert camelCase to nested structure', () {
      final arbContent = '''
{
  "homePageTitle": "Home",
  "homePageSubtitle": "Welcome"
}
''';

      final result = migrateArb(arbContent, false);

      // camelCase is split: "homePageTitle" -> "home" + "page" + "title"
      expect(result['home']['page']['title'], 'Home');
      expect(result['home']['page']['subtitle'], 'Welcome');
    });

    test('should handle nested placeholders', () {
      final arbContent = '''
{
  "message": "{user} has {count, plural, =1{one message} other{{count} messages}}",
  "@message": {
    "description": "User message count"
  }
}
''';

      // Should not throw
      final result = migrateArb(arbContent, false);
      expect(result, isA<Map<String, dynamic>>());
    });

    test('should throw for non-object ARB content', () {
      final arbContent = '''
[
  "invalid",
  "content"
]
''';

      expect(
        () => migrateArb(arbContent, false),
        throwsA(contains('ARB files must be a JSON object')),
      );
    });

    test('should handle empty ARB file', () {
      final arbContent = '''
{
  "@@locale": "en"
}
''';

      final result = migrateArb(arbContent, false);

      expect(result['@@locale'], 'en');
    });

    test('should throw for nested object values', () {
      final arbContent = '''
{
  "@@locale": "en",
  "app": {
    "title": "My App",
    "description": "A great app"
  }
}
''';

      // ARB migration does not support nested object values
      // Values must be strings (or meta entries)
      expect(
        () => migrateArb(arbContent, false),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
