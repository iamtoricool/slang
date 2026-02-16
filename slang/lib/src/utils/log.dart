/// Logging levels for the CLI output
enum Level {
  /// Normal logging, default level
  normal,

  /// Verbose logging, includes detailed information
  verbose,
}

Level _level = Level.normal;
bool testMode = false;

/// Set the logging level
void setLevel(Level level) {
  _level = level;
}

/// Get the current logging level
Level get level => _level;

/// Logs an error message
void error(String message) {
  print(message);
}

void deprecatedWarning(String version, String message) {
  if (testMode) {
    return;
  }
  print('DEPRECATED(v$version): $message');
}

/// Logs informational messages
void info(String message) {
  print(message);
}

/// Logs verbose messages
void verbose(String message) {
  if (_level == Level.verbose) {
    print(message);
  }
}
