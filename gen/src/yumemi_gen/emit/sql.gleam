//// 束4 ── `gen/sql/queries/<service>/<name>.sql`。名前付きクエリ値 1つにつき SELECT 1文。
//// 実行時は `$1..$n` を埋めるだけ。組み立ては全部ここで済ませる(20:837)。

import framework/schema
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi_gen/emit/hash
import yumemi_gen/emit/reads
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/model.{type App, type Entity, type Select}
import yumemi_gen/naming
import yumemi_gen/stop

/// SQL を出せない理由。`class` は 20 の exit code 表(`stop`)へそのまま写る。
pub type Reason {
  Reason(class: stop.Class, text: String)
}

fn undone(text: String) -> Reason {
  Reason(class: stop.NotImplemented, text: text)
}

fn clash(text: String) -> Reason {
  Reason(class: stop.Conflict, text: text)
}

pub type Skipped {
  Skipped(service: String, query: String, reason: Reason)
}

pub fn emit(app: App, hashes: hash.Hashes) -> List(File) {
  let #(files, _) = build(app, hashes)
  files
}

/// 出せなかった SQL を 20 の exit code つきで返す。**1本でも出ていなければ 0 で終われない**
/// ── reads の関数だけ在って SQL が無い状態は、実行時に必ず落ちる不整合(柏木 P2-2)。
pub fn notes(app: App, hashes: hash.Hashes) -> List(stop.Note) {
  let #(_, skipped) = build(app, hashes)
  list.map(skipped, fn(entry) {
    stop.Note(
      class: entry.reason.class,
      text: "SQL を出さなかった "
        <> entry.service
        <> "/"
        <> entry.query
        <> ": "
        <> entry.reason.text,
    )
  })
}

pub fn build(app: App, hashes: hash.Hashes) -> #(List(File), List(Skipped)) {
  let #(files, skipped) = build_queries(app, hashes)
  let #(arrow_files, arrow_skipped) = build_arrows(app, hashes)
  #(list.append(files, arrow_files), list.append(skipped, arrow_skipped))
}

/// 矢印の read の SQL ── `gen/sql/queries/<service>/to_<prop>.sql`。鍵の列(jsonb 配列)を
/// 受けて関係先の行を鍵の順で返す。実行側は Context の `relation` でこれを流し、復号して返す。
fn build_arrows(app: App, hashes: hash.Hashes) -> #(List(File), List(Skipped)) {
  list.fold(app.services, #([], []), fn(acc, service) {
    list.fold(reads.root_arrows(app, service), acc, fn(inner, arrow) {
      let #(files, skipped) = inner
      let query = reads.arrow_query(arrow)
      case arrow_statement(app, arrow) {
        Ok(text) -> #(
          [
            File(
              path: "gen/sql/queries/"
                <> service.module
                <> "/"
                <> query
                <> ".sql",
              text: "-- GENERATED from service."
                <> service.module
                <> " / "
                <> arrow.name
                <> " [sha256:"
                <> hash.service(hashes, service.module)
                <> "] — 手で編集しない\n"
                <> text,
            ),
            ..files
          ],
          skipped,
        )
        Error(reason) -> #(files, [
          Skipped(service: service.module, query: query, reason: reason),
          ..skipped
        ])
      }
    })
  })
}

fn arrow_statement(app: App, arrow: model.Arrow) -> Result(String, Reason) {
  use target <- try(
    model.entity_by_name(app.entities, arrow.target_entity)
    |> option.to_result(clash("矢印の先が無い: " <> arrow.target_entity)),
  )
  use key_column <- try(case target.key_columns {
    [single] -> Ok(single)
    [] ->
      case target.key_column {
        "" -> Error(clash("矢印の先に key が無い: " <> target.module))
        column -> Ok(column)
      }
    _ -> Error(undone("矢印の先が複合 key: " <> target.module <> "(Key は1列の鍵しか運ばない)"))
  })
  let cast = case
    list.find(target.fields, fn(field) { field.column == key_column })
  {
    Ok(field) -> keyset_cast(sql_type(app, field.value))
    Error(_) -> "::text"
  }
  Ok(
    "SELECT t.*\nFROM jsonb_array_elements_text($1::jsonb) WITH ORDINALITY AS keys(value,ord)\nJOIN "
    <> schema.app
    <> "."
    <> target.table
    <> " t ON t."
    <> quoted(key_column)
    <> "=keys.value"
    <> cast
    <> "\nORDER BY keys.ord;\n",
  )
}

fn build_queries(
  app: App,
  hashes: hash.Hashes,
) -> #(List(File), List(Skipped)) {
  list.fold(app.services, #([], []), fn(acc, service) {
    list.fold(service.queries, acc, fn(inner, query) {
      let #(files, skipped) = inner
      case statement(app, query.select) {
        Ok(text) -> #(
          [
            File(
              path: "gen/sql/queries/"
                <> service.module
                <> "/"
                <> query.name
                <> ".sql",
              text: "-- GENERATED from service."
                <> service.module
                <> "."
                <> query.name
                <> " [sha256:"
                <> hash.service(hashes, service.module)
                <> "] — 手で編集しない\n"
                <> text,
            ),
            ..files
          ],
          skipped,
        )
        Error(reason) -> #(files, [
          Skipped(service: service.module, query: query.name, reason: reason),
          ..skipped
        ])
      }
    })
  })
}

// ── 別名 ────────────────────────────────────────────────────────────────────

type Scope {
  Scope(
    /// Entity の名 -> 別名
    aliases: List(#(String, String)),
    next_param: Int,
  )
}

fn assign(scope: Scope, entity: Entity) -> Scope {
  let wanted = naming.initial(entity.table)
  let taken = list.map(scope.aliases, fn(pair) { pair.1 })
  let alias = free(wanted, taken, 1)
  Scope(
    aliases: list.append(scope.aliases, [#(entity.name, alias)]),
    next_param: scope.next_param,
  )
}

fn free(wanted: String, taken: List(String), attempt: Int) -> String {
  case list.contains(taken, wanted) {
    False -> wanted
    True -> free(wanted <> int.to_string(attempt), taken, attempt + 1)
  }
}

fn alias_of(scope: Scope, entity_name: String) -> Option(String) {
  case list.key_find(scope.aliases, entity_name) {
    Ok(alias) -> Some(alias)
    Error(_) -> None
  }
}

// ── 列と型 ──────────────────────────────────────────────────────────────────

const reserved = [
  "order", "user", "group", "limit", "offset", "select", "from", "where",
  "table", "column", "default", "check", "references", "primary", "key", "end",
  "all", "any", "as", "case", "cast", "constraint", "create", "do", "else",
  "for", "foreign", "grant", "having", "in", "into", "is", "join", "left",
  "like", "natural", "not", "null", "on", "only", "or", "outer", "right", "some",
  "then", "to", "true", "false", "union", "unique", "using", "when", "with",
  "desc", "asc", "distinct", "values", "window", "returning",
]

fn quoted(column: String) -> String {
  case list.contains(reserved, column) {
    True -> "\"" <> column <> "\""
    False -> column
  }
}

fn sql_type(app: App, value: model.FieldValue) -> String {
  case value {
    model.PhaseValue(_) -> "text"
    model.DatetimeValue -> "timestamptz"
    model.RelValue(target_module: target_module, ..) ->
      case model.entity_by_module(app.entities, target_module) {
        Some(target) ->
          case
            list.find(target.fields, fn(field) {
              field.column == target.key_column
            })
          {
            Ok(field) -> sql_type(app, field.value)
            Error(_) -> "text"
          }
        None -> "text"
      }
    model.TypeValue(reference) ->
      case reference.module {
        Some("framework/time") ->
          case reference.name {
            "Datetime" -> "timestamptz"
            "Date" -> "date"
            "Time" -> "time"
            _ -> "text"
          }
        Some("framework/vector") -> "public.vector"
        Some(path) ->
          case string.starts_with(path, "gen/types/") {
            True ->
              case model.value_type_by_name(app.value_types, reference.name) {
                Some(value_type) ->
                  case value_type.spec {
                    "Uuid" -> "uuid"
                    "Range" -> "integer"
                    _ -> "text"
                  }
                None -> "text"
              }
            False -> "text"
          }
        None ->
          case reference.name {
            "Int" -> "integer"
            "Bool" -> "boolean"
            "Float" -> "double precision"
            _ -> "text"
          }
      }
  }
}

fn cast_of(kind: String) -> String {
  case kind {
    "uuid" | "timestamptz" | "date" | "time" | "public.vector" -> "::" <> kind
    _ -> ""
  }
}

type Column {
  Column(reference: String, kind: String, optional: Bool)
}

fn column(
  app: App,
  scope: Scope,
  field_name: String,
) -> Result(Column, Reason) {
  case model.field_by_name(app.entities, field_name) {
    None -> Error(clash("列 " <> field_name <> " が Entity 宣言に無い"))
    Some(field) ->
      case alias_of(scope, field.entity_name) {
        None ->
          Error(clash("列 " <> field_name <> " の Entity が from にも join にも無い"))
        Some(alias) ->
          Ok(Column(
            reference: alias <> "." <> quoted(field.column),
            kind: sql_type(app, field.value),
            optional: field.optional,
          ))
      }
  }
}

// ── 1文 ─────────────────────────────────────────────────────────────────────

fn statement(app: App, select: Select) -> Result(String, Reason) {
  use from <- try(
    model.entity_by_name(app.entities, select.from)
    |> option.to_result(clash("from の Entity が無い: " <> select.from)),
  )
  use _ <- try(case select.along {
    [] -> Ok(Nil)
    [model.LDistance] -> Ok(Nil)
    _ -> Error(undone("along(Rank / Running)は未実装"))
  })
  let scope = assign(Scope(aliases: [], next_param: 1), from)
  use #(scope, joins) <- try(join_clauses(app, scope, select.join))
  use #(scope, wheres) <- try(where_clauses(app, scope, select.where))
  // 穴の並びは read 関数と同じ ── Paged の size が先、cursor(keyset)が後。
  let #(scope, size_place) = size_param(scope, select.limit)
  use #(scope, keyset) <- try(keyset_clause(app, scope, select, from))
  use selected <- try(select_list(app, scope, select, from))
  use #(scope, havings) <- try(having_clauses(app, scope, select.having))
  use groups <- try(group_clause(app, scope, select.group))
  use order <- try(order_clause(app, scope, select, from))
  let _ = scope
  let conditions = list.append(wheres, keyset)
  Ok(
    string.concat([
      "SELECT ",
      selected,
      "\nFROM ",
      schema.app,
      ".",
      from.table,
      " ",
      option.unwrap(alias_of(scope, from.name), "t"),
      case joins {
        [] -> ""
        _ -> "\n" <> string.join(joins, "\n")
      },
      case conditions {
        [] -> ""
        _ -> "\nWHERE " <> string.join(conditions, " AND ")
      },
      case groups {
        "" -> ""
        text -> "\nGROUP BY " <> text
      },
      case havings {
        [] -> ""
        _ -> "\nHAVING " <> string.join(havings, " AND ")
      },
      case order {
        "" -> ""
        text -> "\nORDER BY " <> text
      },
      limit_clause(select.limit, size_place),
      ";\n",
    ]),
  )
}

fn try(result: Result(a, e), next: fn(a) -> Result(b, e)) -> Result(b, e) {
  case result {
    Ok(value) -> next(value)
    Error(error) -> Error(error)
  }
}

fn join_clauses(
  app: App,
  scope: Scope,
  arrows: List(String),
) -> Result(#(Scope, List(String)), Reason) {
  list.try_fold(arrows, #(scope, []), fn(acc, arrow_name) {
    let #(current, clauses) = acc
    use arrow <- try(
      model.arrow_by_name(app.arrows, arrow_name)
      |> option.to_result(clash("矢印が無い: " <> arrow_name)),
    )
    use target <- try(
      model.entity_by_name(app.entities, arrow.target_entity)
      |> option.to_result(clash("矢印の先が無い: " <> arrow.target_entity)),
    )
    use owner <- try(
      alias_of(current, arrow.from_entity)
      |> option.to_result(clash("矢印の元が from に無い: " <> arrow.from_entity)),
    )
    let next = assign(current, target)
    use alias <- try(
      alias_of(next, target.name)
      |> option.to_result(undone("別名が付かない: " <> target.name)),
    )
    Ok(#(
      next,
      list.append(clauses, [
        "JOIN "
        <> schema.app
        <> "."
        <> target.table
        <> " "
        <> alias
        <> " ON "
        <> alias
        <> "."
        <> quoted(target.key_column)
        <> "="
        <> owner
        <> "."
        <> quoted(arrow.prop <> "_id"),
      ]),
    ))
  })
}

fn select_list(
  app: App,
  scope: Scope,
  select: Select,
  from: Entity,
) -> Result(String, Reason) {
  let alias = option.unwrap(alias_of(scope, from.name), "t")
  case select.group, select.agg {
    [], [] -> {
      let joined =
        list.filter_map(select.join, fn(arrow_name) {
          case model.arrow_by_name(app.arrows, arrow_name) {
            Some(arrow) ->
              case alias_of(scope, arrow.target_entity) {
                Some(target) ->
                  Ok("to_jsonb(" <> target <> ") AS " <> arrow.prop)
                None -> Error(Nil)
              }
            None -> Error(Nil)
          }
        })
      let distance = case select.along {
        [model.LDistance] ->
          list.filter_map(select.order, fn(order) {
            case order {
              model.ONearest(field, _) ->
                case column(app, scope, field) {
                  Ok(found) ->
                    Ok(
                      found.reference
                      <> " OPERATOR(public.<=>) $1::public.vector AS distance",
                    )
                  Error(_) -> Error(Nil)
                }
              _ -> Error(Nil)
            }
          })
        _ -> []
      }
      use attached <- try(with_clauses(app, scope, from, select.with))
      Ok(string.join(
        list.flatten([[alias <> ".*"], joined, attached, distance]),
        ",",
      ))
    }
    groups, aggs -> {
      use group_cols <- try(
        list.try_map(groups, fn(item) {
          case item {
            model.GByField(field) ->
              case column(app, scope, field) {
                Ok(found) -> Ok(found.reference)
                Error(reason) -> Error(reason)
              }
            model.GBucket(field, unit) ->
              case column(app, scope, field) {
                Ok(found) ->
                  Ok(
                    "date_trunc('"
                    <> string.lowercase(unit)
                    <> "',"
                    <> found.reference
                    <> ")::date",
                  )
                Error(reason) -> Error(reason)
              }
            model.GVia(arrow_name) ->
              case model.arrow_by_name(app.arrows, arrow_name) {
                Some(arrow) ->
                  case alias_of(scope, arrow.from_entity) {
                    Some(owner) ->
                      Ok(owner <> "." <> quoted(arrow.prop <> "_id"))
                    None -> Error(clash("Via の元が from に無い"))
                  }
                None -> Error(clash("Via の矢印が無い: " <> arrow_name))
              }
          }
        }),
      )
      use agg_cols <- try(list.try_map(aggs, agg_expression(app, scope, _)))
      Ok(string.join(list.append(group_cols, agg_cols), ","))
    }
  }
}

fn agg_expression(
  app: App,
  scope: Scope,
  value: model.Agg,
) -> Result(String, Reason) {
  case value {
    model.ACount -> Ok("count(*)::integer AS count")
    model.ASum(field) -> wrap(app, scope, "sum", field)
    model.AMin(field) -> wrap(app, scope, "min", field)
    model.AMax(field) -> wrap(app, scope, "max", field)
    model.AAvg(field) -> wrap(app, scope, "avg", field)
  }
}

fn wrap(
  app: App,
  scope: Scope,
  name: String,
  field: String,
) -> Result(String, Reason) {
  case column(app, scope, field) {
    Ok(found) -> Ok(name <> "(" <> found.reference <> ") AS " <> name)
    Error(reason) -> Error(reason)
  }
}

fn where_clauses(
  app: App,
  scope: Scope,
  conds: List(model.Cond),
) -> Result(#(Scope, List(String)), Reason) {
  list.try_fold(conds, #(scope, []), fn(acc, cond) {
    let #(current, clauses) = acc
    use #(next, text) <- try(where_one(app, current, cond))
    Ok(#(next, list.append(clauses, [text])))
  })
}

fn where_one(
  app: App,
  scope: Scope,
  cond: model.Cond,
) -> Result(#(Scope, String), Reason) {
  case cond {
    model.CEq(field, operand) -> compare(app, scope, field, "=", operand)
    model.CNe(field, operand) -> compare(app, scope, field, "<>", operand)
    model.CLt(field, operand) -> compare(app, scope, field, "<", operand)
    model.CLe(field, operand) -> compare(app, scope, field, "<=", operand)
    model.CGt(field, operand) -> compare(app, scope, field, ">", operand)
    model.CGe(field, operand) -> compare(app, scope, field, ">=", operand)
    model.CIn(field, operand) -> compare(app, scope, field, "= ANY", operand)
    model.CContains(field, operand) ->
      compare(app, scope, field, "ILIKE", operand)
    model.CIsNull(field) ->
      case column(app, scope, field) {
        Ok(found) -> Ok(#(scope, found.reference <> " IS NULL"))
        Error(reason) -> Error(reason)
      }
    model.CNotNull(field) ->
      case column(app, scope, field) {
        Ok(found) -> Ok(#(scope, found.reference <> " IS NOT NULL"))
        Error(reason) -> Error(reason)
      }
    model.CIsTrue(field) ->
      case column(app, scope, field) {
        Ok(found) -> Ok(#(scope, found.reference <> " IS TRUE"))
        Error(reason) -> Error(reason)
      }
    model.CEqOrNull(field, operand) ->
      case column(app, scope, field), operand {
        Ok(found), model.OpParam(_) -> {
          let placeholder =
            "$" <> int.to_string(scope.next_param) <> cast_of(found.kind)
          Ok(#(
            Scope(..scope, next_param: scope.next_param + 1),
            found.reference <> " IS NOT DISTINCT FROM " <> placeholder,
          ))
        }
        Ok(_), _ -> Error(undone("EqOrNull の相手は穴だけ"))
        Error(reason), _ -> Error(reason)
      }
    model.CCurrentVersion(left, right) ->
      case column(app, scope, left), column(app, scope, right) {
        Ok(one), Ok(other) ->
          Ok(#(scope, one.reference <> "=" <> other.reference))
        Error(reason), _ -> Error(reason)
        _, Error(reason) -> Error(reason)
      }
    model.CHas(arrow, inner) -> has_clause(app, scope, arrow, inner, False)
    model.CHasNone(arrow, inner) -> has_clause(app, scope, arrow, inner, True)
  }
}

fn has_clause(
  app: App,
  scope: Scope,
  arrow_name: String,
  inner: List(model.Cond),
  negate: Bool,
) -> Result(#(Scope, String), Reason) {
  use arrow <- try(
    model.arrow_by_name(app.arrows, arrow_name)
    |> option.to_result(clash("Has の矢印が無い: " <> arrow_name)),
  )
  use target <- try(
    model.entity_by_name(app.entities, arrow.target_entity)
    |> option.to_result(clash("Has の関係先が無い: " <> arrow.target_entity)),
  )
  use owner <- try(
    alias_of(scope, arrow.from_entity)
    |> option.to_result(clash("Has の元が from / join に無い: " <> arrow.from_entity)),
  )
  let nested = assign(scope, target)
  use target_alias <- try(
    alias_of(nested, target.name)
    |> option.to_result(undone("Has の関係先に別名が付かない: " <> target.name)),
  )
  use #(after, clauses) <- try(where_clauses(app, nested, inner))
  let relation =
    target_alias
    <> "."
    <> quoted(target.key_column)
    <> "="
    <> owner
    <> "."
    <> quoted(arrow.prop <> "_id")
  let keyword = case negate {
    True -> "NOT EXISTS"
    False -> "EXISTS"
  }
  let predicates = list.append([relation], clauses)
  Ok(#(
    Scope(..scope, next_param: after.next_param),
    keyword
      <> "(\n  SELECT 1 FROM "
      <> schema.app
      <> "."
      <> target.table
      <> " "
      <> target_alias
      <> "\n  WHERE "
      <> string.join(predicates, "\n    AND ")
      <> "\n)",
  ))
}

fn with_clauses(
  app: App,
  scope: Scope,
  from: Entity,
  names: List(String),
) -> Result(List(String), Reason) {
  use #(texts, _) <- try(
    list.try_fold(names, #([], scope), fn(acc, name) {
      let #(texts, current) = acc
      use #(next, text) <- try(with_clause(app, current, from, name))
      Ok(#(list.append(texts, [text]), next))
    }),
  )
  Ok(texts)
}

fn with_clause(
  app: App,
  scope: Scope,
  from: Entity,
  name: String,
) -> Result(#(Scope, String), Reason) {
  use #(child, arrow) <- try(with_relation(app, from, name))
  use owner <- try(
    alias_of(scope, from.name)
    |> option.to_result(clash("with の元が from / join に無い: " <> from.name)),
  )
  let nested = assign(scope, child)
  use child_alias <- try(
    alias_of(nested, child.name)
    |> option.to_result(undone("with の関係先に別名が付かない: " <> child.name)),
  )
  let order = with_order(child, child_alias)
  let output = with_output(from, name)
  let relation =
    child_alias
    <> "."
    <> quoted(arrow.prop <> "_id")
    <> "="
    <> owner
    <> "."
    <> quoted(from.key_column)
  let aggregate = "jsonb_agg(to_jsonb(" <> child_alias <> ")" <> order <> ")"
  Ok(#(
    nested,
    "COALESCE((SELECT "
      <> aggregate
      <> "\nFROM "
      <> schema.app
      <> "."
      <> child.table
      <> " "
      <> child_alias
      <> "\nWHERE "
      <> relation
      <> "),'[]'::jsonb) AS "
      <> output,
  ))
}

fn with_relation(
  app: App,
  from: Entity,
  name: String,
) -> Result(#(Entity, model.Arrow), Reason) {
  case model.arrow_by_name(app.arrows, name) {
    Some(arrow) ->
      case arrow.from_entity == from.name {
        True -> {
          use child <- try(
            model.entity_by_name(app.entities, arrow.target_entity)
            |> option.to_result(clash("with の関係先が無い: " <> arrow.target_entity)),
          )
          Ok(#(child, arrow))
        }
        False -> reverse_with_relation(app, from, name)
      }
    None -> reverse_with_relation(app, from, name)
  }
}

fn reverse_with_relation(
  app: App,
  from: Entity,
  name: String,
) -> Result(#(Entity, model.Arrow), Reason) {
  let candidates =
    list.filter(app.arrows, fn(arrow) { arrow.target_entity == from.name })
  let named =
    list.filter_map(candidates, fn(arrow) {
      case model.entity_by_name(app.entities, arrow.from_entity) {
        Some(child) ->
          case with_name_matches(name, from, child) {
            True -> Ok(#(child, arrow))
            False -> Error(Nil)
          }
        None -> Error(Nil)
      }
    })
  case named {
    [one] -> Ok(one)
    [] ->
      case candidates {
        [one] ->
          case model.entity_by_name(app.entities, one.from_entity) {
            Some(child) -> Ok(#(child, one))
            None -> Error(clash("with の関係先が無い: " <> one.from_entity))
          }
        _ -> Error(clash("with の逆向きが無い: " <> name))
      }
    _ -> Error(clash("with の逆向きが複数: " <> name))
  }
}

fn with_name_matches(name: String, from: Entity, child: Entity) -> Bool {
  let prefix = from.name <> "To"
  case string.starts_with(name, prefix) {
    False -> False
    True -> {
      let requested = string.drop_start(name, string.length(prefix))
      let short = case string.starts_with(child.name, from.name) {
        True -> string.drop_start(child.name, string.length(from.name))
        False -> child.name
      }
      requested == plural(short)
    }
  }
}

fn plural(word: String) -> String {
  case string.ends_with(word, "y") {
    True -> string.drop_end(word, 1) <> "ies"
    False ->
      case
        string.ends_with(word, "s")
        || string.ends_with(word, "x")
        || string.ends_with(word, "ch")
        || string.ends_with(word, "sh")
      {
        True -> word <> "es"
        False -> word <> "s"
      }
  }
}

fn with_output(from: Entity, name: String) -> String {
  let prefix = from.name <> "To"
  case string.starts_with(name, prefix) {
    True -> naming.snake(string.drop_start(name, string.length(prefix)))
    False -> naming.snake(name)
  }
}

fn with_order(child: Entity, alias: String) -> String {
  let key = alias <> "." <> quoted(child.key_column)
  case list.find(child.fields, fn(field) { field.column == "order" }) {
    Ok(_) -> " ORDER BY " <> alias <> ".\"order\"," <> key
    Error(_) -> " ORDER BY " <> key
  }
}

fn compare(
  app: App,
  scope: Scope,
  field: String,
  operator: String,
  operand: model.Operand,
) -> Result(#(Scope, String), Reason) {
  use found <- try(column(app, scope, field))
  case operand {
    model.OpParam(_) -> {
      let placeholder =
        "$" <> int.to_string(scope.next_param) <> cast_of(found.kind)
      Ok(#(
        Scope(..scope, next_param: scope.next_param + 1),
        found.reference <> operator <> placeholder,
      ))
    }
    model.OpNum(value) ->
      Ok(#(scope, found.reference <> operator <> int.to_string(value)))
    model.OpStr(value) ->
      Ok(#(scope, found.reference <> operator <> "'" <> value <> "'"))
    model.OpPhase(_, variant) ->
      Ok(#(
        scope,
        found.reference <> operator <> "'" <> naming.snake(variant) <> "'",
      ))
    model.OpCol(other) ->
      case column(app, scope, other) {
        Ok(target) ->
          Ok(#(scope, found.reference <> operator <> target.reference))
        Error(reason) -> Error(reason)
      }
    model.OpAt(_) -> Error(undone("At(固定時刻)は未実装"))
    model.OpKey(_) -> Error(undone("KeyOf(固定識別子)は未実装"))
  }
}

fn having_clauses(
  app: App,
  scope: Scope,
  entries: List(#(String, model.Agg, model.Operand)),
) -> Result(#(Scope, List(String)), Reason) {
  list.try_fold(entries, #(scope, []), fn(acc, entry) {
    let #(current, clauses) = acc
    let #(name, value, operand) = entry
    let operator = case name {
      "AggGt" -> ">"
      "AggGe" -> ">="
      "AggLt" -> "<"
      "AggLe" -> "<="
      _ -> "="
    }
    use expression <- try(agg_bare(app, current, value))
    case operand {
      model.OpParam(_) ->
        Ok(#(
          Scope(..current, next_param: current.next_param + 1),
          list.append(clauses, [
            expression <> operator <> "$" <> int.to_string(current.next_param),
          ]),
        ))
      model.OpNum(number) ->
        Ok(#(
          current,
          list.append(clauses, [
            expression <> operator <> int.to_string(number),
          ]),
        ))
      _ -> Error(undone("having の相手は穴か数だけ"))
    }
  })
}

fn agg_bare(
  app: App,
  scope: Scope,
  value: model.Agg,
) -> Result(String, Reason) {
  case value {
    model.ACount -> Ok("count(*)")
    model.ASum(field) -> bare(app, scope, "sum", field)
    model.AMin(field) -> bare(app, scope, "min", field)
    model.AMax(field) -> bare(app, scope, "max", field)
    model.AAvg(field) -> bare(app, scope, "avg", field)
  }
}

fn bare(
  app: App,
  scope: Scope,
  name: String,
  field: String,
) -> Result(String, Reason) {
  case column(app, scope, field) {
    Ok(found) -> Ok(name <> "(" <> found.reference <> ")")
    Error(reason) -> Error(reason)
  }
}

fn group_clause(
  app: App,
  scope: Scope,
  groups: List(model.Group),
) -> Result(String, Reason) {
  case groups {
    [] -> Ok("")
    _ -> {
      use parts <- try(
        list.try_map(groups, fn(item) {
          case item {
            model.GByField(field) ->
              case column(app, scope, field) {
                Ok(found) -> Ok(found.reference)
                Error(reason) -> Error(reason)
              }
            model.GBucket(field, unit) ->
              case column(app, scope, field) {
                Ok(found) ->
                  Ok(
                    "date_trunc('"
                    <> string.lowercase(unit)
                    <> "',"
                    <> found.reference
                    <> ")",
                  )
                Error(reason) -> Error(reason)
              }
            model.GVia(arrow_name) ->
              case model.arrow_by_name(app.arrows, arrow_name) {
                Some(arrow) ->
                  case alias_of(scope, arrow.from_entity) {
                    Some(owner) ->
                      Ok(owner <> "." <> quoted(arrow.prop <> "_id"))
                    None -> Error(clash("Via の元が from に無い"))
                  }
                None -> Error(clash("Via の矢印が無い: " <> arrow_name))
              }
          }
        }),
      )
      Ok(string.join(parts, ","))
    }
  }
}

/// 並び。宣言した列のあと、最後の向きで key を1本足す(カーソルの安定順)。
fn order_clause(
  app: App,
  scope: Scope,
  select: Select,
  from: Entity,
) -> Result(String, Reason) {
  use declared <- try(
    list.try_map(select.order, fn(order) {
      case order {
        model.OAsc(field) -> direction(app, scope, field, "ASC")
        model.ODesc(field) -> direction(app, scope, field, "DESC")
        model.OAscAgg(value) ->
          case agg_bare(app, scope, value) {
            Ok(expression) -> Ok(expression <> " ASC")
            Error(reason) -> Error(reason)
          }
        model.ODescAgg(value) ->
          case agg_bare(app, scope, value) {
            Ok(expression) -> Ok(expression <> " DESC")
            Error(reason) -> Error(reason)
          }
        model.ONearest(field, _) ->
          case column(app, scope, field) {
            Ok(found) ->
              Ok(found.reference <> " OPERATOR(public.<=>) $1::public.vector")
            Error(reason) -> Error(reason)
          }
      }
    }),
  )
  case select.group, select.agg, declared {
    [], [], _ -> {
      let alias = option.unwrap(alias_of(scope, from.name), "t")
      let key = alias <> "." <> quoted(from.key_column)
      let last_direction = case list.last(select.order) {
        Ok(model.ODesc(_)) -> "DESC"
        _ -> "ASC"
      }
      let tail = case
        list.any(declared, fn(text) { string.starts_with(text, key <> " ") })
      {
        True -> []
        False -> [key <> " " <> last_direction]
      }
      Ok(string.join(list.append(declared, tail), ","))
    }
    _, _, [] -> Ok("")
    _, _, _ -> Ok(string.join(declared, ","))
  }
}

fn direction(
  app: App,
  scope: Scope,
  field: String,
  way: String,
) -> Result(String, Reason) {
  case column(app, scope, field) {
    Ok(found) ->
      Ok(
        found.reference
        <> " "
        <> way
        <> case found.optional {
          True -> " NULLS LAST"
          False -> ""
        },
      )
    Error(reason) -> Error(reason)
  }
}

/// keyset。`order` が空の Paged は止める(20:787)。
/// 向きが混じる場合は、列ごとの比較を OR でつなぐ lexicographic keyset にする。
fn keyset_clause(
  app: App,
  scope: Scope,
  select: Select,
  from: Entity,
) -> Result(#(Scope, List(String)), Reason) {
  case select.limit {
    model.LPaged(..) ->
      case select.order {
        [] -> Error(clash("order が空の Paged はカーソルが成立しない"))
        orders -> {
          use directions <- try(
            list.try_map(orders, fn(order) {
              case order {
                model.OAsc(field) -> Ok(#(field, "ASC"))
                model.ODesc(field) -> Ok(#(field, "DESC"))
                _ -> Error(undone("keyset は列の Asc / Desc だけ"))
              }
            }),
          )
          let ways = list.unique(list.map(directions, fn(pair) { pair.1 }))
          case ways {
            [single] -> uniform_keyset(app, scope, directions, from, single)
            _ -> {
              use columns <- try(
                list.try_map(directions, fn(pair) { column(app, scope, pair.0) }),
              )
              let key_field = from.name <> naming.pascal(from.key_prop)
              use key <- try(column(app, scope, key_field))
              let terms =
                list.append(
                  list.map2(columns, directions, fn(found, pair) {
                    #(found, pair.1)
                  }),
                  [#(key, last_direction(directions))],
                )
              let first = scope.next_param
              let places =
                range(first + 1, list.length(terms))
                |> list.map(fn(index) { "$" <> int.to_string(index) })
              let comparisons =
                list.map2(terms, places, fn(term, place) {
                  let #(found, way) = term
                  cursor_compare(found, way, place)
                })
              let branches = keyset_branches(terms, places, comparisons, [])
              let text =
                "($"
                <> int.to_string(first)
                <> "::boolean=false OR "
                <> string.join(branches, " OR ")
                <> ")"
              Ok(
                #(Scope(..scope, next_param: first + list.length(terms) + 1), [
                  text,
                ]),
              )
            }
          }
        }
      }
    _ -> Ok(#(scope, []))
  }
}

fn uniform_keyset(
  app: App,
  scope: Scope,
  directions: List(#(String, String)),
  from: Entity,
  way: String,
) -> Result(#(Scope, List(String)), Reason) {
  use columns <- try(
    list.try_map(directions, fn(pair) { column(app, scope, pair.0) }),
  )
  let alias = option.unwrap(alias_of(scope, from.name), "t")
  let key_reference = alias <> "." <> quoted(from.key_column)
  let key_kind = case
    list.find(from.fields, fn(field) { field.column == from.key_column })
  {
    Ok(field) -> sql_type(app, field.value)
    Error(_) -> "text"
  }
  let first = scope.next_param
  let count = list.length(columns) + 1
  let places =
    range(first, count)
    |> list.map(fn(index) { "$" <> int.to_string(index) })
  let places = case list.reverse(places) {
    [last, ..rest] -> list.reverse([last <> cast_of(key_kind), ..rest])
    [] -> []
  }
  let head_cast = case columns {
    [head, ..] -> cast_of(head.kind)
    [] -> ""
  }
  let operator = case way {
    "DESC" -> "<"
    _ -> ">"
  }
  let text =
    "($"
    <> int.to_string(first)
    <> head_cast
    <> " IS NULL OR ("
    <> string.join(
      list.append(list.map(columns, fn(found) { found.reference }), [
        key_reference,
      ]),
      ",",
    )
    <> ")"
    <> operator
    <> "("
    <> string.join(places, ",")
    <> "))"
  Ok(#(Scope(..scope, next_param: first + count), [text]))
}

fn keyset_branches(
  terms: List(#(Column, String)),
  places: List(String),
  comparisons: List(String),
  prefix: List(String),
) -> List(String) {
  case terms, places, comparisons {
    [term, ..rest_terms], [place, ..rest_places], [comparison, ..rest] -> {
      let branch = case prefix {
        [] -> comparison
        _ -> "(" <> string.join(prefix, " AND ") <> " AND " <> comparison <> ")"
      }
      let #(found, _) = term
      let equal = found.reference <> " IS NOT DISTINCT FROM " <> place
      [
        branch,
        ..keyset_branches(
          rest_terms,
          rest_places,
          rest,
          list.append(prefix, [equal]),
        )
      ]
    }
    _, _, _ -> []
  }
}

fn last_direction(directions: List(#(String, String))) -> String {
  case list.last(directions) {
    Ok(pair) -> pair.1
    Error(_) -> "ASC"
  }
}

fn cursor_compare(found: Column, way: String, place: String) -> String {
  let operator = case way {
    "DESC" -> "<"
    _ -> ">"
  }
  let right = place <> keyset_cast(found.kind)
  case found.optional {
    True ->
      "("
      <> place
      <> " IS NOT NULL AND ("
      <> found.reference
      <> " IS NULL OR ("
      <> found.reference
      <> " IS NOT NULL AND "
      <> found.reference
      <> operator
      <> right
      <> ")))"
    False -> found.reference <> operator <> right
  }
}

fn keyset_cast(kind: String) -> String {
  case kind {
    "uuid" -> "::uuid"
    "timestamptz" -> "::timestamptz"
    "date" -> "::date"
    "time" -> "::time"
    "public.vector" -> "::public.vector"
    "integer" -> "::integer"
    "boolean" -> "::boolean"
    "double precision" -> "::double precision"
    _ -> "::text"
  }
}

fn range(first: Int, count: Int) -> List(Int) {
  case count {
    0 -> []
    _ -> [first, ..range(first + 1, count - 1)]
  }
}

/// Paged の size が穴なら番号を1つ取る。read 関数の並びに合わせて keyset より先。
fn size_param(scope: Scope, limit: model.Limit) -> #(Scope, Option(Int)) {
  case limit {
    model.LPaged(size: model.OpParam(_), ..) -> #(
      Scope(..scope, next_param: scope.next_param + 1),
      Some(scope.next_param),
    )
    _ -> #(scope, None)
  }
}

fn limit_clause(limit: model.Limit, size_place: Option(Int)) -> String {
  case limit, size_place {
    model.LNoLimit, _ -> ""
    model.LFirst(count), _ -> "\nLIMIT " <> int.to_string(count)
    model.LPaged(size: model.OpNum(size), ..), _ ->
      "\nLIMIT " <> int.to_string(size + 1)
    model.LPaged(..), Some(place) ->
      "\nLIMIT $" <> int.to_string(place) <> " + 1"
    model.LPaged(..), None -> "\nLIMIT 21"
    model.LFirstPerGroup(..), _ -> ""
  }
}
