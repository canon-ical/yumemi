import shell from "./build/dev/javascript/yumemi_front_scratch/gen/shell.mjs";

let likeCount = 12;
const requests = [];

function article(version = 1) {
  return {
    slug: "article",
    title: "本日の記事",
    body: "夜のシフトが得意な新人です。よろしくお願いします。",
    version,
    order: 0,
    category: { value: "news" },
    tags: { values: ["fixture"] },
  };
}

function json(value) {
  return new Response(JSON.stringify(value), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}

const app = {
  async fetch(request) {
    const url = new URL(request.url);
    requests.push({
      method: request.method,
      path: url.pathname + url.search,
      cookie: request.headers.get("cookie"),
    });
    if (request.method === "GET" && url.pathname === "/api/session") {
      const cookie = request.headers.get("cookie") ?? "";
      if (cookie.includes("no-subject")) return json({ anonymous: false });
      if (cookie.includes("missing-handle")) {
        return json({ anonymous: false, subject: { id: "reader-id" } });
      }
      const signedIn = cookie.includes("subject");
      return json(
        signedIn
          ? { anonymous: false, subject: { handle: "reader-handle", id: "reader-id", email: "must-not-render" } }
          : { anonymous: true },
      );
    }
    if (request.method === "GET" && url.pathname.startsWith("/api/articles/")) {
      return json({
        article: article(1),
        category: { name: "news" },
        tags: [{ name: "fixture" }],
        theme: null,
      });
    }
    if (request.method === "GET" && url.pathname === "/api/articles") {
      return json({
        page: { items: [], next: null },
        counts: [
          [{ name: "fixture" }, 1],
          [{ name: "gleam" }, 1],
          [{ name: "cloudflare" }, 1],
        ],
      });
    }
    if (request.method === "GET" && url.pathname === "/api/widgets") {
      return json({ rows: [{ kind: "Article", article: article(1) }] });
    }
    if (
      request.method === "POST" &&
      url.pathname === "/api/articles/article/publish"
    ) {
      likeCount += 1;
      return json(article(likeCount));
    }
    if (request.method === "POST" && url.pathname === "/api/articles") {
      return json({ slug: "article", phase: "draft" });
    }
    if (request.method === "POST" && url.pathname === "/api/blobs") {
      if (request.headers.get("content-type") === "image/fail") {
        return new Response("upload failed", { status: 503 });
      }
      return json({ key: "uploaded-image-key" });
    }
    if (
      request.method === "POST" &&
      url.pathname === "/api/articles/article/blob_save"
    ) {
      return json({ saved: true });
    }
    return new Response("not found", { status: 404 });
  },
};

const svelte = {
  fetch(request) {
    return new Response(`SVELTE fallback: ${new URL(request.url).pathname}`, {
      status: 200,
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  },
};

export default {
  fetch(request, env, context) {
    const pathname = new URL(request.url).pathname;
    if (pathname === "/__reset") {
      requests.length = 0;
      return json({ reset: true });
    }
    if (pathname === "/__requests") return json(requests);
    if (pathname.startsWith("/api/")) return app.fetch(request);
    const cookie = request.headers.get("cookie") ?? "";
    const bindings = { ...env, APP: app, SVELTE: svelte, YUMEMI_DEV: "1" };
    if (!cookie.includes("missing-public-origin")) {
      bindings.PUBLIC_PUBLIC_ORIGIN = "https://public.example";
    }
    if (!cookie.includes("missing-idp-origin")) {
      bindings.PUBLIC_IDP_ORIGIN = "https://identity.example";
    }
    return shell.fetch(
      request,
      bindings,
      context,
    );
  },
};
