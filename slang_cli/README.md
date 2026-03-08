# slang_cli

The command-line interface for [slang](https://pub.dev/packages/slang), a type-safe i18n library for Dart and Flutter.

This package provides the `slang` command to generate translations, analyze usage, and more.

## Installation

```bash
dart pub global activate slang_cli
```

## Usage

Run the `slang` command in your project root:

```bash
slang
# or
dart run slang_cli:slang
```

### Commands

- `generate`: Generates the translations (default command).
- `analyze`: Analyzes the codebase for missing or unused translations.
  - Supports AST-based analysis to detect usage via intermediate variables and method invocations (e.g. `t.$wip(...)`).
  - Use `--full` to scan the whole source code.
- `watch`: Watches for file changes and regenerates translations.
- `stats`: Prints translation statistics.
- `clean`: Removes unused translations.
- `apply`: Applies translations from analysis results.
- `migrate`: Migrates from ARB files.
- `normalize`: Normalizes translations.

## Setup for Development

If you are developing `slang`, you can run the CLI from source:

```bash
cd slang_cli
dart run bin/slang_cli.dart analyze --full --outdir=../slang/example
```
