import 'package:flutter/widgets.dart';
import 'client.dart';
import 'exception.dart';

/// A widget that provides access to the cloud translation client.
///
/// This widget makes the [SlangCloudClient] available to the entire widget tree
/// via [SlangCloudProvider.of].
///
/// Usage:
/// ```dart
/// void main() async {
///   final client = await SlangCloudClient.create(
///     baseUrl: 'https://api.example.com',
///     applyTranslations: (locale, map, isFlatMap) async {
///       // Apply to slang
///     },
///     setFallback: () async {
///       await LocaleSettings.setLocale(AppLocale.en);
///     },
///   );
///
///   runApp(
///     SlangCloudProvider(
///       client: client,
///       onError: (e) => debugPrint('Error: $e'),
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
class SlangCloudProvider extends InheritedWidget {
  /// The client instance created via [SlangCloudClient.create].
  final SlangCloudClient client;

  /// Optional global error handler.
  /// Called when errors occur in async operations.
  final void Function(SlangCloudException error)? onError;

  const SlangCloudProvider({
    super.key,
    required this.client,
    this.onError,
    required super.child,
  });

  /// Gets the client instance from the widget tree.
  ///
  /// Use this to access the client anywhere in the app:
  /// ```dart
  /// final client = SlangCloudProvider.of(context);
  /// await client.setLanguage('de');
  /// ```
  static SlangCloudClient of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SlangCloudProvider>();
    assert(provider != null, 'SlangCloudProvider not found in widget tree');
    return provider!.client;
  }

  /// Reports an error to the global error handler if one is set.
  ///
  /// This can be called from widgets to report errors:
  /// ```dart
  /// try {
  ///   await client.setLanguage('de');
  /// } on SlangCloudException catch (e) {
  ///   SlangCloudProvider.reportError(context, e);
  /// }
  /// ```
  static void reportError(BuildContext context, SlangCloudException error) {
    final provider = context.dependOnInheritedWidgetOfExactType<SlangCloudProvider>();
    provider?.onError?.call(error);
  }

  @override
  bool updateShouldNotify(SlangCloudProvider oldWidget) => false;
}
