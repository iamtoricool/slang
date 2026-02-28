/// Configuration for the Slang Cloud client.
class SlangCloudConfig {
  /// The base URL of the translation server.
  /// Example: 'https://api.yourapp.com'
  final String baseUrl;

  /// The path to the translations endpoint for checking updates (HEAD request).
  /// The '{locale}' placeholder will be replaced with the target locale.
  /// Default: '/translations/{locale}'
  final String endpoint;

  /// The path to the translations endpoint for downloading translations (GET request).
  /// If not specified, defaults to [endpoint].
  /// The '{locale}' placeholder will be replaced with the target locale.
  /// Example: '/translations/{locale}/download'
  final String downloadEndpoint;

  /// The header key for the translation hash/version.
  /// Default: 'X-Translation-Hash'
  final String hashHeader;

  /// Custom headers to send with the requests (e.g. Authorization).
  final Map<String, String> headers;

  /// Request timeout duration.
  /// Default: 30 seconds
  final Duration timeout;

  /// Whether the translation JSON is in flat map format.
  /// When true, expects format like {"main.title": "value"}
  /// When false (default), expects nested format like {"main": {"title": "value"}}
  final bool isFlatMap;

  const SlangCloudConfig({
    required this.baseUrl,
    this.endpoint = '/translations/{locale}',
    String? downloadEndpoint,
    this.hashHeader = 'X-Translation-Hash',
    this.headers = const {},
    this.timeout = const Duration(seconds: 30),
    this.isFlatMap = false,
  }) : downloadEndpoint = downloadEndpoint ?? endpoint;

  /// Builds the full URL for checking updates (HEAD request).
  String buildUrl(String locale) {
    final path = endpoint.replaceAll('{locale}', locale);
    return '$baseUrl$path';
  }

  /// Builds the full URL for downloading translations (GET request).
  String buildDownloadUrl(String locale) {
    final path = downloadEndpoint.replaceAll('{locale}', locale);
    return '$baseUrl$path';
  }
}
