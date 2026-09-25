import { makeEncode } from "./codec-encode.mjs";
import * as back from "./build/dev/javascript/yumemi_front_scratch/back_values.mjs";
import { List } from "./build/dev/javascript/prelude.mjs";
import { Some, None } from "./build/dev/javascript/gleam_stdlib/gleam/option.mjs";
import shell from "./build/dev/javascript/yumemi_front_scratch/gen/shell.mjs";

const encode = makeEncode({ Some, None, List });
let likeCount = 12;

function json(value) {
  return new Response(JSON.stringify(encode(value)), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}

const app = {
  async fetch(request) {
    const url = new URL(request.url);
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
    if (pathname.startsWith("/api/")) return app.fetch(request);
    return shell.fetch(
      request,
      { ...env, APP: app, SVELTE: svelte, YUMEMI_DEV: "1" },
      context,
    );
  },
};
