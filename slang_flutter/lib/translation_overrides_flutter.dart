part of 'slang_flutter.dart';

/// Supported string interpolation modes matching slang.yaml config.
enum RichTextInterpolationMode {
  /// Dart style: `${param}` or `$param`
  dart,

  /// Single braces: `{param}`
  braces,

  /// Double braces: `{{param}}`
  doubleBraces,
}

/// A runtime parser for rich text interpolation syntax.
///
/// This parser handles the `${paramName}` and `${paramName(@:reference)}` syntax
/// that is normally parsed at compile-time by the slang code generator.
///
/// When translations are loaded dynamically (e.g., via slang_cloud), rich text
/// strings with interpolation need to be parsed at runtime.
///
/// Example:
/// ```
/// "Don't have a account? ${getStarted(@:action.getStarted)}"
/// ```
class RichTextParser {
  /// Pattern matching ${argument} but not \${argument} (dart style)
  static final RegExp _dartInterpolationRegex =
      RegExp(r'(?<!\\)\$\{(.+?)\}');

  /// Pattern matching {argument} but not \{argument} (braces style)
  static final RegExp _bracesInterpolationRegex =
      RegExp(r'(?<!\\)(?<!\$)(?<!\{)\{([^{}]+?)\}(?!\{)');

  /// Pattern matching {{argument}} but not \{{argument}} (double braces style)
  static final RegExp _doubleBracesInterpolationRegex =
      RegExp(r'(?<!\\)\{\{(.+?)\}\}');

  /// Pattern matching @:translation.key or @:{translation.key}
  static final RegExp _referenceRegex = RegExp(
    r'(?<!\\)@:(?:(\w[\w|.]*\w|\w)|\{(\w[\w|.]*\w|\w)\})',
  );

  /// Gets the regex for the specified interpolation mode.
  static RegExp _getRegex(RichTextInterpolationMode mode) {
    switch (mode) {
      case RichTextInterpolationMode.dart:
        return _dartInterpolationRegex;
      case RichTextInterpolationMode.braces:
        return _bracesInterpolationRegex;
      case RichTextInterpolationMode.doubleBraces:
        return _doubleBracesInterpolationRegex;
    }
  }

  /// Parses a rich text string and builds a [TextSpan] using the provided builders.
  ///
  /// The [input] string may contain interpolation patterns like:
  /// - `${paramName}` - Calls builder with empty string if paramName maps to a builder
  /// - `${paramName(@:reference)}` - Resolves the reference and calls builder with it
  ///
  /// [meta] is used to resolve @: references from the translation tree.
  /// [builders] is a map of builder function names to their implementations.
  /// [mode] determines the interpolation style (defaults to dart style).
  static TextSpan parse({
    required String input,
    required TranslationMetadata meta,
    required Map<String, Object> builders,
    RichTextInterpolationMode mode = RichTextInterpolationMode.dart,
  }) {
    final regex = _getRegex(mode);
    final spans = <InlineSpan>[];
    var lastIndex = 0;
    var hasInterpolation = false;

    for (final match in regex.allMatches(input)) {
      hasInterpolation = true;

      // Add text before the interpolation
      if (match.start > lastIndex) {
        final text = input.substring(lastIndex, match.start);
        spans.add(TextSpan(text: _unescape(text, mode)));
      }

      // Parse the interpolation content
      final inner = match.group(1)!;
      final paramResult = _parseParam(inner);
      final builder = builders[paramResult.name];

      if (builder != null) {
        // Check if it's a function (InlineSpanBuilder) or a span (InlineSpan)
        if (builder is InlineSpanBuilder) {
          final arg = _resolveArg(
            arg: paramResult.arg,
            meta: meta,
            builders: builders,
          );
          spans.add(builder(arg));
        } else if (builder is InlineSpan) {
          // It's a variable span (InlineSpan)
          spans.add(builder);
        } else {
          // Unknown type, keep the original text
          spans.add(TextSpan(text: match.group(0)));
        }
      } else {
        // Unknown parameter, keep the original text
        spans.add(TextSpan(text: match.group(0)));
      }

      lastIndex = match.end;
    }

    // If no interpolations were found, return a simple TextSpan
    if (!hasInterpolation) {
      return TextSpan(text: _unescape(input, mode));
    }

    // Add remaining text after last interpolation
    if (lastIndex < input.length) {
      spans.add(TextSpan(text: _unescape(input.substring(lastIndex), mode)));
    }

    return TextSpan(children: spans);
  }

  /// Checks if a string contains rich text interpolation syntax.
  ///
  /// [mode] determines the interpolation style to check for (defaults to dart).
  static bool hasInterpolation(
    String input, {
    RichTextInterpolationMode mode = RichTextInterpolationMode.dart,
  }) {
    return _getRegex(mode).hasMatch(input);
  }

  /// Parses a parameter string that may contain an argument.
  ///
  /// Examples:
  /// - `getStarted` -> name: 'getStarted', arg: null
  /// - `getStarted(@:action.getStarted)` -> name: 'getStarted', arg: '@:action.getStarted'
  static _ParamResult _parseParam(String raw) {
    final start = raw.indexOf('(');
    if (start == -1) {
      return _ParamResult(raw.trim(), null);
    }

    final end = raw.lastIndexOf(')');
    if (end == -1 || end < start) {
      return _ParamResult(raw.trim(), null);
    }

    final name = raw.substring(0, start).trim();
    final arg = raw.substring(start + 1, end).trim();
    return _ParamResult(name, arg);
  }

  /// Resolves an argument value.
  ///
  /// If [arg] starts with '@:', it's resolved as a translation reference.
  /// Otherwise, it's returned as-is.
  static String _resolveArg({
    required String? arg,
    required TranslationMetadata meta,
    required Map<String, Object> builders,
  }) {
    if (arg == null) {
      return '';
    }

    // Check if it's a reference pattern
    final match = _referenceRegex.firstMatch(arg);
    if (match != null) {
      final path = match.group(1) ?? match.group(2)!;
      return _resolveReference(meta, path) ?? arg;
    }

    return arg;
  }

  /// Resolves a translation reference path like "action.getStarted".
  ///
  /// Returns the string value at that path, or null if not found.
  static String? _resolveReference(TranslationMetadata meta, String path) {
    // First try the flat map
    try {
      final flatValue = meta.getTranslation(path);
      if (flatValue is String) {
        return flatValue;
      }

      // If it's a function, try to call it with no arguments
      if (flatValue is Function) {
        try {
          final result = Function.apply(flatValue, const []);
          if (result is String) {
            return result;
          }
        } catch (_) {
          // Function requires parameters, can't resolve
        }
      }
    } catch (_) {
      // getTranslation may fail if flatMapFunction is not set
    }

    return null;
  }

  /// Unescapes escaped characters in text based on the interpolation mode.
  ///
  /// For dart mode:
  /// - \${ -> ${
  /// - \@: -> @:
  ///
  /// For braces mode:
  /// - \{ -> {
  /// - \@: -> @:
  ///
  /// For double braces mode:
  /// - \{{ -> {{
  /// - \@: -> @:
  static String _unescape(String text, RichTextInterpolationMode mode) {
    switch (mode) {
      case RichTextInterpolationMode.dart:
        return text
            .replaceAll(r'\${', r'${')
            .replaceAll(r'\@:', r'@:');
      case RichTextInterpolationMode.braces:
        return text
            .replaceAll(r'\{', r'{')
            .replaceAll(r'\@:', r'@:');
      case RichTextInterpolationMode.doubleBraces:
        return text
            .replaceAll(r'\{{', r'{{')
            .replaceAll(r'\@:', r'@:');
    }
  }
}

/// Result of parsing a parameter.
class _ParamResult {
  final String name;
  final String? arg;

  _ParamResult(this.name, this.arg);
}

class TranslationOverridesFlutter {
  /// Handler for overridden rich text.
  /// Returns a [TextSpan] if the [path] was successfully overridden.
  /// Returns null otherwise.
  static TextSpan? rich(
      TranslationMetadata meta, String path, Map<String, Object> param) {
    final node = meta.overrides[path];
    if (node == null) {
      return null;
    }

    // Handle RichTextNode (parsed at build time from structured data)
    if (node is RichTextNode) {
      return node._buildTextSpan(meta, param);
    }

    // Handle StringTextNode (raw string from dynamic translations)
    // This occurs when translations are loaded dynamically via
    // overrideTranslationsFromMap with rich text interpolation syntax.
    // The server may send "Don't have a account? ${getStarted(@:action.getStarted)}"
    // without knowing it was originally a rich text key.
    if (node is StringTextNode) {
      final content = node.content;
      // Check if the content contains rich text interpolation
      if (RichTextParser.hasInterpolation(content)) {
        return RichTextParser.parse(
          input: content,
          meta: meta,
          builders: param,
        );
      }
      // Plain string without interpolation - return as simple TextSpan
      return TextSpan(text: content);
    }

    print(
        'Overridden $path is not a RichTextNode but a ${node.runtimeType}.');
    return null;
  }

  /// Handler for overridden rich plural.
  /// Returns a [TextSpan] if the [path] was successfully overridden.
  /// Returns null otherwise.
  static TextSpan? richPlural(
      TranslationMetadata meta, String path, Map<String, Object> param) {
    final node = meta.overrides[path];
    if (node == null) {
      return null;
    }
    if (node is! PluralNode) {
      print('Overridden $path is not a PluralNode but a ${node.runtimeType}.');
      return null;
    }
    if (!node.rich) {
      print('Overridden $path must be rich (RichText).');
      return null;
    }

    final PluralResolver resolver;
    if (node.pluralType == PluralType.cardinal) {
      resolver = meta.cardinalResolver ??
          PluralResolvers.cardinal(meta.locale.languageCode);
    } else {
      resolver = meta.ordinalResolver ??
          PluralResolvers.ordinal(meta.locale.languageCode);
    }

    final quantities = node.quantities.cast<Quantity, RichTextNode>();

    return RichPluralResolvers.bridge(
      n: param[node.paramName] as num,
      resolver: resolver,
      zero: quantities[Quantity.zero] != null
          ? () => quantities[Quantity.zero]!
              ._buildTextSpan<num>(meta, param, node.paramName)
          : null,
      one: quantities[Quantity.one] != null
          ? () => quantities[Quantity.one]!
              ._buildTextSpan<num>(meta, param, node.paramName)
          : null,
      two: quantities[Quantity.two] != null
          ? () => quantities[Quantity.two]!
              ._buildTextSpan<num>(meta, param, node.paramName)
          : null,
      few: quantities[Quantity.few] != null
          ? () => quantities[Quantity.few]!
              ._buildTextSpan<num>(meta, param, node.paramName)
          : null,
      many: quantities[Quantity.many] != null
          ? () => quantities[Quantity.many]!
              ._buildTextSpan<num>(meta, param, node.paramName)
          : null,
      other: quantities[Quantity.other] != null
          ? () => quantities[Quantity.other]!
              ._buildTextSpan<num>(meta, param, node.paramName)
          : null,
    );
  }

  /// Handler for overridden rich context.
  /// Returns a [TextSpan] if the [path] was successfully overridden.
  /// Returns null otherwise.
  static TextSpan? richContext<T>(
      TranslationMetadata meta, String path, Map<String, Object> param) {
    final node = meta.overrides[path];
    if (node == null) {
      return null;
    }
    if (node is! ContextNode) {
      print('Overridden $path is not a ContextNode but a ${node.runtimeType}.');
      return null;
    }
    if (!node.rich) {
      print('Overridden $path must be rich (RichText).');
      return null;
    }

    final context = param[node.paramName]! as Enum;
    return (node.entries[context.name]! as RichTextNode?)
        ?._buildTextSpan<T>(meta, param, node.paramName);
  }
}

/// Rich plural resolvers
class RichPluralResolvers {
  /// The plural resolver for rich text.
  /// It uses the original [resolver] (which only handles strings)
  /// to determine which plural form should be used.
  static TextSpan bridge({
    required num n,
    required PluralResolver resolver,
    TextSpan Function()? zero,
    TextSpan Function()? one,
    TextSpan Function()? two,
    TextSpan Function()? few,
    TextSpan Function()? many,
    TextSpan Function()? other,
  }) {
    final String select = resolver(
      n,
      zero: zero != null ? 'zero' : null,
      one: one != null ? 'one' : null,
      two: two != null ? 'two' : null,
      few: few != null ? 'few' : null,
      many: many != null ? 'many' : null,
      other: other != null ? 'other' : null,
    );

    switch (select) {
      case 'zero':
        return zero!();
      case 'one':
        return one!();
      case 'two':
        return two!();
      case 'few':
        return few!();
      case 'many':
        return many!();
      case 'other':
        return other!();
      default:
        throw 'This should not happen';
    }
  }
}

extension on RichTextNode {
  TextSpan _buildTextSpan<T>(
    TranslationMetadata meta,
    Map<String, Object> param, [
    String? builderParam,
  ]) {
    return TextSpan(
      children: spans.map((e) {
        if (e is LiteralSpan) {
          return TextSpan(
            text: e.literal.applyParamsAndLinks(meta, param),
          );
        }
        if (e is FunctionSpan) {
          return (param[e.functionName] as InlineSpanBuilder)(e.arg);
        }
        if (e is VariableSpan) {
          if (e.variableName == builderParam) {
            return (param['${e.variableName}Builder'] as InlineSpan Function(
                T))(param[builderParam] as T);
          }
          return param[e.variableName] as InlineSpan;
        }
        throw 'This should not happen';
      }).toList(),
    );
  }
}
