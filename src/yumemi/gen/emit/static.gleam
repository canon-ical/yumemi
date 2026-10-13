//// back の静的資料を、front-4 と同じ public 名で面 package に写す。

import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import yumemi/gen/emit/types.{type File, File}
import yumemi/gen/markdown
import yumemi/gen/source
import yumemi/gen/static_source.{type Host, type Present, type Sources}

pub fn emit(face: String, sources: Sources) -> List(File) {
  [
    File(
      path: face <> "/src/gen/external.gleam",
      text: external_text(sources.app_name, sources.hosts, sources.hosts_hash),
    ),
    File(
      path: face <> "/src/gen/doc/api_v1.gleam",
      text: api_v1_text(sources.api_v1, sources.api_v1_hash),
    ),
  ]
}

/// `static_source.load_present` の読んだ file の写しだけを出す(0.13.1、穴 2)。`api_v1` は面の
/// `style` module の `body`・`ink`・`heading` を名指しする ── 面がその 3 つを持たなければ class を付けない形で出す。
pub fn emit_present(
  face: String,
  present: Present,
  units: List(source.Unit),
) -> List(File) {
  let external = case present.hosts {
    Some(hosts) -> [
      File(
        path: face <> "/src/gen/external.gleam",
        text: external_text(present.app_name, hosts.hosts, hosts.hash),
      ),
    ]
    None -> []
  }
  let api_v1 = case present.api_v1 {
    Some(document) -> {
      let text = api_v1_text(document.text, document.hash)
      [
        File(
          path: face <> "/src/gen/doc/api_v1.gleam",
          text: case has_style_names(units) {
            True -> text
            False -> without_style(text)
          },
        ),
      ]
    }
    None -> []
  }
  list.append(external, api_v1)
}

/// 面の `src/style.gleam` が `body`・`ink`・`heading` を pub の const か fn で持つか。
fn has_style_names(units: List(source.Unit)) -> Bool {
  case list.find(units, fn(unit) { unit.path == "style" }) {
    Ok(unit) -> {
      let names =
        list.append(
          list.filter_map(unit.module.constants, fn(definition) {
            case definition.definition.publicity {
              glance.Public -> Ok(definition.definition.name)
              glance.Private -> Error(Nil)
            }
          }),
          list.filter_map(unit.module.functions, fn(definition) {
            case definition.definition.publicity {
              glance.Public -> Ok(definition.definition.name)
              glance.Private -> Error(Nil)
            }
          }),
        )
      list.all(["body", "ink", "heading"], list.contains(names, _))
    }
    Error(_) -> False
  }
}

fn without_style(text: String) -> String {
  text
  |> string.replace("import style\n", "")
  |> string.replace("css.class([style.body, style.ink])", "css.class([])")
  |> string.replace("css.class([style.heading, style.ink])", "css.class([])")
}

pub fn external_text(
  app_name: String,
  hosts: List(Host),
  input_hash: String,
) -> String {
  let host_rows = hosts |> list.map(host_text) |> string.join("\n")
  "//// GENERATED from "
  <> app_name
  <> "/src/external_hosts.mjs [sha256:"
  <> input_hash
  <> "] — 手で編集しない\n\n"
  <> "pub type Side {\n  Browser\n  Server\n}\n\n"
  <> "pub type Host {\n"
  <> "  Host(\n"
  <> "    connector: String,\n"
  <> "    host: String,\n"
  <> "    name: String,\n"
  <> "    information: String,\n"
  <> "    purpose: String,\n"
  <> "    side: Side,\n"
  <> "  )\n"
  <> "}\n\n"
  <> "pub const hosts: List(Host) = [\n"
  <> host_rows
  <> "\n]\n"
}

pub fn api_v1_text(source: String, input_hash: String) -> String {
  let document = case markdown.parse(source) {
    Ok(value) -> value
    Error(_) -> panic as "docs/api-v1.md contains unsupported Markdown syntax"
  }
  let helpers = markdown.helpers(document)
  let list_import = case string.contains(helpers, "list.map") {
    True -> "import gleam/list\n"
    False -> ""
  }
  "//// GENERATED from docs/api-v1.md [sha256:"
  <> input_hash
  <> "] — 手で編集しない\n\n"
  <> "import yumemi/front/css\n"
  <> "import yumemi/front/el\n"
  <> "import yumemi/front/html\n"
  <> list_import
  <> "import style\n\n"
  <> "pub fn nodes() -> List(el.Element) {\n"
  <> "  [\n"
  <> string.join(list.map(document.nodes, fn(node) { "    " <> node }), ",\n")
  <> "\n  ]\n}\n\n"
  <> helpers
  <> "\n"
  <> string.join(document.tables, "\n\n")
}

fn host_text(host: Host) -> String {
  "  Host(\n"
  <> "    connector: "
  <> string.inspect(host.connector)
  <> ",\n"
  <> "    host: "
  <> string.inspect(host.host)
  <> ",\n"
  <> "    name: "
  <> string.inspect(host.name)
  <> ",\n"
  <> "    information: "
  <> string.inspect(host.information)
  <> ",\n"
  <> "    purpose: "
  <> string.inspect(host.purpose)
  <> ",\n"
  <> "    side: "
  <> side_text(host.side)
  <> ",\n"
  <> "  ),"
}

fn side_text(side: String) -> String {
  case side {
    "browser" -> "Browser"
    _ -> "Server"
  }
}
