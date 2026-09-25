//// 0.11.2(yumemi-fix-0112)── 生成の live の Args の encode(H1)、GET の Args の query(H2)、
//// 読みの別名の `import service/*` の推移(H3)。

import glance
import gleam/list
import gleam/string
import gleeunit/should
import yumemi_gen/emit/back
import yumemi_gen/emit/front as front_emit
import yumemi_gen/emit/hash
import yumemi_gen/face
import yumemi_gen/reader
import yumemi_gen/reader/front as reader_front
import yumemi_gen/source

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

fn replace(
  units: List(source.Unit),
  extra: List(source.Unit),
) -> List(source.Unit) {
  let paths = list.map(extra, fn(item) { item.path })
  list.append(
    list.filter(units, fn(item) { !list.contains(paths, item.path) }),
    extra,
  )
}

/// `article_publish`(POST)に Bool / Int / Float / Option(Int) の Args、`article_read`(GET、path の穴 `slug`)に
/// String / Bool / Option(String) の Args を足した fixture。
const publish_source = "//// Service publish ── 下書きを公開する。1 module 1 Service。
//// オーナーが読むのはこのファイル。ここに書かれていない判断は実装に存在しない。

// ★ src/service/article_publish.gleam
import entity/article
import entity/staff
import framework/effect.{type Effect, Write}
import framework/step.{type Start, type Step}
import gen/allow/article as allow
import gen/face.{type Face, Admin, Public}
import gen/phase
import gen/root/article_publish.{type Root, type Service, Service}
import gen/types/slug.{type Slug}
import gen/verb
import gleam/option.{type Option}

pub const effect: Effect = Write

pub const faces: List(Face) = [Public, Admin]

/// 引数。root Entity の識別子と同じ Type のフィールドが URL に乗る。
pub type Args {
  Args(slug: Slug, pinned: Bool, rank: Int, weight: Float, note: Option(Int))
}

/// 業務エラー。variant 名がそのまま全入口のエラーコードになる。
pub type Error {
  AlreadyPublished
  AlreadyRetracted
}

pub const service: Service(Args, article.Article, Error) = Service(
  allow: [allow.staff],
  logic: logic,
)

/// 主体・root・引数 → 手順書。root(この slug の記事)は framework が読んで渡す ──
/// 居なければ Logic に届く前に「不在」。フェーズも `it.phase` に入っている。
/// allow が Staff だけなので、生成器は第1引数を staff.Staff に絞る(sum を case で割る必要が無い)。
pub fn logic(
  _by: staff.Staff,
  it: Root,
  _args: Args,
) -> Step(article.Article, Error, Start) {
  case it.phase {
    article.Draft -> {
      use _ <- step.apply(verb.advance_article(
        it.article.slug,
        phase.ArticleDraftToPublished,
      ))
      step.done(it.article)
    }
    article.Published -> step.fail(AlreadyPublished)
    article.Retracted -> step.fail(AlreadyRetracted)
  }
}
"

const read_source = "//// Service read ── 記事を1件読む。一般に見えるのは Published だけ。下書きと取り下げ済みは Staff にしか見えない。

// ★ src/service/article_read.gleam
import entity/article
import entity/category
import entity/tag
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/allow/article as allow
import gen/face.{type Face, Admin, Public}
import gen/reads/article_read as reads
import gen/root/article_read.{type Actor, type Root, type Service, Service}
import gen/types/slug.{type Slug}
import gleam/option.{type Option, None}

pub const effect: Effect = Read

pub const faces: List(Face) = [Public, Admin]

pub type Args {
  Args(slug: Slug, q: String, pinned: Bool, since: Option(String))
}

pub type PageTheme {
  PageTheme(
    background: Option(String),
    background_image: Option(String),
    text: Option(String),
    accent: Option(String),
  )
}

/// 返す形。ここが入口の契約(JSON / MCP の output schema)の正本になる。
pub type Out {
  Out(
    article: article.Article,
    category: category.Category,
    tags: List(tag.Tag),
    theme: Option(PageTheme),
  )
}

/// 業務上の失敗が無い Service は構成子ゼロの型で書く ── 「失敗しない」が型で言える。
pub type Error

pub const service: Service(Args, Out, Error) = Service(
  allow: [
    allow.staff,
    allow.Clause(
      who: allow.Anyone,
      at: allow.Only([article.Published]),
      owner: allow.NoOwner,
    ),
  ],
  logic: logic,
)

/// allow に Staff と Anyone が混じるので、第1引数はこの Service 用に生成された
/// Actor sum(`Anonymous | AsStaff(staff.Staff)`)になる。allow に無い主体は variant に無い。
/// 矢印を辿る read は root 相対に生成された関数(`gen/reads/article_read`)── 存在しない矢印は関数が無い。
pub fn logic(_by: Actor, it: Root, _args: Args) -> Step(Out, Error, Start) {
  use category <- reads.to_category(it)
  use tags <- reads.to_tags(it)
  step.done(Out(article: it.article, category: category, tags: tags, theme: None))
}
"

const read_component = "
import framework/front
import framework/front/live as front_live
import gen/live/article_read
import gen/service
import lustre

pub const calls: List(front.Target(service.Service, Nil)) = [
  front.Of(service.ArticleRead),
]

pub const after_send: front_live.After = front_live.Stay

pub fn app() -> lustre.App(Nil, article_read.State, article_read.Event) {
  todo
}
"

const list_component = "
import framework/front
import framework/front/live as front_live
import gen/live/article_list
import gen/service
import lustre

pub const calls: List(front.Target(service.Service, Nil)) = [
  front.Of(service.ArticleList),
]

pub const after_send: front_live.After = front_live.Stay

pub fn app() -> lustre.App(Nil, article_list.State, article_list.Event) {
  todo
}
"

fn live_files() -> List(#(String, String)) {
  let assert Ok(back_units) = source.load("fixtures/article")
  let back_units =
    replace(back_units, [
      unit("service/article_publish", publish_source),
      unit("service/article_read", read_source),
    ])
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let face_units =
    list.append(face_units, [
      unit("components/read_fixture", read_component),
      unit("components/list_fixture", list_component),
    ])
  let assert Ok(front_model) =
    reader_front.read("public", face_units, app.services)
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
  |> list.map(fn(file) { #(file.path, file.text) })
}

fn live(files: List(#(String, String)), name: String) -> String {
  let assert Ok(#(_, text)) =
    list.find(files, fn(file) {
      file.0 == "public/src/gen/live/" <> name <> ".gleam"
    })
  // 生成物は gleam の構文として読める
  let assert Ok(_) = glance.module(text)
  text
}

/// H1:POST の body は Args の型で encode する ── Bool は真偽、Int / Float は数、Option の中身も同じ。
pub fn live_body_encodes_args_by_type_test() {
  let text = live(live_files(), "article_publish")
  string.contains(text, "#(\"pinned\", case args.pinned {\n") |> should.be_true
  string.contains(text, "\"true\" | \"True\" | \"on\" -> json.bool(True)")
  |> should.be_true
  string.contains(text, "\"false\" | \"False\" | \"\" -> json.bool(False)")
  |> should.be_true
  string.contains(text, "#(\"rank\", case int.parse(args.rank) {\n")
  |> should.be_true
  string.contains(text, "Ok(number) -> json.int(number)") |> should.be_true
  string.contains(
    text,
    "case float.parse(args.weight), int.parse(args.weight) {",
  )
  |> should.be_true
  string.contains(text, "  value -> case int.parse(value) {") |> should.be_true
  string.contains(text, "#(\"slug\", json.string(args.slug))") |> should.be_true
  string.contains(text, "json.string(args.pinned)") |> should.be_false
  string.contains(text, "import gleam/int") |> should.be_true
  string.contains(text, "import gleam/float") |> should.be_true
  // POST は query を付けない
  string.contains(text, "with_query") |> should.be_false
  string.contains(text, "import gleam/uri") |> should.be_false
}

/// H2:GET は path の穴に入らない Args を query に載せ、body は空。Option の空は載せない。
pub fn live_get_puts_args_in_query_test() {
  let files = live_files()
  let text = live(files, "article_read")
  string.contains(text, "\"GET\",\n") |> should.be_true
  string.contains(
    text,
    "with_query(\n        \"/api/articles/\" <> args.slug <> \"\",\n",
  )
  |> should.be_true
  string.contains(text, "[#(\"q\", args.q)],") |> should.be_true
  string.contains(
    text,
    "[#(\"pinned\", case args.pinned { \"true\" | \"True\" | \"on\" -> \"true\" \"false\" | \"False\" | \"\" -> \"false\" other -> other })],",
  )
  |> should.be_true
  string.contains(
    text,
    "case args.since { \"\" -> [] value -> [#(\"since\", value)] },",
  )
  |> should.be_true
  // path の穴は query に載せない
  string.contains(text, "#(\"slug\"") |> should.be_false
  string.contains(text, "json.object([])") |> should.be_true
  string.contains(text, "uri.query_to_string(pairs)") |> should.be_true
  string.contains(text, "import gleam/uri") |> should.be_true

  let listing = live(files, "article_list")
  string.contains(listing, "with_query(\n        \"/api/articles\",\n")
  |> should.be_true
  string.contains(listing, "[#(\"limit\", args.limit)],") |> should.be_true
  string.contains(
    listing,
    "case args.cursor { \"\" -> [] value -> [#(\"cursor\", value)] },",
  )
  |> should.be_true
}

/// transport の JS は変えない(GET は body を送らない)。
pub fn transport_keeps_get_without_body_test() {
  let assert Ok(#(_, ffi)) =
    list.find(live_files(), fn(file) {
      file.0 == "public/src/gen/live/transport_ffi.mjs"
    })
  string.contains(
    ffi,
    "body: method === \"GET\" ? undefined : JSON.stringify(nextBody),",
  )
  |> should.be_true
}

fn read_aliases(units: List(source.Unit)) -> String {
  let assert Ok(app) = reader.read(units)
  let assert Ok(file) =
    back.emit(app, units, hash.of(units), [], []).files
    |> list.find(fn(file) { string.ends_with(file.path, "gen/runtime.mjs") })
  let assert Ok(#(_, rest)) =
    string.split_once(file.text, "const readAliases={")
  let assert Ok(#(table, _)) = string.split_once(rest, "};")
  table
}

/// H3:`import service/<Y>` の先の `gen/reads/<Z>` も別名に入る(捨て名の import が要らない)。循環は止まる。
pub fn read_aliases_follow_service_imports_test() {
  let assert Ok(units) = source.load("fixtures/article")
  read_aliases(units) |> string.contains("article_read:") |> should.be_false

  let read_text =
    read_source
    |> string.replace(
      "import gen/types/slug.{type Slug}\n",
      "import gen/types/slug.{type Slug}\nimport service/article_list\n",
    )
  let list_text =
    source_text(units, "service/article_list")
    |> string.replace(
      "import gleam/option.{type Option}\n",
      "import gleam/option.{type Option}\nimport service/article_read.{type Args as ReadArgs}\n",
    )
  let units =
    replace(units, [
      unit("service/article_read", read_text),
      unit("service/article_list", list_text),
    ])
  let table = read_aliases(units)
  // article_read は article_list を辿り、その読み(article_list)を引く。自分の名は入れない
  table |> string.contains(" article_read:['article_list'],") |> should.be_true
  // 循環(article_list -> article_read -> article_list)は止まり、辿った先の article_read の読みが入る
  table |> string.contains(" article_list:['article_read'],") |> should.be_true
}

fn source_text(units: List(source.Unit), path: String) -> String {
  let assert Ok(found) = list.find(units, fn(item) { item.path == path })
  found.text
}

/// r2:List / record / 組 / Dict の Args ── `article_publish` の Args を差し替えた fixture。
fn wire_files() -> List(#(String, String)) {
  let source =
    publish_source
    |> string.replace(
      "  Args(slug: Slug, pinned: Bool, rank: Int, weight: Float, note: Option(Int))\n}",
      "  Args(
    slug: Slug,
    ids: List(Slug),
    ranks: List(Int),
    flags: Option(List(Bool)),
    theme: Theme,
    pairs: List(#(String, String)),
    place: Place,
    meta: dict.Dict(String, String),
    token: Token,
  )
}

pub type Theme {
  Theme(background: Option(String), accent: Option(String))
}

pub type Place {
  Top
  InSpace(Slug)
}

pub opaque type Token {
  Token(value: String)
}",
    )
    |> string.replace(
      "import gleam/option.{type Option}",
      "import gleam/dict\nimport gleam/option.{type Option}",
    )
  let assert Ok(back_units) = source.load("fixtures/article")
  let back_units =
    replace(back_units, [unit("service/article_publish", source)])
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let assert Ok(front_model) =
    reader_front.read("public", face_units, app.services)
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
  |> list.map(fn(file) { #(file.path, file.text) })
}

/// r2:`List(X)`(X がスカラ)は欄の JSON の文字列の配列を読み、要素を X の規則で JSON の配列に。
/// record・組・Dict は欄の文字列を JSON の本文として送る。構成子が複数の sum は文字列のまま。
pub fn live_body_encodes_list_and_record_args_test() {
  let text = live(wire_files(), "article_publish")
  // List(Slug)── 要素は文字列
  string.contains(text, "#(\"ids\", case list_items(args.ids) {\n")
  |> should.be_true
  string.contains(
    text,
    "  Ok(items) -> json.array(items, fn(value) { json.string(value) })",
  )
  |> should.be_true
  string.contains(text, "  Error(_) -> json.string(args.ids)") |> should.be_true
  // List(Int)── 要素は数
  string.contains(
    text,
    "  Ok(items) -> json.array(items, fn(value) { case int.parse(value) {",
  )
  |> should.be_true
  // Option(List(Bool))── 空なら null、それ以外は真偽の配列
  string.contains(
    text,
    "#(\"flags\", case args.flags {\n  \"\" -> json.null()\n",
  )
  |> should.be_true
  string.contains(text, "  value -> case list_items(value) {") |> should.be_true
  // record・組の List・Dict は JSON の本文
  string.contains(text, "#(\"theme\", json_text(args.theme))") |> should.be_true
  string.contains(text, "#(\"pairs\", json_text(args.pairs))") |> should.be_true
  string.contains(text, "#(\"meta\", json_text(args.meta))") |> should.be_true
  // 構成子が複数の sum は文字列(back の decoder が綴りで読む)
  string.contains(text, "#(\"place\", json.string(args.place))")
  |> should.be_true
  // opaque な 1 欄の型(値型の形)は文字列
  string.contains(text, "#(\"token\", json.string(args.token))")
  |> should.be_true
  // 助け手と import
  string.contains(
    text,
    "fn list_items(text: String) -> Result(List(String), Nil)",
  )
  |> should.be_true
  string.contains(text, "json.parse(text, decode.list(decode.string))")
  |> should.be_true
  string.contains(text, "fn json_text(text: String) -> json.Json")
  |> should.be_true
  string.contains(text, "use <- decode.recursive") |> should.be_true
  string.contains(text, "import gleam/dict") |> should.be_true
  string.contains(text, "import gleam/int") |> should.be_true
}

/// r2:List も record も無い live には助け手を出さない。
pub fn live_without_list_has_no_wire_helpers_test() {
  let text = live(live_files(), "article_publish")
  string.contains(text, "fn list_items") |> should.be_false
  string.contains(text, "fn json_text") |> should.be_false
  string.contains(text, "import gleam/dict") |> should.be_false
}
