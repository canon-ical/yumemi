//// `src/gen/runtime.mjs`(WGy r3)── Service を 1 回走らせる表。機関は yumemi の
//// `framework/server/runtime.mjs`(`runtime(spec)`)で、ここは宣言から導いた表だけを書く。
////
//// - root:root の Entity(`emit/root`)と ★ の root の SQL の `-- root:` の契約(穴の並び)
//// - actor:Service の主体(allow の who)から
//// - verb:生成の verb の穴の並び(`emit/verb.runtime_table`)。手書きの verb は ★ hook `stage_manual`
//// - 読み:生成の読みの穴(Args の型・`-- allow:` の契約・keyset)と戻りの形。手書きの SQL の読みは宣言の hook
//// - connector:`server.connectors` の `Call` / `Send` の口は ★ hook `call_<op>`
//// - outbox:queue の kind の payload、受け手へ送る consumer(`Send` の口を持つ)は commit を解釈の境にする

import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi_gen/emit/root
import yumemi_gen/emit/types.{type File}
import yumemi_gen/emit/typing
import yumemi_gen/emit/verb
import yumemi_gen/model.{type App, type Service}
import yumemi_gen/naming
import yumemi_gen/relation
import yumemi_gen/source.{type Unit}
import yumemi_gen/stop
import yumemi_gen/storage

const framework = "../../yumemi/framework/server/"

pub fn text(
  app: App,
  units: List(Unit),
  queries: List(#(String, String)),
  generated: List(File),
  kinds: List(String),
  header: String,
) -> #(String, List(stop.Note)) {
  let hook_names = list.map(app.server.hooks, fn(hook) { hook.name })
  let generated_verbs = list.map(verb.runtime_table(app), fn(row) { row.0 })
  let manual_names =
    list.append(manual_verbs(app), staged_names(units))
    |> list.unique
    |> list.filter(fn(name) { !list.contains(generated_verbs, name) })
    |> list.sort(string.compare)
  let call_ops = call_ops(app)
  let missing =
    list.flatten([
      case manual_names != [] && !list.contains(hook_names, "stage_manual") {
        True -> ["手書きの verb があるのに hook stage_manual が hooks に無い"]
        False -> []
      },
      list.filter_map(call_ops, fn(op) {
        case list.contains(hook_names, "call_" <> op.0) {
          True -> Error(Nil)
          False ->
            Ok(
              "connector の口 "
              <> op.0
              <> " の hook call_"
              <> op.0
              <> " が hooks に無い",
            )
        }
      }),
    ])
  let notes =
    list.map(missing, fn(text) {
      stop.Note(class: stop.Conflict, text: "runtime: " <> text)
    })
  let used_hooks =
    list.flatten([
      case manual_names {
        [] -> []
        _ -> ["stage_manual"]
      },
      list.map(call_ops, fn(op) { "call_" <> op.0 }),
      list.map(app.server.reads, fn(read) { read.hook }),
      list.filter(["api_key_label", "claim_label"], list.contains(hook_names, _)),
      list.filter(hook_names, fn(name) { string.starts_with(name, "encode_") }),
    ])
    |> list.unique
    |> list.filter(list.contains(hook_names, _))
  let hook_imports =
    app.server.hooks
    |> list.filter(fn(hook) { list.contains(used_hooks, hook.name) })
    |> list.map(fn(hook) {
      "import { "
      <> camel(hook.name)
      <> " } from '../"
      <> hook.module
      <> ".mjs';\n"
    })
    |> string.concat
  let allow_modules =
    app.services
    |> list.map(root.allow_path)
    |> list.unique
    |> list.sort(string.compare)
  let draft_modules =
    verb.runtime_table(app)
    |> list.filter_map(fn(row) {
      case string.split(row.1, "created:['") {
        [_, rest] ->
          case string.split(rest, "'") {
            [module, ..] -> Ok(module)
            _ -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    })
    |> list.unique
    |> list.sort(string.compare)
  let imports =
    string.concat([
      "import { SQL } from './sql.mjs';\n",
      "import * as c from './codec.mjs';\n",
      "import * as subject from './subject.mjs';\n",
      "import { runtime } from '" <> framework <> "runtime.mjs';\n",
      list.map(allow_modules, fn(path) {
        "import * as "
        <> allow_alias(path)
        <> " from './"
        <> string.drop_start(path, 4)
        <> ".mjs';\n"
      })
        |> string.concat,
      list.map(draft_modules, fn(module) {
        "import * as draft_"
        <> module
        <> " from './draft/"
        <> module
        <> ".mjs';\n"
      })
        |> string.concat,
      hook_imports,
    ])
  let body =
    string.concat([
      "const roots={\n",
      roots_text(app, queries),
      "};\n",
      "const actors={\n",
      actors_text(app, generated),
      "};\n",
      "const verbs={\n",
      verb.runtime_table(app)
        |> list.map(fn(row) { " " <> row.0 <> ":" <> row.1 <> ",\n" })
        |> string.concat,
      "};\n",
      "const manualVerbs={names:new Set([",
      string.join(list.map(manual_names, quoted), ","),
      "]),stage:",
      case manual_names {
        [] -> "()=>{throw new Error('no manual verb')}"
        _ -> "stageManual"
      },
      "};\n",
      "const reads={\n",
      reads_text(app, queries),
      "};\n",
      "const readAliases={\n",
      read_aliases(app, units),
      "};\n",
      "const connectors={\n",
      list.map(call_ops, fn(op) {
        " " <> op.0 <> ":" <> camel("call_" <> op.0) <> ",\n"
      })
        |> string.concat,
      "};\n",
      "const connectorNames={",
      list.map(call_ops, fn(op) { op.0 <> ":" <> quoted(op.1) })
        |> string.join(","),
      "};\n",
      outbox_text(app, units, kinds),
      tables_text(app, used_hooks),
      "const labels={apiKeyLabel:",
      case list.contains(used_hooks, "api_key_label") {
        True -> "apiKeyLabel"
        False -> "null"
      },
      ",claimLabel:",
      case list.contains(used_hooks, "claim_label") {
        True -> "claimLabel"
        False -> "null"
      },
      "};\n",
      "export const {statement,run,step,seededId,labeledHmac,apiKeyHmac,claimHmac,resolveSession,resolveApiKey,issueSession,revokeParty,connectorFailureDiagnostic,actorFor,loadRoot,makeContext,invoke}=runtime({SQL,c,cursorArgs:c.cursorArgs,roots,actors,verbs,manualVerbs,reads,readAliases,connectors,connectorNames,folds,enqueues,boundaries,relationDecoders,phaseModules,drafts,subjects,encoders,carried,...labels});\n",
    ])
  #(header <> imports <> body, notes)
}

fn quoted(text: String) -> String {
  "'" <> text <> "'"
}

fn camel(snake: String) -> String {
  case string.split(snake, "_") {
    [] -> snake
    [first, ..rest] -> first <> string.concat(list.map(rest, naming.pascal))
  }
}

fn allow_alias(path: String) -> String {
  "allow_" <> string.replace(string.drop_start(path, 10), "/", "_")
}

/// 手書きの verb の名(Entity の `handwritten_verbs`、ER の外の `handwritten_verbs` / `manual_verbs`)。
pub fn manual_verbs(app: App) -> List(String) {
  list.flatten([
    list.flat_map(app.entities, fn(entity) { entity.handwritten_verbs }),
    list.flat_map(app.handwritten_verbs, fn(entry) { entry.1 }),
    list.flat_map(app.manual_verbs, fn(entry) { entry.1 }),
  ])
  |> list.unique
  |> list.sort(string.compare)
}

/// ★ の source が `stage(ctx, "<name>", ..)` で積む verb の名(verb_manual など、宣言の表に無い手書きの verb)。
fn staged_names(units: List(Unit)) -> List(String) {
  units
  |> list.flat_map(fn(unit) {
    case string.split(unit.text, "stage(ctx, \"") {
      [_, ..rest] ->
        list.filter_map(rest, fn(piece) {
          case string.split_once(piece, "\"") {
            Ok(#(name, _)) -> Ok(name)
            Error(_) -> Error(Nil)
          }
        })
      [] -> []
    }
  })
}

/// 他の Service の読みの module を import する ★ Service -> その Service の名(import の順)。
fn read_aliases(app: App, units: List(Unit)) -> String {
  app.services
  |> list.filter_map(fn(service) {
    let text = case
      list.find(units, fn(unit) { unit.path == "service/" <> service.module })
    {
      Ok(unit) -> unit.text
      Error(_) -> ""
    }
    let others = case string.split(text, "import gen/reads/") {
      [_, ..rest] ->
        list.filter_map(rest, fn(piece) {
          case string.split_once(piece, " ") {
            Ok(#(name, _)) if name != service.module -> Ok(quoted(name))
            _ -> Error(Nil)
          }
        })
      [] -> []
    }
    case others {
      [] -> Error(Nil)
      _ ->
        Ok(" " <> service.module <> ":[" <> string.join(others, ",") <> "],\n")
    }
  })
  |> string.concat
}

/// `Call` / `Send` の口の op と connector の名。
fn call_ops(app: App) -> List(#(String, String)) {
  app.server.connectors
  |> list.flat_map(fn(connector) {
    list.filter_map(connector.ports, fn(port) {
      case port {
        model.CallPort(op: op, ..) | model.SendPort(op: op, ..) ->
          Ok(#(op, connector.name))
        _ -> Error(Nil)
      }
    })
  })
  |> list.unique
}

// ── root ────────────────────────────────────────────────────────────────────

fn root_contract(text: String) -> List(String) {
  string.split(text, "\n")
  |> list.find_map(fn(line) {
    case string.split_once(line, "-- root:") {
      Ok(#(_, rest)) ->
        Ok(
          string.split(string.trim(rest), " ")
          |> list.filter(fn(token) { token != "" }),
        )
      Error(_) -> Error(Nil)
    }
  })
  |> option.from_result
  |> option.unwrap([])
}

fn roots_text(app: App, queries: List(#(String, String))) -> String {
  app.services
  |> list.filter_map(fn(service) {
    let entity = root.root_for(app, service)
    let values =
      list.flatten([
        case entity {
          Some(found) ->
            case found.phases {
              [] -> ["entity:" <> found.module]
              _ -> ["entity:" <> found.module, "phase:" <> found.module]
            }
          None -> []
        },
        case root.with_version(app, service) {
          True -> ["version"]
          False -> []
        },
        list.map(root.carried(app, service), fn(extra) { "carried:" <> extra.0 }),
      ])
    let sql = list.key_find(queries, service.module <> "/root")
    case sql, values {
      Error(_), [] -> Error(Nil)
      _, _ ->
        Ok(
          " "
          <> service.module
          <> ":{sql:"
          <> case sql {
            Ok(_) -> quoted(service.module <> "/root")
            Error(_) -> "null"
          }
          <> ",params:["
          <> case sql {
            Ok(text) -> string.join(list.map(root_contract(text), quoted), ",")
            Error(_) -> ""
          }
          <> "],values:["
          <> string.join(list.map(values, quoted), ",")
          <> "]},\n",
        )
    }
  })
  |> string.concat
}

// ── actor ───────────────────────────────────────────────────────────────────

/// actor の決め方。主体が 1 つなら その型(Direct)。和の Actor(主体が複数、または `Anyone` だけ)は
/// allow の module の `Actor` の構成子の全部から、session の主体に合うものを選ぶ(句は admission の側)。
fn actors_text(app: App, generated: List(File)) -> String {
  app.services
  |> list.map(fn(service) {
    let path = root.allow_path(service)
    let module = allow_alias(path)
    let plan = case list.unique(service.subjects) {
      [model.SubjectEntity(module: subject, ..)] ->
        "{kind:'direct',subject:" <> quoted(subject) <> "}"
      [model.SubjectParty] -> "{kind:'party',module:" <> module <> "}"
      [model.SubjectSystem] -> "{kind:'system',module:" <> module <> "}"
      _ -> {
        let variants = actor_variants(generated, path)
        let entities =
          list.filter_map(variants, fn(variant) {
            case string.split_once(variant, "Actor(") {
              Ok(#(type_name, rest)) ->
                case string.split_once(rest, ".") {
                  Ok(#(entity, _)) ->
                    Ok(
                      "["
                      <> quoted(entity)
                      <> ","
                      <> quoted(type_name <> "Actor")
                      <> "]",
                    )
                  Error(_) -> Error(Nil)
                }
              Error(_) -> Error(Nil)
            }
          })
        "{kind:'sum',module:"
        <> module
        <> ",variants:["
        <> string.join(entities, ",")
        <> "],party:"
        <> bool(
          list.any(variants, string.starts_with(_, "AuthenticatedActor(")),
        )
        <> ",any:"
        <> bool(list.contains(variants, "AnyActor"))
        <> "}"
      }
    }
    " " <> service.module <> ":" <> plan <> ",\n"
  })
  |> string.concat
}

/// 生成した allow の module の `pub type Actor { .. }` の構成子の行。
fn actor_variants(generated: List(File), path: String) -> List(String) {
  case
    list.find(generated, fn(file) { file.path == "src/" <> path <> ".gleam" })
  {
    Error(_) -> []
    Ok(file) ->
      case string.split_once(file.text, "pub type Actor {\n") {
        Error(_) -> []
        Ok(#(_, rest)) ->
          case string.split_once(rest, "\n}") {
            Ok(#(block, _)) ->
              string.split(block, "\n")
              |> list.map(string.trim)
              |> list.filter(fn(line) { line != "" })
            Error(_) -> []
          }
      }
  }
}

fn bool(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

// ── 読み ────────────────────────────────────────────────────────────────────

fn reads_text(app: App, queries: List(#(String, String))) -> String {
  let generated =
    app.services
    |> list.flat_map(fn(service) {
      service.queries
      |> list.filter(fn(query) {
        !storage.in_object_named(app, query.select.from)
      })
      |> list.map(fn(query) { read_row(app, queries, service, query) })
    })
  let manual =
    list.map(app.server.reads, fn(read) {
      " '"
      <> read.service
      <> "/"
      <> read.query
      <> "':{hook:"
      <> camel(read.hook)
      <> "},\n"
    })
  string.concat(list.append(generated, manual))
}

fn read_row(
  app: App,
  queries: List(#(String, String)),
  service: Service,
  query: model.NamedQuery,
) -> String {
  let key = service.module <> "/" <> query.name
  let args =
    typing.params(app, query.select)
    |> list.map(fn(param) { "[" <> arg_kind(param.ty) <> "]" })
  let allow = case list.key_find(queries, key) {
    Ok(text) -> allow_contract(text)
    Error(_) -> []
  }
  let #(out, keyset) = out_shape(app, query)
  " '"
  <> key
  <> "':{key:"
  <> quoted(key)
  <> ",args:["
  <> string.join(args, ",")
  <> "],allow:["
  <> string.join(list.map(allow, quoted), ",")
  <> "],out:"
  <> out
  <> case keyset {
    Some(text) -> ",keyset:" <> text
    None -> ""
  }
  <> "},\n"
}

fn arg_kind(ty: typing.Ty) -> String {
  case ty {
    typing.TyRef(Some("framework/page"), "Cursor") -> quoted("cursor")
    typing.TyApp(typing.TyRef(Some("gleam/option"), "Option"), [inner]) ->
      case inner {
        typing.TyRef(Some("framework/page"), "Cursor") -> quoted("cursor")
        _ -> arg_kind(inner)
      }
    typing.TyApp(typing.TyRef(None, "List"), _) -> quoted("json")
    typing.TyRef(Some("framework/secret"), "Secret") -> quoted("secret")
    // pgvector の穴は JSON の配列の綴り(`[0.1,..]`)で渡す
    typing.TyRef(Some("framework/vector"), _) -> quoted("json")
    typing.TyRef(Some(path), _) ->
      case string.starts_with(path, "gen/types/") {
        True -> quoted("enc") <> "," <> quoted(string.drop_start(path, 10))
        False -> quoted("enc")
      }
    _ -> quoted("enc")
  }
}

/// `-- allow: clauses=$2 party=$3 subject=$4` を穴の順に。
fn allow_contract(text: String) -> List(String) {
  string.split(text, "\n")
  |> list.find_map(fn(line) {
    case string.split_once(line, "-- allow:") {
      Ok(#(_, rest)) ->
        Ok(
          string.split(string.trim(rest), " ")
          |> list.filter_map(fn(pair) {
            case string.split_once(pair, "=$") {
              Ok(#(name, place)) ->
                case int.parse(place) {
                  Ok(number) -> Ok(#(number, name))
                  Error(_) -> Error(Nil)
                }
              Error(_) -> Error(Nil)
            }
          })
          |> list.sort(fn(left, right) { int.compare(left.0, right.0) })
          |> list.map(fn(pair) { pair.1 }),
        )
      Error(_) -> Error(Nil)
    }
  })
  |> option.from_result
  |> option.unwrap([])
}

fn entity_items(
  app: App,
  name: String,
  path: option.Option(String),
) -> List(String) {
  let at = case path {
    Some(label) -> "," <> quoted(label)
    None -> ""
  }
  case model.entity_by_name(app.entities, name) {
    Some(entity) ->
      case entity.phases {
        [] -> ["['entity'," <> quoted(entity.module) <> at <> "]"]
        _ -> [
          "['entity'," <> quoted(entity.module) <> at <> "]",
          "['phase'," <> quoted(entity.module) <> at <> "]",
        ]
      }
    None -> []
  }
}

fn tuple_of(items: List(String)) -> String {
  case items {
    [single] -> single
    _ -> "['tuple',[" <> string.join(items, ",") <> "]]"
  }
}

fn value_item(ty: typing.Ty, label: String) -> String {
  case ty {
    typing.TyApp(typing.TyRef(Some("gleam/option"), "Option"), [inner]) ->
      "['option'," <> value_item(inner, label) <> "," <> quoted(label) <> "]"
    typing.TyRef(None, "Int") -> "['int'," <> quoted(label) <> "]"
    typing.TyRef(None, "Float") -> "['number'," <> quoted(label) <> "]"
    typing.TyRef(None, "Bool") -> "['bool'," <> quoted(label) <> "]"
    typing.TyRef(None, "String") -> "['text'," <> quoted(label) <> "]"
    typing.TyRef(Some(path), _) ->
      case
        string.starts_with(path, "gen/types/"),
        string.starts_with(path, "entity/")
      {
        True, _ ->
          "['value',"
          <> quoted(string.drop_start(path, 10))
          <> ","
          <> quoted(label)
          <> "]"
        _, True ->
          "['sum',"
          <> quoted(string.drop_start(path, 7))
          <> ","
          <> quoted(label)
          <> "]"
        _, _ -> "['text'," <> quoted(label) <> "]"
      }
    _ -> "['text'," <> quoted(label) <> "]"
  }
}

fn out_shape(
  app: App,
  query: model.NamedQuery,
) -> #(String, option.Option(String)) {
  let select = query.select
  case select.group, select.agg {
    [], [] -> {
      let base = entity_items(app, select.from, None)
      let joined =
        list.flat_map(select.join, fn(arrow_name) {
          case relation.join_arrow(app, arrow_name) {
            Ok(arrow) ->
              entity_items(app, arrow.target_entity, Some(arrow.prop))
            Error(_) -> []
          }
        })
      let children =
        typing.with_types(app, select)
        |> list.map(fn(pair) {
          let child = case pair.1 {
            typing.TyApp(_, [typing.TyRef(Some(path), _)]) ->
              "['entity'," <> quoted(string.drop_start(path, 7)) <> "]"
            _ -> "['text','x']"
          }
          "['children'," <> child <> "," <> quoted(pair.0) <> "]"
        })
      let along = case select.along {
        [] -> []
        _ -> ["['number','distance']"]
      }
      let item = tuple_of(list.flatten([base, joined, children, along]))
      case select.limit {
        model.LPaged(..) -> #(
          "['page'," <> item <> "]",
          Some(keyset(app, select)),
        )
        model.LFirst(1) -> #("['option'," <> item <> "]", None)
        _ -> #("['list'," <> item <> "]", None)
      }
    }
    [], aggs -> {
      let items = list.map(aggs, fn(agg) { agg_item(app, agg) })
      #("['one'," <> tuple_of(items) <> "]", None)
    }
    groups, aggs -> {
      let group_items =
        list.map(groups, fn(group) {
          case group {
            model.GByField(field) -> {
              let label = field_column(app, field)
              let base = typing.field_base(app, field)
              case typing.field_optional(app, field) {
                True ->
                  "['option',"
                  <> value_item(base, label)
                  <> ","
                  <> quoted(label)
                  <> "]"
                False -> value_item(base, label)
              }
            }
            _ -> "['text','group']"
          }
        })
      let items = list.map(aggs, fn(agg) { agg_item(app, agg) })
      #("['list'," <> tuple_of(list.append(group_items, items)) <> "]", None)
    }
  }
}

fn agg_item(app: App, agg: model.Agg) -> String {
  case agg {
    model.ACount -> "['number','count']"
    model.ASum(_) -> value_item(typing.agg_ty(app, agg), "sum")
    model.AMin(_) -> value_item(typing.agg_ty(app, agg), "min")
    model.AMax(_) -> value_item(typing.agg_ty(app, agg), "max")
    model.AAvg(_) -> value_item(typing.agg_ty(app, agg), "avg")
  }
}

fn field_column(app: App, field_name: String) -> String {
  app.entities
  |> list.find_map(fn(entity) {
    list.find(entity.fields, fn(field) { field.name == field_name })
  })
  |> fn(found) {
    case found {
      Ok(field) -> field.column
      Error(_) -> naming.snake(field_name)
    }
  }
}

fn column_kind(app: App, field_name: String) -> String {
  case typing.field_base(app, field_name) {
    typing.TyRef(Some("framework/time"), "Datetime") -> "timestamptz"
    typing.TyRef(Some("framework/time"), "Date") -> "date"
    _ -> "value"
  }
}

fn keyset(app: App, select: model.Select) -> String {
  let size = case select.limit {
    model.LPaged(size: model.OpNum(size), ..) -> size
    _ -> 20
  }
  let directions =
    list.filter_map(select.order, fn(order) {
      case order {
        model.OAsc(field) -> Ok(#(field, "ASC"))
        model.ODesc(field) -> Ok(#(field, "DESC"))
        _ -> Error(Nil)
      }
    })
  let uniform =
    list.length(list.unique(list.map(directions, fn(pair) { pair.1 }))) == 1
  let key_column = case model.entity_by_name(app.entities, select.from) {
    Some(entity) -> entity.key_column
    None -> "id"
  }
  let columns =
    list.append(
      list.map(directions, fn(pair) {
        "["
        <> quoted(field_column(app, pair.0))
        <> ","
        <> quoted(column_kind(app, pair.0))
        <> "]"
      }),
      ["[" <> quoted(key_column) <> ",'value']"],
    )
  "{size:"
  <> int.to_string(size)
  <> ",uniform:"
  <> bool(uniform)
  <> ",columns:["
  <> string.join(columns, ",")
  <> "]}"
}

// ── outbox ──────────────────────────────────────────────────────────────────

fn outbox_text(app: App, units: List(Unit), kinds: List(String)) -> String {
  let versioned = fn(kind) {
    case list.find(app.services, fn(service) { service.module == kind }) {
      Ok(service) ->
        case service.args {
          [_, model.Arg(name: "version", ..), ..] -> True
          _ -> False
        }
      Error(_) -> False
    }
  }
  let send_connectors =
    app.server.connectors
    |> list.filter(fn(connector) {
      list.any(connector.ports, fn(port) {
        case port {
          model.SendPort(..) -> True
          _ -> False
        }
      })
    })
    |> list.map(fn(connector) { "gen/connector/" <> connector.name })
  let boundaries =
    list.filter(kinds, fn(kind) {
      let source = case
        list.find(units, fn(unit) { unit.path == "service/" <> kind })
      {
        Ok(unit) -> unit.text
        Error(_) -> ""
      }
      list.any(send_connectors, fn(path) {
        string.contains(source, "import " <> path)
        || string.contains(source, "import " <> string.drop_start(path, 4))
      })
    })
  string.concat([
    "const folds={\n",
    list.map(kinds, fn(kind) {
      case versioned(kind) {
        True -> " " <> kind <> ":v=>({id:v.id,version:v.version}),\n"
        False -> " " <> kind <> ":(v,root)=>({id:v?.id??rootKey(root)}),\n"
      }
    })
      |> string.concat,
    "};\n",
    "const enqueues={\n",
    list.map(kinds, fn(kind) {
      case versioned(kind) {
        True -> " " <> kind <> ":v=>({id:v[0],version:v[1]}),\n"
        False -> " " <> kind <> ":v=>({id:v}),\n"
      }
    })
      |> string.concat,
    "};\n",
    "const boundaries=new Set([",
    string.join(list.map(boundaries, quoted), ","),
    "]);\n",
    "function rootKey(root) {\n const first=Object.values(root??{})[0];\n return c.text(first?.id);\n}\n",
  ])
}

// ── 表の残り ────────────────────────────────────────────────────────────────

fn tables_text(app: App, used_hooks: List(String)) -> String {
  let modules =
    app.entities
    |> list.map(fn(entity) { entity.module })
    |> list.sort(string.compare)
  let decode_hooks =
    app.server.hooks
    |> list.filter_map(fn(hook) {
      case string.starts_with(hook.name, "decode_") {
        True -> Ok(string.drop_start(hook.name, 7))
        False -> Error(Nil)
      }
    })
  let decoded =
    list.append(modules, decode_hooks)
    |> list.unique
  let subjects =
    app.entities
    |> list.filter(fn(entity) { entity.subject })
    |> list.map(fn(entity) { quoted(entity.module) })
  let drafts =
    verb.runtime_table(app)
    |> list.filter_map(fn(row) {
      case string.split(row.1, "created:['") {
        [_, rest] ->
          case string.split(rest, "'") {
            [module, ..] -> Ok(module)
            _ -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    })
    |> list.unique
  let encoders =
    list.filter_map(used_hooks, fn(name) {
      case string.starts_with(name, "encode_") {
        True -> Ok(string.drop_start(name, 7) <> ":" <> camel(name))
        False -> Error(Nil)
      }
    })
  string.concat([
    "const relationDecoders={",
    list.map(decoded, fn(module) {
      module <> ":c.decode" <> naming.pascal(module)
    })
      |> string.join(","),
    "};\n",
    "const phaseModules={",
    list.map(modules, fn(module) { module <> ":c." <> camel(module) })
      |> string.join(","),
    "};\n",
    "const drafts={",
    list.map(drafts, fn(module) { module <> ":draft_" <> module })
      |> string.join(","),
    "};\n",
    "const subjects=[",
    string.join(subjects, ","),
    "];\n",
    "const encoders={",
    string.join(encoders, ","),
    "};\n",
    "const carried={\n",
    carried_text(app),
    "};\n",
  ])
}

/// root に載せる値(`Carried`)。browser / party / subject は入口が運ぶ値、それ以外は root の 1 文が
/// 畳んで持つ列(`List(<module>.<Type>)` は子の行の列)。
fn carried_text(app: App) -> String {
  app.server.roots
  |> list.filter_map(fn(shape) {
    case shape {
      model.Carried(name: name, type_: type_, ..) -> Ok(#(name, type_))
      _ -> Error(Nil)
    }
  })
  |> list.unique
  |> list.map(fn(pair) {
    let #(name, type_) = pair
    let body = case name {
      "browser" -> "s=>c.parse('browser_id',s.browser.id)"
      "party" ->
        "s=>c.option(s.resolved?.party??null,p=>c.checked(c.party.parse(p)))"
      "subject" ->
        "s=>c.option(s.resolved?.subject_kind?new subject[s.resolved.subject_kind[0].toUpperCase()+s.resolved.subject_kind.slice(1)]():null)"
      _ ->
        case string.starts_with(type_, "List(") {
          True -> {
            let inner = string.drop_start(type_, 5) |> string.drop_end(1)
            let module = case string.split_once(inner, ".") {
              Ok(#(found, _)) -> found
              Error(_) -> naming.snake(inner)
            }
            "s=>{const raw=s.row?."
            <> name
            <> ";return c.toList((typeof raw==='string'?JSON.parse(raw):(raw??[])).map(r=>relationDecoders."
            <> module
            <> "(r)));}"
          }
          False ->
            case string.starts_with(type_, "Option(") {
              True -> {
                let inner = string.drop_start(type_, 7) |> string.drop_end(1)
                "s=>c.option(s.row?."
                <> name
                <> "??null,r=>relationDecoders."
                <> module_of(inner)
                <> "(typeof r==='string'?JSON.parse(r):r))"
              }
              False ->
                case string.contains(type_, ".") {
                  True ->
                    "s=>relationDecoders."
                    <> module_of(type_)
                    <> "(s.row?."
                    <> name
                    <> ")"
                  False -> "s=>s.row?." <> name
                }
            }
        }
    }
    " " <> name <> ":" <> body <> ",\n"
  })
  |> string.concat
}

fn module_of(qualified: String) -> String {
  case string.split_once(qualified, ".") {
    Ok(#(found, _)) -> found
    Error(_) -> naming.snake(qualified)
  }
}
