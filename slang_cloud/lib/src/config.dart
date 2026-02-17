/// Configuration for the Slang Cloud client.
class SlangCloudConfig {
  /// The base URL of the translation server.
  /// Example: 'https://api.yourapp.com'
  final String baseUrl;

  /// The path to the translations endpoint.
  /// The '{locale}' placeholder will be replaced with the target locale.
  /// Default: '/translations/{locale}'
  final String translationEndpoint;

  /// The path to the languages list endpoint (optional).
  /// Default: '/languages'
  final String languagesEndpoint;

  /// Custom headers to send with the requests (e.g. Authorization).
  final Map<String, String> headers;

  /// Whether to use a GET or HEAD request to check for updates.
  /// Default: true (HEAD)
  final bool versionCheckViaHead;

  /// The header key for the translation hash/version.
  /// Default: 'X-Translation-Hash'
  final String versionHeader;

  const SlangCloudConfig({
    required this.baseUrl,
    this.translationEndpoint = '/translations/{locale}',
    this.languagesEndpoint = '/languages',
    this.headers = const {},
    this.versionCheckViaHead = true,
    this.versionHeader = 'X-Translation-Hash',
  });
}
