/// Represents a language item fetched from the server.
class SlangLanguage {
  final String code;
  final String name;
  final String? nativeName;

  const SlangLanguage({
    required this.code,
    required this.name,
    this.nativeName,
  });

  factory SlangLanguage.fromJson(Map<String, dynamic> json) {
    return SlangLanguage(
      code: json['code'] as String,
      name: json['name'] as String,
      nativeName: json['nativeName'] as String?,
    );
  }
}

/// The current status of the cloud synchronization.
enum CloudStatus {
  idle,
  checking,
  downloading,
  success,
  error,
}

/// The state snapshot exposed to the UI.
class SlangCloudState {
  final CloudStatus status;
  final Object? error;
  final StackTrace? stackTrace;
  final List<SlangLanguage> supportedLanguages;
  final DateTime? lastUpdated;

  const SlangCloudState({
    required this.status,
    this.error,
    this.stackTrace,
    this.supportedLanguages = const [],
    this.lastUpdated,
  });

  SlangCloudState copyWith({
    CloudStatus? status,
    Object? error,
    StackTrace? stackTrace,
    List<SlangLanguage>? supportedLanguages,
    DateTime? lastUpdated,
  }) {
    return SlangCloudState(
      status: status ?? this.status,
      error: error, // Can be set to null explicitly if not passed, but here we usually just replace it.
      stackTrace: stackTrace,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
