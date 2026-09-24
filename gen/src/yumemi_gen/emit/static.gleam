//// back の静的資料を、front-4 と同じ public 名で面 package に写す。

import gleam/list
import gleam/string
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/static_source.{type Host, type Sources}

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
  "//// GENERATED from docs/api-v1.md [sha256:"
  <> input_hash
  <> "] — 手で編集しない\n\n"
  <> "import framework/front/el\n\n"
  <> "pub fn nodes() -> List(el.Element(Nil)) {\n"
  <> "  [el.text("
  <> string.inspect(source)
  <> ")]\n}\n"
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
