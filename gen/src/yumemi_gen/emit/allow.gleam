//// `src/gen/allow/<module>.gleam`。root が `import gen/allow/<m> as allow` で指す先を生成物にする。
////
//// 名は ★ の用法に合わせる(`reader/allow`):
//// - `Who` / `Owner` は ★ の句に書かれた構成子。`Owner` は `NoOwner` を常に持つ
//// - `At` は `AnyPhase` と、phase があれば `Only(List(<entity>.Phase))`。phase の Entity は
////   ★ の `Only([...])` の要素の module、無ければ allow module と同名の Entity
//// - `Actor` は、この allow module を使う root のうち Actor が別名(`root.actor_is_sum`)の
////   Service の主体の和。Entity は `<Type>Actor(<entity>.<Type>)`、`Party` は
////   `AuthenticatedActor(party: PartyId)`、`System` は `SystemCaller`、最後に `AnyActor`
//// - 判定は ★ が呼ぶものだけ出す ── `is_self` / `is_<entity>` / `party_of`
////
//// 入力ハッシュは、この allow module を使う Service と `src/types.gleam` と `src/entity/*` 全部。

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import yumemi_gen/digest
import yumemi_gen/emit/root
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/model.{type App, type Entity}
import yumemi_gen/naming
import yumemi_gen/reader/allow.{type Usage} as allow_reader
import yumemi_gen/source.{type Unit}
import yumemi_gen/stop.{type Note, Note}

type Variant {
  EntityActor(module: String, type_name: String)
  AuthenticatedActor
  SystemCaller
  AnyActor
}

type Plan {
  Plan(
    module: String,
    path: String,
    usage: Usage,
    services: List(String),
    whos: List(String),
    owners: List(String),
    phase: Option(String),
    variants: List(Variant),
  )
}

pub fn emit(app: App, usages: List(Usage), units: List(Unit)) -> List(File) {
  list.map(paths(app, usages), fn(path) {
    let plan = plan(app, usages, path)
    File(path: "src/" <> path <> ".gleam", text: text(app, plan, units))
  })
}

pub fn notes(app: App, usages: List(Usage)) -> List(Note) {
  list.flat_map(paths(app, usages), fn(path) {
    plan_notes(app, plan(app, usages, path))
  })
}

fn paths(app: App, usages: List(Usage)) -> List(String) {
  list.append(
    list.map(app.services, root.allow_path),
    list.map(usages, fn(usage) { usage.path }),
  )
  |> list.unique
  |> list.sort(string.compare)
}

fn plan(app: App, usages: List(Usage), path: String) -> Plan {
  let module = last_segment(path)
  let usage = allow_reader.find(usages, path)
  let services =
    app.services
    |> list.filter(fn(service) { root.allow_path(service) == path })
  let sum_subjects =
    services
    |> list.filter(fn(service) { root.actor_is_sum(service.subjects) })
    |> list.flat_map(fn(service) { service.subjects })
    |> list.unique
  let whos = who_order(usage.whos)
  let owners =
    union(["NoOwner"], case list.contains(usage.owners, "Self") {
      True -> ["Self"]
      False -> []
    })
    |> union(
      list.filter(usage.owners, fn(owner) {
        owner != "NoOwner" && owner != "Self"
      }),
    )
  let phase = case usage.phase_modules {
    [first, ..] -> Some(first)
    [] ->
      case model.entity_by_module(app.entities, module) {
        Some(entity) ->
          case entity.phases {
            [] -> None
            _ -> Some(module)
          }
        None -> None
      }
  }
  Plan(
    module: module,
    path: path,
    usage: usage,
    services: union(
      list.map(services, fn(service) { service.module }),
      usage.services,
    ),
    whos: whos,
    owners: owners,
    phase: phase,
    variants: variants(whos, sum_subjects),
  )
}

fn who_order(whos: List(String)) -> List(String) {
  let fixed = ["Anyone", "Party", "System"]
  list.flatten([
    list.filter(["Anyone", "Party"], list.contains(whos, _)),
    list.filter(whos, fn(who) { !list.contains(fixed, who) }),
    list.filter(["System"], list.contains(whos, _)),
  ])
}

/// who の名が指す Entity module。reader.gleam の `who_subject` と同じ読み。
fn who_module(who: String) -> Option(String) {
  case who {
    "Anyone" | "Party" | "System" -> None
    _ ->
      case string.starts_with(who, "As") {
        True -> Some(naming.snake(string.drop_start(who, 2)))
        False -> Some(naming.snake(who))
      }
  }
}

fn variants(
  whos: List(String),
  subjects: List(model.Subject),
) -> List(Variant) {
  let entities =
    list.filter_map(subjects, fn(subject) {
      case subject {
        model.SubjectEntity(module: module, type_name: type_name) ->
          Ok(#(module, type_name))
        _ -> Error(Nil)
      }
    })
  let ordered =
    whos
    |> list.filter_map(fn(who) { option.to_result(who_module(who), Nil) })
    |> list.filter_map(fn(module) {
      list.key_find(entities, module) |> ok_pair(module)
    })
    |> list.unique
  let rest =
    list.filter(entities, fn(entity) { !list.contains(ordered, entity) })
  list.flatten([
    list.map(list.append(ordered, rest), fn(entity) {
      EntityActor(module: entity.0, type_name: entity.1)
    }),
    case list.contains(subjects, model.SubjectParty) {
      True -> [AuthenticatedActor]
      False -> []
    },
    case list.contains(subjects, model.SubjectSystem) {
      True -> [SystemCaller]
      False -> []
    },
    [AnyActor],
  ])
}

fn ok_pair(
  found: Result(String, Nil),
  module: String,
) -> Result(#(String, String), Nil) {
  case found {
    Ok(type_name) -> Ok(#(module, type_name))
    Error(_) -> Error(Nil)
  }
}

// ── 注記 ─────────────────────────────────────────────────────────────────────

fn plan_notes(app: App, plan: Plan) -> List(Note) {
  let where = "allow." <> plan.module
  list.flatten([
    list.flat_map(plan.owners, fn(owner) { owner_notes(app, where, owner) }),
    case plan.usage.phase_modules {
      [_, _, ..] as modules -> [
        Note(
          class: stop.Conflict,
          text: where
            <> ": Only の phase が複数の Entity に跨る: "
            <> string.join(modules, ", "),
        ),
      ]
      _ -> []
    },
    list.filter_map(plan.variants, fn(variant) {
      case variant {
        EntityActor(type_name: type_name, ..) ->
          case
            list.contains(
              ["Party", "System", "Authenticated", "Any"],
              type_name,
            )
          {
            True ->
              Ok(Note(
                class: stop.Conflict,
                text: where
                  <> ": Actor の variant "
                  <> type_name
                  <> "Actor が allow の固定の名と衝突する",
              ))
            False -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    }),
    case list.contains(plan.usage.calls, "is_self") {
      True -> is_self_notes(app, plan, where)
      False -> []
    },
  ])
}

fn owner_notes(app: App, where: String, owner: String) -> List(Note) {
  case owner {
    "NoOwner" | "Self" -> []
    _ ->
      case allow_reader.owner_entity(owner) {
        None -> [
          Note(
            class: stop.Vocabulary,
            text: where
              <> ": owner "
              <> owner
              <> " は NoOwner / Self / Via<Entity>Party のどれでもない",
          ),
        ]
        Some(type_name) ->
          case entity_by_type(app, type_name) {
            None -> [
              Note(
                class: stop.Conflict,
                text: where
                  <> ": owner "
                  <> owner
                  <> " の Entity "
                  <> type_name
                  <> " が無い",
              ),
            ]
            Some(entity) ->
              case party_prop(entity) {
                Some(_) -> []
                None -> [
                  Note(
                    class: stop.Conflict,
                    text: where
                      <> ": owner "
                      <> owner
                      <> " の Entity "
                      <> type_name
                      <> " に party 欄が無い",
                  ),
                ]
              }
          }
      }
  }
}

fn is_self_notes(app: App, plan: Plan, where: String) -> List(Note) {
  case model.entity_by_module(app.entities, plan.module) {
    None -> [
      Note(
        class: stop.NotImplemented,
        text: where <> ": is_self の比べる先の Entity " <> plan.module <> " が無い",
      ),
    ]
    Some(it) ->
      list.filter_map(plan.variants, fn(variant) {
        case variant {
          EntityActor(module: module, type_name: type_name) ->
            case self_arm(app, it, module) {
              SelfError(detail) ->
                Ok(Note(
                  class: stop.NotImplemented,
                  text: where
                    <> ": is_self の "
                    <> type_name
                    <> "Actor を比べられない("
                    <> detail
                    <> ")",
                ))
              _ -> Error(Nil)
            }
          _ -> Error(Nil)
        }
      })
  }
}

// ── 本文 ─────────────────────────────────────────────────────────────────────

fn text(app: App, plan: Plan, units: List(Unit)) -> String {
  let #(functions, function_imports) = functions(app, plan)
  let imports =
    list.flatten([
      ["framework/party.{type PartyId}"],
      case plan.phase {
        Some(module) -> ["entity/" <> module]
        None -> []
      },
      list.filter_map(plan.variants, fn(variant) {
        case variant {
          EntityActor(module: module, ..) -> Ok("entity/" <> module)
          _ -> Error(Nil)
        }
      }),
      function_imports,
    ])
    |> list.unique
    |> list.sort(string.compare)
  string.concat([
    "//// GENERATED from allow.",
    plan.module,
    " [sha256:",
    input_hash(plan, units),
    "] — 手で編集しない\n\n",
    list.map(imports, fn(path) { "import " <> path }) |> string.join("\n"),
    "\n\n",
    custom_type("Who", plan.whos),
    custom_type(
      "At",
      list.append(["AnyPhase"], case plan.phase {
        Some(module) -> ["Only(List(" <> module <> ".Phase))"]
        None -> []
      }),
    ),
    custom_type("Owner", plan.owners),
    custom_type("Clause", ["Clause(who: Who, at: At, owner: Owner)"]),
    string.concat(
      list.map(plan.usage.shorthands, fn(name) {
        "pub const "
        <> name
        <> ": Clause = Clause(who: "
        <> naming.pascal(name)
        <> ", at: AnyPhase, owner: NoOwner)\n\n"
      }),
    ),
    custom_type("PartyActor", ["PartyActor(party: PartyId)"]),
    custom_type("SystemActor", ["SystemActor"]),
    custom_type("Actor", list.map(plan.variants, variant_text)),
    "pub type AnyActor =\n  Actor\n",
    functions,
  ])
}

fn custom_type(name: String, variants: List(String)) -> String {
  case variants {
    [] -> "pub type " <> name <> "\n\n"
    _ ->
      "pub type "
      <> name
      <> " {\n"
      <> string.join(list.map(variants, fn(variant) { "  " <> variant }), "\n")
      <> "\n}\n\n"
  }
}

fn variant_text(variant: Variant) -> String {
  case variant {
    EntityActor(module: module, type_name: type_name) ->
      type_name <> "Actor(" <> module <> "." <> type_name <> ")"
    AuthenticatedActor -> "AuthenticatedActor(party: PartyId)"
    SystemCaller -> "SystemCaller"
    AnyActor -> "AnyActor"
  }
}

fn variant_pattern(variant: Variant, binding: String) -> String {
  case variant {
    EntityActor(type_name: type_name, ..) ->
      type_name <> "Actor(" <> binding <> ")"
    AuthenticatedActor -> "AuthenticatedActor(" <> binding <> ")"
    SystemCaller -> "SystemCaller"
    AnyActor -> "AnyActor"
  }
}

/// ★ が呼ぶ判定だけを、呼ばれた順に出す。
fn functions(app: App, plan: Plan) -> #(String, List(String)) {
  let parts =
    list.filter_map(plan.usage.calls, fn(name) {
      case name {
        "is_self" -> is_self(app, plan)
        "party_of" -> Ok(party_of(app, plan))
        _ ->
          case string.starts_with(name, "is_") {
            True -> Ok(is_entity(plan, string.drop_start(name, 3)))
            False -> Error(Nil)
          }
      }
    })
  #(
    string.concat(list.map(parts, fn(part) { "\n" <> part.0 })),
    list.flat_map(parts, fn(part) { part.1 }),
  )
}

type SelfArm {
  SelfArm(arm: String, imports: List(String))
  SelfError(detail: String)
  NotSelf
}

fn is_self(app: App, plan: Plan) -> Result(#(String, List(String)), Nil) {
  case model.entity_by_module(app.entities, plan.module) {
    None -> Error(Nil)
    Some(it) -> {
      let arms =
        list.filter_map(plan.variants, fn(variant) {
          case variant {
            EntityActor(module: module, ..) ->
              case self_arm(app, it, module) {
                SelfArm(arm: arm, imports: imports) ->
                  Ok(#(
                    "    " <> variant_pattern(variant, "value") <> " -> " <> arm,
                    imports,
                  ))
                _ -> Error(Nil)
              }
            _ -> Error(Nil)
          }
        })
      Ok(
        #(
          string.concat([
            "pub fn is_self(by: Actor, it: ",
            it.module,
            ".",
            it.type_name,
            ") -> Bool {\n  case by {\n",
            string.concat(list.map(arms, fn(arm) { arm.0 <> "\n" })),
            "    _ -> False\n  }\n}\n",
          ]),
          ["entity/" <> it.module, ..list.flat_map(arms, fn(arm) { arm.1 })],
        ),
      )
    }
  }
}

/// `it`(allow module の Entity)に対して、主体 `module` が本人か。
/// 同じ Entity なら key の欄を比べ、`Held(<主体>)` の欄を持つならその key と主体の key を比べる。
fn self_arm(app: App, it: Entity, module: String) -> SelfArm {
  case module == it.module, it.key_props {
    True, [] -> SelfError("Entity " <> module <> " に key が無い")
    True, keys ->
      SelfArm(
        arm: keys
          |> list.map(fn(key) { "value." <> key <> " == it." <> key })
          |> string.join(" && "),
        imports: [],
      )
    False, _ ->
      case
        list.find(it.props, fn(prop) {
          case prop.kind {
            model.RelProp(kind: model.Held, target_module: target, ..) ->
              target == module && !prop.optional && !prop.repeated
            _ -> False
          }
        })
      {
        Error(_) -> NotSelf
        Ok(prop) ->
          case model.entity_by_module(app.entities, module) {
            None -> SelfError("Entity " <> module <> " が無い")
            Some(actor) ->
              case key_string(actor, "value") {
                Ok(#(expression, imports)) ->
                  SelfArm(
                    arm: "er.to_string(er.of_held(it."
                      <> prop.name
                      <> ")) == "
                      <> expression,
                    imports: ["framework/er", ..imports],
                  )
                Error(detail) -> SelfError(detail)
              }
          }
      }
  }
}

/// 主体の key を文字列にする式。`er.Key` の文字列と比べるため。
fn key_string(
  entity: Entity,
  binding: String,
) -> Result(#(String, List(String)), String) {
  let field = binding <> "." <> entity.key_prop
  case entity.key_props, entity.key_type {
    [_], Some(model.NamedShape(module: Some(path), ..)) ->
      case string.starts_with(path, "gen/types/"), path {
        True, _ ->
          Ok(#(last_segment(path) <> ".to_string(" <> field <> ")", [path]))
        False, "framework/party" ->
          Ok(#("party.to_string(" <> field <> ")", []))
        False, _ -> Error("key の型 " <> path <> " を文字列にできない")
      }
    [_], Some(model.NamedShape(module: None, name: "String", ..)) ->
      Ok(#(field, []))
    [_], _ -> Error("key の型が読めない")
    _, _ -> Error("key が複数の欄")
  }
}

fn is_entity(plan: Plan, module: String) -> #(String, List(String)) {
  let found =
    list.find(plan.variants, fn(variant) {
      case variant {
        EntityActor(module: actor, ..) -> actor == module
        _ -> False
      }
    })
  case found {
    Ok(variant) -> #(
      string.concat([
        "pub fn is_",
        module,
        "(by: Actor) -> Bool {\n  case by {\n    ",
        variant_pattern(variant, "_"),
        " -> True\n    _ -> False\n  }\n}\n",
      ]),
      [],
    )
    Error(_) -> #(
      "pub fn is_" <> module <> "(_by: Actor) -> Bool {\n  False\n}\n",
      [],
    )
  }
}

fn party_of(app: App, plan: Plan) -> #(String, List(String)) {
  let arms =
    list.map(plan.variants, fn(variant) {
      case variant {
        EntityActor(module: module, ..) ->
          case
            option.then(
              model.entity_by_module(app.entities, module),
              party_prop,
            )
          {
            Some(prop) ->
              case prop.optional {
                True -> #(
                  variant_pattern(variant, "value") <> " -> value.party",
                  False,
                )
                False -> #(
                  variant_pattern(variant, "value") <> " -> Some(value.party)",
                  True,
                )
              }
            None -> #(variant_pattern(variant, "_") <> " -> None", False)
          }
        AuthenticatedActor -> #(
          variant_pattern(variant, "party") <> " -> Some(party)",
          True,
        )
        SystemCaller | AnyActor -> #(
          variant_pattern(variant, "_") <> " -> None",
          False,
        )
      }
    })
  let some = list.any(arms, fn(arm) { arm.1 })
  #(
    string.concat([
      "pub fn party_of(by: Actor) -> Option(PartyId) {\n  case by {\n",
      string.concat(list.map(arms, fn(arm) { "    " <> arm.0 <> "\n" })),
      "  }\n}\n",
    ]),
    [
      case some {
        True -> "gleam/option.{type Option, None, Some}"
        False -> "gleam/option.{type Option, None}"
      },
    ],
  )
}

fn party_prop(entity: Entity) -> Option(model.Prop) {
  case
    list.find(entity.props, fn(prop) { prop.name == "party" && !prop.repeated })
  {
    Ok(prop) -> Some(prop)
    Error(_) -> None
  }
}

fn entity_by_type(app: App, type_name: String) -> Option(Entity) {
  case list.find(app.entities, fn(entity) { entity.type_name == type_name }) {
    Ok(entity) -> Some(entity)
    Error(_) -> None
  }
}

// ── 入力ハッシュ ─────────────────────────────────────────────────────────────

/// この allow module を使う Service と、`src/types.gleam`・`src/entity/*` 全部。
/// `emit/hash` の `services` と同じ綴り方で、Service を束ねる口だけここに置く。
fn input_hash(plan: Plan, units: List(Unit)) -> String {
  units
  |> list.filter(fn(unit) {
    unit.path == "types"
    || string.starts_with(unit.path, "entity/")
    || list.contains(
      list.map(plan.services, fn(service) { "service/" <> service }),
      unit.path,
    )
  })
  |> list.sort(fn(left, right) { string.compare(left.path, right.path) })
  |> list.map(fn(unit) { unit.path <> "\n" <> unit.text })
  |> string.join("\n")
  |> digest.short
}

/// 初出の順を保った和。
fn union(left: List(String), right: List(String)) -> List(String) {
  list.unique(list.append(left, right))
}

fn last_segment(path: String) -> String {
  case list.last(string.split(path, "/")) {
    Ok(segment) -> segment
    Error(_) -> path
  }
}
