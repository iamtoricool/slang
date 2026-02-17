import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:slang_cloud/src/client.dart';
import 'package:slang_cloud/src/config.dart';
import 'package:slang_cloud/src/storage.dart';
import 'package:crypto/crypto.dart';
import 'package:slang_cloud/src/model.dart';
import 'package:slang/slang.dart'; // Import BaseAppLocale

/// Controller to interact with the CloudTranslationProvider.
class CloudTranslationController {
  final _CloudTranslationProviderState _state;

  CloudTranslationController(this._state);

  /// Manually triggers an update check for the current locale.
  Future<void> checkForUpdates() => _state._checkForUpdates();

  /// Fetches the list of supported languages from the server.
  Future<void> fetchLanguages() => _state._fetchLanguages();
}

/// A wrapper widget that manages over-the-air translation updates.
class CloudTranslationProvider extends StatefulWidget {
  final SlangCloudConfig config;
  final SlangCloudStorage? storage;
  final Widget child;
  final bool checkOnStart;
  final Duration? updateInterval;
  final String Function(BuildContext context)? localeGetter;
  final Stream<dynamic>? localeStream;

  /// The function to override translations.
  /// Usually `LocaleSettings.overrideTranslationsFromMap`.
  /// The [locale] argument is a String, so you might need to convert it to your AppLocale enum.
  final Future<void> Function({
    required String locale,
    required bool isFlatMap,
    required Map<String, dynamic> map,
  }) overrideCallback;

  /// Optional HTTP client for testing or custom networking.
  final http.Client? client;

  const CloudTranslationProvider({
    super.key,
    required this.config,
    required this.overrideCallback,
    this.storage,
    this.client,
    required this.child,
    this.checkOnStart = true,
    this.updateInterval,
    this.localeGetter,
    this.localeStream,
  });

  /// Access the current state of the cloud provider.
  /// This will trigger a rebuild when the state changes.
  static SlangCloudState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedCloudTranslationProvider>()!.state;
  }

  /// Access the controller to trigger actions.
  /// This will NOT trigger a rebuild.
  static CloudTranslationController get(BuildContext context) {
    return context.getInheritedWidgetOfExactType<InheritedCloudTranslationProvider>()!.controller;
  }

  @override
  State<CloudTranslationProvider> createState() => _CloudTranslationProviderState();
}

class _CloudTranslationProviderState extends State<CloudTranslationProvider> {
  late final SlangCloudClient _client;
  late final CloudTranslationController _controller;
  SlangCloudState _state = const SlangCloudState(status: CloudStatus.idle);
  Timer? _timer;
  StreamSubscription? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _client = SlangCloudClient(
      config: widget.config,
      storage: widget.storage ?? InMemorySlangCloudStorage(),
      client: widget.client,
    );
    _controller = CloudTranslationController(this);

    if (widget.checkOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdates();
        _fetchLanguages();
      });
    }

    if (widget.updateInterval != null) {
      _timer = Timer.periodic(widget.updateInterval!, (_) {
        _checkForUpdates();
      });
    }

    if (widget.localeStream != null) {
      _localeSubscription = widget.localeStream!.listen((event) {
        // Locale changed, trigger update for new locale
        if (event is BaseAppLocale) {
          _checkForUpdates(event.languageCode);
        } else {
          _checkForUpdates();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _localeSubscription?.cancel();
    super.dispose();
  }

  void _updateState(SlangCloudState Function(SlangCloudState) updater) {
    if (mounted) {
      setState(() {
        _state = updater(_state);
      });
    }
  }

  Future<void> _fetchLanguages() async {
    // Only fetch if we haven't already or explicitly requested (logic can be improved)
    try {
      final languages = await _client.fetchLanguages();
      _updateState((s) => s.copyWith(supportedLanguages: languages));
    } catch (e) {
      debugPrint('SlangCloud: Failed to fetch languages: $e');
    }
  }

  Future<void> _checkForUpdates([String? targetLocale]) async {
    final locale = targetLocale ?? widget.localeGetter?.call(context) ?? 'en'; // Default fallback

    _updateState((s) => s.copyWith(status: CloudStatus.checking, error: null));

    try {
      final newHash = await _client.checkForUpdate(locale);

      if (newHash != null) {
        _updateState((s) => s.copyWith(status: CloudStatus.downloading));
        final jsonContent = await _client.fetchTranslation(locale);

        if (jsonContent != null) {
          // Verify hash
          final downloadedHash = md5.convert(utf8.encode(jsonContent)).toString();
          if (downloadedHash != newHash) {
            debugPrint('SlangCloud: Hash mismatch for $locale. Expected $newHash, got $downloadedHash');
          }

          await _client.storage.setTranslation(locale, jsonContent);
          await _client.storage.setVersion(locale, newHash);

          // Decode JSON and apply override
          final Map<String, dynamic> map = jsonDecode(jsonContent);
          await widget.overrideCallback(
            locale: locale,
            isFlatMap: false, // Assuming nested JSON from cloud
            map: map,
          );

          _updateState((s) => s.copyWith(
                status: CloudStatus.success,
                lastUpdated: DateTime.now(),
              ));
        } else {
          _updateState((s) => s.copyWith(status: CloudStatus.error, error: 'Failed to download content'));
        }
      } else {
        _updateState((s) => s.copyWith(status: CloudStatus.success)); // Up to date
      }
    } catch (e, stackTrace) {
      _updateState((s) => s.copyWith(status: CloudStatus.error, error: e));
      debugPrint('SlangCloud Error: $e\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return InheritedCloudTranslationProvider(
      state: _state,
      controller: _controller,
      child: widget.child,
    );
  }
}

class InheritedCloudTranslationProvider extends InheritedWidget {
  final SlangCloudState state;
  final CloudTranslationController controller;

  const InheritedCloudTranslationProvider({
    super.key,
    required this.state,
    required this.controller,
    required super.child,
  });

  @override
  bool updateShouldNotify(InheritedCloudTranslationProvider oldWidget) {
    return state != oldWidget.state;
  }
}
