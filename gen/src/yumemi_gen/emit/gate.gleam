//// 面の門 `src/gen/gate.mjs` ── 生成 shell の entry lifecycle hook。
////
//// - `before_route(request, env)` ── route 表(literal-first)で Page を引き、URL の段の `-` をフォルダの `_` に
////   戻し、門(sign-in・主体・同意・既定の admit)と条件つきの redirect を当てる。
////   返り値は `{response}`(門で止めた)か `{request, route, session}`(通した。route は外れなら null)
//// - `after_response(request, env, response)` ── CSP `frame-src` と pageview の script を足す
//// - `serve(dispatch)` ── 上の 2 本で dispatch を挟んだ Worker の `fetch`。生成 shell の export default
////
//// 値の運び(route の値・session・query を読みへ渡すこと)はここに無い。

import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi_gen/reader/gate.{
  type Check, type Fail, type Gate, type Match, type Redirect, type Rule,
}

pub fn text(header: String, gate: Gate, route_paths: List(String)) -> String {
  let reads_session = gate.rules != [] || gate.redirects != []
  let reads_session = case gate.pageview {
    Some(_) -> True
    None -> reads_session
  }
  let pageview_routes = case gate.pageview {
    Some(pageview) -> expand(pageview.pages, route_paths)
    None -> []
  }
  let frame_src = case gate.frame_hosts {
    [] -> "null"
    hosts ->
      quoted(
        "frame-src "
        <> string.join(list.map(hosts, fn(host) { "https://" <> host }), " "),
      )
  }
  header
  <> "\n\n"
  <> "import * as route from \"./route.mjs\";\n\n"
  <> "const signIn = {path: "
  <> quoted(gate.sign_in_path)
  <> ", fallback: "
  <> quoted(gate.sign_in_fallback)
  <> "};\n"
  <> "const readsSession = "
  <> bool(reads_session)
  <> ";\n"
  <> "const rules = "
  <> js_list(list.map(gate.rules, rule_js), "\n  ")
  <> ";\n"
  <> "const redirects = "
  <> js_list(list.map(gate.redirects, redirect_js), "\n  ")
  <> ";\n"
  <> "const frameSrc = "
  <> frame_src
  <> ";\n"
  <> "const framePages = "
  <> js_list(list.map(gate.frame_src, match_js), " ")
  <> ";\n"
  <> "const pageviewRoutes = "
  <> js_list(list.map(pageview_routes, quoted), " ")
  <> ";\n"
  <> case gate.pageview {
    Some(pageview) ->
      "const pageviewScript = String.raw`"
      <> pageview_script(
        pageview_routes,
        pageview.endpoint,
        pageview.source_param,
        pageview.storage_key,
      )
      <> "`;\n"
    None -> "const pageviewScript = null;\n"
  }
  <> "\n"
  <> runtime
}

fn expand(matches: List(Match), route_paths: List(String)) -> List(String) {
  route_paths
  |> list.filter(fn(path) {
    list.any(matches, fn(match) { gate.covers(match, path) })
  })
}

fn rule_js(rule: Rule) -> String {
  "{pages: "
  <> js_list(list.map(rule.pages, match_js), " ")
  <> ", except: "
  <> js_list(list.map(rule.except, match_js), " ")
  <> ", checks: "
  <> js_list(list.map(rule.checks, check_js), " ")
  <> "}"
}

fn match_js(match: Match) -> String {
  case match {
    gate.Every -> "{type: \"every\"}"
    gate.Exact(path) -> "{type: \"exact\", path: " <> quoted(path) <> "}"
    gate.Prefix(path) -> "{type: \"prefix\", path: " <> quoted(path) <> "}"
  }
}

fn check_js(check: Check) -> String {
  case check {
    gate.SignedIn(fail) ->
      "{type: \"signed-in\", fail: " <> fail_js(fail) <> "}"
    gate.Adult(fail) -> "{type: \"adult\", fail: " <> fail_js(fail) <> "}"
    gate.SubjectKind(kinds, fail) ->
      "{type: \"subject-kind\", kinds: "
      <> js_list(list.map(kinds, quoted), " ")
      <> ", fail: "
      <> fail_js(fail)
      <> "}"
    gate.Consent(kind, fail) ->
      "{type: \"consent\", kind: "
      <> quoted(kind)
      <> ", fail: "
      <> fail_js(fail)
      <> "}"
    gate.Admitted(kinds) ->
      "{type: \"admitted\", kinds: "
      <> js_list(list.map(kinds, quoted), " ")
      <> "}"
  }
}

fn fail_js(fail: Fail) -> String {
  case fail {
    gate.ToSignIn(status, back) ->
      "{type: \"sign-in\", status: "
      <> int.to_string(status)
      <> ", back: "
      <> bool(back)
      <> "}"
    gate.Deny(status, body) ->
      "{type: \"deny\", status: "
      <> int.to_string(status)
      <> ", body: "
      <> quoted(body)
      <> "}"
    gate.RedirectTo(location) ->
      "{type: \"redirect\", location: " <> quoted(location) <> "}"
  }
}

fn redirect_js(redirect: Redirect) -> String {
  "{pages: "
  <> js_list(list.map(redirect.pages, match_js), " ")
  <> ", when: "
  <> case redirect.when_adult {
    True -> "\"adult\""
    False -> "\"signed-in\""
  }
  <> ", to: "
  <> case redirect.to {
    gate.SafeParam(param, fallback) ->
      "{type: \"safe-param\", param: "
      <> quoted(param)
      <> ", fallback: "
      <> quoted(fallback)
      <> "}"
    gate.Fixed(location) ->
      "{type: \"fixed\", location: " <> quoted(location) <> "}"
  }
  <> "}"
}

fn js_list(items: List(String), separator: String) -> String {
  case items, separator {
    [], _ -> "[]"
    _, "\n  " -> "[\n  " <> string.join(items, ",\n  ") <> ",\n]"
    _, _ -> "[" <> string.join(items, ", ") <> "]"
  }
}

fn bool(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn quoted(value: String) -> String {
  "\""
  <> value
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  <> "\""
}

/// 成人 session の追跡 Page に差す script。対象の判定は server と同じ route の表で、
/// param の段は空でないこと、URL の段の `-` はフォルダの `_` に対応する。
fn pageview_script(
  routes: List(String),
  endpoint: String,
  source_param: String,
  storage_key: String,
) -> String {
  [
    "<script>",
    "(() => {",
    "  const trackedRoutes = " <> js_list(list.map(routes, quoted), " ") <> ";",
    "  const trackedPath = (pathname) => {",
    "    const actual = pathname.split(\"/\");",
    "    return trackedRoutes.some((route) => {",
    "      const expected = route.split(\"/\");",
    "      return expected.length === actual.length && expected.every((segment, index) => segment.startsWith(\":\")",
    "        ? actual[index] !== \"\"",
    "        : segment === actual[index] || segment.replaceAll(\"_\", \"-\") === actual[index]);",
    "    });",
    "  };",
    "  if (!trackedPath(location.pathname)) return;",
    "",
    "  const previousEventKey = " <> quoted(storage_key) <> ";",
    "  let previousEvent = null;",
    "  try {",
    "    const navigation = performance.getEntriesByType(\"navigation\")[0];",
    "    if (window.opener && navigation?.type === \"navigate\") {",
    "      sessionStorage.removeItem(previousEventKey);",
    "    } else {",
    "      const value = sessionStorage.getItem(previousEventKey);",
    "      previousEvent = value && /^[0-9a-f-]{36}$/.test(value) ? value : null;",
    "    }",
    "  } catch (_) {}",
    "",
    "  const send = () => {",
    "    const id = crypto.randomUUID();",
    "    const navigation = performance.getEntriesByType(\"navigation\")[0];",
    "    const payload = {",
    "      id,",
    "      client_at: new Date().toISOString(),",
    "      kind: navigation?.type === \"reload\" ? \"reload\" : \"initial\",",
    "      path: location.pathname",
    "    };",
    "    if (!previousEvent && document.referrer) {",
    "      try {",
    "        const referrer = new URL(document.referrer);",
    "        if (referrer.origin === location.origin) payload.referrer_path = referrer.pathname;",
    "        else payload.referrer_host = referrer.host;",
    "      } catch (_) {}",
    "    }",
    "    if (previousEvent) payload.prev = previousEvent;",
    "    const sourceKey = new URL(location.href).searchParams.get("
      <> quoted(source_param)
      <> ");",
    "    if (sourceKey && /^[a-z0-9_]{1,16}$/.test(sourceKey)) payload.source_key = sourceKey;",
    "    previousEvent = id;",
    "    try { sessionStorage.setItem(previousEventKey, id); } catch (_) {}",
    "",
    "    const body = JSON.stringify(payload);",
    "    void fetch(" <> quoted(endpoint) <> ", {",
    "      method: \"POST\",",
    "      headers: {\"content-type\": \"application/json\"},",
    "      body,",
    "      keepalive: true",
    "    }).catch(() => fetch(" <> quoted(endpoint) <> ", {",
    "      method: \"POST\",",
    "      headers: {\"content-type\": \"application/json\"},",
    "      body,",
    "      keepalive: true",
    "    }).catch(() => {}));",
    "  };",
    "",
    "  const afterPaint = () => {",
    "    if (\"requestIdleCallback\" in window) window.requestIdleCallback(send, {timeout: 1000});",
    "    else requestAnimationFrame(send);",
    "  };",
    "  if (document.readyState === \"complete\") afterPaint();",
    "  else window.addEventListener(\"load\", afterPaint, {once: true});",
    "})();",
    "</script>",
  ]
  |> string.join("\n")
}

const runtime = "const contexts = new WeakMap();

function literalMatches(segment, value) {
  return segment === value || segment.replaceAll(\"_\", \"-\") === value;
}

function matchRoute(pathname) {
  const actual = pathname.split(\"/\");
  for (const pageRoute of route.routes) {
    const expected = pageRoute.path.split(\"/\");
    if (expected.length !== actual.length) continue;
    const params = {};
    let matches = true;
    for (let index = 0; index < expected.length; index += 1) {
      const segment = expected[index];
      if (segment.startsWith(\":\")) params[segment.slice(1)] = decodeURIComponent(actual[index]);
      else if (!literalMatches(segment, actual[index])) {
        matches = false;
        break;
      }
    }
    if (!matches) continue;
    const canonical = expected.map((segment, index) => segment.startsWith(\":\") ? actual[index] : segment).join(\"/\");
    return {path: pageRoute.path, params, pathname: canonical};
  }
  return null;
}

function covers(match, path) {
  if (match.type === \"every\") return true;
  if (match.type === \"exact\") return match.path === path;
  return match.path === \"/\" || path === match.path || path.startsWith(match.path + \"/\");
}

function anyCovers(matches, path) {
  return matches.some((match) => covers(match, path));
}

function text(status, body) {
  return new Response(body, {status, headers: {\"content-type\": \"text/plain; charset=utf-8\"}});
}

function redirectTo(status, location) {
  return new Response(null, {status, headers: {Location: location}});
}

function signInResponse(fail, request, env) {
  const origin = env.PUBLIC_IDP_ORIGIN || signIn.fallback;
  const target = origin + signIn.path + (fail.back ? \"?redirect_uri=\" + encodeURIComponent(request.url) : \"\");
  return redirectTo(fail.status, target);
}

function failed(fail, request, env) {
  if (fail.type === \"sign-in\") return signInResponse(fail, request, env);
  if (fail.type === \"deny\") return text(fail.status, fail.body);
  return redirectTo(302, fail.location);
}

async function readSession(request, env) {
  try {
    const response = await env.APP.fetch(new Request(new URL(\"/api/session\", request.url), request));
    if (!response.ok) return {status: response.status, ok: false, session: null};
    const session = await response.json().catch(() => null);
    return {status: response.status, ok: true, session};
  } catch (_) {
    return {status: 502, ok: false, session: null};
  }
}

function checkFailure(check, read, request, env) {
  const session = read.session;
  if (check.type === \"admitted\") {
    if (!read.ok) {
      if (read.status === 403) return text(403, \"adult declaration required\");
      if (read.status === 404) return text(404, \"muse not found\");
      return text(read.status, \"session read failed\");
    }
    const subject = session?.subject;
    if (!subject || (check.kinds.length > 0 && !check.kinds.includes(subject.kind)) || typeof subject.handle !== \"string\") {
      return text(403, \"adult declaration required\");
    }
    return null;
  }
  if (check.type === \"signed-in\") {
    if (read.status === 401 || read.status === 403) return failed(check.fail, request, env);
    if (!read.ok) return text(read.status, \"session read failed\");
    if (!session || session.anonymous) return failed(check.fail, request, env);
    return null;
  }
  if (!read.ok) return text(read.status, \"session read failed\");
  if (check.type === \"adult\") return session?.adult === true ? null : failed(check.fail, request, env);
  if (check.type === \"subject-kind\") return check.kinds.includes(session?.subject?.kind) ? null : failed(check.fail, request, env);
  if (check.type === \"consent\") return session?.consents?.[check.kind] ? null : failed(check.fail, request, env);
  return text(500, \"invalid gate check\");
}

function safeParam(value, fallback) {
  if (!value || !value.startsWith(\"/\") || value.startsWith(\"//\") || /[\\\\\\u0000-\\u001f]/.test(value)) {
    return fallback;
  }
  try {
    const url = new URL(value, \"https://yumemi.invalid\");
    if (url.origin !== \"https://yumemi.invalid\") return fallback;
    const out = url.pathname + url.search + url.hash;
    return out.startsWith(\"//\") ? fallback : out;
  } catch (_) {
    return fallback;
  }
}

function redirectFor(redirect, session, url) {
  const passes = redirect.when === \"adult\"
    ? session?.adult === true
    : Boolean(session) && !session.anonymous;
  if (!passes) return null;
  const location = redirect.to.type === \"fixed\"
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
  return response.headers.get(\"content-type\")?.startsWith(\"text/html\") ?? false;
}

function tracksPageview(context) {
  return pageviewRoutes.includes(context.path) && Object.values(context.params).every((value) => value !== \"\");
}

export async function after_response(request, env, response) {
  const context = contexts.get(request);
  if (!context) return response;
  let output = response;
  if (frameSrc !== null && anyCovers(framePages, context.path) && isHtml(output)) {
    const headers = new Headers(output.headers);
    headers.set(\"content-security-policy\", frameSrc);
    output = new Response(output.body, {status: output.status, statusText: output.statusText, headers});
  }
  if (pageviewScript === null || !tracksPageview(context) || output.status !== 200 || !isHtml(output)) return output;
  if (context.session?.adult !== true) return output;
  const html = await output.text();
  const offset = html.indexOf(\"</body>\");
  if (offset < 0) throw new Error(\"SSR body is missing\");
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
"
