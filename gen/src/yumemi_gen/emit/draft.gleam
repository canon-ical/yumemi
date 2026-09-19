//// 束0 ── Entity の Property から `src/gen/draft/*.gleam` を出す。
//// key を除いた入力と、key を戻した作成結果を同じ Property 定義から組み立てる。

import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi_gen/emit/hash
import yumemi_gen/emit/render.{type Style, Style}
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/emit/typing
import yumemi_gen/model

pub fn emit(app: model.App, hashes: hash.Hashes) -> List(File) {
  app.entities
  |> list.sort(fn(left, right) { string.compare(left.module, right.module) })
  |> list.map(one(_, app, hashes))
}

fn one(entity: model.Entity, app: model.App, hashes: hash.Hashes) -> File {
  let aliases =
    list.map(app.entities, fn(other) {
      #("entity/" <> other.module, "entity_" <> other.module)
    })
  let style =
    Style(
      qualified: list.map(app.entities, fn(other) { "entity/" <> other.module }),
      aliases: aliases,
    )
  let draft_fields = fields(entity, app, False)
  let created_fields = fields(entity, app, True)
  let types =
    list.append(
      list.map(draft_fields, fn(field) { field.0 }),
      list.map(created_fields, fn(field) { field.0 }),
    )
  let imports = render.imports(style, types, [])
  File(
    path: "src/gen/draft/" <> entity.module <> ".gleam",
    text: string.concat([
      "//// GENERATED from entity.",
      entity.module,
      " [sha256:",
      hash.entity(hashes, entity.module),
      "] — 手で編集しない\n\n",
      imports,
      case imports {
        "" -> "\n"
        _ -> "\n\n"
      },
      declaration(entity.name <> "Draft", draft_fields, style),
      "\n",
      declaration(entity.name <> "Created", created_fields, style),
    ]),
  )
}

fn fields(
  entity: model.Entity,
  app: model.App,
  include_key: Bool,
) -> List(#(typing.Ty, String)) {
  entity.props
  |> list.filter_map(fn(prop) {
    case include_key || !list.contains(entity.key_props, prop.name) {
      False -> Error(Nil)
      True ->
        case model.field_for_prop(entity, prop.name) {
          None ->
            case prop.kind {
              model.RelProp(kind: model.Multi, ..) -> Error(Nil)
              _ -> Ok(#(wrapped_prop_type(prop), prop.name))
            }
          Some(field) -> Ok(#(wrapped(field, prop, app), prop.name))
        }
    }
  })
}

fn wrapped_prop_type(prop: model.Prop) -> typing.Ty {
  let base = case prop.kind {
    model.ValueProp(reference) -> typing.type_ref(reference)
    model.SumProp(reference, ..) -> typing.type_ref(reference)
    model.RelProp(target_module: target_module, target_type: target_type, ..) ->
      typing.key_of(typing.TyRef(Some("entity/" <> target_module), target_type))
  }
  wrap(base, prop.optional, prop.repeated)
}

fn wrapped(
  field: model.FieldDef,
  prop: model.Prop,
  app: model.App,
) -> typing.Ty {
  wrap(typing.field_base(app, field.name), prop.optional, prop.repeated)
}

fn wrap(base: typing.Ty, optional: Bool, repeated: Bool) -> typing.Ty {
  let repeated = case repeated {
    True -> typing.list_of(base)
    False -> base
  }
  case optional {
    True -> typing.option(repeated)
    False -> repeated
  }
}

fn declaration(
  name: String,
  fields: List(#(typing.Ty, String)),
  style: Style,
) -> String {
  case fields {
    [] -> "pub type " <> name <> " {\n  " <> name <> "\n}\n"
    _ ->
      string.concat([
        "pub type ",
        name,
        " {\n  ",
        name,
        "(\n",
        fields
          |> list.map(fn(field) {
            "    " <> field.1 <> ": " <> render.ty(style, field.0) <> ",\n"
          })
          |> string.concat,
        "  )\n}\n",
      ])
  }
}
