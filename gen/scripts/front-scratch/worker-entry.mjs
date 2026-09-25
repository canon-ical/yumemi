import { makeEncode } from "./codec-encode.mjs";
import * as back from "./build/dev/javascript/yumemi_front_scratch/back_values.mjs";
import { List } from "./build/dev/javascript/prelude.mjs";
import { Some, None } from "./build/dev/javascript/gleam_stdlib/gleam/option.mjs";
import shell from "./build/dev/javascript/yumemi_front_scratch/gen/shell.mjs";

const encode = makeEncode({ Some, None, List });
let likeCount = 12;
const requests = [];

function json(value) {
  return new Response(JSON.stringify(encode(value)), {
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
      return json(back.article_read());
    }
    if (request.method === "GET" && url.pathname === "/api/articles") {
      return json(back.article_list());
    }
    if (request.method === "GET" && url.pathname === "/api/widgets") {
      return json(back.widget_list());
    }
    if (
      request.method === "POST" &&
      url.pathname === "/api/articles/article/publish"
    ) {
      likeCount += 1;
      return json(back.article(likeCount));
    }
    if (request.method === "POST" && url.pathname === "/api/articles") {
      return json(back.created());
    }
    if (request.method === "POST" && url.pathname === "/api/blobs") {
      if (request.headers.get("content-type") === "image/fail") {
        return new Response("upload failed", { status: 503 });
      }
      return json(back.upload_response());
    }
    if (
      request.method === "POST" &&
      url.pathname === "/api/articles/article/blob_save"
    ) {
      return json(back.saved());
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
