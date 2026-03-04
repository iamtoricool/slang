import 'dart:async';

import 'package:example/models/language_model.dart';
import 'package:example/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slang_cloud/slang_cloud.dart';

import 'i18n/strings.g.dart';
import 'storage/shared_prefs_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  // Create storage with SharedPreferences
  final storage = await SharedPreferencesSlangCloudStorage.create();

  // Pre-initialize cloud client (loads cached translations from storage)
  // Change this to createHonoClient(storage) for Hono server
  final client = await createLaravelClient(storage);

  runApp(
    ProviderScope(
      overrides: [
        languageListProvider.overrideWith((ref) async => fetchLaravelLanguages()),
      ],
      child: SlangCloudProvider(
        client: client,
        onError: (error) {
          debugPrint('SlangCloud error: $error');
        },
        child: TranslationProvider(
          child: const MainApp(),
        ),
      ),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomeView(),
    );
  }
}

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.main.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to default',
            onPressed: () => _showResetDialog(context),
          ),
        ],
      ),
      body: Center(child: Text(context.t.main.description)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const LanguageListView()),
        ),
        heroTag: 'languageSelector',
        child: const Icon(Icons.translate),
      ),
    );
  }

  Future<void> _showResetDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Language'),
        content: const Text(
          'This will clear your saved language preference and reset to the default language.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Clear cache
        await SlangCloudProvider.of(context).clearCache();

        // Reset to device locale
        await LocaleSettings.setLocale(LocaleSettings.currentLocale);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Language reset to default'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to reset'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class LanguageListView extends ConsumerStatefulWidget {
  const LanguageListView({super.key});

  @override
  ConsumerState<LanguageListView> createState() => _LanguageListViewState();
}

class _LanguageListViewState extends ConsumerState<LanguageListView> {
  String? _switchingLanguageCode;
  bool _checkingUpdate = false;

  @override
  Widget build(BuildContext context) {
    final languageList = ref.watch(languageListProvider);
    final client = SlangCloudProvider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.languageList.title),
        actions: [
          IconButton(
            icon: _checkingUpdate
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            onPressed: _checkingUpdate ? null : () => _checkForUpdates(client),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(languageListProvider),
        child: languageList.when(
          data: (languages) {
            final currentLocale = client.currentLocale ?? LocaleSettings.currentLocale.languageCode;

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final language = languages[index];
                final isSelected = language.code == currentLocale;
                final isSwitching = _switchingLanguageCode == language.code;

                return ListTile(
                  leading: isSwitching
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.language),
                  title: Text(language.name),
                  subtitle: Text('${language.nativeName} • ${language.code.toUpperCase()}'),
                  trailing: Text(
                    language.updatedAt.toString().substring(0, 10),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  selected: isSelected,
                  onTap: isSwitching ? null : () => _switchLanguage(client, language),
                );
              },
            );
          },
          error: (error, stackTrace) => _buildErrorWidget(error),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Failed to load languages',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(languageListProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates(SlangCloudClient client) async {
    setState(() {
      _checkingUpdate = true;
    });

    try {
      final hasUpdate = await client.hasUpdate();

      if (mounted) {
        if (hasUpdate) {
          final updated = await client.updateIfAvailable();
          if (updated && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Translations updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Translations are up to date'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check for updates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
        });
      }
    }
  }

  Future<void> _switchLanguage(SlangCloudClient client, LanguageModel language) async {
    setState(() {
      _switchingLanguageCode = language.code;
    });

    try {
      await client.setLanguage(language.code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${language.name}'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _switchingLanguageCode = null;
        });
      }
    }
  }
}
