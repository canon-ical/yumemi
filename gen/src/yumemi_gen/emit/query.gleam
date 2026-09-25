//// 束2 ── 読みの語彙。3 module に割れる(2026-09-16 人見裁定)。
////   `src/gen/query/from.gleam`  ── From だけ
////   `src/gen/query/field.gleam` ── Field だけ
////   `src/gen/query.gleam`       ── 残り(Arrow / Operand / Cond / … / Select)と From / Field の型別名
//// From と Field を同じ module に置くと構成子の名前空間が衝突する(Entity `consent_version` の
//// From と Entity Consent の `version` 列が `ConsentVersion` で衝突し `Duplicate definition`)。
//// From / Field / Arrow / Operand は Entity 宣言から、残りは framework/query.gleam の
//// 構成子をそのまま単型に写す(アプリは語彙を足せない、20:664)。`Select` の `Pick` も
//// framework 側に同じ形で在る(役員 人見 09-25、1 対 1 は test が見る)。

import gleam/list
import gleam/string
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/model.{type App}

/// From を持つ module の道(アプリの import に出る)。
pub const from_module = "gen/query/from"

/// Field を持つ module の道。
pub const field_module = "gen/query/field"

pub fn emit(app: App, input_hash: String) -> List(File) {
  [
    File(
      path: "src/gen/query/from.gleam",
      text: string.concat([
        header(input_hash),
        "\n",
        block("From", from_variants(app)),
      ]),
    ),
    File(
      path: "src/gen/query/field.gleam",
      text: string.concat([
        header(input_hash),
        "\n",
        block("Field", field_variants(app)),
      ]),
    ),
    File(path: "src/gen/query.gleam", text: text(app, input_hash)),
  ]
}

fn header(input_hash: String) -> String {
  "//// GENERATED from entity declarations / named Select values [sha256:"
  <> input_hash
  <> "] — 手で編集しない\n"
}

fn entities_in_order(app: App) -> List(model.Entity) {
  list.sort(app.entities, fn(a, b) { string.compare(a.module, b.module) })
}

fn from_variants(app: App) -> List(String) {
  list.map(entities_in_order(app), fn(entity) { entity.name })
}

fn field_variants(app: App) -> List(String) {
  list.flat_map(entities_in_order(app), fn(entity) {
    list.map(entity.fields, fn(field) { field.name })
  })
}

/// 構成子は module ごとに1つの名前空間に並ぶ。割ったあとも同じ module の中で
/// 名前が重なりうる(Arrow と KeyOf、Field どうし)ので、module ごとに数えて報告する。
/// 20 は直し方を決めていないので、生成器は黙って直さない。
pub fn collisions(app: App) -> List(#(String, String)) {
  let lifecycles = list.filter(entities_in_order(app), model.has_lifecycle)
  let query_names =
    list.flatten([
      arrow_names(app),
      ["Param", "Num", "Str", "At", "Col"],
      list.map(lifecycles, fn(entity) { "PhaseOf" <> entity.name }),
      list.map(entities_in_order(app), fn(entity) { "KeyOf" <> entity.name }),
      cond_variants(),
      ["Count", "Sum", "Min", "Max", "Avg"],
      ["AggGt", "AggGe", "AggLt", "AggLe", "AggEq"],
      ["Day", "Week", "Month"],
      ["ByField", "Bucket", "Via"],
      ["Nearest", "Asc", "Desc", "AscAgg", "DescAgg"],
      ["Distance", "Rank", "Running"],
      ["NoLimit", "Paged", "First", "FirstPerGroup"],
      ["Select", "Pick"],
    ])
  list.flatten([
    duplicates(from_module, from_variants(app)),
    duplicates(field_module, field_variants(app)),
    duplicates("gen/query", query_names),
  ])
}

fn duplicates(module: String, names: List(String)) -> List(#(String, String)) {
  names
  |> list.filter(fn(name) {
    list.length(list.filter(names, fn(other) { other == name })) > 1
  })
  |> list.unique
  |> list.map(fn(name) { #(module, name) })
}

fn cond_variants() -> List(String) {
  [
    "CurrentVersion", "Eq", "Ne", "Lt", "Le", "Gt", "Ge", "In", "Contains",
    "IsNull", "NotNull", "IsTrue", "EqOrNull", "Has", "HasNone",
  ]
}

fn text(app: App, input_hash: String) -> String {
  let entities = entities_in_order(app)
  let lifecycles = list.filter(entities, model.has_lifecycle)
  let imports =
    list.flatten([
      list.map(entities, fn(entity) { "import entity/" <> entity.module }),
      [
        "import framework/er.{type Key}",
        "import framework/time.{type Datetime}",
        "import " <> field_module,
        "import " <> from_module,
        "import gleam/option.{type Option}",
      ],
    ])
  string.concat([
    header(input_hash),
    "\n",
    string.join(imports, "\n"),
    "\n\n",
    "/// From の実体は gen/query/from。名前空間を割るためだけに別 module にしてある。\n",
    "pub type From =\n  from.From\n",
    "\n",
    "/// Field の実体は gen/query/field。\n",
    "pub type Field =\n  field.Field\n",
    "\n",
    "/// 順向き(子 -> 親)は関係 Property 1 つにつき 1 本。末尾は `with:` に書かれた\n",
    "/// Held の逆向き(親 -> 子の List)。\n",
    block("Arrow", arrow_names(app)),
    "\n",
    block(
      "Operand(p)",
      list.flatten([
        ["Param(p)", "Num(Int)", "Str(String)", "At(Datetime)"],
        list.map(lifecycles, fn(entity) {
          "PhaseOf" <> entity.name <> "(" <> entity.module <> ".Phase)"
        }),
        list.map(entities, fn(entity) {
          "KeyOf"
          <> entity.name
          <> "(Key("
          <> entity.module
          <> "."
          <> entity.type_name
          <> "))"
        }),
        ["Col(Field)"],
      ]),
    ),
    "\n",
    block("Cond(p)", [
      "CurrentVersion(Field, Field)",
      "Eq(Field, Operand(p))",
      "Ne(Field, Operand(p))",
      "Lt(Field, Operand(p))",
      "Le(Field, Operand(p))",
      "Gt(Field, Operand(p))",
      "Ge(Field, Operand(p))",
      "In(Field, Operand(p))",
      "Contains(Field, Operand(p))",
      "IsNull(Field)",
      "NotNull(Field)",
      "IsTrue(Field)",
      "EqOrNull(Field, Operand(p))",
      "Has(Arrow, List(Cond(p)))",
      "HasNone(Arrow, List(Cond(p)))",
    ]),
    "\n",
    block("Agg", [
      "Count", "Sum(Field)", "Min(Field)", "Max(Field)", "Avg(Field)",
    ]),
    "\n",
    block("CondAgg(p)", [
      "AggGt(Agg, Operand(p))",
      "AggGe(Agg, Operand(p))",
      "AggLt(Agg, Operand(p))",
      "AggLe(Agg, Operand(p))",
      "AggEq(Agg, Operand(p))",
    ]),
    "\n",
    block("Unit", ["Day", "Week", "Month"]),
    "\n",
    block("Group", ["ByField(Field)", "Bucket(Field, Unit)", "Via(Arrow)"]),
    "\n",
    block("Order(p)", [
      "Nearest(Field, Operand(p))",
      "Asc(Field)",
      "Desc(Field)",
      "AscAgg(Agg)",
      "DescAgg(Agg)",
    ]),
    "\n",
    block("Along", [
      "Distance", "Rank(per: Option(Group))", "Running(Agg, per: Option(Group))",
    ]),
    "\n",
    block("Limit(p)", [
      "NoLimit",
      "Paged(size: Operand(p), after: Operand(p))",
      "First(Int)",
      "FirstPerGroup(Int, Group)",
    ]),
    "\n",
    "/// `Pick` は返す列を選ぶ口。`select` は `Select` を直に書き、行は選んだ列の record になる。\n",
    "/// `columns` に with の子の列を混ぜると、その子も選んだ列だけの record になる。\n",
    "pub type Select(p) {\n",
    "  Select(\n",
    "    from: From,\n",
    "    join: List(Arrow),\n",
    "    where: List(Cond(p)),\n",
    "    group: List(Group),\n",
    "    having: List(CondAgg(p)),\n",
    "    agg: List(Agg),\n",
    "    along: List(Along),\n",
    "    with: List(Arrow),\n",
    "    order: List(Order(p)),\n",
    "    limit: Limit(p),\n",
    "  )\n",
    "  Pick(columns: List(Field), select: Select(p))\n",
    "}\n",
  ])
}

/// Arrow の構成子。順向きのあとに逆向き。
fn arrow_names(app: App) -> List(String) {
  list.append(
    list.map(app.arrows, fn(arrow) { arrow.name }),
    list.map(app.reverse_arrows, fn(arrow) { arrow.name }),
  )
}

fn block(name: String, variants: List(String)) -> String {
  string.concat([
    "pub type ",
    name,
    " {\n",
    string.concat(list.map(variants, fn(variant) { "  " <> variant <> "\n" })),
    "}\n",
  ])
}
