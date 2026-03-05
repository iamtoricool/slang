import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slang_flutter/slang_flutter.dart';

void main() {
  group('RichTextParser', () {
    group('hasInterpolation', () {
      test('returns true for simple interpolation', () {
        expect(
          RichTextParser.hasInterpolation(r'Hello ${name}'),
          isTrue,
        );
      });

      test('returns true for interpolation with reference', () {
        expect(
          RichTextParser.hasInterpolation(
              r"Don't have an account? ${getStarted(@:action.getStarted)}"),
          isTrue,
        );
      });

      test('returns false for plain text', () {
        expect(
          RichTextParser.hasInterpolation('Hello World'),
          isFalse,
        );
      });

      test('returns false for escaped interpolation', () {
        expect(
          RichTextParser.hasInterpolation(r'Hello \${name}'),
          isFalse,
        );
      });
    });

    group('parse', () {
      late TranslationMetadata meta;

      setUp(() {
        final locale = FakeAppLocale(languageCode: 'en');
        final translations = FakeTranslations(
          locale,
          overrides: {},
        );
        meta = translations.$meta;
      });

      test('parses plain text without interpolation', () {
        final result = RichTextParser.parse(
          input: 'Hello World',
          meta: meta,
          builders: {},
        );

        expect(result.children, isNull);
        expect(result.text, 'Hello World');
      });

      test('parses text with builder parameter', () {
        InlineSpanBuilder getStartedBuilder = (text) => TextSpan(
            text: text, style: const TextStyle(color: Color(0xFF0000FF)));

        final result = RichTextParser.parse(
          input: r"Don't have an account? ${getStarted}",
          meta: meta,
          builders: {'getStarted': getStartedBuilder},
        );

        expect(result.children, hasLength(2));
        expect((result.children![0] as TextSpan).text,
            "Don't have an account? ");
        expect((result.children![1] as TextSpan).text, "");
      });

      test('parses text with builder and @:reference', () {
        // Create a translation with the reference value
        final locale = FakeAppLocale(languageCode: 'en');
        final translations = FakeTranslations(
          locale,
          overrides: {},
        );
        // Add flat map function that provides reference values
        translations.$meta.setFlatMapFunction((path) {
          if (path == 'action.getStarted') return 'Get Started';
          return null;
        });
        meta = translations.$meta;

        InlineSpanBuilder getStartedBuilder = (text) => TextSpan(
            text: text, style: const TextStyle(color: Color(0xFF0000FF)));

        final result = RichTextParser.parse(
          input: r"Don't have an account? ${getStarted(@:action.getStarted)}",
          meta: meta,
          builders: {'getStarted': getStartedBuilder},
        );

        expect(result.children, hasLength(2));
        expect((result.children![0] as TextSpan).text,
            "Don't have an account? ");
        expect((result.children![1] as TextSpan).text, "Get Started");
      });

      test('keeps unknown parameters as-is', () {
        final result = RichTextParser.parse(
          input: r'Hello ${unknownParam}',
          meta: meta,
          builders: {},
        );

        expect(result.children, hasLength(2));
        expect((result.children![0] as TextSpan).text, 'Hello ');
        expect((result.children![1] as TextSpan).text, r'${unknownParam}');
      });

      test('handles multiple interpolations', () {
        InlineSpanBuilder linkBuilder =
            (text) => TextSpan(text: text, style: const TextStyle());

        final result = RichTextParser.parse(
          input: r'Click ${here} to ${action}',
          meta: meta,
          builders: {'here': linkBuilder, 'action': linkBuilder},
        );

        expect(result.children, hasLength(4));
        expect((result.children![0] as TextSpan).text, 'Click ');
        expect((result.children![2] as TextSpan).text, ' to ');
      });

      test('handles variable spans', () {
        final result = RichTextParser.parse(
          input: r'Hello ${name}',
          meta: meta,
          builders: {
            'name': const TextSpan(text: 'World'),
          },
        );

        expect(result.children, hasLength(2));
        expect((result.children![0] as TextSpan).text, 'Hello ');
        expect((result.children![1] as TextSpan).text, 'World');
      });
    });

    group('edge cases', () {
      late TranslationMetadata meta;

      setUp(() {
        final locale = FakeAppLocale(languageCode: 'en');
        final translations = FakeTranslations(
          locale,
          overrides: {},
        );
        meta = translations.$meta;
      });

      test('handles empty string', () {
        final result = RichTextParser.parse(
          input: '',
          meta: meta,
          builders: {},
        );

        expect(result.text, '');
        expect(result.children, isNull);
      });

      test('handles only interpolation without surrounding text', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: text.toUpperCase());

        final result = RichTextParser.parse(
          input: r'${action}',
          meta: meta,
          builders: {'action': builder},
        );

        expect(result.children, hasLength(1));
        expect((result.children![0] as TextSpan).text, '');
      });

      test('handles multiple consecutive interpolations without text between', () {
        InlineSpanBuilder builder1 = (text) => TextSpan(text: 'A');
        InlineSpanBuilder builder2 = (text) => TextSpan(text: 'B');

        final result = RichTextParser.parse(
          input: r'${first}${second}',
          meta: meta,
          builders: {'first': builder1, 'second': builder2},
        );

        expect(result.children, hasLength(2));
        expect((result.children![0] as TextSpan).text, 'A');
        expect((result.children![1] as TextSpan).text, 'B');
      });

      test('handles interpolation at start of string', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: 'Bold');

        final result = RichTextParser.parse(
          input: r'${prefix} text follows',
          meta: meta,
          builders: {'prefix': builder},
        );

        expect(result.children, hasLength(2));
        expect((result.children![0] as TextSpan).text, 'Bold');
        expect((result.children![1] as TextSpan).text, ' text follows');
      });

      test('handles interpolation at end of string', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: 'End');

        final result = RichTextParser.parse(
          input: r'Text precedes ${suffix}',
          meta: meta,
          builders: {'suffix': builder},
        );

        expect(result.children, hasLength(2));
        expect((result.children![0] as TextSpan).text, 'Text precedes ');
        expect((result.children![1] as TextSpan).text, 'End');
      });

      test('handles whitespace in parameter names', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: 'Value');

        final result = RichTextParser.parse(
          input: r'${ spacedName }',
          meta: meta,
          builders: {'spacedName': builder},
        );

        expect(result.children, hasLength(1));
        expect((result.children![0] as TextSpan).text, 'Value');
      });

      test('handles empty argument in interpolation', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: '[$text]');

        final result = RichTextParser.parse(
          input: r'${builder()}',
          meta: meta,
          builders: {'builder': builder},
        );

        expect(result.children, hasLength(1));
        expect((result.children![0] as TextSpan).text, '[]');
      });

      test('handles nested parentheses in argument', () {
        // Setup flatMapFunction to handle reference lookups
        meta.setFlatMapFunction((path) => null);
        InlineSpanBuilder builder = (text) => TextSpan(text: text);

        final result = RichTextParser.parse(
          input: r'${link(@:path.to(nested))}',
          meta: meta,
          builders: {'link': builder},
        );

        expect(result.children, hasLength(1));
        expect((result.children![0] as TextSpan).text, '@:path.to(nested)');
      });

      test('handles unresolved @: reference gracefully', () {
        // Setup flatMapFunction that returns null for unresolved paths
        meta.setFlatMapFunction((path) => null);
        InlineSpanBuilder builder = (text) => TextSpan(text: '[$text]');

        final result = RichTextParser.parse(
          input: r'${link(@:nonexistent.path)}',
          meta: meta,
          builders: {'link': builder},
        );

        expect(result.children, hasLength(1));
        // Should keep the original reference string when not found
        expect((result.children![0] as TextSpan).text, '[@:nonexistent.path]');
      });

      test('handles special characters in text', () {
        final result = RichTextParser.parse(
          input: r'Hello! @#$%^&*() World',
          meta: meta,
          builders: {},
        );

        // Special characters are kept as-is (no regex escaping needed)
        expect(result.text, r'Hello! @#$%^&*() World');
      });

      test('handles unicode characters', () {
        final result = RichTextParser.parse(
          input: r'Hello ${emoji} World',
          meta: meta,
          builders: {'emoji': const TextSpan(text: '🎉')},
        );

        expect(result.children, hasLength(3));
        expect((result.children![1] as TextSpan).text, '🎉');
      });

      test('handles newlines in text', () {
        InlineSpanBuilder builder = (text) => const TextSpan(text: 'End');

        final result = RichTextParser.parse(
          input: 'Line 1\nLine 2\n\${value}',
          meta: meta,
          builders: {'value': builder},
        );

        expect(result.children, hasLength(2));
        expect((result.children![0] as TextSpan).text, 'Line 1\nLine 2\n');
      });

      test('handles escaped dollar sign', () {
        final result = RichTextParser.parse(
          input: r'Price: \${amount}',
          meta: meta,
          builders: {},
        );

        expect(result.text, r'Price: ${amount}');
      });

      test('handles escaped @: reference marker', () {
        final result = RichTextParser.parse(
          input: r'Contact \@:support for help',
          meta: meta,
          builders: {},
        );

        expect(result.text, r'Contact @:support for help');
      });

      test('handles mixed escaped and unescaped interpolations', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: 'VAL');

        final result = RichTextParser.parse(
          input: r'\${escaped} ${real} \${alsoEscaped}',
          meta: meta,
          builders: {'real': builder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![0] as TextSpan).text, r'${escaped} ');
        expect((result.children![1] as TextSpan).text, 'VAL');
        // The trailing escaped interpolation is combined with the text after VAL
        expect((result.children![2] as TextSpan).text, r' ${alsoEscaped}');
      });

      test('handles builder returning WidgetSpan', () {
        InlineSpanBuilder widgetBuilder = (text) => WidgetSpan(
              child: SizedBox.shrink(),
              alignment: PlaceholderAlignment.middle,
            );

        final result = RichTextParser.parse(
          input: r'Text ${widget} more',
          meta: meta,
          builders: {'widget': widgetBuilder},
        );

        expect(result.children, hasLength(3));
        expect(result.children![1], isA<WidgetSpan>());
      });

      test('handles very long input string', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: 'X');
        final longText = 'A' * 10000;

        final result = RichTextParser.parse(
          input: '${longText}${r'${var}'}',
          meta: meta,
          builders: {'var': builder},
        );

        expect(result.children, hasLength(2));
        expect((result.children![0] as TextSpan).text, longText);
      });

      test('handles single character interpolation', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: 'B');

        final result = RichTextParser.parse(
          input: r'A${x}C',
          meta: meta,
          builders: {'x': builder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![0] as TextSpan).text, 'A');
        expect((result.children![1] as TextSpan).text, 'B');
        expect((result.children![2] as TextSpan).text, 'C');
      });

      test('handles builder with styled TextSpan', () {
        InlineSpanBuilder styledBuilder = (text) => TextSpan(
              text: text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontSize: 16,
              ),
            );

        final result = RichTextParser.parse(
          input: r'Click ${here} to continue',
          meta: meta,
          builders: {'here': styledBuilder},
        );

        expect(result.children, hasLength(3));
        final styledSpan = result.children![1] as TextSpan;
        expect(styledSpan.text, '');
        expect(styledSpan.style!.fontWeight, FontWeight.bold);
        expect(styledSpan.style!.color, Colors.blue);
      });

      test('handles deeply nested @: reference paths', () {
        final locale = FakeAppLocale(languageCode: 'en');
        final translations = FakeTranslations(
          locale,
          overrides: {},
        );
        translations.$meta.setFlatMapFunction((path) {
          if (path == 'a.very.deeply.nested.path.value') return 'Found!';
          return null;
        });
        meta = translations.$meta;

        InlineSpanBuilder builder = (text) => TextSpan(text: text);

        final result = RichTextParser.parse(
          input: r'Value: ${ref(@:a.very.deeply.nested.path.value)}',
          meta: meta,
          builders: {'ref': builder},
        );

        expect(result.children, hasLength(2));
        expect((result.children![1] as TextSpan).text, 'Found!');
      });

      test('handles builder returning different text than input', () {
        InlineSpanBuilder transformativeBuilder = (text) => TextSpan(
              text: text.isEmpty ? 'EMPTY' : 'PREFIX:$text:SUFFIX',
            );

        final result = RichTextParser.parse(
          input: r'Start ${transform(someValue)} End',
          meta: meta,
          builders: {'transform': transformativeBuilder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![1] as TextSpan).text, 'PREFIX:someValue:SUFFIX');
      });

      test('handles interpolation with curly braces in argument', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: text);

        final result = RichTextParser.parse(
          input: r'${link(@:{complex.key})}',
          meta: meta,
          builders: {'link': builder},
        );

        // Note: The regex-based parser has limitations with curly braces inside arguments.
        // The ${...} pattern uses non-greedy matching, so it stops at the first }.
        // The remaining text after the match is treated as literal text.
        expect(result.children, hasLength(2));
        expect((result.children![1] as TextSpan).text, ')}');
      });

      test('handles multiple builders with different return values', () {
        InlineSpanBuilder boldBuilder = (text) => TextSpan(
              text: text,
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
        InlineSpanBuilder italicBuilder = (text) => TextSpan(
              text: text,
              style: const TextStyle(fontStyle: FontStyle.italic),
            );

        final result = RichTextParser.parse(
          input: r'${bold} and ${italic}',
          meta: meta,
          builders: {'bold': boldBuilder, 'italic': italicBuilder},
        );

        expect(result.children, hasLength(3));
        final boldSpan = result.children![0] as TextSpan;
        final italicSpan = result.children![2] as TextSpan;
        expect(boldSpan.style!.fontWeight, FontWeight.bold);
        expect(italicSpan.style!.fontStyle, FontStyle.italic);
      });

      test('handles builder that ignores input text', () {
        InlineSpanBuilder staticBuilder = (text) =>
            const TextSpan(text: 'STATIC');

        final result = RichTextParser.parse(
          input: r'${link(anything)}',
          meta: meta,
          builders: {'link': staticBuilder},
        );

        expect((result.children![0] as TextSpan).text, 'STATIC');
      });

      test('handles tab characters in text', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: 'X');

        final result = RichTextParser.parse(
          input: 'Col1\t\${val}\tCol3',
          meta: meta,
          builders: {'val': builder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![0] as TextSpan).text, 'Col1\t');
        expect((result.children![2] as TextSpan).text, '\tCol3');
      });

      test('handles double quotes in text', () {
        final result = RichTextParser.parse(
          input: r'He said "${quote}"',
          meta: meta,
          builders: {'quote': const TextSpan(text: 'Hello')},
        );

        // The parser treats the trailing `"` as separate text
        expect(result.children, hasLength(3));
        expect((result.children![0] as TextSpan).text, 'He said "');
        expect((result.children![1] as TextSpan).text, 'Hello');
        expect((result.children![2] as TextSpan).text, '"');
      });

      test('handles single quotes in text', () {
        final result = RichTextParser.parse(
          input: r"It's ${value}'s item",
          meta: meta,
          builders: {'value': const TextSpan(text: 'John')},
        );

        // The text after interpolation is split into a separate span
        expect(result.children, hasLength(3));
        expect((result.children![0] as TextSpan).text, "It's ");
        expect((result.children![1] as TextSpan).text, "John");
        expect((result.children![2] as TextSpan).text, "'s item");
      });

      test('handles backslash characters', () {
        final result = RichTextParser.parse(
          input: r'Path: C:\Users\${name}',
          meta: meta,
          builders: {'name': const TextSpan(text: 'Admin')},
        );

        // The backslash before ${name} escapes the $, so no interpolation occurs
        // The unescape function converts \ to \ and \${ to ${
        expect(result.text, r'Path: C:\Users${name}');
      });

      test('handles interpolations with numbers in names', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: text);

        final result = RichTextParser.parse(
          input: r'${item1} and ${item2}',
          meta: meta,
          builders: {'item1': builder, 'item2': builder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![0] as TextSpan).text, '');
        expect((result.children![1] as TextSpan).text, ' and ');
      });

      test('handles empty builders map', () {
        final result = RichTextParser.parse(
          input: r'Plain text without builders',
          meta: meta,
          builders: {},
        );

        expect(result.text, 'Plain text without builders');
      });

      test('handles only escaped interpolations', () {
        final result = RichTextParser.parse(
          input: r'\${not} \${parsed}',
          meta: meta,
          builders: {},
        );

        expect(result.text, r'${not} ${parsed}');
      });

      test('handles rich text with nested TextSpan children', () {
        InlineSpanBuilder complexBuilder = (text) => TextSpan(
              text: 'Outer',
              children: [
                TextSpan(text: 'Inner1'),
                TextSpan(text: text),
                TextSpan(text: 'Inner2'),
              ],
            );

        final result = RichTextParser.parse(
          input: r'Start ${complex(value)} End',
          meta: meta,
          builders: {'complex': complexBuilder},
        );

        expect(result.children, hasLength(3));
        final middleSpan = result.children![1] as TextSpan;
        expect(middleSpan.children, hasLength(3));
        expect((middleSpan.children![1] as TextSpan).text, 'value');
      });

      test('handles multiple @: references in same input', () {
        final locale = FakeAppLocale(languageCode: 'en');
        final translations = FakeTranslations(
          locale,
          overrides: {},
        );
        translations.$meta.setFlatMapFunction((path) {
          if (path == 'a') return 'First';
          if (path == 'b') return 'Second';
          return null;
        });
        meta = translations.$meta;

        InlineSpanBuilder refBuilder = (text) => TextSpan(text: '[$text]');

        final result = RichTextParser.parse(
          input: r'${ref(@:a)} and ${ref(@:b)}',
          meta: meta,
          builders: {'ref': refBuilder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![0] as TextSpan).text, '[First]');
        expect((result.children![2] as TextSpan).text, '[Second]');
      });

      test('handles mixed known and unknown parameters', () {
        InlineSpanBuilder knownBuilder = (text) => TextSpan(text: 'KNOWN');

        final result = RichTextParser.parse(
          input: r'${known} ${unknown} ${known}',
          meta: meta,
          builders: {'known': knownBuilder},
        );

        expect(result.children, hasLength(5));
        expect((result.children![0] as TextSpan).text, 'KNOWN');
        expect((result.children![1] as TextSpan).text, ' ');
        expect((result.children![2] as TextSpan).text, r'${unknown}');
        expect((result.children![3] as TextSpan).text, ' ');
        expect((result.children![4] as TextSpan).text, 'KNOWN');
      });

      test('handles parameter names with underscores', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: text);

        final result = RichTextParser.parse(
          input: r'${first_name} ${last_name}',
          meta: meta,
          builders: {'first_name': builder, 'last_name': builder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![0] as TextSpan).text, '');
        expect((result.children![1] as TextSpan).text, ' ');
        expect((result.children![2] as TextSpan).text, '');
      });

      test('handles parameter names starting with numbers (if valid)', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: 'X');

        final result = RichTextParser.parse(
          input: r'A${n1}B',
          meta: meta,
          builders: {'n1': builder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![1] as TextSpan).text, 'X');
      });

      test('handles case sensitivity in parameter names', () {
        InlineSpanBuilder lowerBuilder = (text) => TextSpan(text: 'lower');
        InlineSpanBuilder upperBuilder = (text) => TextSpan(text: 'UPPER');

        final result = RichTextParser.parse(
          input: r'${name} ${NAME}',
          meta: meta,
          builders: {'name': lowerBuilder, 'NAME': upperBuilder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![0] as TextSpan).text, 'lower');
        expect((result.children![2] as TextSpan).text, 'UPPER');
      });

      test('handles empty argument with @: prefix', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: '[$text]');

        final result = RichTextParser.parse(
          input: r'${link(@:)}',
          meta: meta,
          builders: {'link': builder},
        );

        expect(result.children, hasLength(1));
        expect((result.children![0] as TextSpan).text, '[@:]');
      });

      test('handles argument with spaces', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: '[$text]');

        final result = RichTextParser.parse(
          input: r'${link(  some value  )}',
          meta: meta,
          builders: {'link': builder},
        );

        expect(result.children, hasLength(1));
        expect((result.children![0] as TextSpan).text, '[some value]');
      });

      test('handles builder name collision with reference path', () {
        // Setup where builder name matches a reference path component
        final locale = FakeAppLocale(languageCode: 'en');
        final translations = FakeTranslations(
          locale,
          overrides: {},
        );
        translations.$meta.setFlatMapFunction((path) {
          if (path == 'action') return 'ActionValue';
          return null;
        });
        meta = translations.$meta;

        InlineSpanBuilder actionBuilder = (text) => TextSpan(text: 'Builder:$text');

        final result = RichTextParser.parse(
          input: r'${action(@:action)}',
          meta: meta,
          builders: {'action': actionBuilder},
        );

        expect(result.children, hasLength(1));
        expect((result.children![0] as TextSpan).text, 'Builder:ActionValue');
      });

      test('handles rapid successive parsing calls', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: text);

        for (int i = 0; i < 100; i++) {
          final result = RichTextParser.parse(
            input: r'${value}',
            meta: meta,
            builders: {'value': builder},
          );
          expect((result.children![0] as TextSpan).text, '');
        }
      });

      test('handles builder that returns null text', () {
        InlineSpanBuilder nullTextBuilder = (text) => TextSpan(text: null);

        final result = RichTextParser.parse(
          input: r'Start ${nullText} End',
          meta: meta,
          builders: {'nullText': nullTextBuilder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![1] as TextSpan).text, isNull);
      });

      test('handles argument containing special regex characters', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: text);

        final result = RichTextParser.parse(
          input: r'${link(.*+?^$[])}',
          meta: meta,
          builders: {'link': builder},
        );

        expect(result.children, hasLength(1));
        expect((result.children![0] as TextSpan).text, '.*+?^\$[]');
      });

      test('handles text with only whitespace and interpolation', () {
        InlineSpanBuilder builder = (text) => TextSpan(text: 'X');

        final result = RichTextParser.parse(
          input: '   \${value}   ',
          meta: meta,
          builders: {'value': builder},
        );

        expect(result.children, hasLength(3));
        expect((result.children![0] as TextSpan).text, '   ');
        expect((result.children![2] as TextSpan).text, '   ');
      });

      test('handles CRLF line endings', () {
        final result = RichTextParser.parse(
          input: 'Line1\r\nLine2',
          meta: meta,
          builders: {},
        );

        expect(result.text, 'Line1\r\nLine2');
      });

      test('handles input that looks like but is not interpolation', () {
        // These look like interpolations but use wrong characters
        final result = RichTextParser.parse(
          input: r'(param) [param] <param> %param%',
          meta: meta,
          builders: {},
        );

        expect(result.text, r'(param) [param] <param> %param%');
      });
    });

    group('interpolation modes', () {
      late TranslationMetadata meta;

      setUp(() {
        final locale = FakeAppLocale(languageCode: 'en');
        final translations = FakeTranslations(
          locale,
          overrides: {},
        );
        meta = translations.$meta;
      });

      group('braces mode', () {
        test('parses {param} syntax', () {
          InlineSpanBuilder builder = (text) => TextSpan(text: 'VALUE');

          final result = RichTextParser.parse(
            input: 'Hello {name}',
            meta: meta,
            builders: {'name': builder},
            mode: RichTextInterpolationMode.braces,
          );

          expect(result.children, hasLength(2));
          expect((result.children![0] as TextSpan).text, 'Hello ');
          expect((result.children![1] as TextSpan).text, 'VALUE');
        });

        test('handles escaped braces', () {
          final result = RichTextParser.parse(
            input: r'Not \{parsed} as interpolation',
            meta: meta,
            builders: {},
            mode: RichTextInterpolationMode.braces,
          );

          expect(result.text, 'Not {parsed} as interpolation');
        });

        test('does not detect dart syntax in braces mode', () {
          // ${name} should NOT be parsed in braces mode
          final result = RichTextParser.parse(
            input: r'Hello ${name}',
            meta: meta,
            builders: {},
            mode: RichTextInterpolationMode.braces,
          );

          expect(result.text, r'Hello ${name}');
        });

        test('hasInterpolation detects braces syntax', () {
          expect(
            RichTextParser.hasInterpolation('{param}', mode: RichTextInterpolationMode.braces),
            isTrue,
          );
          expect(
            RichTextParser.hasInterpolation(r'\{param}', mode: RichTextInterpolationMode.braces),
            isFalse,
          );
        });
      });

      group('doubleBraces mode', () {
        test('parses {{param}} syntax', () {
          InlineSpanBuilder builder = (text) => TextSpan(text: 'VALUE');

          final result = RichTextParser.parse(
            input: 'Hello {{name}}',
            meta: meta,
            builders: {'name': builder},
            mode: RichTextInterpolationMode.doubleBraces,
          );

          expect(result.children, hasLength(2));
          expect((result.children![0] as TextSpan).text, 'Hello ');
          expect((result.children![1] as TextSpan).text, 'VALUE');
        });

        test('handles escaped double braces', () {
          final result = RichTextParser.parse(
            input: r'Not \{{parsed}} as interpolation',
            meta: meta,
            builders: {},
            mode: RichTextInterpolationMode.doubleBraces,
          );

          expect(result.text, 'Not {{parsed}} as interpolation');
        });

        test('does not detect single braces in doubleBraces mode', () {
          // {name} should NOT be parsed in doubleBraces mode
          final result = RichTextParser.parse(
            input: 'Hello {name}',
            meta: meta,
            builders: {},
            mode: RichTextInterpolationMode.doubleBraces,
          );

          expect(result.text, 'Hello {name}');
        });

        test('hasInterpolation detects double braces syntax', () {
          expect(
            RichTextParser.hasInterpolation('{{param}}', mode: RichTextInterpolationMode.doubleBraces),
            isTrue,
          );
          expect(
            RichTextParser.hasInterpolation(r'\{{param}}', mode: RichTextInterpolationMode.doubleBraces),
            isFalse,
          );
        });
      });

      test('each mode ignores other modes syntax', () {
        // Test that dart mode doesn't pick up braces or doubleBraces
        expect(
          RichTextParser.hasInterpolation('{param}', mode: RichTextInterpolationMode.dart),
          isFalse,
        );
        expect(
          RichTextParser.hasInterpolation('{{param}}', mode: RichTextInterpolationMode.dart),
          isFalse,
        );

        // Test that braces mode doesn't pick up dart syntax
        expect(
          RichTextParser.hasInterpolation(r'${param}', mode: RichTextInterpolationMode.braces),
          isFalse,
        );
        expect(
          RichTextParser.hasInterpolation('{{param}}', mode: RichTextInterpolationMode.braces),
          isFalse,
        );

        // Test that doubleBraces mode doesn't pick up dart or braces syntax
        expect(
          RichTextParser.hasInterpolation(r'${param}', mode: RichTextInterpolationMode.doubleBraces),
          isFalse,
        );
        expect(
          RichTextParser.hasInterpolation('{param}', mode: RichTextInterpolationMode.doubleBraces),
          isFalse,
        );
      });
    });

    group('TranslationOverridesFlutter integration', () {
      test('handles StringTextNode with interpolation', () {
        final locale = FakeAppLocale(languageCode: 'en');
        final translations = FakeTranslations(
          locale,
          overrides: {},
        );
        translations.$meta.setFlatMapFunction((path) {
          if (path == 'action.getStarted') return 'Get Started';
          return null;
        });

        // Create a mock StringTextNode by directly testing the rich() method
        // The actual node creation would happen during overrideTranslationsFromMap
        final result = TranslationOverridesFlutter.rich(
          translations.$meta,
          'test.key',
          {
            'getStarted': (String text) => TextSpan(
              text: text,
              style: const TextStyle(color: Colors.blue),
            ),
          },
        );

        // Should return null when no override exists
        expect(result, isNull);
      });
    });
  });
}
