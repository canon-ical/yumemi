// GENERATED from public/src/{gate.gleam,pages/**} and src/{entry,server}.gleam [sha256:2cc97fd670ec] — 手で編集しない

import * as route from "./route.mjs";

const signIn = {path: "/auth/sign-in", fallback: ""};
const readsSession = false;
const sessionPath = "/fixture/session";
const rules = [];
const redirects = [];
const frameSrc = null;
const framePages = [];
const pageviewRoutes = [];
const pageviewScript = null;

const contexts = new WeakMap();

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
  return redirectTo(302, fail.location);
}

async function readSession(request, env) {
  if (sessionPath === null) return {status: 502, ok: false, session: null};
  try {
    const response = await env.APP.fetch(new Request(new URL(sessionPath, request.url), request));
    if (!response.ok) return {status: response.status, ok: false, session: null};
    const session = await response.json().catch(() => null);
    return {status: response.status, ok: true, session};
  } catch (_) {
    return {status: 502, ok: false, session: null};
  }
}

function checkFailure(check, read, request, env) {
  const session = read.session;
  if (check.type === "admitted") {
    if (!read.ok) {
      if (read.status === 403) return text(403, "adult declaration required");
      if (read.status === 404) return text(404, "muse not found");
      return text(read.status, "session read failed");
    }
    const subject = session?.subject;
    if (!subject || (check.kinds.length > 0 && !check.kinds.includes(subject.kind)) || typeof subject.handle !== "string") {
      return text(403, "adult declaration required");
    }
    return null;
  }
  if (check.type === "signed-in") {
    if (read.status === 401 || read.status === 403) return failed(check.fail, request, env);
    if (!read.ok) return text(read.status, "session read failed");
    if (!session || session.anonymous) return failed(check.fail, request, env);
    return null;
  }
  if (!read.ok) return text(read.status, "session read failed");
  if (check.type === "adult") return session?.adult === true ? null : failed(check.fail, request, env);
  if (check.type === "subject-kind") return check.kinds.includes(session?.subject?.kind) ? null : failed(check.fail, request, env);
  if (check.type === "consent") return session?.consents?.[check.kind] ? null : failed(check.fail, request, env);
  return text(500, "invalid gate check");
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

function redirectFor(redirect, session, url) {
  const passes = redirect.when === "adult"
    ? session?.adult === true
    : Boolean(session) && !session.anonymous;
  if (!passes) return null;
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
  return pageviewRoutes.includes(context.path) && Object.values(context.params).every((value) => value !== "");
}

export async function after_response(request, env, response) {
  const context = contexts.get(request);
  if (!context) return response;
  let output = response;
  if (frameSrc !== null && anyCovers(framePages, context.path) && isHtml(output)) {
    const headers = new Headers(output.headers);
    headers.set("content-security-policy", frameSrc);
    output = new Response(output.body, {status: output.status, statusText: output.statusText, headers});
  }
  if (pageviewScript === null || !tracksPageview(context) || output.status !== 200 || !isHtml(output)) return output;
  if (context.session?.adult !== true) return output;
  const html = await output.text();
  const offset = html.indexOf("</body>");
  if (offset < 0) throw new Error("SSR body is missing");
  return new Response(html.slice(0, offset) + pageviewScript + html.slice(offset), {
    status: output.status,
    statusText: output.statusText,
    headers: output.headers,
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
