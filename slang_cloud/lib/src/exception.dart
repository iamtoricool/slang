/// Exception thrown by SlangCloud operations.
class SlangCloudException implements Exception {
  /// Human-readable error message
  final String message;

  const SlangCloudException(this.message);

  @override
  String toString() => 'SlangCloudException: $message';
}
