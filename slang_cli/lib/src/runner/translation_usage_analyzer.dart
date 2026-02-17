import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:slang/src/utils/log.dart' as log;
import 'dart:io';

/// Type-based AST analyzer for detecting translation usage.
/// Detects translations accessed via any BuildContext variable, not just 'context'.
class TranslationUsageAnalyzer {
  final String translateVar;
  final Map<String, String> _translationVariables = {}; // name -> path
  final Set<String> _usedPaths = {};
  final Set<String> _shadowedNames = {}; // variables that shadow translateVar

  TranslationUsageAnalyzer({required this.translateVar});

  Future<Set<String>> analyzeFile(String filePath,
      {String? projectRoot}) async {
    // Clear per-file state; variables are file-scoped but usage is global
    _translationVariables.clear();
    _shadowedNames.clear();

    try {
      final resolvedUnit = await _resolveFile(filePath, projectRoot);
      if (resolvedUnit == null) {
        log.verbose('Failed to resolve $filePath');
        return _usedPaths;
      }

      final visitor = TranslationUsageVisitor(this, resolvedUnit);
      resolvedUnit.unit.accept(visitor);
      return _usedPaths;
    } catch (e) {
      log.verbose('Failed to analyze $filePath: $e');
      return _usedPaths;
    }
  }

  /// Resolves a file using AnalysisContextCollection for type information
  Future<ResolvedUnitResult?> _resolveFile(
      String filePath, String? projectRoot) async {
    try {
      // Use file's directory as project root if not provided
      final root = projectRoot ?? File(filePath).parent.path;

      final collection = AnalysisContextCollection(
        includedPaths: [root],
      );

      final context = collection.contextFor(filePath);
      final session = context.currentSession;
      final result = await session.getResolvedUnit(filePath);

      if (result is ResolvedUnitResult) {
        return result;
      }
      return null;
    } catch (e) {
      log.verbose('Resolution failed for $filePath: $e');
      return null;
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
/// Uses type information to detect BuildContext variables
class TranslationUsageVisitor extends RecursiveAstVisitor<void> {
  final TranslationUsageAnalyzer analyzer;
  final ResolvedUnitResult resolvedUnit;

  TranslationUsageVisitor(this.analyzer, this.resolvedUnit);

  /// Joins a base path with a suffix, handling the empty base path case
  /// (which occurs when a variable is a root alias for the translate var).
  String _joinPath(String basePath, String suffix) {
    return basePath.isEmpty ? suffix : '$basePath.$suffix';
  }

  /// Checks if a type is BuildContext or a subtype of it
  /// Returns null if type information is unavailable (e.g., missing imports)
  bool? _isBuildContextType(DartType? type) {
    if (type == null) return null; // Unknown type

    // Check for dynamic or invalid type (unresolved imports)
    final typeStr = type.toString();
    if (typeStr == 'dynamic' || typeStr == 'InvalidType') {
      return null;
    }

    final element = type.element;
    if (element == null) return null;

    // Check for BuildContext directly
    if (element.name == 'BuildContext') {
      return true;
    }

    // Check if it's a subtype of BuildContext
    final typeSystem = resolvedUnit.typeSystem;

    // Get the BuildContext type from Flutter framework
    final buildContextType = _getBuildContextType();
    if (buildContextType != null) {
      return typeSystem.isSubtypeOf(type, buildContextType);
    }

    return null; // BuildContext type not found in imports
  }

  /// Attempts to find the BuildContext type in the resolved unit
  DartType? _getBuildContextType() {
    // Look through the library's imported namespaces for BuildContext
    final library = resolvedUnit.libraryElement;

    // Check exported namespaces
    for (final export in library.exportedLibraries) {
      final buildContext = export.getClass('BuildContext');
      if (buildContext != null) {
        return buildContext.thisType;
      }
    }

    // Check if BuildContext is defined in this library
    final localBuildContext = library.getClass('BuildContext');
    if (localBuildContext != null) {
      return localBuildContext.thisType;
    }

    return null;
  }

  /// Gets the static type of an expression
  DartType? _getExpressionType(Expression expression) {
    return expression.staticType;
  }

  /// Checks if an expression is a BuildContext variable with .t access
  /// Examples: context.t, modalContext.t, this.context.t
  /// Uses type-based detection when available, falls back to string-based for common patterns
  bool _isBuildContextWithTranslation(Expression expression) {
    // Handle PropertyAccess: context.t, modalContext.t
    if (expression is PropertyAccess) {
      final target = expression.realTarget;
      final propertyName = expression.propertyName.name;

      // Check if property is 't' (or the configured translateVar)
      if (propertyName != analyzer.translateVar) {
        return false;
      }

      // Check if target is BuildContext (type-based)
      final targetType = _getExpressionType(target);
      final typeCheck = _isBuildContextType(targetType);
      if (typeCheck == true) {
        return true;
      }

      // Fallback: if type resolution unavailable (null), use string pattern
      // This handles cases where Flutter isn't imported (like in tests)
      if (typeCheck == null) {
        // Common pattern: anything ending with "context" or "Context"
        final targetStr = target.toString();
        if (targetStr.toLowerCase().endsWith('context')) {
          return true;
        }
      }

      // Handle this.context pattern
      if (target is PropertyAccess && target.realTarget is ThisExpression) {
        final innerType = _getExpressionType(target);
        final innerCheck = _isBuildContextType(innerType);
        if (innerCheck == true) {
          return true;
        }
        // Fallback for this.context
        if (innerCheck == null &&
            target.toString().toLowerCase().endsWith('context')) {
          return true;
        }
      }
    }

    // Handle PrefixedIdentifier: context.t
    if (expression is PrefixedIdentifier) {
      final prefix = expression.prefix;
      final identifier = expression.identifier.name;

      if (identifier != analyzer.translateVar) {
        return false;
      }

      // Check if prefix is BuildContext (type-based)
      final prefixType = _getExpressionType(prefix);
      final typeCheck = _isBuildContextType(prefixType);
      if (typeCheck == true) {
        return true;
      }

      // Fallback: if type resolution unavailable (null), use string pattern
      if (typeCheck == null) {
        final prefixStr = prefix.toString();
        if (prefixStr.toLowerCase().endsWith('context')) {
          return true;
        }
      }
    }

    return false;
  }

  /// Checks if an expression is a direct translation access (t.xxx)
  /// or a BuildContext translation access (context.t.xxx, modalContext.t.xxx)
  bool _isTranslationAccess(Expression expression) {
    // If translateVar has been shadowed in this file, don't match
    if (analyzer.isShadowed(analyzer.translateVar)) {
      return false;
    }

    // Check for BuildContext.t pattern (type-based)
    if (_isBuildContextWithTranslation(expression)) {
      return true;
    }

    // Check for PropertyAccess chains where the root is BuildContext.t
    // e.g., context.t.mainScreen.title
    if (expression is PropertyAccess) {
      // Walk up the chain to find if it starts with BuildContext.t
      Expression current = expression;
      while (current is PropertyAccess) {
        final target = current.realTarget;
        if (_isBuildContextWithTranslation(target)) {
          return true;
        }
        current = target;
      }
    }

    final exprString = expression.toString();

    // Direct access: t.some.path
    if (exprString.startsWith('${analyzer.translateVar}.')) {
      return true;
    }

    return false;
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

      // Check if this is BuildContext.t.xxx
      if (_isBuildContextWithTranslation(expression)) {
        return _getBuildContextTranslationPath(expression);
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

      // Check if this is BuildContext.t.xxx pattern
      if (_isBuildContextWithTranslation(expression)) {
        return _getBuildContextTranslationPath(expression);
      }
    }

    // Handle direct translation access like t.mainScreen.title
    if (_isTranslationAccess(expression)) {
      return _getExpressionPath(expression);
    }

    return null;
  }

  /// Extracts path from BuildContext.t expression
  /// context.t.mainScreen.title -> mainScreen.title
  String _getBuildContextTranslationPath(Expression expression) {
    // For context.t.mainScreen, we need to extract mainScreen and beyond
    if (expression is PropertyAccess) {
      // Check if this is the .t access itself
      if (expression.propertyName.name == analyzer.translateVar) {
        final target = expression.realTarget;
        final typeCheck = _isBuildContextType(_getExpressionType(target));
        if (typeCheck == true) {
          // This is context.t - return empty path (root)
          return '';
        }
        // Fallback: check for context pattern when type resolution unavailable
        if (typeCheck == null &&
            target.toString().toLowerCase().endsWith('context')) {
          return '';
        }
      }

      // This is a chain after .t, walk up to find the .t
      final parts = <String>[expression.propertyName.name];
      Expression current = expression.realTarget;

      while (current is PropertyAccess) {
        if (current.propertyName.name == analyzer.translateVar) {
          // Found context.t, return the collected path
          return parts.reversed.join('.');
        }
        parts.add(current.propertyName.name);
        current = current.realTarget;
      }

      // Check if we hit context.t as PrefixedIdentifier
      if (current is PrefixedIdentifier) {
        if (current.identifier.name == analyzer.translateVar) {
          final typeCheck =
              _isBuildContextType(_getExpressionType(current.prefix));
          if (typeCheck == true) {
            return parts.reversed.join('.');
          }
          // Fallback: check for context pattern when type resolution unavailable
          if (typeCheck == null &&
              current.prefix.toString().toLowerCase().endsWith('context')) {
            return parts.reversed.join('.');
          }
        }
      }
    }

    if (expression is PrefixedIdentifier) {
      // This is context.t - return empty path
      if (expression.identifier.name == analyzer.translateVar) {
        final typeCheck =
            _isBuildContextType(_getExpressionType(expression.prefix));
        if (typeCheck == true) {
          return '';
        }
        // Fallback: check for context pattern when type resolution unavailable
        if (typeCheck == null &&
            expression.prefix.toString().toLowerCase().endsWith('context')) {
          return '';
        }
      }
    }

    return '';
  }

  /// Extracts path from translation access expression
  String _getExpressionPath(Expression expression) {
    // Handle BuildContext.t case first (type-based)
    final buildContextPath = _getBuildContextTranslationPath(expression);
    if (buildContextPath.isNotEmpty ||
        _isBuildContextWithTranslation(expression)) {
      return buildContextPath;
    }

    // Handle PropertyAccess chains where the root is BuildContext.t
    // e.g., context.t.mainScreen.title -> extract mainScreen.title
    if (expression is PropertyAccess) {
      final parts = <String>[expression.propertyName.name];
      Expression current = expression.realTarget;

      while (current is PropertyAccess) {
        if (_isBuildContextWithTranslation(current)) {
          // Found BuildContext.t, return the collected path
          return parts.reversed.join('.');
        }
        parts.add(current.propertyName.name);
        current = current.realTarget;
      }

      // Check if the root is BuildContext.t PrefixedIdentifier
      if (current is PrefixedIdentifier &&
          _isBuildContextWithTranslation(current)) {
        return parts.reversed.join('.');
      }
    }

    // Handle direct t.some.path case (most general)
    final exprString = expression.toString();
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
    // or BuildContext.t pattern
    if (_isTranslationAccess(node)) {
      final path = _getExpressionPath(node);
      log.verbose('  Recording path: ${path}');
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

    // Case 4: BuildContext.t.method() - type-based detection
    // This handles context.t.method(), modalContext.t.method(), etc.
    if (target != null) {
      // Check if target is BuildContext.t
      if (_isBuildContextWithTranslation(target)) {
        analyzer.recordUsedPath(node.methodName.name);
        return;
      }

      // Check if target is BuildContext.t.something
      if (target is PropertyAccess &&
          _isBuildContextWithTranslation(target.realTarget)) {
        final basePath = _getBuildContextTranslationPath(target.realTarget);
        final fullPath = _joinPath(basePath, node.methodName.name);
        analyzer.recordUsedPath(fullPath);
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

    // Check if this is BuildContext.t pattern (type-based)
    if (_isBuildContextWithTranslation(node)) {
      final path = _getBuildContextTranslationPath(node);
      analyzer.recordUsedPath(path);
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
}
