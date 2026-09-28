//// 面の門の宣言(`<face>/src/gate.gleam` の `pub const gate`、型は `framework/gate`)を読む。
////
//// 宣言が無い面は、入口 `Http` の `admit` / `subject` から既定の門を組む(`Authenticated` の面だけ)。
//// CSP の host は入口 `Http` の `frame_src` 欄から読む(`api/src/entry.gleam`)。
//// session を読む口は `api/src/server.gleam` の `attached_roles` の `ReadSession` が指す attached の path
//// (framework は app の口の名を知らない)。門が session を読むのに `ReadSession` が無ければ exit 3。
//// Page の指し先(`Exact` / `Prefix`)が面の route に無ければ exit 4。

import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import yumemi_gen/glance_util as g
import yumemi_gen/model
import yumemi_gen/naming
import yumemi_gen/source.{type Unit}
import yumemi_gen/stop.{type Note, Note}

pub type Gate {
  Gate(
    /// `src/gate.gleam` から読んだか(False は入口からの既定か、門無し)。
    declared: Bool,
    sign_in_path: String,
    sign_in_fallback: String,
    rules: List(Rule),
    redirects: List(Redirect),
    frame_src: List(Match),
    frame_hosts: List(String),
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
  Adult(fail: Fail)
  SubjectKind(kinds: List(String), fail: Fail)
  Consent(kind: String, fail: Fail)
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
  Redirect(pages: List(Match), when_adult: Bool, to: To)
}

pub type To {
  SafeParam(param: String, fallback: String)
  Fixed(location: String)
  /// 0.11.5:決まった path に要求の query を保って返す。
  FixedKeep(location: String)
}

pub type Pageview {
  Pageview(
    pages: List(Match),
    endpoint: String,
    source_param: String,
    storage_key: String,
  )
}

/// 門が session を読むか(rules・redirects・pageview のどれかを持つ)。
pub fn reads_session(gate: Gate) -> Bool {
  gate.rules != [] || gate.redirects != [] || gate.pageview != None
}

/// 門が何かを持つか。持たない面の `gate.mjs` は素通しになる。
pub fn is_empty(gate: Gate) -> Bool {
  gate.rules == []
  && gate.redirects == []
  && gate.frame_src == []
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
  let hosts = frame_hosts(back_units, face_name)
  case list.find(face_units, fn(unit) { unit.path == "gate" }) {
    Error(_) -> #(default_gate(face_name, entries, hosts), [])
    Ok(unit) ->
      case g.find_constant(g.in_order(unit.module), "gate") {
        None -> #(default_gate(face_name, entries, hosts), [
          Note(
            stop.Missing,
            face_name <> "/gate: `pub const gate` が無い(門の宣言は `gate` の 1 つ)",
          ),
        ])
        Some(constant) ->
          case gate_of(constant.value) {
            Error(reason) -> #(empty(hosts), [
              Note(stop.Conflict, face_name <> "/gate: " <> reason),
            ])
            Ok(gate) -> {
              let gate = Gate(..gate, frame_hosts: hosts)
              #(gate, match_notes(face_name, gate, route_paths))
            }
          }
      }
  }
}

fn empty(hosts: List(String)) -> Gate {
  Gate(
    declared: False,
    sign_in_path: "/auth/sign-in",
    sign_in_fallback: "",
    rules: [],
    redirects: [],
    frame_src: [],
    frame_hosts: hosts,
    pageview: None,
    session_path: None,
  )
}

fn default_gate(
  face_name: String,
  entries: List(model.Entry),
  hosts: List(String),
) -> Gate {
  case list.find(entries, fn(entry) { entry.name == face_name }) {
    Ok(model.Entry(admit: model.AuthenticatedAdmit, subject: subject, ..)) -> {
      let kinds = case subject {
        model.AnyEntrySubject -> []
        model.NamedEntrySubjects(names) -> list.map(names, naming.snake)
      }
      Gate(..empty(hosts), rules: [
        Rule(pages: [Every], except: [], checks: [Admitted(kinds)]),
      ])
    }
    _ -> empty(hosts)
  }
}

// ── 入口の frame_src ─────────────────────────────────────────────

fn frame_hosts(units: List(Unit), face_name: String) -> List(String) {
  case list.find(units, fn(unit) { unit.path == "entry" }) {
    Error(_) -> []
    Ok(unit) ->
      case g.find_constant(g.in_order(unit.module), "entries") {
        None -> []
        Some(constant) ->
          g.list_elements(constant.value)
          |> list.find_map(fn(entry) {
            case
              option.then(g.labelled(entry, "name"), g.string_value)
              == Some(face_name)
            {
              True ->
                case g.labelled(entry, "frame_src") {
                  Some(value) ->
                    Ok(
                      list.filter_map(g.list_elements(value), fn(item) {
                        option.to_result(g.string_value(item), Nil)
                      }),
                    )
                  None -> Ok([])
                }
              False -> Error(Nil)
            }
          })
          |> result.unwrap([])
      }
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
      use frame_src <- result.try(list_field(
        expression,
        "frame_src",
        3,
        match_of,
      ))
      use pageview_expression <- result.try(field(expression, "pageview", 4))
      use pageview <- result.try(pageview_of(pageview_expression))
      Ok(Gate(
        declared: True,
        sign_in_path: sign_in_path,
        sign_in_fallback: sign_in_fallback,
        rules: rules,
        redirects: redirects,
        frame_src: frame_src,
        frame_hosts: [],
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
    Some("Adult") -> result.map(fail_field(expression, 0), Adult)
    Some("SubjectKind") -> {
      use kinds <- result.try(
        list_field(expression, "kinds", 0, fn(item) {
          option.to_result(g.string_value(item), "`kinds` は文字列の literal")
        }),
      )
      use fail <- result.try(fail_field(expression, 1))
      Ok(SubjectKind(kinds, fail))
    }
    Some("Consent") -> {
      use kind <- result.try(string_field(expression, "kind", 0))
      use fail <- result.try(fail_field(expression, 1))
      Ok(Consent(kind, fail))
    }
    _ -> Error("検査は SignedIn / Adult / SubjectKind / Consent")
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
            "RedirectBack の location は面の中の path(`/` で始め、`//` で始めず、`#` を持たない)",
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

/// 面の中の path(`/` で始め、`//` で始めない)。
fn face_path(location: String) -> Bool {
  string.starts_with(location, "/") && !string.starts_with(location, "//")
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
      use when_adult <- result.try(case g.ctor_name(when) {
        Some("WhenAdult") -> Ok(True)
        Some("WhenSignedIn") -> Ok(False)
        _ -> Error("`when` は WhenAdult / WhenSignedIn")
      })
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
                  "FixedKeep の location は面の中の path(`/` で始め、`//` で始めず、`?` も `#` も持たない)",
                )
            }
          })
        _ -> Error("`to` は SafeParam / Fixed / FixedKeep")
      })
      Ok(Redirect(pages: pages, when_adult: when_adult, to: to))
    }
    _ -> Error("`redirects` の要素は `Redirect(..)`")
  }
}

fn pageview_of(
  expression: glance.Expression,
) -> Result(Option(Pageview), String) {
  case g.ctor_name(expression) {
    Some("NoPageview") -> Ok(None)
    Some("Pageview") -> {
      use pages <- result.try(list_field(expression, "pages", 0, match_of))
      use endpoint <- result.try(string_field(expression, "endpoint", 1))
      use source_param <- result.try(string_field(expression, "source_param", 2))
      use storage_key <- result.try(string_field(expression, "storage_key", 3))
      Ok(
        Some(Pageview(
          pages: pages,
          endpoint: endpoint,
          source_param: source_param,
          storage_key: storage_key,
        )),
      )
    }
    _ -> Error("`pageview` は NoPageview / Pageview(..)")
  }
}

// ── 指し先の検査 ─────────────────────────────────────────────────

fn gate_matches(gate: Gate) -> List(Match) {
  list.flatten([
    list.flat_map(gate.rules, fn(rule) { list.append(rule.pages, rule.except) }),
    list.flat_map(gate.redirects, fn(redirect) { redirect.pages }),
    gate.frame_src,
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
