/// Abstract base class for all Slang Cloud exceptions.
///
/// All exceptions thrown by slang_cloud extend this class.
/// Developers can catch [SlangCloudException] to handle all slang_cloud errors,
/// or catch specific subclasses for fine-grained error handling.
abstract class SlangCloudException implements Exception {
  /// Human-readable error message
  final String message;

  /// The locale that was being processed when the error occurred
  final String? locale;

  /// The original error that caused this exception, if any
  final dynamic originalError;

  /// The HTTP response body for debugging (if applicable)
  final String? responseBody;

  const SlangCloudException(
    this.message, {
    this.locale,
    this.originalError,
    this.responseBody,
  });

  @override
  String toString() {
    final buffer = StringBuffer('SlangCloudException: $message');
    if (locale != null) {
      buffer.write(' (locale: $locale)');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a network error occurs.
///
/// This includes connection failures, DNS errors, socket errors, etc.
/// These errors are retryable by default.
class SlangCloudNetworkException extends SlangCloudException {
  const SlangCloudNetworkException(
    super.message, {
    super.locale,
    super.originalError,
    super.responseBody,
  });
}

/// Exception thrown when a request times out.
///
/// These errors are retryable by default.
class SlangCloudTimeoutException extends SlangCloudException {
  /// The duration that was waited before timing out
  final Duration? timeout;

  const SlangCloudTimeoutException(
    super.message, {
    this.timeout,
    super.locale,
    super.originalError,
    super.responseBody,
  });
}

/// Exception thrown when the server returns a 404 Not Found response.
///
/// This typically means the requested locale doesn't exist on the server.
/// These errors are NOT retryable.
class SlangCloudNotFoundException extends SlangCloudException {
  const SlangCloudNotFoundException(
    super.message, {
    super.locale,
    super.originalError,
    super.responseBody,
  });
}

/// Exception thrown when the server returns a 401 Unauthorized response.
///
/// This indicates authentication failure. The developer should check
/// their authentication headers in [SlangCloudConfig.headers].
/// These errors are NOT retryable.
class SlangCloudUnauthorizedException extends SlangCloudException {
  const SlangCloudUnauthorizedException(
    super.message, {
    super.locale,
    super.originalError,
    super.responseBody,
  });
}

/// Exception thrown when the server returns a 403 Forbidden response.
///
/// This indicates the client doesn't have permission to access the resource.
/// These errors are NOT retryable.
class SlangCloudForbiddenException extends SlangCloudException {
  const SlangCloudForbiddenException(
    super.message, {
    super.locale,
    super.originalError,
    super.responseBody,
  });
}

/// Exception thrown when the server returns a 5xx server error response.
///
/// These errors may be retryable depending on the specific error.
class SlangCloudServerException extends SlangCloudException {
  /// The HTTP status code returned by the server
  final int statusCode;

  const SlangCloudServerException(
    super.message, {
    required this.statusCode,
    super.locale,
    super.originalError,
    super.responseBody,
  });
}

/// Exception thrown when the downloaded content's hash doesn't match
/// the expected hash from the server.
///
/// This indicates potential data corruption or man-in-the-middle attack.
/// These errors are NOT retryable - the developer should investigate.
class SlangCloudHashMismatchException extends SlangCloudException {
  /// The expected hash from the server
  final String expectedHash;

  /// The actual hash of the downloaded content
  final String actualHash;

  const SlangCloudHashMismatchException(
    super.message, {
    required this.expectedHash,
    required this.actualHash,
    super.locale,
    super.originalError,
    super.responseBody,
  });

  @override
  String toString() {
    return 'SlangCloudHashMismatchException: $message '
        '(expected: $expectedHash, actual: $actualHash, locale: $locale)';
  }
}

/// Exception thrown when the server returns an invalid or malformed response.
///
/// This includes:
/// - Invalid JSON
/// - Missing required headers (e.g., X-Translation-Hash)
/// - Unexpected response format
///
/// These errors are NOT retryable.
class SlangCloudInvalidResponseException extends SlangCloudException {
  const SlangCloudInvalidResponseException(
    super.message, {
    super.locale,
    super.originalError,
    super.responseBody,
  });
}

/// Exception thrown when a request is cancelled.
///
/// This typically happens when the widget is disposed while a request
/// is in progress.
class SlangCloudCancelledException extends SlangCloudException {
  const SlangCloudCancelledException(
    super.message, {
    super.locale,
    super.originalError,
  });
}
