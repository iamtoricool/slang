import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:slang_cloud/slang_cloud.dart';

import 'i18n/strings.g.dart';
import 'models/language_model.dart';
import 'storage/shared_prefs_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  // Create storage with SharedPreferences
  final storage = await SharedPreferencesSlangCloudStorage.create();

  // Create the cloud client with callbacks for slang integration
  final cloudClient = await SlangCloudClient.create(
    baseUrl: 'http://10.0.2.2:3000',
    hashHeader: 'X-Translation-Hash',
    isFlatMap: false,
    storage: storage,
    applyTranslations: (locale, translations, isFlatMap) async {
      await LocaleSettings.instance.overrideTranslationsFromMap(
        locale: AppLocaleUtils.parse(locale),
        map: translations,
        isFlatMap: isFlatMap,
      );
    },
    setFallback: () async {
      // Use device locale as fallback
      await LocaleSettings.setLocale(LocaleSettings.currentLocale);
    },
  );

  runApp(
    SlangCloudProvider(
      client: cloudClient,
      onError: (error) {
        debugPrint('SlangCloud error: $error');
      },
      child: TranslationProvider(
        child: ProviderScope(
          child: const MainApp(),
        ),
      ),
    ),
  );
}

final languageListProvider = FutureProvider<List<LanguageModel>>((ref) async {
  final response = await http.get(Uri.parse('http://10.0.2.2:3000/languages'));

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => LanguageModel.fromJson(e)).toList();
  } else {
    throw Exception('Failed to load languages: ${response.statusCode}');
  }
}, retry: (retryCount, error) => null);

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
      final client = SlangCloudProvider.of(context);

      // Clear cache
      await client.clearCache();

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
    final currentLocale = client.currentLocale;

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
        onRefresh: () => ref.refresh(languageListProvider.future),
        child: languageList.when(
          data: (languages) {
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
                  onTap: isSwitching ? null : () => _switchLanguage(language),
                );
              },
            );
          },
          error: (error, stackTrace) {
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
                    onPressed: () => ref.refresh(languageListProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
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

  Future<void> _switchLanguage(LanguageModel language) async {
    setState(() {
      _switchingLanguageCode = language.code;
    });

    try {
      final client = SlangCloudProvider.of(context);
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
