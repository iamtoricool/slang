import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:slang_cloud/src/controller.dart';
import 'package:slang_cloud/src/model.dart';

/// A widget that provides access to the cloud translation controller.
///
/// This widget listens to the controller's state changes and triggers
/// the [onTranslationsReceived] callback when new translations are downloaded.
///
/// Usage:
/// ```dart
/// void main() {
///   final controller = CloudTranslationController(
///     config: SlangCloudConfig(baseUrl: 'https://api.example.com'),
///   );
///
///   runApp(
///     CloudTranslationProvider(
///       controller: controller,
///       onTranslationsReceived: (locale, translations) async {
///         // Apply translations using your slang setup
///       },
///       child: MyApp(),
///     ),
///   );
/// }
/// ```
class CloudTranslationProvider extends StatefulWidget {
  /// The controller instance created via [CloudTranslationController].
  final CloudTranslationController controller;

  /// Called when new translations are received from the server.
  ///
  /// Use this callback to apply the translations using your slang setup:
  /// ```dart
  /// onTranslationsReceived: (locale, translations, isFlatMap) async {
  ///   final appLocale = AppLocaleUtils.parse(locale);
  ///   await LocaleSettings.instance.overrideTranslationsFromMap(
  ///     locale: appLocale,
  ///     map: translations,
  ///     isFlatMap: isFlatMap,
  ///   );
  /// }
  /// ```
  final Future<void> Function(
    String locale,
    Map<String, dynamic> translations,
    bool isFlatMap,
  ) onTranslationsReceived;

  final Widget child;

  const CloudTranslationProvider({
    super.key,
    required this.controller,
    required this.onTranslationsReceived,
    required this.child,
  });

  /// Gets the controller instance from the widget tree.
  ///
  /// Use this to trigger actions like switching locales:
  /// ```dart
  /// try {
  ///   await CloudTranslationProvider.of(context).setLanguage('de');
  /// } catch (e) {
  ///   // Handle error
  /// }
  /// ```
  static CloudTranslationController of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<_CloudTranslationInherited>();
    assert(provider != null, 'CloudTranslationProvider not found in widget tree');
    return provider!.controller;
  }

  @override
  State<CloudTranslationProvider> createState() => _CloudTranslationProviderState();
}

class _CloudTranslationProviderState extends State<CloudTranslationProvider> {
  String? _lastAppliedLocale;
  String? _lastAppliedHash;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() async {
    final state = widget.controller.value;

    // Apply when transitioning to Ready with a new locale OR new hash
    if (state is CloudReady && state.currentLocale != null) {
      final localeChanged = state.currentLocale != _lastAppliedLocale;
      final hashChanged = state.currentHash != _lastAppliedHash;

      if (localeChanged || hashChanged) {
        await _applyTranslations(state.currentLocale!);
        _lastAppliedLocale = state.currentLocale;
        _lastAppliedHash = state.currentHash;
      }
    }
  }

  Future<void> _applyTranslations(String locale) async {
    try {
      final jsonStr = await widget.controller.getCachedTranslation(locale);
      if (jsonStr != null) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        await widget.onTranslationsReceived(
          locale,
          map,
          widget.controller.config.isFlatMap,
        );
      }
    } catch (e) {
      debugPrint('SlangCloud: Failed to apply translations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CloudTranslationInherited(
      controller: widget.controller,
      state: widget.controller.value,
      child: widget.child,
    );
  }
}

/// Inherited widget that provides the controller to descendants.
class _CloudTranslationInherited extends InheritedWidget {
  final CloudTranslationController controller;
  final CloudState state;

  const _CloudTranslationInherited({
    required this.controller,
    required this.state,
    required super.child,
  });

  @override
  bool updateShouldNotify(_CloudTranslationInherited oldWidget) {
    return state != oldWidget.state;
  }
}
