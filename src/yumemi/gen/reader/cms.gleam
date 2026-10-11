//// 業務付き CMS の機能の宣言の検査(0.12、51 v6 第 32・33・36・37・39・40 条)。
////
//// - 申告:門の `Declared` / `WhenDeclared`・要件の `Declared`・役の `Declare` / `NeedsDeclared` の kind が
////   `browser.declarations` に無い、`browser` の宣言が無い(第 32 条)。`Declaration` の重なり・綴り・期間(第 33 条)
//// - 数える口:`ToService` の Service と Args(第 36 条)、`Store` の `resolve` と欄・`browser` の宣言(第 37 条)
//// - media の variant の名と `theme_background`(第 39 条)
//// - 同意:要件と門の `Consented` / `ConsentedFor` の kind が `consents` に無い(第 40 条)
////
//// 面の門の検査(`gate_notes`)は面ごとに、back の宣言の検査(`notes`)は app に 1 回。

import glance
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi/gen/emit/http as http_emit
import yumemi/gen/glance_util as g
import yumemi/gen/model
import yumemi/gen/reader/gate
import yumemi/gen/source.{type Unit}
import yumemi/gen/stop.{type Note, Note}

/// Service の `pub const requires` の 1 項(`Declared` / `Consented` / `ConsentedFor`)。
pub type Requirement {
  Requirement(service: String, constructor: String, kind: String)
}

/// back の Service の要件を読む。kind が文字列の literal でない項は kind "" で返す(検査で名指す)。
pub fn requirements(units: List(Unit)) -> List(Requirement) {
  units
  |> list.filter(fn(unit) { string.starts_with(unit.path, "service/") })
  |> list.flat_map(fn(unit) {
    let service = string.drop_start(unit.path, string.length("service/"))
    case g.find_constant(unit.module, "requires") {
      None -> []
      Some(constant) ->
        g.list_elements(constant.value)
        |> list.map(fn(item) {
          let constructor = option.unwrap(g.ctor_name(item), "")
          let kind =
            case g.labelled(item, "kind") {
              Some(value) -> Some(value)
              None -> list.first(g.args(item)) |> option.from_result
            }
            |> option.then(g.string_value)
            |> option.unwrap("")
          Requirement(service: service, constructor: constructor, kind: kind)
        })
    }
  })
}

fn declared_kinds(app: model.App) -> Option(List(String)) {
  option.map(app.server.browser, fn(browser) {
    list.map(browser.declarations, fn(d) { d.kind })
  })
}

fn declaration_note(app: model.App, kind: String, where: String) -> List(Note) {
  case declared_kinds(app) {
    None -> [
      Note(
        stop.Conflict,
        where
          <> " の申告 \""
          <> kind
          <> "\" に src/server.gleam の `browser` の宣言が無い(申告は browser の署名 cookie に焼く)",
      ),
    ]
    Some(kinds) ->
      case list.contains(kinds, kind) {
        True -> []
        False -> [
          Note(
            stop.Conflict,
            where
              <> " の申告 \""
              <> kind
              <> "\" が src/server.gleam の browser.declarations に無い(宣言した種類: "
              <> string.join(kinds, ", ")
              <> ")",
          ),
        ]
      }
  }
}

fn consent_note(app: model.App, kind: String, where: String) -> List(Note) {
  case list.contains(app.server.consents, kind) {
    True -> []
    False -> [
      Note(
        stop.Conflict,
        where
          <> " の同意 \""
          <> kind
          <> "\" が src/server.gleam の `consents` に無い(宣言した種類: "
          <> string.join(app.server.consents, ", ")
          <> ")",
      ),
    ]
  }
}

/// 面の門の申告と同意の綴り(第 32・40 条)。
pub fn gate_notes(
  app: model.App,
  face_name: String,
  declared: gate.Gate,
) -> List(Note) {
  let where = face_name <> "/gate"
  let checks = list.flat_map(declared.rules, fn(rule) { rule.checks })
  let whens =
    list.append(
      list.map(declared.redirects, fn(redirect) { redirect.when }),
      case declared.pageview {
        Some(pageview) -> pageview.only
        None -> []
      },
    )
  list.flatten([
    list.flat_map(checks, fn(check) {
      case check {
        gate.Declared(kind: kind, ..) -> declaration_note(app, kind, where)
        gate.Consented(kind: kind, ..) -> consent_note(app, kind, where)
        _ -> []
      }
    }),
    list.flat_map(whens, fn(when) {
      case when {
        model.WhenDeclared(kind) -> declaration_note(app, kind, where)
        model.WhenSignedIn -> []
      }
    }),
  ])
  |> list.unique
}

/// back の宣言の検査(第 32・33・36・37・39・40 条)と、`ToService` の逃げ道の数(警告)。
pub fn notes(app: model.App, units: List(Unit)) -> List(Note) {
  list.flatten([
    requirement_notes(app, units),
    role_notes(app),
    declaration_notes(app),
    counted_notes(app, units),
    media_notes(app),
  ])
}

fn requirement_notes(app: model.App, units: List(Unit)) -> List(Note) {
  requirements(units)
  |> list.flat_map(fn(requirement) {
    let where = "service." <> requirement.service <> " requires"
    case requirement.constructor, requirement.kind {
      "Declared", "" | "Consented", "" | "ConsentedFor", "" -> [
        Note(
          stop.Conflict,
          where
            <> " の "
            <> requirement.constructor
            <> " の kind は文字列の literal で書く",
        ),
      ]
      "Declared", kind -> declaration_note(app, kind, where)
      "Consented", kind | "ConsentedFor", kind -> consent_note(app, kind, where)
      constructor, _ -> [
        Note(
          stop.Conflict,
          where
            <> " の項 `"
            <> constructor
            <> "` は Declared / Consented / ConsentedFor でない(0.11 の要件の名は 0.12 で消えた)",
        ),
      ]
    }
  })
}

fn role_notes(app: model.App) -> List(Note) {
  app.server.attached_roles
  |> list.flat_map(fn(row) {
    case row.role {
      "declare" | "needs_declared" ->
        declaration_note(
          app,
          row.kind,
          "server.gleam: attached_roles の " <> row.attached,
        )
      _ -> []
    }
  })
}

fn declaration_notes(app: model.App) -> List(Note) {
  case app.server.browser {
    None -> []
    Some(browser) -> {
      let kinds = list.map(browser.declarations, fn(d) { d.kind })
      let claims = list.map(browser.declarations, fn(d) { d.claim })
      list.flatten([
        kinds
          |> list.filter(fn(kind) { list.count(kinds, fn(k) { k == kind }) > 1 })
          |> list.unique
          |> list.map(fn(kind) { "申告の kind \"" <> kind <> "\" が 2 つある" }),
        claims
          |> list.filter(fn(claim) {
            list.count(claims, fn(c) { c == claim }) > 1
          })
          |> list.unique
          |> list.map(fn(claim) { "申告の claim \"" <> claim <> "\" が 2 つある" }),
        browser.declarations
          |> list.filter_map(fn(d) {
            case
              gate.slug_name(d.kind),
              d.claim != "" && d.claim != "id",
              d.max_age_days >= 1 && d.max_age_days <= browser.max_age_days
            {
              True, True, True -> Error(Nil)
              False, _, _ ->
                Ok("申告の kind \"" <> d.kind <> "\" が [a-z][a-z0-9_]* でない")
              _, False, _ ->
                Ok("申告 \"" <> d.kind <> "\" の claim は空でも id でもない名にする")
              _, _, False ->
                Ok(
                  "申告 \""
                  <> d.kind
                  <> "\" の max_age_days "
                  <> int.to_string(d.max_age_days)
                  <> " が 1〜cookie の max_age_days("
                  <> int.to_string(browser.max_age_days)
                  <> ")の外",
                )
            }
          }),
      ])
      |> list.map(fn(text) {
        Note(stop.Conflict, "server.gleam: browser: " <> text)
      })
    }
  }
}

/// 送る本文の欄の名 -> 必ず載るか(`kind`・`client_at`・`path` と framework の `id` は必ず、他は載らないことがある)。
fn event_fields(fields: List(model.PageviewField)) -> List(#(String, Bool)) {
  [
    #("id", True),
    ..list.flat_map(fields, fn(field) {
      let required = case field {
        model.NavKindField | model.ClientAtField | model.PathField -> True
        _ -> False
      }
      list.map(gate.field_names(field), fn(name) { #(name, required) })
    })
  ]
}

fn service_unit(units: List(Unit), service: String) -> Option(Unit) {
  list.find(units, fn(unit) { unit.path == "service/" <> service })
  |> option.from_result
}

/// custom type `name` の最初の構成子の (欄の名, 型) の並び。
fn record_fields(unit: Unit, name: String) -> List(#(String, glance.Type)) {
  case g.find_custom_type(unit.module, name) {
    Some(custom) ->
      case custom.variants {
        [variant, ..] ->
          list.filter_map(variant.fields, fn(field) {
            case g.variant_field_label(field) {
              Some(label) -> Ok(#(label, g.variant_field_type(field)))
              None -> Error(Nil)
            }
          })
        [] -> []
      }
    None -> []
  }
}

fn counted_notes(app: model.App, units: List(Unit)) -> List(Note) {
  app.server.counted
  |> list.flat_map(fn(counted) {
    let where = counted.face <> "/gate: pageview"
    case counted.sink {
      model.ServiceSink(service) ->
        case service_unit(units, service) {
          None -> [
            Note(
              stop.Conflict,
              where <> " の ToService(\"" <> service <> "\") の Service が無い",
            ),
          ]
          Some(unit) -> {
            let fields = event_fields(counted.fields)
            let args = record_fields(unit, "Args")
            let mismatched =
              list.filter_map(args, fn(arg) {
                let #(name, type_) = arg
                case list.key_find(fields, name) {
                  Error(_) ->
                    Ok(
                      "Args の欄 `"
                      <> name
                      <> "` が fields から組む欄に無い(組める欄: "
                      <> string.join(list.map(fields, fn(f) { f.0 }), ", ")
                      <> ")",
                    )
                  Ok(True) -> Error(Nil)
                  Ok(False) ->
                    case g.type_name(type_) {
                      Some("Option") -> Error(Nil)
                      _ ->
                        Ok("Args の欄 `" <> name <> "` は載らないことがあるので Option で受ける")
                    }
                }
              })
              |> list.map(fn(text) {
                Note(
                  stop.Conflict,
                  where <> " の ToService(\"" <> service <> "\"): " <> text,
                )
              })
            // 第 36 条:event の id は必ず受ける(id の再送の検出は Service の側)。欄の型は event の値から decode できる型
            let id = case list.key_find(args, "id") {
              Ok(_) -> []
              Error(_) -> [
                Note(
                  stop.Missing,
                  where
                    <> " の ToService(\""
                    <> service
                    <> "\"): Args に欄 `id` が無い(event の id で再送を見分ける)",
                ),
              ]
            }
            let typed = case
              list.find(app.services, fn(row) { row.module == service })
            {
              Error(_) -> []
              Ok(row) ->
                list.filter_map(row.args, fn(arg) {
                  case list.key_find(fields, arg.name) {
                    Error(_) -> Error(Nil)
                    Ok(_) ->
                      case
                        http_emit.decodes_from_event(
                          app,
                          units,
                          row,
                          arg,
                          arg.name,
                        )
                      {
                        Ok(False) ->
                          Ok(Note(
                            stop.Conflict,
                            where
                              <> " の ToService(\""
                              <> service
                              <> "\"): Args の欄 `"
                              <> arg.name
                              <> "` の型を event の値から decode できない(event の欄は文字列"
                              <> case arg.name {
                              "kind" -> "、initial / reload / spa の 3 値"
                              _ -> ""
                            }
                              <> "。String・値型・hook"
                              <> case arg.name {
                              "client_at" -> "・Datetime"
                              "kind" -> "・3 値を持つ列挙"
                              _ -> ""
                            }
                              <> " で受ける)",
                          ))
                        _ -> Error(Nil)
                      }
                  }
                })
            }
            let mark = case
              http_emit.carries_browser(app, service),
              app.server.browser
            {
              True, None -> [
                Note(
                  stop.Missing,
                  where
                    <> " の ToService(\""
                    <> service
                    <> "\") は印(browser)を root に運ぶのに src/server.gleam の `browser` の宣言が無い",
                ),
              ]
              _, _ -> []
            }
            list.flatten([
              id,
              mismatched,
              typed,
              mark,
              [
                Note(
                  stop.Warning,
                  counted.face
                    <> ": 逃げ道 ToService を 1 つ使っている(数える口 → service."
                    <> service
                    <> "。framework の器 Store に移せば消える)",
                ),
              ],
            ])
          }
        }
      model.StoreSink(
        resolve: resolve,
        rollup_by: rollup_by,
        exclude_when: exclude,
      ) -> {
        let browser = case app.server.browser {
          None -> [
            Note(
              stop.Missing,
              where
                <> " の Store に src/server.gleam の `browser` の宣言が無い(ユニークの印を焼けない)",
            ),
          ]
          Some(_) -> []
        }
        // 第 37 条:器は path で数える(訪問の入口・path の次元)。fields に `Path` が無い Store は止める
        let browser = case list.contains(counted.fields, model.PathField) {
          True -> browser
          False ->
            list.append(browser, [
              Note(
                stop.Missing,
                where <> " の Store の fields に Path が無い(器は path ごとに数える)",
              ),
            ])
        }
        let dims = case resolve {
          None ->
            list.map(list.append(rollup_by, exclude), fn(name) {
              Note(
                stop.Conflict,
                where
                  <> " の Store の欄 `"
                  <> name
                  <> "` を返す resolve の Service が無い(None)",
              )
            })
          Some(service) ->
            case service_unit(units, service) {
              None -> [
                Note(
                  stop.Conflict,
                  where <> " の Store の resolve の Service が無い: " <> service,
                ),
              ]
              Some(unit) -> {
                let out = record_fields(unit, "Out")
                let args = record_fields(unit, "Args")
                list.flatten([
                  case list.map(args, fn(arg) { arg.0 }) {
                    ["path"] -> []
                    _ -> [
                      Note(
                        stop.Conflict,
                        where
                          <> " の Store の resolve(service."
                          <> service
                          <> ")の Args は `path` の欄 1 つにする",
                      ),
                    ]
                  },
                  list.filter_map(rollup_by, fn(name) {
                    case list.key_find(out, name) {
                      Ok(_) -> Error(Nil)
                      Error(_) ->
                        Ok(Note(
                          stop.Conflict,
                          where
                            <> " の Store の rollup_by `"
                            <> name
                            <> "` が service."
                            <> service
                            <> " の Out に無い",
                        ))
                    }
                  }),
                  list.filter_map(exclude, fn(name) {
                    case list.key_find(out, name) {
                      Ok(type_) ->
                        case g.type_name(type_) {
                          Some("Bool") -> Error(Nil)
                          _ ->
                            Ok(Note(
                              stop.Conflict,
                              where
                                <> " の Store の exclude_when `"
                                <> name
                                <> "` が Bool でない",
                            ))
                        }
                      Error(_) ->
                        Ok(Note(
                          stop.Conflict,
                          where
                            <> " の Store の exclude_when `"
                            <> name
                            <> "` が service."
                            <> service
                            <> " の Out に無い",
                        ))
                    }
                  }),
                ])
              }
            }
        }
        list.append(browser, dims)
      }
    }
  })
}

fn media_notes(app: model.App) -> List(Note) {
  case app.server.media {
    None -> []
    Some(media) -> {
      let names = list.map(media.variants, fn(variant) { variant.name })
      list.flatten([
        names
          |> list.filter(fn(name) { list.count(names, fn(n) { n == name }) > 1 })
          |> list.unique
          |> list.map(fn(name) { "variant の名 \"" <> name <> "\" が 2 つある" }),
        names
          |> list.filter(fn(name) { !gate.slug_name(name) })
          |> list.map(fn(name) {
            "variant の名 \"" <> name <> "\" が [a-z][a-z0-9_]* でない"
          }),
        case list.contains(names, media.theme_background) {
          True -> []
          False -> [
            "theme_background \""
            <> media.theme_background
            <> "\" が variants に無い",
          ]
        },
      ])
      |> list.map(fn(text) {
        Note(stop.Conflict, "server.gleam: media: " <> text)
      })
    }
  }
}
