import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:slang/src/utils/log.dart' as log;
import 'dart:io';

/// AST-based analyzer for detecting translation usage
class TranslationUsageAnalyzer {
  final String translateVar;
  final Map<String, String> _translationVariables = {}; // name -> path
  final Set<String> _usedPaths = {};
  final Set<String> _shadowedNames = {}; // variables that shadow translateVar

  TranslationUsageAnalyzer({required this.translateVar});

  Set<String> analyzeFile(String filePath) {
    // Clear per-file state; variables are file-scoped but usage is global
    _translationVariables.clear();
    _shadowedNames.clear();

    try {
      final content = File(filePath).readAsStringSync();
      final result = parseString(path: filePath, content: content);
      final visitor = TranslationUsageVisitor(this);
      result.unit.accept(visitor);
      return _usedPaths;
    } catch (e) {
      log.verbose('Failed to analyze $filePath: $e');
      return _usedPaths;
    }
  }

  void recordTranslationVariable(String variableName, String path) {
    _translationVariables[variableName] = path;
  }

  void recordUsedPath(String path) {
    if (path.isNotEmpty) {
      _usedPaths.add(path);
    }
  }

  bool isTranslationVariable(String variableName) {
    return _translationVariables.containsKey(variableName);
  }

  String? getVariablePath(String variableName) {
    return _translationVariables[variableName];
  }

  void recordShadowedName(String name) {
    _shadowedNames.add(name);
  }

  bool isShadowed(String name) {
    return _shadowedNames.contains(name);
  }
}

/// AST visitor that tracks translation variable assignments and usage
class TranslationUsageVisitor extends RecursiveAstVisitor<void> {
  final TranslationUsageAnalyzer analyzer;

  TranslationUsageVisitor(this.analyzer);

  /// Joins a base path with a suffix, handling the empty base path case
  /// (which occurs when a variable is a root alias for the translate var).
  String _joinPath(String basePath, String suffix) {
    return basePath.isEmpty ? suffix : '$basePath.$suffix';
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final name = node.name.lexeme;
    final initializer = node.initializer;

    if (initializer != null) {
      final path = _extractTranslationPath(initializer);
      if (path != null) {
        // This is a translation variable (e.g., final screen = t.mainScreen)
        // or a root alias (e.g., final t2 = t → path is empty string)
        analyzer.recordTranslationVariable(name, path);
      } else if (name == analyzer.translateVar) {
        // Variable shadows the translate var with a non-translation value
        // (e.g., final t = 'hello'). Mark as shadowed so t.length isn't
        // incorrectly detected as a translation access.
        analyzer.recordShadowedName(name);
      }
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.realTarget;
    if (target is SimpleIdentifier) {
      final basePath = analyzer.getVariablePath(target.name);
      if (basePath != null) {
        final fullPath = _joinPath(basePath, node.propertyName.name);
        analyzer.recordUsedPath(fullPath);
        return;
      }
    }

    // Handle nested cases like screen.header.title where screen is a variable
    if (target is PropertyAccess || target is PrefixedIdentifier) {
      final rootTarget = _getRootTarget(target);
      if (rootTarget is SimpleIdentifier) {
        final variablePath = analyzer.getVariablePath(rootTarget.name);
        if (variablePath != null) {
          final targetPath = _getTargetPath(target);
          final fullPath = _joinPath(
            variablePath,
            '$targetPath.${node.propertyName.name}',
          );
          analyzer.recordUsedPath(fullPath);
          return;
        }
      }
    }

    // Check if this is a direct translation access like t.mainScreen.title
    if (_isTranslationAccess(node)) {
      final path = _getExpressionPath(node);
      analyzer.recordUsedPath(path);
      return;
    }

    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.realTarget;

    // Case 1: Variable usage (e.g. final s = t.section; s.method())
    if (target is SimpleIdentifier) {
      final variablePath = analyzer.getVariablePath(target.name);
      if (variablePath != null) {
        final fullPath = _joinPath(variablePath, node.methodName.name);
        analyzer.recordUsedPath(fullPath);
        return;
      }

      // Case 2: Direct usage on root (e.g. t.method())
      if (target.name == analyzer.translateVar &&
          !analyzer.isShadowed(target.name)) {
        analyzer.recordUsedPath(node.methodName.name);
        return;
      }
    }

    // Case 3: Chained usage (e.g. t.section.method() or context.t.method())
    if (target != null && _isTranslationAccess(target)) {
      final basePath = _getExpressionPath(target);
      final fullPath = _joinPath(basePath, node.methodName.name);
      analyzer.recordUsedPath(fullPath);
      return;
    }

    // Case 4: context.t.method()
    // target is context.t (PrefixedIdentifier)
    if (target is PrefixedIdentifier) {
      if (target.prefix.name == 'context' &&
          target.identifier.name == analyzer.translateVar) {
        analyzer.recordUsedPath(node.methodName.name);
        return;
      }
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefix = node.prefix;
    final identifier = node.identifier;

    // Check if this is a translation variable usage like screen.title
    final basePath = analyzer.getVariablePath(prefix.name);
    if (basePath != null) {
      final fullPath = _joinPath(basePath, identifier.name);
      analyzer.recordUsedPath(fullPath);
      return;
    }

    // Check if this is a direct translation access like t.mainScreen
    if (_isTranslationAccess(node)) {
      final path = _getExpressionPath(node);
      analyzer.recordUsedPath(path);
      return;
    }

    super.visitPrefixedIdentifier(node);
  }

  /// Extracts translation path from expressions like t.mainScreen.title
  /// Returns empty string for bare translate var (e.g., `final t2 = t;`),
  /// which represents a root alias.
  String? _extractTranslationPath(Expression expression) {
    // Handle bare SimpleIdentifier (e.g., `final t2 = t;`)
    if (expression is SimpleIdentifier) {
      if (expression.name == analyzer.translateVar &&
          !analyzer.isShadowed(expression.name)) {
        return ''; // root alias — path is empty
      }
      // Could also be an alias of an alias (e.g., final t3 = t2;)
      final variablePath = analyzer.getVariablePath(expression.name);
      if (variablePath != null) {
        return variablePath;
      }
    }

    // Handle PrefixedIdentifier (e.g., t.mainScreen, screen.title)
    if (expression is PrefixedIdentifier) {
      final prefix = expression.prefix;
      final identifier = expression.identifier;

      // Check if this is a translation variable access like screen.title
      final variablePath = analyzer.getVariablePath(prefix.name);
      if (variablePath != null) {
        return _joinPath(variablePath, identifier.name);
      }
    }

    // Handle PropertyAccess (e.g., t.mainScreen.title, t.mainScreen.title)
    if (expression is PropertyAccess) {
      final target = expression.realTarget;

      // Check for simple variable access like screen.title
      if (target is SimpleIdentifier) {
        final variablePath = analyzer.getVariablePath(target.name);
        if (variablePath != null) {
          return _joinPath(variablePath, expression.propertyName.name);
        }
      }

      // Handle nested cases like screen.subtitle.title
      if (target is PropertyAccess) {
        final rootTarget = _getRootTarget(target);
        if (rootTarget is SimpleIdentifier) {
          final variablePath = analyzer.getVariablePath(rootTarget.name);
          if (variablePath != null) {
            final targetPath = _getPropertyAccessPath(target);
            return _joinPath(
              variablePath,
              '$targetPath.${expression.propertyName.name}',
            );
          }
        }
      }
    }

    // Handle direct translation access like t.mainScreen.title
    if (_isTranslationAccess(expression)) {
      return _getExpressionPath(expression);
    }

    return null;
  }

  /// Checks if an expression is a translation access
  bool _isTranslationAccess(Expression expression) {
    // If translateVar has been shadowed in this file, don't match
    if (analyzer.isShadowed(analyzer.translateVar)) {
      return false;
    }

    final exprString = expression.toString();

    // Direct access: t.some.path
    if (exprString.startsWith('${analyzer.translateVar}.')) {
      return true;
    }

    // Context access: context.t.some.path
    if (exprString.startsWith('context.${analyzer.translateVar}.')) {
      return true;
    }

    return false;
  }

  /// Extracts path from translation access expression
  String _getExpressionPath(Expression expression) {
    final exprString = expression.toString();

    // Handle context.t case first (most specific)
    final contextPrefix = 'context.${analyzer.translateVar}.';
    final contextIndex = exprString.indexOf(contextPrefix);
    if (contextIndex != -1) {
      return exprString.substring(contextIndex + contextPrefix.length);
    }

    // Handle direct t.some.path case (most general)
    final prefix = '${analyzer.translateVar}.';
    final startIndex = exprString.indexOf(prefix);
    if (startIndex != -1) {
      return exprString.substring(startIndex + prefix.length);
    }

    return '';
  }

  /// Gets the root target of a property access chain
  Expression _getRootTarget(Expression node) {
    Expression current = node;
    while (current is PropertyAccess) {
      current = current.realTarget;
    }

    // Handle PrefixedIdentifier case (e.g., for screen.header)
    if (current is PrefixedIdentifier) {
      return current.prefix;
    }

    return current;
  }

  /// Gets the full property access path (excluding the root)
  String _getPropertyAccessPath(PropertyAccess node) {
    final parts = <String>[node.propertyName.name];
    Expression current = node.realTarget;

    while (current is PropertyAccess) {
      parts.insert(0, current.propertyName.name);
      current = current.realTarget;
    }

    return parts.join('.');
  }

  /// Gets the path from a target expression (PropertyAccess or PrefixedIdentifier)
  String _getTargetPath(Expression target) {
    if (target is PropertyAccess) {
      return _getPropertyAccessPath(target);
    } else if (target is PrefixedIdentifier) {
      return target.identifier.name;
    }
    return '';
  }
}
