//// back の codec(WGy、0.11.1)── `src/gen/codec.mjs`。行(Postgres の JSON)と Gleam の値の間の写しを、
//// Entity と値型の宣言から書く。共通の口(checked・parse・option・encode・phase …)は framework の
//// `framework/server/codec.mjs` が持ち、生成物は表(scalar・整数の値型)と Entity ごとの decoder だけを持つ。
////
//// 導く規則(Property の型ごと、列は reader の FieldDef と同じ):
////
//// | 型 | 写し |
//// |---|---|
//// | 値型(`gen/types/*`) | `parse('<名>', v)`(整数の値型は `Number(v)`、文字列は `String(v)`) |
//// | `PartyId` / `Blob` / `Secret` | `checked(party.parse(v))` / `checked(blob.parse(String(v)))` / `secret.hmac(String(v))` |
//// | `Datetime` / `Date` / `Time` | `cDatetime(v)` / `cDate(v)` / `cTime(v)` |
//// | `Int` / `Float` / `Bool` / `String` | `Number(v)` / `Number(v)` / `Boolean(v)` / `String(v)` |
//// | `Held(E)` / `Has(E)` / `Link(E)` | `er.held_from_row({key:r.<prop>_id})` / `er.from_row(..)` / `option(r.<prop>_id, v=>er.key(String(v)))` |
//// | 構成子だけの sum | `phase(<module>, v)` |
//// | payload を持つ sum | `<型>.decode<型>(r)`(`src/gen/<型>.mjs`) |
//// | 欄を持つ record(1 構成子) | `new <module>.<型>(<欄ごとに同じ規則>)`(jsonb の object) |
//// | `Option(T)` / `List(T)` | `option(v, ..)` / `list(v, ..)` |
////
//// 宣言から導けない decoder(列の形が宣言と違う、ER の外の集計など)は、`server.hooks` に `decode_<名>` の
//// hook を宣言すると、生成物がその ★ を名指しで re-export する(導いた decoder より hook が勝つ)。
//// 規則で導けない Property を持つ Entity は decoder を出さず、file の頭に名指しする。

import glance
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import yumemi_gen/glance_util as g
import yumemi_gen/model.{type App, type Entity, type Prop}
import yumemi_gen/naming
import yumemi_gen/source.{type Unit}
import yumemi_gen/storage

const framework = "../../yumemi/framework/"

pub fn text(app: App, units: List(Unit), input: String) -> String {
  let hooks =
    list.filter(app.server.hooks, fn(hook) {
      string.starts_with(hook.name, "decode_") || hook.name == "cursor_args"
    })
  let hooked = fn(name) { list.any(hooks, fn(hook) { hook.name == name }) }
  let decoders =
    app.entities
    |> list.filter(fn(entity) { !hooked("decode_" <> entity.module) })
    |> list.map(fn(entity) { #(entity, decoder(app, units, entity)) })
  let derived =
    list.filter_map(decoders, fn(item) {
      case item.1 {
        Ok(body) -> Ok(body)
        Error(_) -> Error(Nil)
      }
    })
  let skipped =
    list.filter_map(decoders, fn(item) {
      case item.1 {
        Ok(_) -> Error(Nil)
        Error(reason) -> Ok({ item.0 }.module <> "(" <> reason <> ")")
      }
    })
  let entity_imports =
    list.map(app.entities, fn(entity) {
      "import * as "
      <> alias(entity.module)
      <> " from '../"
      <> "entity/"
      <> entity.module
      <> ".mjs';\n"
    })
  let collection_imports =
    list.map(app.collections, fn(collection) {
      "import * as "
      <> alias(collection.module)
      <> " from '../"
      <> collection.module
      <> ".mjs';\n"
    })
  let type_imports =
    list.map(app.value_types, fn(value) {
      "import * as t_"
      <> value.name
      <> " from './types/"
      <> value.name
      <> ".mjs';\n"
    })
  let sum_imports =
    sum_types(app)
    |> list.map(fn(name) {
      "import * as "
      <> sum_alias(name)
      <> " from './"
      <> naming.snake(name)
      <> ".mjs';\n"
    })
  let hook_exports =
    list.map(hooks, fn(hook) {
      "export { "
      <> camel(hook.name)
      <> " } from '../"
      <> hook.module
      <> ".mjs';\n"
    })
  let names =
    list.append(
      list.map(app.entities, fn(entity) { alias(entity.module) }),
      list.map(app.collections, fn(collection) { alias(collection.module) }),
    )
  "//// GENERATED from entity / types declarations [sha256:"
  <> input
  <> "] — 手で編集しない\n"
  <> case skipped {
    [] -> ""
    _ -> "// 宣言から導けない decoder(hook も無い): " <> string.join(skipped, ", ") <> "\n"
  }
  <> "import { Some, None } from '../../gleam_stdlib/gleam/option.mjs';\n"
  <> "import { toList, List } from '../gleam.mjs';\n"
  <> "import * as party from '"
  <> framework
  <> "party.mjs';\n"
  <> "import * as time from '"
  <> framework
  <> "time.mjs';\n"
  <> "import * as blob from '"
  <> framework
  <> "blob.mjs';\n"
  <> "import * as er from '"
  <> framework
  <> "er.mjs';\n"
  <> "import * as page from '"
  <> framework
  <> "page.mjs';\n"
  <> "import * as secret from '"
  <> framework
  <> "secret_ffi.mjs';\n"
  <> "import { codec } from '"
  <> framework
  <> "server/codec.mjs';\n"
  <> string.concat(entity_imports)
  <> string.concat(collection_imports)
  <> string.concat(type_imports)
  <> string.concat(sum_imports)
  <> string.concat(hook_exports)
  <> "export { Some, None, toList, "
  <> string.join(names, ", ")
  <> ", party, time, page, er, blob };\n"
  <> "export const scalar = {"
  <> string.join(
    list.map(app.value_types, fn(value) { value.name <> ":t_" <> value.name }),
    ",",
  )
  <> "};\n"
  <> "const integerKeys=new Set(["
  <> string.join(
    app.value_types
      |> list.filter(fn(value) { value.backing == model.IntValue })
      |> list.map(fn(value) { "'" <> value.name <> "'" }),
    ",",
  )
  <> "]);\n"
  <> "const base=codec({scalar,integerKeys,Some,None,List,time});\n"
  <> "export const {checked,parse,option,unwrap,text,tag,encode,phase,timeText,dateText}=base;\n"
  <> "const {cDate,cDatetime,cTime,list}=base;\n"
  <> string.concat(derived)
}

fn alias(module: String) -> String {
  camel(module)
}

fn sum_alias(name: String) -> String {
  camel(naming.snake(name)) <> "Codec"
}

fn camel(snake: String) -> String {
  case string.split(snake, "_") {
    [] -> snake
    [first, ..rest] -> first <> string.concat(list.map(rest, naming.pascal))
  }
}

/// payload を持つ sum の型の名(`back.sum_files` と同じ集合)。
fn sum_types(app: App) -> List(String) {
  app.entities
  |> list.flat_map(fn(entity) {
    list.filter_map(entity.props, fn(prop) {
      case prop.kind {
        model.SumProp(
          type_ref: model.TypeRef(name: name, ..),
          payloads: [_, ..],
        ) -> Ok(name)
        _ -> Error(Nil)
      }
    })
  })
  |> list.unique
}

fn decoder(
  app: App,
  units: List(Unit),
  entity: Entity,
) -> Result(String, String) {
  use values <- result.try(
    list.try_map(entity.props, fn(prop) { prop_value(app, units, entity, prop) }),
  )
  Ok(
    "export function decode"
    <> entity.name
    <> "(r) {\n return new "
    <> alias(entity.module)
    <> "."
    <> entity.type_name
    <> "(\n  "
    <> string.join(values, ",\n  ")
    <> ",\n );\n}\n",
  )
}

fn column(entity: Entity, prop: Prop) -> String {
  case model.field_for_prop(entity, prop.name) {
    Some(field) -> field.column
    None -> prop.name
  }
}

fn prop_value(
  app: App,
  units: List(Unit),
  entity: Entity,
  prop: Prop,
) -> Result(String, String) {
  let raw = "r." <> column(entity, prop)
  // `Text` の宣言(列の値 -> 構成子)を持つ sum は、列の値を構成子の snake 名へ戻してから読む
  let raw = case storage.text_values(app, entity, prop.name) {
    [] -> raw
    pairs ->
      "({"
      <> string.join(
        list.map(pairs, fn(pair) {
          "'" <> pair.1 <> "':'" <> naming.snake(pair.0) <> "'"
        }),
        ",",
      )
      <> "}["
      <> raw
      <> "]??"
      <> raw
      <> ")"
  }
  case prop.kind {
    model.RelProp(kind: model.Held, ..) ->
      Ok(
        wrap(prop.optional, False, raw, fn(v) {
          "er.held_from_row({key:" <> v <> "})"
        }),
      )
    model.RelProp(kind: model.Has, ..) ->
      Ok(
        wrap(prop.optional, False, raw, fn(v) {
          "er.from_row({key:" <> v <> "})"
        }),
      )
    model.RelProp(kind: model.Link, ..) ->
      Ok("option(" <> raw <> ",v=>er.key(String(v)))")
    model.RelProp(kind: model.Multi, ..) -> Error(prop.name <> " が Multi")
    model.SumProp(type_ref: model.TypeRef(name: name, ..), payloads: [_, ..]) ->
      Ok(sum_alias(name) <> ".decode" <> name <> "(r)")
    model.SumProp(type_ref: type_ref, payloads: []) ->
      value_of(app, units, type_ref.module, type_ref.name, [])
      |> result.map(fn(each) { wrap(prop.optional, prop.repeated, raw, each) })
    model.ValueProp(type_ref: type_ref) ->
      value_of(
        app,
        units,
        own_module(units, entity, type_ref),
        type_ref.name,
        type_ref.parameters,
      )
      |> result.map(fn(each) { wrap(prop.optional, prop.repeated, raw, each) })
  }
}

/// 型の module が無い(同じ Entity の module に在る)ときは Entity の module。
fn own_module(
  units: List(Unit),
  entity: Entity,
  type_ref: model.TypeRef,
) -> Option(String) {
  case type_ref.module, type_ref.name {
    Some(path), _ -> Some(path)
    None, "Int" | None, "Float" | None, "Bool" | None, "String" -> None
    None, name ->
      case
        list.find(units, fn(unit) { unit.path == "entity/" <> entity.module })
      {
        Ok(unit) ->
          case g.find_custom_type(unit.module, name) {
            Some(_) -> Some(unit.path)
            None -> None
          }
        Error(_) -> None
      }
  }
}

fn wrap(
  optional: Bool,
  repeated: Bool,
  raw: String,
  each: fn(String) -> String,
) -> String {
  case optional, repeated {
    False, False -> each(raw)
    True, False -> "option(" <> raw <> ",v=>" <> each("v") <> ")"
    False, True -> "list(" <> raw <> ",v=>" <> each("v") <> ")"
    True, True -> "option(" <> raw <> ",w=>list(w,v=>" <> each("v") <> "))"
  }
}

/// 型 1 つの写し(値の JS の式を受けて、Gleam の値の式を返す)。
fn value_of(
  app: App,
  units: List(Unit),
  module: Option(String),
  name: String,
  _parameters: List(model.TypeShape),
) -> Result(fn(String) -> String, String) {
  case module, name {
    Some("framework/party"), "PartyId" ->
      Ok(fn(v) { "checked(party.parse(" <> v <> "))" })
    Some("framework/blob"), "Blob" ->
      Ok(fn(v) { "checked(blob.parse(String(" <> v <> ")))" })
    Some("framework/secret"), "Secret" ->
      Ok(fn(v) { "secret.hmac(String(" <> v <> "))" })
    Some("framework/time"), "Datetime" -> Ok(fn(v) { "cDatetime(" <> v <> ")" })
    Some("framework/time"), "Date" -> Ok(fn(v) { "cDate(" <> v <> ")" })
    Some("framework/time"), "Time" -> Ok(fn(v) { "cTime(" <> v <> ")" })
    None, "Int" | None, "Float" -> Ok(fn(v) { "Number(" <> v <> ")" })
    None, "Bool" -> Ok(fn(v) { "Boolean(" <> v <> ")" })
    None, "String" -> Ok(fn(v) { "String(" <> v <> ")" })
    Some(path), _ ->
      case string.starts_with(path, "gen/types/") {
        True ->
          case model.value_type_by_name(app.value_types, name) {
            Some(value) ->
              case value.backing {
                model.IntValue ->
                  Ok(fn(v) {
                    "parse('" <> value.name <> "',Number(" <> v <> "))"
                  })
                model.StringValue ->
                  Ok(fn(v) {
                    "parse('" <> value.name <> "',String(" <> v <> "))"
                  })
              }
            None -> Error("値型 " <> name <> " が無い")
          }
        False -> custom_of(app, units, path, name)
      }
    None, _ -> Error("型 " <> name <> " の module が分からない")
  }
}

/// ★ の module の custom type。構成子だけなら相と同じ写し、欄を持つ 1 構成子なら record として写す。
fn custom_of(
  app: App,
  units: List(Unit),
  path: String,
  name: String,
) -> Result(fn(String) -> String, String) {
  use unit <- result.try(
    list.find(units, fn(unit) { unit.path == path })
    |> result.replace_error(path <> "." <> name <> " の module が読めない"),
  )
  case
    g.find_custom_type(unit.module, name),
    g.find_type_alias(unit.module, name)
  {
    Some(custom), _ -> custom_value(app, units, unit, path, name, custom)
    None, Some(type_alias) ->
      annotation_of(app, units, unit, type_alias.aliased)
    None, None -> Error(path <> "." <> name <> " が custom type でも alias でもない")
  }
}

fn custom_value(
  app: App,
  units: List(Unit),
  unit: Unit,
  path: String,
  name: String,
  custom: glance.CustomType,
) -> Result(fn(String) -> String, String) {
  let owner = case
    list.find(app.entities, fn(entity) { entity.module == last(path) })
  {
    Ok(entity) -> alias(entity.module)
    Error(_) -> alias(last(path))
  }
  case list.all(custom.variants, fn(variant) { variant.fields == [] }) {
    True -> Ok(fn(v) { "phase(" <> owner <> "," <> v <> ")" })
    False ->
      case custom.variants {
        [variant] -> {
          use fields <- result.try(
            list.try_map(variant.fields, fn(field) {
              use label <- result.try(
                g.variant_field_label(field)
                |> option.to_result(name <> " の欄に名が無い"),
              )
              use each <- result.try(annotation_of(
                app,
                units,
                unit,
                g.variant_field_type(field),
              ))
              Ok(#(label, each))
            }),
          )
          Ok(fn(v) {
            "new "
            <> owner
            <> "."
            <> variant.name
            <> "("
            <> string.join(
              list.map(fields, fn(pair) { { pair.1 }(v <> "." <> pair.0) }),
              ",",
            )
            <> ")"
          })
        }
        _ -> Error(name <> " は payload を持つ構成子が複数")
      }
  }
}

/// record の欄の型注釈(`Option(Color)` など)を写しに。import から module を解く。
fn annotation_of(
  app: App,
  units: List(Unit),
  unit: Unit,
  annotation: glance.Type,
) -> Result(fn(String) -> String, String) {
  case annotation {
    glance.NamedType(name: "Option", parameters: [inner], ..) -> {
      use each <- result.try(annotation_of(app, units, unit, inner))
      Ok(fn(v) { "option(" <> v <> ",x=>" <> each("x") <> ")" })
    }
    glance.NamedType(name: "List", parameters: [inner], ..) -> {
      use each <- result.try(annotation_of(app, units, unit, inner))
      Ok(fn(v) { "list(" <> v <> ",x=>" <> each("x") <> ")" })
    }
    glance.NamedType(name: name, module: qualifier, ..) -> {
      let module = case qualifier {
        Some(alias) -> import_path_of_alias(unit, alias)
        None ->
          case import_path_of_type(unit, name) {
            Some(path) -> Some(path)
            None ->
              case g.find_custom_type(unit.module, name) {
                Some(_) -> Some(unit.path)
                None -> None
              }
          }
      }
      value_of(app, units, module, name, [])
    }
    _ -> Error("欄の型が読めない")
  }
}

fn import_path_of_type(unit: Unit, name: String) -> Option(String) {
  unit.module.imports
  |> list.find(fn(definition) {
    list.any(definition.definition.unqualified_types, fn(item) {
      item.name == name
    })
  })
  |> result.map(fn(definition) { definition.definition.module })
  |> option.from_result
}

fn import_path_of_alias(unit: Unit, alias: String) -> Option(String) {
  unit.module.imports
  |> list.find(fn(definition) {
    case definition.definition.alias {
      Some(glance.Named(name)) -> name == alias
      _ -> last(definition.definition.module) == alias
    }
  })
  |> result.map(fn(definition) { definition.definition.module })
  |> option.from_result
}

fn last(path: String) -> String {
  path |> string.split("/") |> list.last |> result.unwrap(path)
}
