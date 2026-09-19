//// Lifecycle の辺から src/gen/phase.gleam を起こす。

import gleam/list
import gleam/string
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/model.{type App, type Entity}
import yumemi_gen/naming

pub fn emit(app: App, input_hash: String) -> List(File) {
  let entities =
    app.entities
    |> list.filter(fn(entity) { entity.edges != [] })
    |> list.sort(fn(left, right) { string.compare(left.module, right.module) })
  case entities {
    [] -> []
    _ -> [
      File(path: "src/gen/phase.gleam", text: text(entities, input_hash)),
    ]
  }
}

fn text(entities: List(Entity), input_hash: String) -> String {
  let imports =
    entities
    |> list.map(fn(entity) { "import entity/" <> entity.module })
    |> string.join("\n")
  string.concat([
    "//// GENERATED from entity declarations / edges [sha256:",
    input_hash,
    "] — 手で編集しない\n\n",
    imports,
    "\n\n",
    entities
      |> list.map(entity_text)
      |> string.join("\n"),
  ])
}

fn entity_text(entity: Entity) -> String {
  let variants =
    entity.edges
    |> list.map(fn(edge) {
      let #(from, to) = edge
      naming.pascal(from) <> "To" <> naming.pascal(to)
    })
  let from_cases =
    list.map2(entity.edges, variants, fn(edge, variant) {
      let #(from, _) = edge
      "    " <> variant <> " -> " <> entity.module <> "." <> from
    })
    |> string.join("\n")
  let to_cases =
    list.map2(entity.edges, variants, fn(edge, variant) {
      let #(_, to) = edge
      "    " <> variant <> " -> " <> entity.module <> "." <> to
    })
    |> string.join("\n")
  string.concat([
    "pub type ",
    entity.name,
    "Step {\n",
    variants |> list.map(fn(variant) { "  " <> variant }) |> string.join("\n"),
    "\n}\n\n",
    "pub fn ",
    entity.module,
    "_from(step: ",
    entity.name,
    "Step) -> ",
    entity.module,
    ".Phase {\n",
    "  case step {\n",
    from_cases,
    "\n  }\n}\n\n",
    "pub fn ",
    entity.module,
    "_to(step: ",
    entity.name,
    "Step) -> ",
    entity.module,
    ".Phase {\n",
    "  case step {\n",
    to_cases,
    "\n  }\n}\n",
  ])
}
