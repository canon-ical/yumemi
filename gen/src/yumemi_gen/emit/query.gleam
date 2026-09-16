//// 束2 ── `src/gen/query.gleam`。読みの語彙。
//// From / Field / Arrow / Operand は Entity 宣言から、残りは framework/query.gleam の
//// 構成子をそのまま単型に写す(アプリは語彙を足せない、20:664)。

import gleam/list
import gleam/string
import yumemi_gen/emit/types.{type File, File}
import yumemi_gen/model.{type App}
import yumemi_gen/naming

pub fn emit(app: App) -> List(File) {
  [File(path: "src/gen/query.gleam", text: text(app))]
}

fn text(app: App) -> String {
  let entities = list.sort(app.entities, fn(a, b) { string.compare(a.module, b.module) })
  let lifecycles = list.filter(entities, model.has_lifecycle)
  let imports =
    list.flatten([
      list.map(entities, fn(entity) { "import entity/" <> entity.module }),
      [
        "import framework/er.{type Key}",
        "import framework/time.{type Datetime}",
        "import gleam/option.{type Option}",
      ],
    ])
  string.concat([
    "//// GENERATED from entity declarations / named Select values — 手で編集しない\n",
    "\n",
    string.join(imports, "\n"),
    "\n\n",
    block("From", list.map(entities, fn(entity) { entity.name })),
    "\n",
    block(
      "Field",
      list.flat_map(entities, fn(entity) {
        list.map(entity.fields, fn(field) { field.name })
      }),
    ),
    "\n",
    block("Arrow", list.map(app.arrows, fn(arrow) { arrow.name })),
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
      "Distance", "Rank(per: Option(Group))",
      "Running(Agg, per: Option(Group))",
    ]),
    "\n",
    block("Limit(p)", [
      "NoLimit",
      "Paged(size: Operand(p), after: Operand(p))",
      "First(Int)",
      "FirstPerGroup(Int, Group)",
    ]),
    "\n",
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
    "}\n",
  ])
}

fn block(name: String, variants: List(String)) -> String {
  let _ = naming.pascal
  string.concat([
    "pub type ",
    name,
    " {\n",
    string.concat(list.map(variants, fn(variant) { "  " <> variant <> "\n" })),
    "}\n",
  ])
}
