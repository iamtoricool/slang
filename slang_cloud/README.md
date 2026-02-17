# slang_cloud

Cloud integration for [slang](https://pub.dev/packages/slang), enabling over-the-air translation updates.
This package allows you to fetch translations from a remote server and apply them to your Flutter app at runtime, without needing an app store update.

## Features

-   **Over-the-Air Updates:** Fetch new translations on app start.
-   **Caching:** Locally caches translations for offline support.
-   **Versioning:** Uses MD5 hashing (via `X-Translation-Hash` header) to minimize bandwidth usage.
-   **Flexible Storage:** Interface-based storage allowing `SharedPreferences`, `Hive`, or custom implementations.
-   **Type-Safe Overrides:** Leverages `slang`'s `overrideTranslationsFromMap` for safe runtime updates.

## usage

1.  **Add Dependency:**

```yaml
dependencies:
  slang: ^4.0.0
  slang_flutter: ^4.0.0
  slang_cloud: ^0.1.0
```

2.  **Wrap your App:**

```dart
import 'package:flutter/material.dart';
import 'package:slang_cloud/slang_cloud.dart';
import 'i18n/strings.g.dart'; // Your generated slang file

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocale();

  runApp(
    CloudTranslationProvider(
      config: SlangCloudConfig(
        baseUrl: 'https://api.yourapp.com',
        // Optional: Custom endpoint
        // translationEndpoint: '/api/v1/translations/{locale}',
        // Optional: Custom headers
        // headers: {'Authorization': 'Bearer <token>'},
      ),
      // Callback to apply the override.
      // You must provide this because LocaleSettings is generated code.
      overrideCallback: ({required locale, required isFlatMap, required map}) async {
        // Convert string locale to enum if needed, or use the raw string if supported.
        // For standard slang setup:
        final appLocale = AppLocaleUtils.parse(locale);
        await LocaleSettings.overrideTranslationsFromMap(
          locale: appLocale,
          isFlatMap: isFlatMap,
          map: map,
        );
      },
      // Optional: Custom storage (default is in-memory for testing)
      // storage: MyHiveStorage(),
      child: MyApp(),
    ),
  );
}
```

## Backend Specification

See [BACKEND_SPEC.md](BACKEND_SPEC.md) for details on implementing the translation server.
