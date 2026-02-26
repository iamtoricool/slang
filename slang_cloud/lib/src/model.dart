/// Minimal cloud state - sealed class pattern.
/// Only two states: Loading and Ready.
sealed class CloudState {
  /// Last successfully set locale (null until first success)
  final String? currentLocale;

  /// When the locale was last successfully updated
  final DateTime? lastUpdated;

  const CloudState({this.currentLocale, this.lastUpdated});

  /// True if currently loading
  bool get isLoading => this is CloudLoading;
}

/// State during check/download operations.
class CloudLoading extends CloudState {
  const CloudLoading({super.currentLocale, super.lastUpdated});
}

/// State when not loading - has cached locale data or null.
class CloudReady extends CloudState {
  const CloudReady({super.currentLocale, super.lastUpdated});
}
