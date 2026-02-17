import { createHash } from "node:crypto";

const translations = {
  en: {
    main: {
      title: "Slang Cloud Demo (Server)",
      description: "This text is served from the Bun backend!",
      button: "Check for Updates"
    }
  },
  de: {
    main: {
      title: "Slang Cloud Demo (Server DE)",
      description: "Dieser Text kommt vom Bun Backend!",
      button: "Nach Updates suchen"
    },
    common: {
      "version": "tor nani"
    }
  }
};

const languages = [
  { code: "en", name: "English" },
  { code: "de", name: "Deutsch" }
];

function getHash(content: string): string {
  return createHash("md5").update(content).digest("hex");
}

const server = Bun.serve({
  port: 3000,
  fetch(req) {
    const url = new URL(req.url);
    const path = url.pathname;
    const method = req.method;

    // CORS headers
    const headers = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, X-Translation-Hash",
    };

    if (method === "OPTIONS") {
      return new Response(null, { headers });
    }

    // GET /languages
    if (path === "/languages" && method === "GET") {
      return new Response(JSON.stringify(languages), {
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
      });
    }

    // GET /languages/:code
    const langMatch = path.match(/^\/languages\/([a-z]{2})$/);
    if (langMatch && method === "GET") {
      const code = langMatch[1];
      const lang = languages.find((l) => l.code === code);

      if (lang) {
        return new Response(JSON.stringify(lang), {
          headers: {
            ...headers,
            "Content-Type": "application/json",
          },
        });
      }
      return new Response("Not Found", { status: 404, headers });
    }

    // GET/HEAD /translations/:locale
    const match = path.match(/^\/translations\/([a-z]{2})$/);
    if (match) {
      const locale = match[1];
      const data = translations[locale as keyof typeof translations];

      if (!data) {
        return new Response("Not Found", { status: 404, headers });
      }

      const jsonContent = JSON.stringify(data);
      const hash = getHash(jsonContent);

      const responseHeaders = {
        ...headers,
        "Content-Type": "application/json",
        "X-Translation-Hash": hash,
      };

      if (method === "HEAD") {
        return new Response(null, { headers: responseHeaders });
      }

      return new Response(jsonContent, { headers: responseHeaders });
    }

    return new Response("Not Found", { status: 404, headers });
  },
});

console.log(`Listening on http://localhost:${server.port} ...`);
