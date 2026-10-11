//// 面の門の宣言(`<face>/src/gate.gleam` の `pub const gate`、型は `yumemi/gate`)を読む。
////
//// 宣言が無い面は、入口 `Http` の `admit` / `subject` から既定の門を組む(`Authenticated` の面だけ)。
//// CSP は門の `csp`(Page 群と閉じた指令の組、0.12)。host の綴りが外れれば exit 4(51 v6 第 38 条)。
//// 数える口 `pageview` の欄の重なりと綴り(第 35 条)、`pages` の指し先(第 34 条)もここで見る。
//// session を読む口は `api/src/server.gleam` の `attached_roles` の `ReadSession` が指す attached の path
//// (framework は app の口の名を知らない)。門が session を読むのに `ReadSession` が無ければ exit 3。
//// Page の指し先(`Exact` / `Prefix`)が面の route に無ければ exit 4。

import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import yumemi/gen/glance_util as g
import yumemi/gen/model
import yumemi/gen/naming
import yumemi/gen/source.{type Unit}
import yumemi/gen/stop.{type Note, Note}

pub type Gate {
  Gate(
    /// `src/gate.gleam` から読んだか(False は入口からの既定か、門無し)。
    declared: Bool,
    sign_in_path: String,
    sign_in_fallback: String,
    rules: List(Rule),
    redirects: List(Redirect),
    csp: List(Csp),
    pageview: Option(Pageview),
    /// session を読む口の path(`ReadSession` の attached)。宣言が無ければ None。
    session_path: Option(String),
  )
}

pub type Match {
  Exact(path: String)
  Prefix(path: String)
  Every
}

pub type Rule {
  Rule(pages: List(Match), except: List(Match), checks: List(Check))
}

pub type Check {
  SignedIn(fail: Fail)
  Declared(kind: String, fail: Fail)
  SubjectKind(kinds: List(String), fail: Fail)
  Consented(kind: String, fail: Fail)
  /// 入口の `admit: Authenticated` からの既定。session の読みの失敗は生成 shell の読みの失敗と同じ本文で返す。
  Admitted(kinds: List(String))
}

pub type Fail {
  ToSignIn(status: Int, back: Bool)
  Deny(status: Int, body: String)
  RedirectTo(location: String)
  /// 0.11.5:面の中の `location` へ、query `param` に要求の path + search を付けて返す。
  RedirectBack(location: String, param: String)
}

pub type Redirect {
  Redirect(pages: List(Match), when: model.GateWhen, to: To)
}

pub type To {
  SafeParam(param: String, fallback: String)
  Fixed(location: String)
  /// 0.11.5:決まった path に要求の query を保って返す。
  FixedKeep(location: String)
}

pub type Csp {
  Csp(pages: List(Match), directives: List(#(String, List(String))))
}

pub type Pageview {
  Pageview(
    pages: List(Match),
    only: List(model.GateWhen),
    fields: List(model.PageviewField),
    sink: model.PageviewSink,
  )
}

/// 門が session を読むか(rules・redirects か、条件 `only` を持つ pageview のどれかを持つ)。
pub fn reads_session(gate: Gate) -> Bool {
  gate.rules != []
  || gate.redirects != []
  || case gate.pageview {
    Some(pageview) -> pageview.only != []
    None -> False
  }
}

/// 門が何かを持つか。持たない面の `gate.mjs` は素通しになる。
pub fn is_empty(gate: Gate) -> Bool {
  gate.rules == []
  && gate.redirects == []
  && gate.csp == []
  && gate.pageview == None
}

pub fn read(
  face_name: String,
  face_units: List(Unit),
  back_units: List(Unit),
  entries: List(model.Entry),
  route_paths: List(String),
  session_path: Option(String),
) -> #(Gate, List(Note)) {
  let #(gate, notes) =
    read_gate(face_name, face_units, back_units, entries, route_paths)
  let gate = Gate(..gate, session_path: session_path)
  case reads_session(gate), session_path {
    True, None -> #(gate, [
      Note(
        stop.Missing,
        face_name
          <> "/gate: 門が session を読むのに src/server.gleam の attached_roles に `ReadSession` が無い",
      ),
      ..notes
    ])
    _, _ -> #(gate, notes)
  }
}

fn read_gate(
  face_name: String,
  face_units: List(Unit),
  back_units: List(Unit),
  entries: List(model.Entry),
  route_paths: List(String),
) -> #(Gate, List(Note)) {
  let _ = back_units
  case list.find(face_units, fn(unit) { unit.path == "gate" }) {
    Error(_) -> #(default_gate(face_name, entries), [])
    Ok(unit) ->
      case g.find_constant(g.in_order(unit.module), "gate") {
        None -> #(default_gate(face_name, entries), [
          Note(
            stop.Missing,
            face_name <> "/gate: `pub const gate` が無い(門の宣言は `gate` の 1 つ)",
          ),
        ])
        Some(constant) ->
          case gate_of(constant.value) {
            Error(reason) -> #(empty(), [
              Note(stop.Conflict, face_name <> "/gate: " <> reason),
            ])
            Ok(gate) -> #(
              gate,
              list.flatten([
                match_notes(face_name, gate, route_paths),
                csp_notes(face_name, gate),
                pageview_notes(face_name, gate),
              ]),
            )
          }
      }
  }
}

fn empty() -> Gate {
  Gate(
    declared: False,
    sign_in_path: "/auth/sign-in",
    sign_in_fallback: "",
    rules: [],
    redirects: [],
    csp: [],
    pageview: None,
    session_path: None,
  )
}

fn default_gate(face_name: String, entries: List(model.Entry)) -> Gate {
  case list.find(entries, fn(entry) { entry.name == face_name }) {
    Ok(model.Entry(admit: model.AuthenticatedAdmit, subject: subject, ..)) -> {
      let kinds = case subject {
        model.AnyEntrySubject -> []
        model.NamedEntrySubjects(names) -> list.map(names, naming.snake)
      }
      Gate(..empty(), rules: [
        Rule(pages: [Every], except: [], checks: [Admitted(kinds)]),
      ])
    }
    _ -> empty()
  }
}

// ── 宣言の読み ───────────────────────────────────────────────────

/// ラベル付きならラベルで、無ければ位置で引く。
fn field(
  expression: glance.Expression,
  label: String,
  index: Int,
) -> Result(glance.Expression, String) {
  case g.labelled(expression, label) {
    Some(item) -> Ok(item)
    None ->
      case has_labels(expression) {
        True -> Error("`" <> label <> "` が無い")
        False ->
          case list.drop(g.args(expression), index) {
            [item, ..] -> Ok(item)
            [] -> Error("`" <> label <> "` が無い")
          }
      }
  }
}

fn has_labels(expression: glance.Expression) -> Bool {
  case expression {
    glance.Call(arguments: arguments, ..) ->
      list.any(arguments, fn(argument) {
        case argument {
          glance.LabelledField(..) -> True
          _ -> False
        }
      })
    _ -> False
  }
}

fn string_field(
  expression: glance.Expression,
  label: String,
  index: Int,
) -> Result(String, String) {
  use item <- result.try(field(expression, label, index))
  option.to_result(g.string_value(item), "`" <> label <> "` は文字列の literal で書く")
}

fn int_field(
  expression: glance.Expression,
  label: String,
  index: Int,
) -> Result(Int, String) {
  use item <- result.try(field(expression, label, index))
  g.int_value(item)
  |> option.then(fn(text) { option.from_result(int.parse(text)) })
  |> option.to_result("`" <> label <> "` は整数の literal で書く")
}

fn bool_field(
  expression: glance.Expression,
  label: String,
  index: Int,
) -> Result(Bool, String) {
  use item <- result.try(field(expression, label, index))
  case g.ctor_name(item) {
    Some("True") -> Ok(True)
    Some("False") -> Ok(False)
    _ -> Error("`" <> label <> "` は True / False で書く")
  }
}

fn list_field(
  expression: glance.Expression,
  label: String,
  index: Int,
  each: fn(glance.Expression) -> Result(a, String),
) -> Result(List(a), String) {
  use item <- result.try(field(expression, label, index))
  case item {
    glance.List(elements: elements, rest: None, ..) ->
      list.try_map(elements, each)
    _ -> Error("`" <> label <> "` は List の literal で書く")
  }
}

fn gate_of(expression: glance.Expression) -> Result(Gate, String) {
  case g.ctor_name(expression) {
    Some("Gate") -> {
      use sign_in <- result.try(field(expression, "sign_in", 0))
      use sign_in_path <- result.try(string_field(sign_in, "path", 0))
      use sign_in_fallback <- result.try(string_field(
        sign_in,
        "fallback_origin",
        1,
      ))
      use rules <- result.try(list_field(expression, "rules", 1, rule_of))
      use redirects <- result.try(list_field(
        expression,
        "redirects",
        2,
        redirect_of,
      ))
      use csp <- result.try(list_field(expression, "csp", 3, csp_of))
      use pageview_expression <- result.try(field(expression, "pageview", 4))
      use pageview <- result.try(pageview_of(pageview_expression))
      Ok(Gate(
        declared: True,
        sign_in_path: sign_in_path,
        sign_in_fallback: sign_in_fallback,
        rules: rules,
        redirects: redirects,
        csp: csp,
        pageview: pageview,
        session_path: None,
      ))
    }
    _ -> Error("`gate` は `Gate(..)` の literal で書く")
  }
}

fn match_of(expression: glance.Expression) -> Result(Match, String) {
  case g.ctor_name(expression) {
    Some("Exact") -> result.map(string_field(expression, "path", 0), Exact)
    Some("Prefix") -> result.map(string_field(expression, "path", 0), Prefix)
    Some("Every") -> Ok(Every)
    _ -> Error("Page の指し先は Exact / Prefix / Every")
  }
}

fn rule_of(expression: glance.Expression) -> Result(Rule, String) {
  case g.ctor_name(expression) {
    Some("Rule") -> {
      use pages <- result.try(list_field(expression, "pages", 0, match_of))
      use except <- result.try(list_field(expression, "except", 1, match_of))
      use checks <- result.try(list_field(expression, "checks", 2, check_of))
      case pages, checks {
        [], _ -> Error("Rule の `pages` が空")
        _, [] -> Error("Rule の `checks` が空")
        _, _ -> Ok(Rule(pages: pages, except: except, checks: checks))
      }
    }
    _ -> Error("`rules` の要素は `Rule(..)`")
  }
}

fn check_of(expression: glance.Expression) -> Result(Check, String) {
  case g.ctor_name(expression) {
    Some("SignedIn") -> result.map(fail_field(expression, 0), SignedIn)
    Some("Declared") -> {
      use kind <- result.try(string_field(expression, "kind", 0))
      use fail <- result.try(fail_field(expression, 1))
      Ok(Declared(kind, fail))
    }
    Some("SubjectKind") -> {
      use kinds <- result.try(
        list_field(expression, "kinds", 0, fn(item) {
          option.to_result(g.string_value(item), "`kinds` は文字列の literal")
        }),
      )
      use fail <- result.try(fail_field(expression, 1))
      Ok(SubjectKind(kinds, fail))
    }
    Some("Consented") -> {
      use kind <- result.try(string_field(expression, "kind", 0))
      use fail <- result.try(fail_field(expression, 1))
      Ok(Consented(kind, fail))
    }
    _ -> Error("検査は SignedIn / Declared / SubjectKind / Consented")
  }
}

fn fail_field(
  expression: glance.Expression,
  index: Int,
) -> Result(Fail, String) {
  use item <- result.try(field(expression, "fail", index))
  case g.ctor_name(item) {
    Some("ToSignIn") -> {
      use status <- result.try(int_field(item, "status", 0))
      use back <- result.try(bool_field(item, "back", 1))
      case status {
        301 | 302 | 303 | 307 | 308 -> Ok(ToSignIn(status, back))
        _ -> Error("ToSignIn の status は 3xx の redirect")
      }
    }
    Some("Deny") -> {
      use status <- result.try(int_field(item, "status", 0))
      use body <- result.try(string_field(item, "body", 1))
      Ok(Deny(status, body))
    }
    Some("RedirectTo") ->
      result.try(string_field(item, "location", 0), fn(location) {
        case string.starts_with(location, "/") {
          True -> Ok(RedirectTo(location))
          False -> Error("RedirectTo は面の中の path(`/` で始める)")
        }
      })
    Some("RedirectBack") -> {
      use location <- result.try(string_field(item, "location", 0))
      use param <- result.try(string_field(item, "param", 1))
      case face_path(location) && !string.contains(location, "#") {
        False ->
          Error(
            "RedirectBack の location は面の中の path(`/` で始め、`//` で始めず、`\\` も制御文字も `#` も持たない)",
          )
        True ->
          case param_name(param) {
            True -> Ok(RedirectBack(location, param))
            False -> Error("RedirectBack の param は `[A-Za-z0-9_.-]+`")
          }
      }
    }
    _ -> Error("失敗の応答は ToSignIn / Deny / RedirectTo / RedirectBack")
  }
}

/// 面の中の path(`/` で始め、`//` で始めず、`\` も制御文字も持たない ── 門の `safeParam` と同じ判定)。
/// browser は `\` を `/` に読み、tab・改行を捨てるので、`/\evil.example` も `/<tab>/evil.example` も外の origin になる。
fn face_path(location: String) -> Bool {
  string.starts_with(location, "/")
  && !string.starts_with(location, "//")
  && !string.contains(location, "\\")
  && !list.any(string.to_utf_codepoints(location), fn(point) {
    string.utf_codepoint_to_int(point) < 0x20
  })
}

/// query の名に URL 符号化の要らない字だけ。
fn param_name(param: String) -> Bool {
  param != ""
  && string.to_graphemes(param)
  |> list.all(fn(char) {
    string.contains(
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-",
      char,
    )
  })
}

fn redirect_of(expression: glance.Expression) -> Result(Redirect, String) {
  case g.ctor_name(expression) {
    Some("Redirect") -> {
      use pages <- result.try(list_field(expression, "pages", 0, match_of))
      use when <- result.try(field(expression, "when", 1))
      use when <- result.try(when_of(when))
      use to <- result.try(field(expression, "to", 2))
      use to <- result.try(case g.ctor_name(to) {
        Some("SafeParam") -> {
          use param <- result.try(string_field(to, "param", 0))
          use fallback <- result.try(string_field(to, "fallback", 1))
          Ok(SafeParam(param, fallback))
        }
        Some("Fixed") -> result.map(string_field(to, "location", 0), Fixed)
        Some("FixedKeep") ->
          result.try(string_field(to, "location", 0), fn(location) {
            case
              face_path(location)
              && !string.contains(location, "?")
              && !string.contains(location, "#")
            {
              True -> Ok(FixedKeep(location))
              False ->
                Error(
                  "FixedKeep の location は面の中の path(`/` で始め、`//` で始めず、`\\` も制御文字も `?` も `#` も持たない)",
                )
            }
          })
        _ -> Error("`to` は SafeParam / Fixed / FixedKeep")
      })
      Ok(Redirect(pages: pages, when: when, to: to))
    }
    _ -> Error("`redirects` の要素は `Redirect(..)`")
  }
}

fn when_of(expression: glance.Expression) -> Result(model.GateWhen, String) {
  case g.ctor_name(expression) {
    Some("WhenDeclared") ->
      result.map(string_field(expression, "kind", 0), model.WhenDeclared)
    Some("WhenSignedIn") -> Ok(model.WhenSignedIn)
    _ -> Error("条件は WhenDeclared / WhenSignedIn")
  }
}

fn csp_of(expression: glance.Expression) -> Result(Csp, String) {
  case g.ctor_name(expression) {
    Some("Csp") -> {
      use pages <- result.try(list_field(expression, "pages", 0, match_of))
      use directives <- result.try(
        list_field(expression, "directives", 1, fn(item) {
          use name <- result.try(case g.ctor_name(item) {
            Some("FrameSrc") -> Ok("frame-src")
            Some("ImgSrc") -> Ok("img-src")
            Some("ConnectSrc") -> Ok("connect-src")
            Some("MediaSrc") -> Ok("media-src")
            _ -> Error("CSP の指令は FrameSrc / ImgSrc / ConnectSrc / MediaSrc")
          })
          use hosts <- result.try(
            list_field(item, "hosts", 0, fn(host) {
              option.to_result(g.string_value(host), "`hosts` は文字列の literal")
            }),
          )
          Ok(#(name, hosts))
        }),
      )
      case pages {
        [] -> Error("Csp の `pages` が空")
        _ -> Ok(Csp(pages: pages, directives: directives))
      }
    }
    _ -> Error("`csp` の要素は `Csp(..)`")
  }
}

fn pageview_of(
  expression: glance.Expression,
) -> Result(Option(Pageview), String) {
  case g.ctor_name(expression) {
    Some("NoPageview") -> Ok(None)
    Some("Pageview") -> {
      use pages <- result.try(list_field(expression, "pages", 0, match_of))
      use only <- result.try(list_field(expression, "only", 1, when_of))
      use fields <- result.try(list_field(expression, "fields", 2, field_of))
      use sink <- result.try(field(expression, "sink", 3))
      use sink <- result.try(sink_of(sink))
      case pages {
        [] -> Error("Pageview の `pages` が空")
        _ ->
          Ok(
            Some(Pageview(pages: pages, only: only, fields: fields, sink: sink)),
          )
      }
    }
    _ ->
      Error("`pageview` は NoPageview / Pageview(pages:, only:, fields:, sink:)")
  }
}

fn field_of(
  expression: glance.Expression,
) -> Result(model.PageviewField, String) {
  case g.ctor_name(expression) {
    Some("NavKind") -> Ok(model.NavKindField)
    Some("ClientAt") -> Ok(model.ClientAtField)
    Some("Path") -> Ok(model.PathField)
    Some("Previous") -> Ok(model.PreviousField)
    Some("Referrer") -> Ok(model.ReferrerField)
    Some("FromQuery") -> {
      use name <- result.try(string_field(expression, "name", 0))
      use param <- result.try(string_field(expression, "param", 1))
      use pattern <- result.try(field(expression, "pattern", 2))
      use max <- result.try(case g.ctor_name(pattern) {
        Some("Slug") -> int_field(pattern, "max", 0)
        _ -> Error("FromQuery の `pattern` は Slug(max:)")
      })
      Ok(model.FromQueryField(name: name, param: param, max: max))
    }
    _ ->
      Error(
        "欄は NavKind / ClientAt / Path / Previous / Referrer / FromQuery(閉じた語彙。正規表現の文字列は受けない)",
      )
  }
}

fn sink_of(
  expression: glance.Expression,
) -> Result(model.PageviewSink, String) {
  case g.ctor_name(expression) {
    Some("Store") -> {
      use resolve <- result.try(field(expression, "resolve", 0))
      use resolve <- result.try(case g.ctor_name(resolve) {
        Some("None") -> Ok(None)
        Some("Some") ->
          case g.args(resolve) {
            [inner] ->
              option.to_result(
                option.map(g.string_value(inner), Some),
                "Store の `resolve` は Some(\"<Service>\") / None",
              )
            _ -> Error("Store の `resolve` は Some(\"<Service>\") / None")
          }
        _ -> Error("Store の `resolve` は Some(\"<Service>\") / None")
      })
      let text_item = fn(item) {
        option.to_result(g.string_value(item), "欄の名は文字列の literal")
      }
      use rollup_by <- result.try(list_field(
        expression,
        "rollup_by",
        1,
        text_item,
      ))
      use exclude_when <- result.try(list_field(
        expression,
        "exclude_when",
        2,
        text_item,
      ))
      Ok(model.StoreSink(
        resolve: resolve,
        rollup_by: rollup_by,
        exclude_when: exclude_when,
      ))
    }
    Some("ToService") ->
      result.map(string_field(expression, "service", 0), model.ServiceSink)
    _ -> Error("`sink` は Store(..) / ToService(..)")
  }
}

/// 欄の名(送る本文の鍵)。`Referrer` は `referrer_path` / `referrer_host` の 2 つ。
pub fn field_names(field: model.PageviewField) -> List(String) {
  case field {
    model.NavKindField -> ["kind"]
    model.ClientAtField -> ["client_at"]
    model.PathField -> ["path"]
    model.PreviousField -> ["prev"]
    model.ReferrerField -> ["referrer_path", "referrer_host"]
    model.FromQueryField(name: name, ..) -> [name]
  }
}

// ── CSP と数える口の検査 ──────────────────────────────────────────

/// host の綴り(`[a-z0-9.-]+`、先頭に `*.` を 1 つ許す)。51 v6 第 38 条。
pub fn host_spelling(host: String) -> Bool {
  let body = case string.starts_with(host, "*.") {
    True -> string.drop_start(host, 2)
    False -> host
  }
  body != ""
  && !string.starts_with(body, ".")
  && list.all(string.to_graphemes(body), fn(char) {
    string.contains("abcdefghijklmnopqrstuvwxyz0123456789.-", char)
  })
}

fn csp_notes(face_name: String, gate: Gate) -> List(Note) {
  gate.csp
  |> list.flat_map(fn(csp) { csp.directives })
  |> list.flat_map(fn(directive) { directive.1 })
  |> list.unique
  |> list.filter(fn(host) { !host_spelling(host) })
  |> list.map(fn(host) {
    Note(
      stop.Conflict,
      face_name
        <> "/gate: csp の host \""
        <> host
        <> "\" が host の綴りでない([a-z0-9.-]+、先頭に *. を 1 つ許す。https:// や path は書かない)",
    )
  })
}

fn pageview_notes(face_name: String, gate: Gate) -> List(Note) {
  case gate.pageview {
    None -> []
    Some(pageview) -> {
      let names = list.flat_map(pageview.fields, field_names)
      let duplicated =
        pageview.fields
        |> list.filter(fn(field) {
          list.count(pageview.fields, fn(other) { other == field }) > 1
          || list.count(names, fn(name) {
            list.contains(field_names(field), name)
          })
          > list.length(field_names(field))
        })
        |> list.flat_map(field_names)
        |> list.unique
        |> list.map(fn(name) {
          Note(
            stop.Conflict,
            face_name <> "/gate: pageview の欄 `" <> name <> "` が 2 つある",
          )
        })
      let reserved =
        pageview.fields
        |> list.filter_map(fn(field) {
          case field {
            model.FromQueryField(name: name, param: param, max: max) ->
              case
                list.contains(event_names, name) || !slug_name(name),
                param_name(param)
                && !string.contains(param, ".")
                && !string.contains(param, "-"),
                max >= 1 && max <= 64
              {
                False, True, True -> Error(Nil)
                True, _, _ ->
                  Ok(
                    "FromQuery の name `"
                    <> name
                    <> "` は [a-z][a-z0-9_]* で、受け口の event の欄の名("
                    <> string.join(event_names, "・")
                    <> ")でない",
                  )
                _, False, _ ->
                  Ok("FromQuery の param `" <> param <> "` が [A-Za-z0-9_]+ でない")
                _, _, False ->
                  Ok(
                    "FromQuery の Slug(max: "
                    <> int.to_string(max)
                    <> ") が 1〜64 の外",
                  )
              }
            _ -> Error(Nil)
          }
        })
        |> list.map(fn(text) {
          Note(stop.Conflict, face_name <> "/gate: pageview の " <> text)
        })
      list.append(duplicated, reserved)
    }
  }
}

/// 受け口の event の欄の名(framework の `id` と `fields` の欄)。`FromQuery` の name には使えない(51 v6 第 35 条)。
pub const event_names = [
  "id", "kind", "client_at", "path", "prev", "referrer_path", "referrer_host",
]

/// `[a-z][a-z0-9_]*`(申告の kind・欄の名・variant の名の綴り)。
pub fn slug_name(name: String) -> Bool {
  case string.to_graphemes(name) {
    [first, ..rest] ->
      string.contains("abcdefghijklmnopqrstuvwxyz", first)
      && list.all(rest, fn(char) {
        string.contains("abcdefghijklmnopqrstuvwxyz0123456789_", char)
      })
    [] -> False
  }
}

// ── 指し先の検査 ─────────────────────────────────────────────────

fn gate_matches(gate: Gate) -> List(Match) {
  list.flatten([
    list.flat_map(gate.rules, fn(rule) { list.append(rule.pages, rule.except) }),
    list.flat_map(gate.redirects, fn(redirect) { redirect.pages }),
    list.flat_map(gate.csp, fn(csp) { csp.pages }),
    case gate.pageview {
      Some(pageview) -> pageview.pages
      None -> []
    },
  ])
}

fn match_notes(
  face_name: String,
  gate: Gate,
  route_paths: List(String),
) -> List(Note) {
  gate_matches(gate)
  |> list.unique
  |> list.filter_map(fn(match) {
    case match {
      Every -> Error(Nil)
      Exact(path) ->
        case list.contains(route_paths, path) {
          True -> Error(Nil)
          False ->
            Ok(Note(
              stop.Conflict,
              face_name
                <> "/gate: Exact(\""
                <> path
                <> "\") の Page が面の route に無い",
            ))
        }
      Prefix(path) ->
        case list.any(route_paths, fn(route) { prefix_covers(path, route) }) {
          True -> Error(Nil)
          False ->
            Ok(Note(
              stop.Conflict,
              face_name <> "/gate: Prefix(\"" <> path <> "\") の下に Page が 1 つも無い",
            ))
        }
    }
  })
}

pub fn prefix_covers(prefix: String, route: String) -> Bool {
  route == prefix || string.starts_with(route, prefix <> "/") || prefix == "/"
}

/// `match` が route `path` を指すか(生成時の判定。実行時は gate.mjs が同じ規則で見る)。
pub fn covers(match: Match, path: String) -> Bool {
  case match {
    Every -> True
    Exact(expected) -> expected == path
    Prefix(prefix) -> prefix_covers(prefix, path)
  }
}
