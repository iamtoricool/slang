import { Hono } from "hono";
import { cors } from "hono/cors";
import { createHash } from "node:crypto";

/**
 * Slang Cloud Server - Hono Implementation
 *
 * Features:
 * - HEAD/GET /translations/:locale - For slang_cloud client
 * - Full CRUD for languages
 * - Translation management (full replace, patch, nested updates)
 * - In-memory storage with auto hash calculation
 * - CORS enabled for Flutter web testing
 */

// Types
interface Language {
  code: string;
  name: string;
  nativeName?: string;
  translations: Record<string, any>;
  hash: string;
  createdAt: Date;
  updatedAt: Date;
}

interface CreateLanguageRequest {
  code: string;
  name: string;
  nativeName?: string;
  translations?: Record<string, any>;
}

interface UpdateTranslationsRequest {
  translations: Record<string, any>;
}

// In-memory database
const database = new Map<string, Language>();

// Helper functions
function calculateHash(translations: Record<string, any>): string {
  return createHash("md5").update(JSON.stringify(translations)).digest("hex");
}

function validateTranslations(data: any): Record<string, any> {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    throw new Error("Translations must be a valid JSON object");
  }
  return data;
}

function deepMerge(target: any, source: any): any {
  if (typeof target !== "object" || target === null) return source;
  if (typeof source !== "object" || source === null) return target;

  const result = { ...target };
  for (const key in source) {
    if (source.hasOwnProperty(key)) {
      if (
        typeof source[key] === "object" &&
        source[key] !== null &&
        !Array.isArray(source[key])
      ) {
        result[key] = deepMerge(result[key], source[key]);
      } else {
        result[key] = source[key];
      }
    }
  }
  return result;
}

function createLanguage(data: CreateLanguageRequest): Language {
  const translations = data.translations || {};
  const now = new Date();
  return {
    code: data.code,
    name: data.name,
    nativeName: data.nativeName,
    translations: validateTranslations(translations),
    hash: calculateHash(translations),
    createdAt: now,
    updatedAt: now,
  };
}

// Seed data
function seedDatabase() {
  const seedLanguages: CreateLanguageRequest[] = [
    {
      code: "en",
      name: "English",
      nativeName: "English",
      translations: {
        main: {
          title: "Slang Cloud Demo (Server)",
          description: "This text is served from the Hono backend!",
          button: "Check for Updates",
        },
      },
    },
    {
      code: "de",
      name: "German",
      nativeName: "Deutsch",
      translations: {
        main: {
          title: "Slang Cloud Demo (Server DE)",
          description: "Dieser Text kommt vom Hono Backend!",
          button: "Nach Updates suchen",
        },
        common: {
          version: "tor nani",
        },
      },
    },
  ];

  seedLanguages.forEach((lang) => {
    database.set(lang.code, createLanguage(lang));
  });

  console.log(`✅ Seeded ${seedLanguages.length} languages`);
}

// Initialize app
const app = new Hono();

// Middleware
app.use(
  "*",
  cors({
    origin: "*",
    allowMethods: ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "X-Translation-Hash"],
  })
);

// Health check
app.get("/", (c) => {
  return c.json({
    status: "ok",
    service: "slang-cloud-server",
    version: "1.0.0",
    languages: database.size,
  });
});

// ============================================
// TRANSLATION ENDPOINTS (for slang_cloud)
// ============================================

// HEAD /translations/:locale - Check version
app.on("HEAD", "/translations/:locale", (c) => {
  const locale = c.req.param("locale");
  const language = database.get(locale);

  if (!language) {
    return c.json({ error: "Language not found" }, 404);
  }

  c.header("X-Translation-Hash", language.hash);
  c.header("Content-Type", "application/json");
  return c.body(null, 200);
});

// GET /translations/:locale - Download translations
app.get("/translations/:locale", (c) => {
  const locale = c.req.param("locale");
  const language = database.get(locale);

  if (!language) {
    return c.json({ error: "Language not found" }, 404);
  }

  c.header("X-Translation-Hash", language.hash);
  return c.json(language.translations);
});

// ============================================
// LANGUAGE MANAGEMENT ENDPOINTS
// ============================================

// GET /languages - List all languages (metadata only)
app.get("/languages", (c) => {
  const languages = Array.from(database.values()).map((lang) => ({
    code: lang.code,
    name: lang.name,
    nativeName: lang.nativeName,
    hash: lang.hash,
    updatedAt: lang.updatedAt.toISOString(),
  }));

  return c.json(languages);
});

// GET /languages/:code - Get single language with translations
app.get("/languages/:code", (c) => {
  const code = c.req.param("code");
  const language = database.get(code);

  if (!language) {
    return c.json({ error: "Language not found" }, 404);
  }

  return c.json({
    code: language.code,
    name: language.name,
    nativeName: language.nativeName,
    translations: language.translations,
    hash: language.hash,
    createdAt: language.createdAt.toISOString(),
    updatedAt: language.updatedAt.toISOString(),
  });
});

// POST /languages - Create new language
app.post("/languages", async (c) => {
  try {
    const body = await c.req.json<CreateLanguageRequest>();

    // Validation
    if (!body.code || typeof body.code !== "string" || body.code.length !== 2) {
      return c.json(
        { error: "Invalid code. Must be 2 character language code" },
        400
      );
    }

    if (!body.name || typeof body.name !== "string") {
      return c.json({ error: "Name is required" }, 400);
    }

    const code = body.code.toLowerCase();

    if (database.has(code)) {
      return c.json({ error: "Language already exists" }, 409);
    }

    const language = createLanguage({
      ...body,
      code,
    });

    database.set(code, language);

    return c.json(
      {
        code: language.code,
        name: language.name,
        nativeName: language.nativeName,
        hash: language.hash,
        createdAt: language.createdAt.toISOString(),
        updatedAt: language.updatedAt.toISOString(),
      },
      201
    );
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// PUT /languages/:code - Full replace language
app.put("/languages/:code", async (c) => {
  try {
    const code = c.req.param("code").toLowerCase();
    const existing = database.get(code);

    if (!existing) {
      return c.json({ error: "Language not found" }, 404);
    }

    const body = await c.req.json<CreateLanguageRequest>();

    if (body.name && typeof body.name !== "string") {
      return c.json({ error: "Invalid name" }, 400);
    }

    const translations = body.translations
      ? validateTranslations(body.translations)
      : existing.translations;

    const updated: Language = {
      ...existing,
      name: body.name || existing.name,
      nativeName: body.nativeName !== undefined
        ? body.nativeName
        : existing.nativeName,
      translations,
      hash: calculateHash(translations),
      updatedAt: new Date(),
    };

    database.set(code, updated);

    return c.json({
      code: updated.code,
      name: updated.name,
      nativeName: updated.nativeName,
      hash: updated.hash,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    });
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// PATCH /languages/:code - Partial update metadata only
app.patch("/languages/:code", async (c) => {
  try {
    const code = c.req.param("code").toLowerCase();
    const existing = database.get(code);

    if (!existing) {
      return c.json({ error: "Language not found" }, 404);
    }

    const body = await c.req.json<Partial<CreateLanguageRequest>>();

    if (body.name !== undefined && typeof body.name !== "string") {
      return c.json({ error: "Invalid name" }, 400);
    }

    const updated: Language = {
      ...existing,
      name: body.name !== undefined ? body.name : existing.name,
      nativeName: body.nativeName !== undefined
        ? body.nativeName
        : existing.nativeName,
      updatedAt: new Date(),
    };

    database.set(code, updated);

    return c.json({
      code: updated.code,
      name: updated.name,
      nativeName: updated.nativeName,
      hash: updated.hash,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    });
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// DELETE /languages/:code - Delete language
app.delete("/languages/:code", (c) => {
  const code = c.req.param("code").toLowerCase();

  if (!database.has(code)) {
    return c.json({ error: "Language not found" }, 404);
  }

  database.delete(code);
  return c.json({ message: "Language deleted successfully" });
});

// ============================================
// TRANSLATION MANAGEMENT ENDPOINTS
// ============================================

// GET /languages/:code/translations - Get translations only
app.get("/languages/:code/translations", (c) => {
  const code = c.req.param("code").toLowerCase();
  const language = database.get(code);

  if (!language) {
    return c.json({ error: "Language not found" }, 404);
  }

  return c.json({
    translations: language.translations,
    hash: language.hash,
    updatedAt: language.updatedAt.toISOString(),
  });
});

// PUT /languages/:code/translations - Full replace translations
app.put("/languages/:code/translations", async (c) => {
  try {
    const code = c.req.param("code").toLowerCase();
    const existing = database.get(code);

    if (!existing) {
      return c.json({ error: "Language not found" }, 404);
    }

    const body = await c.req.json<UpdateTranslationsRequest>();

    if (!body.translations) {
      return c.json({ error: "translations field is required" }, 400);
    }

    const translations = validateTranslations(body.translations);

    const updated: Language = {
      ...existing,
      translations,
      hash: calculateHash(translations),
      updatedAt: new Date(),
    };

    database.set(code, updated);

    return c.json({
      code: updated.code,
      hash: updated.hash,
      updatedAt: updated.updatedAt.toISOString(),
      translations: updated.translations,
    });
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// PATCH /languages/:code/translations - Merge/patch translations
app.patch("/languages/:code/translations", async (c) => {
  try {
    const code = c.req.param("code").toLowerCase();
    const existing = database.get(code);

    if (!existing) {
      return c.json({ error: "Language not found" }, 404);
    }

    const body = await c.req.json<UpdateTranslationsRequest>();

    if (!body.translations) {
      return c.json({ error: "translations field is required" }, 400);
    }

    const patch = validateTranslations(body.translations);
    const merged = deepMerge(existing.translations, patch);

    const updated: Language = {
      ...existing,
      translations: merged,
      hash: calculateHash(merged),
      updatedAt: new Date(),
    };

    database.set(code, updated);

    return c.json({
      code: updated.code,
      hash: updated.hash,
      updatedAt: updated.updatedAt.toISOString(),
      translations: updated.translations,
    });
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// POST /languages/:code/translations - Add/update specific keys
app.post("/languages/:code/translations", async (c) => {
  try {
    const code = c.req.param("code").toLowerCase();
    const existing = database.get(code);

    if (!existing) {
      return c.json({ error: "Language not found" }, 404);
    }

    const body = await c.req.json<Record<string, any>>();

    // Validate that body is an object
    if (typeof body !== "object" || body === null || Array.isArray(body)) {
      return c.json({ error: "Request body must be a JSON object" }, 400);
    }

    // Merge with existing
    const merged = deepMerge(existing.translations, body);

    const updated: Language = {
      ...existing,
      translations: merged,
      hash: calculateHash(merged),
      updatedAt: new Date(),
    };

    database.set(code, updated);

    return c.json({
      code: updated.code,
      hash: updated.hash,
      updatedAt: updated.updatedAt.toISOString(),
      translations: updated.translations,
    });
  } catch (error: any) {
    return c.json({ error: error.message || "Invalid request" }, 400);
  }
});

// Start server
seedDatabase();

const port = process.env.PORT || 3000;
console.log(`🚀 Slang Cloud Server running on http://localhost:${port}`);
console.log(`📖 API Documentation: http://localhost:${port}/`);
console.log(`⚡ Auto-reload enabled (bun --watch)`);

export default {
  port,
  fetch: app.fetch,
};
