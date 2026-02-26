import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:slang_cloud/slang_cloud.dart';
import 'i18n/strings.g.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  // Determine the base URL based on the platform.
  // Android emulator needs 10.0.2.2 to access the host machine's localhost.
  String baseUrl = 'http://localhost:3000';
  if (!kIsWeb && Platform.isAndroid) {
    baseUrl = 'http://10.0.2.2:3000';
  }

  // Create controller instance (non-singleton)
  final controller = CloudTranslationController(
    config: SlangCloudConfig(baseUrl: baseUrl),
  );

  runApp(
    CloudTranslationProvider(
      controller: controller,
      onTranslationsReceived: (localeCode, translations, isFlatMap) async {
        final appLocale = AppLocaleUtils.parse(localeCode);
        await LocaleSettings.instance.overrideTranslationsFromMap(
          locale: appLocale,
          map: translations,
          isFlatMap: isFlatMap,
        );
      },
      child: TranslationProvider(child: const MainApp()),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(context.t.main.title),
          actions: const [
            // Status indicator
            _CloudStatusIndicator(),
          ],
        ),
        body: const _LanguageSelector(),
      ),
    );
  }
}

/// Widget that displays the current cloud sync status
class _CloudStatusIndicator extends StatelessWidget {
  const _CloudStatusIndicator();

  @override
  Widget build(BuildContext context) {
    final state = CloudTranslationProvider.of(context).value;

    if (state is CloudLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Widget that handles language selection
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    final controller = CloudTranslationProvider.of(context);
    final state = controller.value;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(context.t.main.description),
          const SizedBox(height: 20),

          // Language buttons (hardcoded for demo)
          _LanguageButton(
            label: 'English',
            localeCode: 'en',
            isCurrent: state.currentLocale == 'en',
          ),
          const SizedBox(height: 10),
          _LanguageButton(
            label: 'German',
            localeCode: 'de',
            isCurrent: state.currentLocale == 'de',
          ),
          const SizedBox(height: 10),

          // Check for updates button
          ElevatedButton.icon(
            onPressed: () => _checkForUpdates(context),
            icon: const Icon(Icons.refresh),
            label: const Text('Check for Updates'),
          ),

          const SizedBox(height: 20),

          // Display current locale info
          if (state.currentLocale != null)
            Text(
              'Current: ${state.currentLocale}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (state.lastUpdated != null)
            Text(
              'Last updated: ${state.lastUpdated}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = CloudTranslationProvider.of(context);

    try {
      await controller.checkForUpdates();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Checked for updates'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to check updates: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Reusable language button widget
class _LanguageButton extends StatelessWidget {
  final String label;
  final String localeCode;
  final bool isCurrent;

  const _LanguageButton({
    required this.label,
    required this.localeCode,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final state = CloudTranslationProvider.of(context).value;
    final isLoading = state.isLoading;

    return ElevatedButton(
      onPressed: isLoading ? null : () => _switchLocale(context, localeCode),
      style: ElevatedButton.styleFrom(
        backgroundColor: isCurrent ? Colors.green : null,
        minimumSize: const Size(200, 48),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check, size: 16),
          ],
        ],
      ),
    );
  }

  Future<void> _switchLocale(BuildContext context, String localeCode) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = CloudTranslationProvider.of(context);

    try {
      await controller.setLanguage(localeCode);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Successfully switched to $localeCode'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to switch locale: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
