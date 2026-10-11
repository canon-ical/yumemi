//// 0.11.2(yumemi-fix-0112)── 生成の live の Args の encode(H1)、GET の Args の query(H2)、
//// 読みの別名の `import service/*` の推移(H3)。

import glance
import gleam/list
import gleam/string
import gleeunit/should
import simplifile
import yumemi/gen/emit/back
import yumemi/gen/emit/front as front_emit
import yumemi/gen/emit/hash
import yumemi/gen/face
import yumemi/gen/reader
import yumemi/gen/reader/front as reader_front
import yumemi/gen/source

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
import yumemi/effect.{type Effect, Write}
import yumemi/step.{type Start, type Step}
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
import yumemi/effect.{type Effect, Read}
import yumemi/step.{type Start, type Step}
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

// 0.12 段 C:interactive Component は view と宣言だけ(lustre の app は無い)。読みは reloads で呼ぶ。
const read_component = "
import gen/live/article_read as read
import gen/route
import gen/service
import yumemi/front/el
import yumemi/front/html
import yumemi/front/live

pub const calls: List(service.Service) = [service.ArticleRead]

pub const after_send: List(#(service.Service, live.After(route.Route))) = []

pub const reloads: live.Reloads(service.Service, read.Field) = live.Reloads(read: service.ArticleRead, on: [read.Q])

pub fn view(it: read.Args) -> el.Element {
  html.input_([read.bind(read.Q, it.q)])
}
"

const list_component = "
import gen/live/article_list as listing
import gen/route
import gen/service
import yumemi/front/el
import yumemi/front/html
import yumemi/front/live

pub const calls: List(service.Service) = [service.ArticleList]

pub const after_send: List(#(service.Service, live.After(route.Route))) = []

pub const reloads: live.Reloads(service.Service, listing.Field) = live.Reloads(read: service.ArticleList, on: [listing.Limit])

pub fn view(it: listing.Args) -> el.Element {
  html.input_([listing.bind(listing.Limit, it.limit)])
}
"

fn live_files() -> List(#(String, String)) {
  let assert Ok(back_units) = source.load("gen/fixtures/article")
  let back_units =
    replace(back_units, [
      unit("service/article_publish", publish_source),
      unit("service/article_read", read_source),
    ])
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("gen/fixtures/article/public")
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
      path: "gen/fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
  |> list.map(fn(file) { #(file.path, file.text) })
}

/// 生成の client.mjs(束ねる前)の字。0.12 段 C で Args の送り方は runtime の表(Service ごとの method・
/// path・Args の欄の型)に移った。
fn client(files: List(#(String, String))) -> String {
  let assert Ok(#(_, text)) =
    list.find(files, fn(file) {
      file.0 == "public/priv/static/_yumemi/client.mjs"
    })
  text
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
/// 0.12 段 C:encode は runtime(`interactive.mjs` の wireValue)が表の型で行う。期待を live の Gleam の字から
/// 表の行に替えた(runtime の振る舞いは yumemi_012_y3_test の runtime_wire_* で見る)。
pub fn live_body_encodes_args_by_type_test() {
  let files = live_files()
  let text = client(files)
  string.contains(
    text,
    "\"article_publish\": { \"method\": \"POST\", \"path\": \"/api/articles/:slug/publish\", \"read\": false, \"upload\": false, \"accepted\": false, \"entry\": false, \"args\": [{ \"name\": \"slug\", \"wire\": \"text\", \"blob\": false }, { \"name\": \"pinned\", \"wire\": \"bool\", \"blob\": false }, { \"name\": \"rank\", \"wire\": \"int\", \"blob\": false }, { \"name\": \"weight\", \"wire\": \"float\", \"blob\": false }, { \"name\": \"note\", \"wire\": { \"option\": \"int\" }, \"blob\": false }]",
  )
  |> should.be_true
  // live module は Args を文字列の欄で持ち、送り方を持たない
  let module = live(files, "article_publish")
  string.contains(
    module,
    "Args(slug: String, pinned: String, rank: String, weight: String, note: String)",
  )
  |> should.be_true
  string.contains(module, "json.") |> should.be_false
}

/// H2:GET は path の穴に入らない Args を query に載せ、body は空。Option の空は載せない。
/// 0.12 段 C:query は runtime が組む。表に GET と穴のある path と欄の型が載る(期待を Gleam の字から替えた)。
pub fn live_get_puts_args_in_query_test() {
  let files = live_files()
  let text = client(files)
  string.contains(
    text,
    "\"article_read\": { \"method\": \"GET\", \"path\": \"/api/articles/:slug\", \"read\": true",
  )
  |> should.be_true
  string.contains(
    text,
    "{ \"name\": \"q\", \"wire\": \"text\", \"blob\": false }",
  )
  |> should.be_true
  string.contains(
    text,
    "{ \"name\": \"pinned\", \"wire\": \"bool\", \"blob\": false }",
  )
  |> should.be_true
  string.contains(
    text,
    "{ \"name\": \"since\", \"wire\": { \"option\": \"text\" }, \"blob\": false }",
  )
  |> should.be_true
  string.contains(
    text,
    "\"article_list\": { \"method\": \"GET\", \"path\": \"/api/articles\"",
  )
  |> should.be_true
  // 読みは reloads で呼び直す(Out に List がある article_list は一覧、article_read も tags の List で一覧)
  string.contains(
    text,
    "\"reloads\": { \"read\": \"article_list\", \"on\": [\"limit\"], \"list\": true }",
  )
  |> should.be_true
}

/// transport の JS は変えない(GET は body を送らない)。0.12 段 C:transport_ffi.mjs は無くなり、runtime の
/// `call` が GET で body を送らない(期待を transport_ffi の字から runtime の字に替えた)。
pub fn transport_keeps_get_without_body_test() {
  list.any(live_files(), fn(file) {
    string.ends_with(file.0, "transport_ffi.mjs")
  })
  |> should.be_false
  let assert Ok(runtime) = simplifile.read("src/yumemi/front/interactive.mjs")
  string.contains(
    runtime,
    "body: spec.method === \"GET\" ? undefined : spec.entry && spec.args.length === 0 ? \"null\" : JSON.stringify(args),",
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
  let assert Ok(units) = source.load("gen/fixtures/article")
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
  let assert Ok(back_units) = source.load("gen/fixtures/article")
  let back_units =
    replace(back_units, [unit("service/article_publish", source)])
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("gen/fixtures/article/public")
  let assert Ok(front_model) =
    reader_front.read("public", face_units, app.services)
  let package =
    face.Package(
      name: "public",
      path: "gen/fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
  |> list.map(fn(file) { #(file.path, file.text) })
}

/// r2:`List(X)`(X がスカラ)は欄の JSON の文字列の配列を読み、要素を X の規則で JSON の配列に。
/// record・組・Dict は欄の文字列を JSON の本文として送る。構成子が複数の sum は文字列のまま。
/// 0.12 段 C:同じ規則を runtime の表の型(`list`・`json`・`text`)で持つ(期待を Gleam の字から替えた)。
pub fn live_body_encodes_list_and_record_args_test() {
  let text = client(wire_files())
  [
    "{ \"name\": \"ids\", \"wire\": { \"list\": \"text\" }, \"blob\": false }",
    "{ \"name\": \"ranks\", \"wire\": { \"list\": \"int\" }, \"blob\": false }",
    "{ \"name\": \"flags\", \"wire\": { \"option\": { \"list\": \"bool\" } }, \"blob\": false }",
    "{ \"name\": \"theme\", \"wire\": \"json\", \"blob\": false }",
    "{ \"name\": \"pairs\", \"wire\": \"json\", \"blob\": false }",
    "{ \"name\": \"place\", \"wire\": \"text\", \"blob\": false }",
    "{ \"name\": \"meta\", \"wire\": \"json\", \"blob\": false }",
    "{ \"name\": \"token\", \"wire\": \"text\", \"blob\": false }",
  ]
  |> list.each(fn(row) { string.contains(text, row) |> should.be_true })
}

/// r2:List も record も無い live には助け手を出さない。
pub fn live_without_list_has_no_wire_helpers_test() {
  let text = live(live_files(), "article_publish")
  string.contains(text, "fn list_items") |> should.be_false
  string.contains(text, "fn json_text") |> should.be_false
  string.contains(text, "import gleam/dict") |> should.be_false
}
