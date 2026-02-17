import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:slang_cloud/src/client.dart';
import 'package:slang_cloud/src/config.dart';
import 'package:slang_cloud/src/storage.dart';
import 'package:crypto/crypto.dart';

/// A wrapper widget that manages over-the-air translation updates.
class CloudTranslationProvider extends StatefulWidget {
  final SlangCloudConfig config;
  final SlangCloudStorage? storage;
  final Widget child;
  final bool checkOnStart;
  final Duration? updateInterval;
  final void Function(String locale)? onUpdate;
  final void Function(Object error, StackTrace)? onError;
  final String Function(BuildContext context)? localeGetter;

  /// The function to override translations.
  /// Usually `LocaleSettings.overrideTranslationsFromMap`.
  /// The [locale] argument is a String, so you might need to convert it to your AppLocale enum.
  final Future<void> Function({
    required String locale,
    required bool isFlatMap,
    required Map<String, dynamic> map,
  }) overrideCallback;

  const CloudTranslationProvider({
    super.key,
    required this.config,
    required this.overrideCallback,
    this.storage,
    required this.child,
    this.checkOnStart = true,
    this.updateInterval,
    this.onUpdate,
    this.onError,
    this.localeGetter,
  });

  @override
  State<CloudTranslationProvider> createState() => _CloudTranslationProviderState();
}

class _CloudTranslationProviderState extends State<CloudTranslationProvider> {
  late final SlangCloudClient _client;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _client = SlangCloudClient(
      config: widget.config,
      storage: widget.storage ?? InMemorySlangCloudStorage(),
    );

    if (widget.checkOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdates();
      });
    }

    if (widget.updateInterval != null) {
      _timer = Timer.periodic(widget.updateInterval!, (_) {
        _checkForUpdates();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    final locale = widget.localeGetter?.call(context) ?? 'en'; // Default fallback

    try {
      final newHash = await _client.checkForUpdate(locale);

      if (newHash != null) {
        final jsonContent = await _client.fetchTranslation(locale);

        if (jsonContent != null) {
          // Verify hash
          final downloadedHash = md5.convert(utf8.encode(jsonContent)).toString();
          if (downloadedHash != newHash) {
            print('SlangCloud: Hash mismatch for $locale. Expected $newHash, got $downloadedHash');
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

          if (widget.onUpdate != null) {
            widget.onUpdate!(locale);
          }
        }
      }
    } catch (e, stacktrace) {
      if (widget.onError != null) {
        widget.onError!(e, stacktrace);
      } else {
        print('SlangCloud Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
