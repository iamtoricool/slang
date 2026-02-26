# slang_cloud

Cloud integration for [slang](https://pub.dev/packages/slang), enabling over-the-air translation updates.
This package allows you to fetch translations from a remote server and apply them to your Flutter app at runtime, without needing an app store update.

## Features

-   **Over-the-Air Updates:** Fetch new translations for specific locales
-   **Caching:** Locally caches translations in memory for offline support
-   **Versioning:** Uses MD5 hashing (via `X-Translation-Hash` header) to minimize bandwidth usage
-   **Type-Safe Overrides:** Leverages `slang`'s `overrideTranslationsFromMap` for safe runtime updates
-   **Minimal API:** Simple `setLanguage()` method handles check + download

## Usage

1.  **Add Dependency:**

```yaml
dependencies:
  slang: ^4.0.0
  slang_flutter: ^4.0.0
  slang_cloud: ^0.1.0
```

2.  **Initialize Controller:**

```dart
import 'package:flutter/material.dart';
import 'package:slang_cloud/slang_cloud.dart';
import 'i18n/strings.g.dart'; // Your generated slang file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  // Create controller instance (non-singleton)
  final controller = CloudTranslationController(
    config: SlangCloudConfig(
      baseUrl: 'https://api.yourapp.com',
      // Optional: Set to true if your backend sends flat maps
      // isFlatMap: false, // Default: nested JSON format
    ),
  );

  runApp(
    CloudTranslationProvider(
      controller: controller,
      onTranslationsReceived: (localeCode, translations, isFlatMap) async {
        // Apply translations using your slang setup
        final appLocale = AppLocaleUtils.parse(localeCode);
        await LocaleSettings.instance.overrideTranslationsFromMap(
          locale: appLocale,
          isFlatMap: isFlatMap,
          map: translations,
        );
      },
      child: MyApp(),
    ),
  );
}
```

3.  **Access Controller in UI:**

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Access controller and its state
    final controller = CloudTranslationProvider.of(context);
    final state = controller.value;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(context.t.main.title),
          actions: [
            // Show status using type check
            if (state is CloudLoading)
              CircularProgressIndicator()
            else
              SizedBox.shrink(),
          ],
        ),
        body: Column(
          children: [
            // Language switcher buttons
            ElevatedButton(
              onPressed: state.isLoading
                ? null
                : () async {
                    try {
                      await controller.setLanguage('de');
                    } catch (e) {
                      // Handle error
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  },
              child: Text('Switch to German'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Configuration

### JSON Format

The `isFlatMap` configuration option controls the expected JSON format:

**Nested format (default, `isFlatMap: false`):**
```json
{
  "main": {
    "title": "Hello",
    "description": "Welcome"
  }
}
```

**Flat map format (`isFlatMap: true`):**
```json
{
  "main.title": "Hello",
  "main.description": "Welcome"
}
```

The `isFlatMap` parameter is automatically passed to your callback from the config.

## API Reference

### CloudTranslationController

The controller manages cloud translation operations:

```dart
// Create instance (not singleton)
final controller = CloudTranslationController(
  config: SlangCloudConfig(baseUrl: '...'),
);

// Set language (checks hash, downloads if needed)
await controller.setLanguage('de');

// Check for updates for current locale (silently fails)
await controller.checkForUpdates();

// Access current state
final state = controller.value;

// Get cached translation
final json = await controller.getCachedTranslation('de');

// Dispose when done
controller.dispose();
```

### CloudTranslationProvider

The provider widget connects the controller to your app:

```dart
CloudTranslationProvider(
  controller: controller, // Required: controller instance
  onTranslationsReceived: (locale, map, isFlatMap) async {
    // Required: apply translations to slang
  },
  child: MyApp(),
)
```

Access the controller anywhere in the widget tree:
```dart
final controller = CloudTranslationProvider.of(context);
```

### CloudState

Sealed class state with two implementations:

```dart
final state = controller.value;

// Type checking
if (state is CloudLoading) {
  return LoadingWidget();
}

// Or use isLoading getter
return state.isLoading ? LoadingWidget() : ContentWidget();

// Access locale data (available in all states)
final currentLocale = state.currentLocale;
final lastUpdated = state.lastUpdated;
```

## Backend Specification

See [BACKEND_SPEC.md](BACKEND_SPEC.md) for details on implementing the translation server.

## Notes

- This package handles **translation fetching only**, not language discovery
- Apps should implement their own language selection UI
- Language listing/discovery is the responsibility of the app
- Errors are thrown from `setLanguage()` - handle them in your app (e.g., show snackbar)
