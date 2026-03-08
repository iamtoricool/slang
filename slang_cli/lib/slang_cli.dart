/// CLI for slang, a type-safe i18n library for Dart and Flutter.
///
/// This package provides command-line tools for managing translations,
/// including code generation, analysis, and migration utilities.
///
/// Usage:
/// ```bash
/// dart run slang_cli
/// dart run slang_cli analyze --full
/// dart run slang_cli generate
/// ```
library;

// Commands
export 'src/commands/analyze.dart' show runAnalyzeTranslations;
export 'src/commands/apply.dart' show runApplyTranslations;
export 'src/commands/clean.dart' show runClean;
export 'src/commands/configure.dart' show runConfigure;
export 'src/commands/edit.dart' show runEdit;
export 'src/commands/generate.dart' show generateTranslations;
export 'src/commands/help.dart' show printHelp;
export 'src/commands/migrate.dart' show runMigrate;
export 'src/commands/migrate_arb.dart' show migrateArb;
export 'src/commands/normalize.dart' show runNormalize;
export 'src/commands/stats.dart' show runStats;
export 'src/commands/wip.dart' show runWip;

// Analyzer
export 'src/analyzer/translation_usage_analyzer.dart'
    show TranslationUsageAnalyzer;
