// GENERATED from public/src/{gate.gleam,pages/**} and src/{entry,server}.gleam [sha256:8446dd81f19f] — 手で編集しない

import * as route from "./route.mjs";

const signIn = {path: "/auth/sign-in", fallback: "https://auth.example"};
const readsSession = true;
const sessionPath = "/fixture/session";
const rules = [
  {pages: [{type: "exact", path: "/status"}], except: [], checks: [{type: "declared", kind: "adult", fail: {type: "redirect-back", location: "/", param: "next"}}]},
  {pages: [{type: "prefix", path: "/article"}], except: [], checks: [{type: "consented", kind: "use", fail: {type: "sign-in", status: 302, back: true}}]},
];
const redirects = [
  {pages: [{type: "exact", path: "/status"}], when: {type: "declared", kind: "region"}, to: {type: "safe-param", param: "returnTo", fallback: "/status"}},
];
const cspRoutes = {
  "/article/:slug": "frame-src 'self' https://frames.example https://*.video.example; img-src 'self' https://img.example",
  "/status": "connect-src 'self' https://api.example; media-src 'self' https://media.example",
};
const pageviewRoutes = ["/article/:slug", "/status"];
const pageviewOnly = [{type: "declared", kind: "adult"}];

const contexts = new WeakMap();
const pageviewMark = "<meta name=\"yumemi-pageview\">";

function literalMatches(segment, value) {
  return segment === value || segment.replaceAll("_", "-") === value;
}

function matchRoute(pathname) {
  const actual = pathname.split("/");
  for (const pageRoute of route.routes) {
    const expected = pageRoute.path.split("/");
    if (expected.length !== actual.length) continue;
    const params = {};
    let matches = true;
    for (let index = 0; index < expected.length; index += 1) {
      const segment = expected[index];
      if (segment.startsWith(":")) params[segment.slice(1)] = decodeURIComponent(actual[index]);
      else if (!literalMatches(segment, actual[index])) {
        matches = false;
        break;
      }
    }
    if (!matches) continue;
    const canonical = expected.map((segment, index) => segment.startsWith(":") ? actual[index] : segment).join("/");
    return {path: pageRoute.path, params, pathname: canonical};
  }
  return null;
}

function covers(match, path) {
  if (match.type === "every") return true;
  if (match.type === "exact") return match.path === path;
  return match.path === "/" || path === match.path || path.startsWith(match.path + "/");
}

function anyCovers(matches, path) {
  return matches.some((match) => covers(match, path));
}

function text(status, body) {
  return new Response(body, {status, headers: {"content-type": "text/plain; charset=utf-8"}});
}

function redirectTo(status, location) {
  return new Response(null, {status, headers: {Location: location}});
}

function signInResponse(fail, request, env) {
  const origin = env.PUBLIC_IDP_ORIGIN || signIn.fallback;
  const target = origin + signIn.path + (fail.back ? "?redirect_uri=" + encodeURIComponent(request.url) : "");
  return redirectTo(fail.status, target);
}

function failed(fail, request, env) {
  if (fail.type === "sign-in") return signInResponse(fail, request, env);
  if (fail.type === "deny") return text(fail.status, fail.body);
  if (fail.type === "redirect-back") return redirectBack(fail, request);
  return redirectTo(302, fail.location);
}

async function readSession(request, env) {
  if (sessionPath === null) return {status: 502, ok: false, session: null, cause: "session path is missing"};
  try {
    const response = await env.APP.fetch(new Request(new URL(sessionPath, request.url), request));
    if (!response.ok) return {status: response.status, ok: false, session: null, cause: "session read returned " + response.status};
    const session = await response.json().catch(() => null);
    return {status: response.status, ok: true, session};
  } catch (error) {
    return {status: 502, ok: false, session: null, cause: error};
  }
}

function checkFailure(check, read, request, env) {
  const session = read.session;
  if (check.type === "admitted") {
    if (!read.ok) return readFailure(read);
    const subject = session?.subject;
    if (!subject || (check.kinds.length > 0 && !check.kinds.includes(subject.kind)) || typeof subject.handle !== "string") {
      return text(403, "forbidden");
    }
    return null;
  }
  if (check.type === "signed-in") {
    if (read.status === 401 || read.status === 403) return failed(check.fail, request, env);
    if (!read.ok) return readFailure(read);
    if (!session || session.anonymous) return failed(check.fail, request, env);
    return null;
  }
  if (!read.ok) return readFailure(read);
  if (check.type === "declared") return passes({type: "declared", kind: check.kind}, session) ? null : failed(check.fail, request, env);
  if (check.type === "subject-kind") return check.kinds.includes(session?.subject?.kind) ? null : failed(check.fail, request, env);
  if (check.type === "consented") return session?.consents?.[check.kind] === true ? null : failed(check.fail, request, env);
  return text(403, "forbidden");
}

// 門が自分で返す本文は 403 の forbidden・404 の not found・503 の unavailable の 3 つ(0.12)。
// 読みの 5xx(APP binding の例外・session の path が無いときを含む)は権限の拒否に畳まず、元の status と原因を log に出す
function readFailure(read) {
  if (read.status === 404) return text(404, "not found");
  if (read.status >= 500) {
    console.error("yumemi gate: session read error", read.status, read.cause);
    return text(503, "unavailable");
  }
  return text(403, "forbidden");
}

// 門の条件(`WhenDeclared(kind)` / `WhenSignedIn`)
function passes(when, session) {
  if (when.type === "declared") return session?.declared?.[when.kind] === true;
  return Boolean(session) && !session.anonymous;
}

function safeParam(value, fallback) {
  if (!value || !value.startsWith("/") || value.startsWith("//") || /[\\\u0000-\u001f]/.test(value)) {
    return fallback;
  }
  try {
    const url = new URL(value, "https://yumemi.invalid");
    if (url.origin !== "https://yumemi.invalid") return fallback;
    const out = url.pathname + url.search + url.hash;
    return out.startsWith("//") ? fallback : out;
  } catch (_) {
    return fallback;
  }
}

// 面の中の location へ、要求の path + search を param に付けて返す。面の中の path でなければ付けない(safeParam の判定)
function redirectBack(fail, request) {
  const url = new URL(request.url);
  const back = safeParam(url.pathname + url.search, null);
  if (back === null) return redirectTo(302, fail.location);
  const joint = fail.location.includes("?") ? "&" : "?";
  return redirectTo(302, fail.location + joint + fail.param + "=" + encodeURIComponent(back));
}

function redirectFor(redirect, session, url) {
  if (!passes(redirect.when, session)) return null;
  const location = redirect.to.type === "fixed"
    ? redirect.to.location
    : safeParam(url.searchParams.get(redirect.to.param), redirect.to.fallback);
  return redirectTo(302, location);
}

export async function before_route(request, env) {
  const url = new URL(request.url);
  const matched = matchRoute(url.pathname);
  if (!matched) return {request, route: null, session: undefined};
  let routed = request;
  if (matched.pathname !== url.pathname) {
    const target = new URL(request.url);
    target.pathname = matched.pathname;
    routed = new Request(target, request);
  }
  let session = undefined;
  if (readsSession) {
    const read = await readSession(request, env);
    session = read.session;
    for (const rule of rules) {
      if (!anyCovers(rule.pages, matched.path) || anyCovers(rule.except, matched.path)) continue;
      for (const check of rule.checks) {
        const response = checkFailure(check, read, request, env);
        if (response) return {response};
      }
    }
    for (const redirect of redirects) {
      if (!anyCovers(redirect.pages, matched.path)) continue;
      const response = redirectFor(redirect, session, url);
      if (response) return {response};
    }
  }
  const context = {path: matched.path, params: matched.params, session};
  contexts.set(routed, context);
  return {request: routed, route: {path: matched.path, params: matched.params}, session};
}

function isHtml(response) {
  return response.headers.get("content-type")?.startsWith("text/html") ?? false;
}

function tracksPageview(context) {
  return pageviewRoutes.includes(context.path) && Object.values(context.params).every((value) => value !== "")
    && pageviewOnly.every((when) => passes(when, context.session));
}

export async function after_response(request, env, response) {
  const context = contexts.get(request);
  if (!context) return response;
  let output = response;
  const csp = Object.hasOwn(cspRoutes, context.path) ? cspRoutes[context.path] : null;
  if (csp !== null && isHtml(output)) {
    const headers = new Headers(output.headers);
    headers.set("content-security-policy", csp);
    output = new Response(output.body, {status: output.status, statusText: output.statusText, headers});
  }
  if (!tracksPageview(context) || output.status !== 200 || !isHtml(output)) return output;
  // 数える印は頁の読み込みでも client 遷移の fetch でも同じ meta だけ。送るのは client.mjs の送り手 1 つ
  const html = await output.text();
  const offset = html.indexOf("</head>");
  if (offset < 0) throw new Error("SSR head is missing");
  return new Response(html.slice(0, offset) + pageviewMark + html.slice(offset), {
    status: output.status,
    statusText: output.statusText,
    headers: new Headers(output.headers),
  });
}

export function serve(dispatch) {
  return {
    async fetch(request, env) {
      const before = await before_route(request, env);
      if (before.response) return before.response;
      const response = await dispatch(before.request, env, before);
      return after_response(before.request, env, response);
    },
  };
}
