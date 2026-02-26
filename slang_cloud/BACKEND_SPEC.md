# Slang Cloud Backend Specification

This document describes the API contract that any backend service must implement to support `slang_cloud`.

## Endpoints

### 1. Check Version (HEAD)

Checks if a new version of the translation is available.

**Request:**
- **Method:** `HEAD`
- **URL:** `/translations/{locale}` (configurable)
- **Headers:** Configurable (e.g., `Authorization: Bearer <token>`)

**Response:**
- **Status:** `200 OK`
- **Headers:**
    - `X-Translation-Hash`: The MD5 hash of the current translation file.

**Client Logic:**
The client compares the `X-Translation-Hash` from the response with its locally cached hash. If they differ, it proceeds to download the full translation using the `GET` endpoint.

---

### 2. Download Translation (GET)

Retrieves the translation file for a specific locale.

**Request:**
- **Method:** `GET`
- **URL:** `/translations/{locale}` (same as Check Version)
- **Headers:** Same as Check Version.

**Response:**
- **Status:** `200 OK`
- **Body:** JSON object containing the translations. Nested structure is supported.
- **Headers:**
    - `X-Translation-Hash`: The MD5 hash of the response body.
    - `Content-Type`: `application/json`

**Example Response Body:**
```json
{
  "main": {
    "title": "Welcome",
    "description": "Hello World"
  },
  "common": {
    "save": "Save",
    "cancel": "Cancel"
  }
}
```

---

### 3. List Languages (GET)

Retrieves the list of supported languages.

**Request:**
- **Method:** `GET`
- **URL:** `/languages`

**Response:**
- **Status:** `200 OK`
- **Body:** JSON array of language objects (metadata only, no translations).

**Example Response Body:**
```json
[
  {
    "code": "en",
    "name": "English",
    "nativeName": "English",
    "hash": "abc123...",
    "updatedAt": "2024-01-15T10:30:00Z"
  },
  {
    "code": "de",
    "name": "German",
    "nativeName": "Deutsch",
    "hash": "def456...",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
]
```

---

### 4. Get Language (GET)

Retrieves details for a specific language code with translations.

**Request:**
- **Method:** `GET`
- **URL:** `/languages/{code}`

**Response:**
- **Status:** `200 OK`
- **Body:** Single language object with translations.

**Example Response Body:**
```json
{
  "code": "en",
  "name": "English",
  "nativeName": "English",
  "translations": {
    "main": {
      "title": "Welcome",
      "description": "Hello World"
    }
  },
  "hash": "abc123...",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

---

### 5. Create Language (POST)

Creates a new language with translations.

**Request:**
- **Method:** `POST`
- **URL:** `/languages`
- **Headers:** `Content-Type: application/json`
- **Body:**
```json
{
  "code": "es",
  "name": "Spanish",
  "nativeName": "Español",
  "translations": {
    "main": {
      "title": "Bienvenido",
      "description": "Hola Mundo"
    }
  }
}
```

**Response:**
- **Status:** `201 Created`
- **Body:** Created language object (without translations).

---

### 6. Update Language (PUT)

Full replacement of language (metadata + translations).

**Request:**
- **Method:** `PUT`
- **URL:** `/languages/{code}`
- **Headers:** `Content-Type: application/json`
- **Body:** Complete language object.

**Response:**
- **Status:** `200 OK`
- **Body:** Updated language object (without translations).

---

### 7. Patch Language (PATCH)

Partial update of language metadata only.

**Request:**
- **Method:** `PATCH`
- **URL:** `/languages/{code}`
- **Headers:** `Content-Type: application/json`
- **Body:** Partial update object.
```json
{
  "name": "Updated Name",
  "nativeName": "Updated Native"
}
```

**Response:**
- **Status:** `200 OK`
- **Body:** Updated language object (without translations).

---

### 8. Delete Language (DELETE)

Deletes a language and all its translations.

**Request:**
- **Method:** `DELETE`
- **URL:** `/languages/{code}`

**Response:**
- **Status:** `200 OK`
- **Body:** `{ "message": "Language deleted successfully" }`

---

## Translation Management Endpoints

### 9. Get Translations (GET)

Retrieves translations for a specific language.

**Request:**
- **Method:** `GET`
- **URL:** `/languages/{code}/translations`

**Response:**
- **Status:** `200 OK`
- **Body:**
```json
{
  "translations": {
    "main": {
      "title": "Welcome"
    }
  },
  "hash": "abc123...",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

---

### 10. Replace Translations (PUT)

Full replacement of translations.

**Request:**
- **Method:** `PUT`
- **URL:** `/languages/{code}/translations`
- **Headers:** `Content-Type: application/json`
- **Body:**
```json
{
  "translations": {
    "main": {
      "title": "New Title",
      "description": "New Description"
    }
  }
}
```

**Response:**
- **Status:** `200 OK`
- **Body:** Updated translations with new hash.

---

### 11. Merge Translations (PATCH)

Deep merge with existing translations.

**Request:**
- **Method:** `PATCH`
- **URL:** `/languages/{code}/translations`
- **Headers:** `Content-Type: application/json`
- **Body:**
```json
{
  "translations": {
    "main": {
      "button": "New Button"
    }
  }
}
```

**Response:**
- **Status:** `200 OK`
- **Body:** Merged translations with new hash.

---

### 12. Add/Update Keys (POST)

Add or update specific translation keys.

**Request:**
- **Method:** `POST`
- **URL:** `/languages/{code}/translations`
- **Headers:** `Content-Type: application/json`
- **Body:** Nested object with keys to add/update.
```json
{
  "common": {
    "save": "Save",
    "cancel": "Cancel"
  }
}
```

**Response:**
- **Status:** `200 OK`
- **Body:** Updated translations with new hash.

---

## Hash Calculation

The `X-Translation-Hash` header should be calculated as:

```javascript
import { createHash } from 'crypto';

const hash = createHash('md5')
  .update(JSON.stringify(translations))
  .digest('hex');
```

**Important:**
- Hash must be recalculated on every translation update
- Used by client to determine if download is needed
- MD5 is sufficient for versioning purposes

---

## Error Handling

### Standard HTTP Status Codes

| Status | Meaning |
|--------|---------|
| 200 OK | Success |
| 201 Created | Resource created successfully |
| 400 Bad Request | Invalid request body or parameters |
| 404 Not Found | Language or resource not found |
| 409 Conflict | Resource already exists (e.g., duplicate code) |
| 500 Internal Server Error | Server error |

### Error Response Format

```json
{
  "error": "Error message description"
}
```

---

## CORS Configuration

For Flutter web testing, enable CORS with these headers:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, X-Translation-Hash
```

---

## Data Structure

### Language Object

```typescript
interface Language {
  code: string;           // 2-character language code (en, de, es)
  name: string;           // Display name
  nativeName?: string;    // Native name (optional)
  translations: object;   // Nested JSON object
  hash: string;          // MD5 hash of translations
  createdAt: Date;       // Creation timestamp
  updatedAt: Date;       // Last update timestamp
}
```

### Translation Object

Translations should be a valid JSON object. Both flat and nested structures are supported:

**Nested (recommended):**
```json
{
  "main": {
    "title": "Welcome",
    "description": "Hello"
  }
}
```

**Flat:**
```json
{
  "main.title": "Welcome",
  "main.description": "Hello"
}
```

**Note:** Use `isFlatMap: true` in slang_cloud config for flat format.

---

## Integration Example

The Hono server implementation in `/example/server` demonstrates a complete backend following this specification with in-memory storage.

See `README.md` in the server directory for detailed usage instructions.
