//// `server.storage` の写像(WGy r3、鷹野の裁定)── Entity の器(Neon / Durable Object)と、
//// 導出と違う列の持ち方。穴の契約(Property 1 つに穴 1 つ、値は codec の encode)は変えず、
//// 割る・写すのは SQL の側でする。

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi_gen/model
import yumemi_gen/naming

/// 列名の上書き(`Column`)と、record を割る列(`Split`)を FieldDef の列に写す。
/// 割った列は `a,b` の 1 つの綴りで持ち、INSERT / RETURNING はそのまま並び、UPDATE は組の代入にする。
pub fn apply(
  entities: List(model.Entity),
  rows: List(model.Storage),
) -> List(model.Entity) {
  list.map(entities, fn(entity) {
    let fields =
      list.map(entity.fields, fn(field) {
        case column_of(rows, entity, field) {
          Some(column) -> model.FieldDef(..field, column: column)
          None -> field
        }
      })
    model.Entity(..entity, fields: fields)
  })
}

fn column_of(
  rows: List(model.Storage),
  entity: model.Entity,
  field: model.FieldDef,
) -> Option(String) {
  list.find_map(rows, fn(row) {
    case row {
      model.ColumnName(entity: module, property: property, column: column) ->
        case module == entity.module && owns(entity, property, field) {
          True -> Ok(column)
          False -> Error(Nil)
        }
      model.SplitColumns(entity: module, property: property, columns: columns) ->
        case module == entity.module && owns(entity, property, field) {
          True -> Ok(string.join(list.map(columns, fn(pair) { pair.1 }), ","))
          False -> Error(Nil)
        }
      _ -> Error(Nil)
    }
  })
  |> option.from_result
}

fn owns(entity: model.Entity, property: String, field: model.FieldDef) -> Bool {
  field.name == entity.name <> naming.pascal(property)
}

/// Entity が Durable Object の器に在るか(PG の SQL を出さない)。
pub fn in_object(app: model.App, module: String) -> Bool {
  list.any(app.server.storage, fn(row) {
    case row {
      model.InObject(entity: entity, ..) -> entity == module
      _ -> False
    }
  })
}

/// Entity の名(`Notification`)で引く `in_object`。
pub fn in_object_named(app: model.App, name: String) -> Bool {
  case model.entity_by_name(app.entities, name) {
    Some(entity) -> in_object(app, entity.module)
    None -> False
  }
}

fn row_for(
  app: model.App,
  field: model.FieldDef,
) -> Option(#(model.Entity, model.Storage)) {
  case model.entity_by_name(app.entities, field.entity_name) {
    None -> None
    Some(entity) ->
      list.find(app.server.storage, fn(row) {
        case row {
          model.TextSum(entity: module, property: property, ..)
          | model.SplitColumns(entity: module, property: property, ..)
          | model.ArrayColumn(entity: module, property: property, ..) ->
            module == entity.module && owns(entity, property, field)
          _ -> False
        }
      })
      |> option.from_result
      |> option.map(fn(row) { #(entity, row) })
  }
}

/// 列の SQL の型の上書き(`Text` は text、`Array` は `<element>[]`)。
pub fn sql_type(app: model.App, field: model.FieldDef) -> Option(String) {
  case row_for(app, field) {
    Some(#(_, model.TextSum(..))) -> Some("text")
    Some(#(_, model.ArrayColumn(element: element, ..))) -> Some(element <> "[]")
    _ -> None
  }
}

/// 穴 1 つから列の値を書く(`Split` は列の数だけ、`Text` は構成子の snake 名を列の値へ)。
pub fn values(
  app: model.App,
  field: model.FieldDef,
  placeholder: String,
) -> Option(List(String)) {
  case row_for(app, field) {
    Some(#(_, model.SplitColumns(columns: columns, ..))) ->
      Some(
        list.map(columns, fn(pair) {
          "(" <> placeholder <> "::jsonb->>'" <> pair.0 <> "')"
        }),
      )
    Some(#(_, model.TextSum(values: pairs, ..))) ->
      Some([
        "(CASE "
        <> placeholder
        <> "::text "
        <> string.join(
          list.map(pairs, fn(pair) {
            "WHEN '" <> naming.snake(pair.0) <> "' THEN '" <> pair.1 <> "'"
          }),
          " ",
        )
        <> " ELSE "
        <> placeholder
        <> "::text END)",
      ])
    _ -> None
  }
}

/// `Text` の宣言の (構成子, 列の値)。無ければ空。
pub fn text_values(
  app: model.App,
  entity: model.Entity,
  property: String,
) -> List(#(String, String)) {
  list.find_map(app.server.storage, fn(row) {
    case row {
      model.TextSum(entity: module, property: name, values: values)
        if module == entity.module && name == property
      -> Ok(values)
      _ -> Error(Nil)
    }
  })
  |> option.from_result
  |> option.unwrap([])
}

/// `Split` の宣言の (record の欄, 列)。無ければ空。
pub fn split_columns(
  app: model.App,
  entity: model.Entity,
  property: String,
) -> List(#(String, String)) {
  list.find_map(app.server.storage, fn(row) {
    case row {
      model.SplitColumns(entity: module, property: name, columns: columns)
        if module == entity.module && name == property
      -> Ok(columns)
      _ -> Error(Nil)
    }
  })
  |> option.from_result
  |> option.unwrap([])
}
