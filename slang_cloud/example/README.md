# Slang Cloud Example App

A Flutter example app demonstrating slang_cloud package with Riverpod state management.

## Features

- **Riverpod State Management**: Uses flutter_riverpod ^3.2.1
- **Dynamic Language List**: Fetches available languages from server
- **Pull-to-Refresh**: Swipe down to refresh language list
- **Language Switching**: Tap to switch languages with loading indicator
- **Visual Feedback**: Shows selected language, loading states, and error messages

## Architecture

```
main.dart
├── LanguageModel (extracted to models/)
├── Providers (in main.dart)
│   └── languageListProvider (FutureProvider)
├── Views
│   ├── HomeView (main screen)
│   └── LanguageListView (language selection)
└── Server Integration
    └── HTTP client for /languages endpoint
```

## Setup

1. Start the server:
```bash
cd server
bun install
bun run dev
```

2. Run the Flutter app:
```bash
cd example
flutter pub get
flutter run
```

## API Integration

The app communicates with the Hono backend server:

- **GET /languages** - Fetches list of available languages
- **GET /translations/:locale** - Downloads translations (via slang_cloud)
- **HEAD /translations/:locale** - Checks for updates (via slang_cloud)

## File Structure

```
lib/
├── main.dart                 # App entry, providers, views
├── models/
│   └── language_model.dart   # Language data model
└── i18n/
    ├── strings.i18n.json    # Source translations
    └── strings.g.dart        # Generated slang files
```

## Key Features

### Riverpod Providers
```dart
final languageListProvider = FutureProvider<List<LanguageModel>>((ref) async {
  final response = await http.get(Uri.parse('http://10.0.2.2:3000/languages'));
  // Parse and return languages
});
```

### Pull-to-Refresh
```dart
RefreshIndicator(
  onRefresh: () async {
    ref.invalidate(languageListProvider);
    await ref.read(languageListProvider.future);
  },
  child: // ListView
)
```

### Language Switching with Loading
```dart
ListTile(
  leading: isSwitching
    ? CircularProgressIndicator()
    : isSelected
      ? Icon(Icons.check_circle, color: Colors.green)
      : Icon(Icons.language),
  onTap: isSwitching ? null : () => _switchLanguage(language),
)
```

## Testing

1. Start the Hono server
2. Run the Flutter app
3. Tap the floating action button to open language list
4. Pull down to refresh languages
5. Tap a language to switch
6. Observe loading indicator and success/error messages

## Dependencies

- flutter_riverpod: ^3.2.1 (State management)
- http: ^1.2.0 (HTTP requests)
- slang: ^4.x (Localization)
- slang_flutter: ^4.x (Flutter integration)
- slang_cloud: (Local path)
