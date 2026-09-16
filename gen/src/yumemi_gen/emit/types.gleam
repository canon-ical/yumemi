//// 束1 ── `src/gen/types/*.gleam`。types.gleam の `Spec` 1つにつき1 module。
//// Range だけ Int を包み、他は String を包む(framework/spec.validate の入口の型)。

import gleam/list
import gleam/string
import yumemi_gen/model.{type ValueType}

pub type File {
  File(path: String, text: String)
}

pub fn emit(types: List(ValueType), input_hash: String) -> List(File) {
  list.map(types, one(_, input_hash))
}

fn one(value: ValueType, input_hash: String) -> File {
  let text = case value.backing {
    model.IntValue -> int_module(value, input_hash)
    model.StringValue -> string_module(value, input_hash)
  }
  File(path: "src/gen/types/" <> value.name <> ".gleam", text: text)
}

fn header(value: ValueType, input_hash: String) -> String {
  "//// GENERATED from types."
  <> value.name
  <> " [sha256:"
  <> input_hash
  <> "] — 手で編集しない\n"
}

fn string_module(value: ValueType, input_hash: String) -> String {
  let name = value.type_name
  string.concat([
    header(value, input_hash),
    "\n",
    "import framework/spec\n",
    "import gleam/result\n",
    "import types\n",
    "\n",
    "pub opaque type ",
    name,
    " {\n",
    "  ",
    name,
    "(value: String)\n",
    "}\n",
    "\n",
    "pub fn parse(raw: String) -> Result(",
    name,
    ", spec.Error) {\n",
    "  spec.validate(raw, types.",
    value.name,
    ") |> result.map(",
    name,
    ")\n",
    "}\n",
    "\n",
    "pub fn to_string(value: ",
    name,
    ") -> String {\n",
    "  value.value\n",
    "}\n",
  ])
}

fn int_module(value: ValueType, input_hash: String) -> String {
  let name = value.type_name
  string.concat([
    header(value, input_hash),
    "\n",
    "import framework/spec\n",
    "import gleam/int\n",
    "import types\n",
    "\n",
    "pub opaque type ",
    name,
    " {\n",
    "  ",
    name,
    "(value: Int)\n",
    "}\n",
    "\n",
    "pub fn parse(raw: Int) -> Result(",
    name,
    ", spec.Error) {\n",
    "  case spec.validate(int.to_string(raw), types.",
    value.name,
    ") {\n",
    "    Ok(_) -> Ok(",
    name,
    "(raw))\n",
    "    Error(error) -> Error(error)\n",
    "  }\n",
    "}\n",
    "\n",
    "pub fn from_int(raw: Int) -> ",
    name,
    " {\n",
    "  let assert Ok(value) = parse(raw)\n",
    "  value\n",
    "}\n",
    "\n",
    "pub fn to_int(value: ",
    name,
    ") -> Int {\n",
    "  value.value\n",
    "}\n",
    "\n",
    "pub fn to_string(value: ",
    name,
    ") -> String {\n",
    "  int.to_string(value.value)\n",
    "}\n",
  ])
}
