//// 面の門 `src/gen/gate.mjs` ── 生成 shell の entry lifecycle hook。
////
//// - `before_route(request, env)` ── route 表(literal-first)で Page を引き、URL の段の `-` をフォルダの `_` に
////   戻し、門(sign-in・主体・同意・既定の admit)と条件つきの redirect を当てる。
////   返り値は `{response}`(門で止めた)か `{request, route, session}`(通した。route は外れなら null)
//// - `after_response(request, env, response)` ── Page ごとの CSP の header と、数える印 `<meta name="yumemi-pageview">`
////   を足す(0.12)。印は頁の読み込みでも client 遷移の fetch でも同じ meta だけで、inline の script は出さない
////   ── 送るのは client.mjs の送り手(`yumemi/front/pageview.mjs`)1 つ
//// - `serve(dispatch)` ── 上の 2 本で dispatch を挟んだ Worker の `fetch`。生成 shell の export default
////
//// 値の運び(route の値・session・query を読みへ渡すこと)はここに無い。

import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi/gen/model
import yumemi/gen/reader/gate.{
  type Check, type Fail, type Gate, type Match, type Redirect, type Rule,
  reads_session,
}

/// Page の route の CSP の header の値(0.12)。`csp` の宣言のうち route に当たるものの指令を宣言順に足し合わせ、
/// 同じ指令の host は 1 つにまとめる。各指令の先頭に `'self'` を 1 つ自動で足す(framework の受け口・遷移の取得・
/// media は同じ origin にある。外す口は持たない)。当たる宣言が無ければ None。client 遷移の route 表(`emit/front` の
/// `navigation`)も同じ値を Page ごとに持つ。
pub fn csp_for(gate: Gate, path: String) -> option.Option(String) {
  let directives =
    gate.csp
    |> list.filter(fn(csp) {
      list.any(csp.pages, fn(match) { gate.covers(match, path) })
    })
    |> list.flat_map(fn(csp) { csp.directives })
  let names = list.unique(list.map(directives, fn(directive) { directive.0 }))
  case names {
    [] -> None
    _ ->
      Some(
        names
        |> list.map(fn(name) {
          let hosts =
            directives
            |> list.filter(fn(directive) { directive.0 == name })
            |> list.flat_map(fn(directive) { directive.1 })
            |> list.unique
          string.join(
            [name, "'self'", ..list.map(hosts, fn(host) { "https://" <> host })],
            " ",
          )
        })
        |> string.join("; "),
      )
  }
}

/// route ごとの CSP(CSP を持つ route だけ)。
pub fn csp_routes(
  gate: Gate,
  route_paths: List(String),
) -> List(#(String, String)) {
  list.filter_map(route_paths, fn(path) {
    case csp_for(gate, path) {
      Some(value) -> Ok(#(path, value))
      None -> Error(Nil)
    }
  })
}

pub fn text(header: String, gate: Gate, route_paths: List(String)) -> String {
  text_live(header, gate, route_paths, False)
}

/// `live`(0.14、面に `Live` の Block がある):断片の口の要求(header `x-yumemi-block`)には数える印を差さない。
/// 門の判定(成人の申告・同意・session)は頁と同じに掛かる。
pub fn text_live(
  header: String,
  gate: Gate,
  route_paths: List(String),
  live: Bool,
) -> String {
  let reads_session = reads_session(gate)
  let #(pageview_routes, pageview_only) = case gate.pageview {
    Some(pageview) -> #(
      expand(pageview.pages, route_paths),
      list.map(pageview.only, when_js),
    )
    None -> #([], [])
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
  <> "const sessionPath = "
  <> case gate.session_path {
    Some(path) -> quoted(path)
    None -> "null"
  }
  <> ";\n"
  <> "const rules = "
  <> js_list(list.map(gate.rules, rule_js), "\n  ")
  <> ";\n"
  <> "const redirects = "
  <> js_list(list.map(gate.redirects, redirect_js), "\n  ")
  <> ";\n"
  <> "const cspRoutes = "
  <> case csp_routes(gate, route_paths) {
    [] -> "{}"
    pairs ->
      "{\n"
      <> string.concat(
        list.map(pairs, fn(pair) {
          "  " <> quoted(pair.0) <> ": " <> quoted(pair.1) <> ",\n"
        }),
      )
      <> "}"
  }
  <> ";\n"
  <> "const pageviewRoutes = "
  <> js_list(list.map(pageview_routes, quoted), " ")
  <> ";\n"
  <> case live {
    True -> "const blockHeader = \"x-yumemi-block\";\n"
    False -> ""
  }
  <> "const pageviewOnly = "
  <> js_list(pageview_only, " ")
  <> ";\n"
  <> "\n"
  <> case live {
    True ->
      string.replace(
        runtime_for(gate),
        "if (!tracksPageview(context) ||",
        "if (request.headers.has(blockHeader) || !tracksPageview(context) ||",
      )
    False -> runtime_for(gate)
  }
}

fn when_js(when: model.GateWhen) -> String {
  case when {
    model.WhenDeclared(kind) ->
      "{type: \"declared\", kind: " <> quoted(kind) <> "}"
    model.WhenSignedIn -> "{type: \"signed-in\"}"
  }
}

/// 0.11.5 の語(`RedirectBack` / `FixedKeep`)を使う門だけ runtime に足す。使わない門の `gate.mjs` は 0.11.4 と同じ字。
fn runtime_for(gate: Gate) -> String {
  let back =
    list.any(gate.rules, fn(rule) {
      list.any(rule.checks, fn(check) {
        case check {
          gate.SignedIn(gate.RedirectBack(..))
          | gate.Declared(_, gate.RedirectBack(..))
          | gate.SubjectKind(_, gate.RedirectBack(..))
          | gate.Consented(_, gate.RedirectBack(..)) -> True
          _ -> False
        }
      })
    })
  let keep =
    list.any(gate.redirects, fn(redirect) {
      case redirect.to {
        gate.FixedKeep(..) -> True
        _ -> False
      }
    })
  let with_back = case back {
    False -> runtime
    True ->
      runtime
      |> string.replace(failed_tail, redirect_back_branch <> failed_tail)
      |> string.replace(
        redirect_for_head,
        redirect_back_fn <> redirect_for_head,
      )
  }
  case keep {
    False -> with_back
    True -> string.replace(with_back, fixed_location, fixed_keep_location)
  }
}

const failed_tail = "  return redirectTo(302, fail.location);\n}\n"

const redirect_back_branch =
  "  if (fail.type === \"redirect-back\") return redirectBack(fail, request);\n"

const redirect_for_head = "function redirectFor(redirect, session, url) {\n"

const redirect_back_fn =
  "// 面の中の location へ、要求の path + search を param に付けて返す。面の中の path でなければ付けない(safeParam の判定)
function redirectBack(fail, request) {
  const url = new URL(request.url);
  const back = safeParam(url.pathname + url.search, null);
  if (back === null) return redirectTo(302, fail.location);
  const joint = fail.location.includes(\"?\") ? \"&\" : \"?\";
  return redirectTo(302, fail.location + joint + fail.param + \"=\" + encodeURIComponent(back));
}

"

const fixed_location = "    ? redirect.to.location\n    : safeParam("

const fixed_keep_location =
  "    ? redirect.to.location\n    : redirect.to.type === \"fixed-keep\"\n    ? redirect.to.location + url.search\n    : safeParam("

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
    gate.Declared(kind, fail) ->
      "{type: \"declared\", kind: "
      <> quoted(kind)
      <> ", fail: "
      <> fail_js(fail)
      <> "}"
    gate.SubjectKind(kinds, fail) ->
      "{type: \"subject-kind\", kinds: "
      <> js_list(list.map(kinds, quoted), " ")
      <> ", fail: "
      <> fail_js(fail)
      <> "}"
    gate.Consented(kind, fail) ->
      "{type: \"consented\", kind: "
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
    gate.RedirectBack(location, param) ->
      "{type: \"redirect-back\", location: "
      <> quoted(location)
      <> ", param: "
      <> quoted(param)
      <> "}"
  }
}

fn redirect_js(redirect: Redirect) -> String {
  "{pages: "
  <> js_list(list.map(redirect.pages, match_js), " ")
  <> ", when: "
  <> when_js(redirect.when)
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
    gate.FixedKeep(location) ->
      "{type: \"fixed-keep\", location: " <> quoted(location) <> "}"
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

const runtime =
  "const contexts = new WeakMap();
const pageviewMark = \"<meta name=\\\"yumemi-pageview\\\">\";

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
  if (sessionPath === null) return {status: 502, ok: false, session: null, cause: \"session path is missing\"};
  try {
    const response = await env.APP.fetch(new Request(new URL(sessionPath, request.url), request));
    if (!response.ok) return {status: response.status, ok: false, session: null, cause: \"session read returned \" + response.status};
    // 本文が JSON でないのも読めなかった方(匿名に畳まない)
    const session = await response.json();
    return {status: response.status, ok: true, session};
  } catch (error) {
    return {status: 502, ok: false, session: null, cause: error};
  }
}

function checkFailure(check, read, request, env) {
  const session = read.session;
  if (check.type === \"admitted\") {
    if (!read.ok) return readFailure(read);
    const subject = session?.subject;
    if (!subject || (check.kinds.length > 0 && !check.kinds.includes(subject.kind)) || typeof subject.handle !== \"string\") {
      return text(403, \"forbidden\");
    }
    return null;
  }
  if (check.type === \"signed-in\") {
    if (read.status === 401 || read.status === 403) return failed(check.fail, request, env);
    if (!read.ok) return readFailure(read);
    if (!session || session.anonymous) return failed(check.fail, request, env);
    return null;
  }
  if (!read.ok) return readFailure(read);
  if (check.type === \"declared\") return passes({type: \"declared\", kind: check.kind}, session) ? null : failed(check.fail, request, env);
  if (check.type === \"subject-kind\") return check.kinds.includes(session?.subject?.kind) ? null : failed(check.fail, request, env);
  if (check.type === \"consented\") return session?.consents?.[check.kind] === true ? null : failed(check.fail, request, env);
  return text(403, \"forbidden\");
}

// 門が自分で返す本文は 403 の forbidden・404 の not found・503 の unavailable の 3 つ(0.12)。
// 読みの 5xx(APP binding の例外・session の path が無いときを含む)は権限の拒否に畳まず、元の status と原因を log に出す
function readFailure(read) {
  if (read.status === 404) return text(404, \"not found\");
  if (read.status >= 500) {
    console.error(\"yumemi gate: session read error\", read.status, read.cause);
    return text(503, \"unavailable\");
  }
  return text(403, \"forbidden\");
}

// 門の条件(`WhenDeclared(kind)` / `WhenSignedIn`)
function passes(when, session) {
  if (when.type === \"declared\") return session?.declared?.[when.kind] === true;
  return Boolean(session) && !session.anonymous;
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
  if (!passes(redirect.when, session)) return null;
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
    // 読みの 5xx は「読めなかった」で匿名(null)ではない。shell へは読んでいない(undefined)として渡し、
    // session を要る頁では shell が読み直して 503 にする(0.12)
    const unreadable = !read.ok && read.status >= 500;
    session = unreadable ? undefined : read.session;
    for (const rule of rules) {
      if (!anyCovers(rule.pages, matched.path) || anyCovers(rule.except, matched.path)) continue;
      for (const check of rule.checks) {
        const response = checkFailure(check, read, request, env);
        if (response) return {response};
      }
    }
    for (const redirect of redirects) {
      if (!anyCovers(redirect.pages, matched.path)) continue;
      if (unreadable) return {response: readFailure(read)};
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
  return pageviewRoutes.includes(context.path) && Object.values(context.params).every((value) => value !== \"\")
    && pageviewOnly.every((when) => passes(when, context.session));
}

export async function after_response(request, env, response) {
  const context = contexts.get(request);
  if (!context) return response;
  let output = response;
  const csp = Object.hasOwn(cspRoutes, context.path) ? cspRoutes[context.path] : null;
  if (csp !== null && isHtml(output)) {
    const headers = new Headers(output.headers);
    headers.set(\"content-security-policy\", csp);
    output = new Response(output.body, {status: output.status, statusText: output.statusText, headers});
  }
  if (!tracksPageview(context) || output.status !== 200 || !isHtml(output)) return output;
  // 数える印は頁の読み込みでも client 遷移の fetch でも同じ meta だけ。送るのは client.mjs の送り手 1 つ
  const html = await output.text();
  const offset = html.indexOf(\"</head>\");
  if (offset < 0) throw new Error(\"SSR head is missing\");
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
"
