# Slang Cloud Server

A Hono-based backend server for slang_cloud package with full translation management API and Vue.js 3 Admin Panel.

## Features

- **In-memory storage** for testing
- **Auto hash calculation** (MD5)
- **Full CRUD** for languages
- **Translation management** (full replace, merge, nested updates)
- **CORS enabled** for Flutter web
- **Slang Cloud compatible** endpoints
- **Vue.js 3 Admin Panel** with key-value editor
- **Import/Export JSON** functionality

## Quick Start

```bash
# Install dependencies
bun install

# Start server (auto-reload)
bun run dev

# Or without auto-reload
bun run start
```

Server runs on `http://localhost:3000`

## Admin Panel

Access the web-based admin UI at: **http://localhost:3000/admin**

### Features

- **Visual Language Management**: Add, edit, delete languages
- **Key-Value Translation Editor**: Simple dot-notation editor
- **Real-time Hash Display**: See MD5 hash of translations
- **Import/Export**: Import JSON (merge/replace) or export to file
- **Clone Languages**: Duplicate existing languages
- **Responsive Design**: Works on desktop and mobile
- **Toast Notifications**: Success/error feedback

### Screenshot

```
┌──────────────────────────────────────────────────────┐
│ 🌐 Slang Cloud Admin                           v1.0  │
├──────────────┬───────────────────────────────────────┤
│              │                                       │
│ LANGUAGES    │  LANGUAGE EDITOR                      │
│              │                                       │
│ [+ Add New]  │  🇺🇸 en    English                     │
│              │  Hash: a1b2c3d4...                    │
│ 🔍 Search... │  Updated: 2 mins ago                  │
│              │                                       │
│ 🇺🇸 en  ✓    │  Translations:                        │
│ 🇩🇪 de       │  ┌─────────────────────────────────┐  │
│              │  │ Key              │ Value        │  │
│              │  ├──────────────────┼──────────────┤  │
│              │  │ main.title       │ [Hello   ]   │  │
│              │  │ main.description │ [World   ]   │  │
│              │  │ [+ Add Key]                     │  │
│              │  └─────────────────────────────────┘  │
│              │                                       │
│              │  [💾 Save] [📋 Clone] [📤 Export]    │
│              │                                       │
└──────────────┴───────────────────────────────────────┘
```

## API Endpoints

### Client Endpoints (for slang_cloud)

| Method | Endpoint | Description |
|--------|----------|-------------|
| HEAD | `/translations/:locale` | Check version (returns X-Translation-Hash) |
| GET | `/translations/:locale` | Download translations |

### Language Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/languages` | List all languages (metadata) |
| GET | `/languages/:code` | Get language with translations |
| POST | `/languages` | Create new language |
| PUT | `/languages/:code` | Full replace language |
| PATCH | `/languages/:code` | Partial update metadata |
| DELETE | `/languages/:code` | Delete language |

### Translation Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/languages/:code/translations` | Get translations only |
| PUT | `/languages/:code/translations` | Full replace translations |
| PATCH | `/languages/:code/translations` | Merge with existing |
| POST | `/languages/:code/translations` | Add/update specific keys |

### Admin

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin` | Vue.js 3 Admin Panel |

## Usage Examples

### Using Admin Panel

1. Open http://localhost:3000/admin
2. Click **"+ Add Language"** to create a new language
3. Enter code (e.g., "es"), name, and native name
4. Click **"Add First Key"** or **"+ Add Key"** to add translations
5. Use dot notation for nested keys: `main.title`, `common.save`
6. Click **"Save Changes"** to persist
7. Use **Import/Export** for bulk operations

### Using API

#### Create Language
```bash
curl -X POST http://localhost:3000/languages \
  -H "Content-Type: application/json" \
  -d '{
    "code": "es",
    "name": "Spanish",
    "nativeName": "Español",
    "translations": {
      "main": {
        "title": "Título",
        "description": "Descripción"
      }
    }
  }'
```

#### Update Translations
```bash
# Full replace
curl -X PUT http://localhost:3000/languages/es/translations \
  -H "Content-Type: application/json" \
  -d '{"translations": {"main": {"title": "Nuevo"}}}'

# Merge/Patch
curl -X PATCH http://localhost:3000/languages/es/translations \
  -H "Content-Type: application/json" \
  -d '{"translations": {"main": {"button": "Botón"}}}'

# Add specific keys
curl -X POST http://localhost:3000/languages/es/translations \
  -H "Content-Type: application/json" \
  -d '{"common": {"save": "Guardar"}}'
```

#### Check Version (slang_cloud)
```bash
curl -I http://localhost:3000/translations/en
# Returns: X-Translation-Hash: abc123...
```

## Admin Panel Tech Stack

- **Vue.js 3**: Composition API with reactive state
- **Tailwind CSS**: Via CDN for styling
- **Font Awesome**: Icons via CDN
- **No Build Step**: Embedded HTML/JS in server

## Key-Value Editor

The admin panel uses a **flat key-value representation** with dot notation:

```
main.title         → "Slang Cloud Demo"
main.description   → "This is a description"
common.save        → "Save"
common.cancel      → "Cancel"
```

This is automatically converted to nested JSON when saved:
```json
{
  "main": {
    "title": "Slang Cloud Demo",
    "description": "This is a description"
  },
  "common": {
    "save": "Save",
    "cancel": "Cancel"
  }
}
```

## Postman Collection

Import `postman_collection.json` into Postman for easy API testing.

## Default Data

Server comes pre-seeded with:
- **en** (English)
- **de** (German)

## Data Structure

```typescript
interface Language {
  code: string;           // 2-char code (en, de, es)
  name: string;           // Display name
  nativeName?: string;    // Native name
  translations: object;   // JSON object
  hash: string;          // MD5 of translations
  createdAt: Date;
  updatedAt: Date;
}
```

## Development

- **Auto-reload**: `bun run dev`
- **TypeScript**: Full type support
- **Validation**: JSON validation on all endpoints
- **Error handling**: Proper HTTP status codes
- **Admin UI**: No build step required (Vue 3 CDN)

## Notes

- Data is stored **in-memory** (resets on restart)
- All translation updates **auto-calculate** MD5 hash
- **CORS enabled** for all origins (testing only)
- Supports **nested JSON** structures
- **No authentication** (demo/development only)

## Integration with slang_cloud

The server is compatible with slang_cloud Flutter package:

```dart
final controller = CloudTranslationController(
  config: SlangCloudConfig(
    baseUrl: 'http://localhost:3000',
    endpoint: '/translations/{locale}',
    hashHeader: 'X-Translation-Hash',
  ),
);

// Set language
await controller.setLanguage('en');
```
