# Slang Cloud Server

A Hono-based backend server for slang_cloud package with full translation management API.

## Features

- **In-memory storage** for testing
- **Auto hash calculation** (MD5)
- **Full CRUD** for languages
- **Translation management** (full replace, merge, nested updates)
- **CORS enabled** for Flutter web
- **Slang Cloud compatible** endpoints

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

## Usage Examples

### Create Language
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

### Update Translations
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

### Check Version (slang_cloud)
```bash
curl -I http://localhost:3000/translations/en
# Returns: X-Translation-Hash: abc123...
```

## Postman Collection

Import `postman_collection.json` into Postman for easy testing.

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

## Notes

- Data is stored **in-memory** (resets on restart)
- All translation updates **auto-calculate** MD5 hash
- **CORS enabled** for all origins (testing only)
- Supports **nested JSON** structures

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
