# Slang Cloud Backend Specification

This document describes the API contract that any backend service must implement to support `slang_cloud`.

## Endpoints

### 1. Get Translation

Retrieves the translation file for a specific locale.

**Request:**
- **Method:** `GET`
- **URL:** `/translations/{locale}` (configurable)
- **Headers:** Configurable (e.g., `Authorization: Bearer <token>`)

**Response:**
- **Status:** `200 OK`
- **Body:** JSON object containing the translations. Nested structure is supported and recommended.
- **Headers:**
    - `X-Translation-Hash`: The MD5 hash of the response body. This is used for versioning and caching.

**Example Response Body:**
```json
{
  "welcome": "Welcome",
  "login": {
    "title": "Login",
    "button": "Sign In"
  }
}
```

### 2. Check Version

Checks if a new version of the translation is available.

**Request:**
- **Method:** `HEAD` (or `GET` if configured)
- **URL:** `/translations/{locale}` (same as Get Translation)
- **Headers:** Same as Get Translation.

**Response:**
- **Status:** `200 OK`
- **Headers:**
    - `X-Translation-Hash`: The MD5 hash of the current translation file.

**Client Logic:**
The client compares the `X-Translation-Hash` from the response with its locally cached hash. If they differ, it proceeds to download the full translation using the `GET` endpoint.

### 3. List Languages

Retrieves the list of supported languages.

**Request:**
- **Method:** `GET`
- **URL:** `/languages` (configurable)

**Response:**
- **Status:** `200 OK`
- **Body:** JSON array of language objects.

**Example Response Body:**
```json
[
  {
    "code": "en",
    "name": "English",
    "nativeName": "English"
  },
  {
    "code": "de",
    "name": "German",
    "nativeName": "Deutsch"
  }
]
```

### 4. Get Language (Optional)

Retrieves details for a specific language code.

**Request:**
- **Method:** `GET`
- **URL:** `/languages/{code}`

**Response:**
- **Status:** `200 OK`
- **Body:** Single language object.

## Error Handling

- **404 Not Found:** The client will assume no translation exists for this locale and will fallback to local resources.
- **5xx Server Error:** The client will ignore the error and use cached or local resources.
