//// yumemi-0145(0.14.5)── `server.storage` の `InSchema`(Entity の表を `app` でない schema に置く)と
//// `Derived`(表の列に持たない Property)。宣言の無い App の生成物は変わらない(fixture の全生成物は
//// 0.14.4 と 1 字も違わない ── 便の RESULTS が比べた)。ここは宣言のある App の生成物と条文を見る。

import glance
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import yumemi/gen/emit/draft
import yumemi/gen/emit/hash
import yumemi/gen/emit/sql
import yumemi/gen/emit/verb
import yumemi/gen/reader
import yumemi/gen/reader/server as server_reader
import yumemi/gen/source

const article_fixture = "gen/fixtures/article"

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

/// article の fixture の server を storage だけの宣言に替える(`[]` は宣言なし)。
fn storage_units(storage: String) -> List(source.Unit) {
  let assert Ok(units) = source.load(article_fixture)
  list.append(list.filter(units, fn(item) { item.path != "server" }), [
    unit(
      "server",
      "import yumemi/server.{Array, Column, Derived, DurableObject, InObject, InSchema, Split, Text}\n\n"
        <> "pub const durable_objects: List(server.DurableObject) = [DurableObject(class: \"TagDo\", module: \"tag_do\", adapter: \"TagDoAdapter\", methods: [])]\n"
        <> "pub const storage: List(server.Storage) = "
        <> storage
        <> "\n",
    ),
  ])
}

/// verb の SQL と生成の読みの SQL の全部(path, 本文)。
fn sql_files(units: List(source.Unit)) -> List(#(String, String)) {
  let assert Ok(app) = reader.read(units)
  list.append(verb.sql(app, hash.of(units)), sql.emit(app, hash.of(units)))
  |> list.map(fn(file) { #(file.path, file.text) })
}

fn file(files: List(#(String, String)), path: String) -> String {
  let assert Ok(#(_, text)) = list.find(files, fn(item) { item.0 == path })
  text
}

fn notes_of(units: List(source.Unit)) -> List(String) {
  let assert Ok(app) = reader.read(units)
  server_reader.notes(app) |> list.map(fn(note) { note.text })
}

fn has_note(notes: List(String), text: String) -> Bool {
  list.any(notes, fn(note) { string.contains(note, text) })
}

// ── InSchema ────────────────────────────────────────────────────────────────

/// `InSchema` の Entity の表は `<schema>.<表>` で出る。生成の SQL の差は `app.category` → `public.category`
/// だけで、他の Entity の SQL・file の集合は変わらない。
pub fn in_schema_moves_only_the_table_name_test() {
  let plain = sql_files(storage_units("[]"))
  let moved =
    sql_files(storage_units(
      "[InSchema(entity: \"category\", schema: \"public\")]",
    ))
  notes_of(storage_units("[InSchema(entity: \"category\", schema: \"public\")]"))
  |> should.equal([])
  list.map(moved, fn(item) { item.0 })
  |> should.equal(list.map(plain, fn(item) { item.0 }))
  list.each(plain, fn(item) {
    file(moved, item.0)
    |> should.equal(string.replace(item.1, "app.category", "public.category"))
  })
  // 差が 0 でないことを確かめる(category の verb は表の名を書く)
  let create = file(moved, "db/queries/verb/create_category.sql")
  string.contains(create, "INSERT INTO public.category(") |> should.be_true
  list.any(moved, fn(item) { string.contains(item.1, "app.category") })
  |> should.be_false
}

/// 宣言の無い App は `app` のまま(storage が空でも、他の写像だけでも)。
pub fn without_in_schema_the_table_stays_in_app_test() {
  let files =
    sql_files(storage_units(
      "[Column(entity: \"article\", property: \"title\", column: \"headline\")]",
    ))
  file(files, "db/queries/verb/create_article.sql")
  |> string.contains("INSERT INTO app.article(")
  |> should.be_true
  file(files, "db/queries/verb/create_category.sql")
  |> string.contains("INSERT INTO app.category(")
  |> should.be_true
}

/// schema の名は SQL の素の識別子だけ。`framework`・同じ Entity に 2 つ・`InObject` の Entity は止める。
pub fn in_schema_stops_test() {
  let notes =
    notes_of(storage_units(
      "[InSchema(entity: \"article\", schema: \"Public\"), InSchema(entity: \"category\", schema: \"framework\"), InSchema(entity: \"staff\", schema: \"a\"), InSchema(entity: \"staff\", schema: \"b\"), InObject(entity: \"tag\", object: \"TagDo\"), InSchema(entity: \"tag\", schema: \"public\"), InSchema(entity: \"ghost\", schema: \"public\")]",
    ))
  [
    "storage article の InSchema の schema が SQL の素の識別子でない: Public",
    "storage category の InSchema の schema framework は framework の持ち物",
    "storage staff に InSchema が 2 つ以上",
    "storage tag は InObject(PG の表が無い)なのに InSchema がある",
    "storage の Entity が無い: ghost",
  ]
  |> list.each(fn(text) { has_note(notes, text) |> should.be_true })
  list.length(notes) |> should.equal(5)
}

// ── Derived ─────────────────────────────────────────────────────────────────

/// `Derived` の Property は create の列と値、RETURNING、update の verb、Draft・Created、runtime の表に出ない。
/// 穴は 1 つ減り、他の列は変わらない。
pub fn derived_leaves_the_verbs_test() {
  let declared =
    storage_units("[Derived(entity: \"article\", property: \"body\")]")
  notes_of(declared) |> should.equal([])
  let plain = sql_files(storage_units("[]"))
  let derived = sql_files(declared)
  let before = file(plain, "db/queries/verb/create_article.sql")
  let create = file(derived, "db/queries/verb/create_article.sql")
  string.contains(before, "body") |> should.be_true
  string.contains(create, "body") |> should.be_false
  string.split(create, "$")
  |> list.length
  |> should.equal(list.length(string.split(before, "$")) - 1)
  list.any(plain, fn(item) {
    item.0 == "db/queries/verb/update_article_body.sql"
  })
  |> should.be_true
  list.any(derived, fn(item) { string.contains(item.0, "article_body") })
  |> should.be_false
  // 他の verb の SQL に body の列は残らない(put・create_many の列も)。冪等キーの記録の `'{body}'` は
  // 記録した応答の body(列でない)なので見ない
  list.filter(derived, fn(item) {
    string.starts_with(item.0, "db/queries/verb/")
    && !string.ends_with(item.0, "_idempotency_order.sql")
  })
  |> list.any(fn(item) { string.contains(item.1, "body") })
  |> should.be_false
  let assert Ok(app) = reader.read(declared)
  let assert Ok(article) =
    draft.emit(app, hash.of(declared))
    |> list.find(fn(file) { file.path == "src/gen/draft/article.gleam" })
  string.contains(article.text, "body") |> should.be_false
  string.contains(article.text, "title:") |> should.be_true
  let runtime =
    verb.runtime_table(app)
    |> list.map(fn(row) { row.1 })
    |> string.join("\n")
  string.contains(runtime, "'body'") |> should.be_false
  let assert Ok(code) =
    list.find(verb.emit(app, hash.of(declared)), fn(file) {
      file.path == "src/gen/verb.gleam"
    })
  string.contains(code.text, "update_article_body") |> should.be_false
}

/// `Derived` の Entity の行をまるごと渡す生成の読み(`t.*`)は SQL を出さず exit 4 で名指す。
/// 宣言の無い App は同じ読みを出す。
pub fn derived_stops_whole_row_reads_test() {
  let plain = storage_units("[]")
  let declared =
    storage_units("[Derived(entity: \"article\", property: \"body\")]")
  let assert Ok(plain_app) = reader.read(plain)
  let assert Ok(app) = reader.read(declared)
  let plain_paths = sql_files(plain) |> list.map(fn(item) { item.0 })
  list.contains(plain_paths, "db/queries/article_list/items.sql")
  |> should.be_true
  sql.notes(plain_app, hash.of(plain))
  |> list.any(fn(note) { string.contains(note.text, "Derived") })
  |> should.be_false
  let paths = sql_files(declared) |> list.map(fn(item) { item.0 })
  list.contains(paths, "db/queries/article_list/items.sql") |> should.be_false
  // 行を渡さない集計(counts)は出る
  list.contains(paths, "db/queries/article_list/counts.sql") |> should.be_true
  sql.notes(app, hash.of(declared))
  |> list.any(fn(note) {
    string.contains(note.text, "article_list/items")
    && string.contains(
      note.text,
      "Article の行を生成の読みで渡せない ── Derived の Property(body)は表の列に無い",
    )
  })
  |> should.be_true
}

/// verb で書く Property・表の列に要る Property・列の写像との重ね掛けは `Derived` にできない。
pub fn derived_stops_test() {
  let notes =
    notes_of(storage_units(
      "[Derived(entity: \"article\", property: \"title\"), Derived(entity: \"article\", property: \"slug\"), Derived(entity: \"article\", property: \"category\"), Derived(entity: \"article\", property: \"order\"), Derived(entity: \"article\", property: \"version\"), Derived(entity: \"article\", property: \"body\"), Column(entity: \"article\", property: \"body\", column: \"b\"), InObject(entity: \"tag\", object: \"TagDo\"), Derived(entity: \"tag\", property: \"name\"), Derived(entity: \"article\", property: \"nope\")]",
    ))
  [
    "storage article の Derived title を verb の Update pin で書こうとしている",
    "storage article の Derived title を verb の DeleteWhere で書こうとしている",
    "storage article の Derived slug は key",
    "storage article の Derived category は関係の Property",
    "storage article の Derived category は put の鍵",
    "storage article の Derived category は並び(OrderedBy)の列",
    "storage article の Derived order は put の鍵",
    "storage article の Derived order は並び(OrderedBy)の列",
    "storage article の Derived version は verb が書く列",
    "storage article の Derived body に Column / Text / Split / Array / Derived を重ねている",
    "storage tag の Derived name は InObject の Entity",
    "storage tag の Derived name は key",
    "storage article に Property が無い: nope",
  ]
  |> list.each(fn(text) { has_note(notes, text) |> should.be_true })
  list.length(notes) |> should.equal(13)
}

/// 柏木 ゲート 2 P2:`column` を通らずに列を書く 2 か所 ── allow 句の owner の `party` と with の子の `order`。
/// `Derived` なら SQL を出さず exit 4、宣言が無ければ今の SQL。
fn read_service(
  name: String,
  face: String,
  allow: String,
  select: String,
) -> source.Unit {
  let allow_import = case allow {
    "" -> ""
    _ -> "import gen/allow/article as allow\n"
  }
  unit("service/" <> name, "import yumemi/effect.{type Effect, Read}
import yumemi/step.{type Start, type Step}
" <> allow_import <> "import gen/face.{type Face, " <> face <> "}
import gen/query as q
import gen/root/" <> name <> ".{type Actor, type Root, type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [" <> face <> "]

pub type Args {
  Args(name: String)
}

pub type Out {
  Out
}

pub type Error

pub type P {
  Name
}

pub const items: q.Select(P) = " <> select <> "

pub const service: Service(Args, Out, Error) = Service(allow: [" <> allow <> "], logic: logic)

pub fn logic(_by: Actor, _it: Root, _args: Args) -> Step(Out, Error, Start) {
  step.done(Out)
}
")
}

fn with_storage(
  app_dir: String,
  extra: List(source.Unit),
  storage: String,
) -> List(source.Unit) {
  let assert Ok(units) = source.load(app_dir)
  let paths = ["server", ..list.map(extra, fn(item) { item.path })]
  list.flatten([
    list.filter(units, fn(item) { !list.contains(paths, item.path) }),
    extra,
    [
      unit(
        "server",
        "import yumemi/server.{Derived}\n\npub const storage: List(server.Storage) = "
          <> storage
          <> "\n",
      ),
    ],
  ])
}

fn read_sql(units: List(source.Unit), path: String) -> Result(String, Nil) {
  let assert Ok(app) = reader.read(units)
  sql.emit(app, hash.of(units))
  |> list.find(fn(file) { file.path == path })
  |> result.map(fn(file) { file.text })
}

fn sql_note(units: List(source.Unit), text: String) -> Bool {
  let assert Ok(app) = reader.read(units)
  sql.notes(app, hash.of(units))
  |> list.any(fn(note) { string.contains(note.text, text) })
}

pub fn derived_party_stops_the_allow_owner_test() {
  let memo =
    unit(
      "entity/memo",
      "import yumemi/party.{type PartyId}
import gen/types/title.{type Title}

pub type Memo {
  Memo(title: Title, party: PartyId)
}

pub fn key(it: Memo) -> Title {
  it.title
}

pub const collection: String = \"memos\"
",
    )
  // 行を渡さない集計(whole_rows を通らない)の allow 句が m.party を書く
  let service =
    read_service(
      "memo_count",
      "Public",
      "allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.ViaMemoParty)",
      "q.Select(from: q.Memo, join: [], where: [], group: [], having: [], agg: [q.Count], along: [], with: [], order: [], limit: q.NoLimit)",
    )
  let plain = with_storage(article_fixture, [memo, service], "[]")
  let assert Ok(text) = read_sql(plain, "db/queries/memo_count/items.sql")
  string.contains(text, "m.party=$") |> should.be_true
  let declared =
    with_storage(
      article_fixture,
      [memo, service],
      "[Derived(entity: \"memo\", property: \"party\")]",
    )
  notes_of(declared) |> should.equal([])
  read_sql(declared, "db/queries/memo_count/items.sql") |> should.be_error
  sql_note(
    declared,
    "allow 句の owner ViaMemoParty の Memo の party は Derived(表の列に持たない Property)",
  )
  |> should.be_true
}

pub fn derived_order_stops_the_with_child_order_test() {
  let assert Ok(units) = source.load("gen/fixtures/relation")
  let assert Ok(photo) =
    list.find(units, fn(item) { item.path == "entity/photo" })
  // order を並び(OrderedBy)にしない Photo ── 並びの列は Derived にできない(条文)ので外す
  let assert [head, ..] = string.split(photo.text, "\n/// 順序列は値域つき")
  let photo = unit("entity/photo", head <> "\n")
  // 子の列を選んだ with(to_jsonb(p) でなく jsonb_build_object)── whole_rows を通らない
  let service =
    read_service(
      "album_pick",
      "Test",
      "",
      "q.Pick(columns: [q.AlbumId, q.AlbumTitle, q.PhotoCaption], select: q.Select(from: q.Album, join: [], where: [], group: [], having: [], agg: [], along: [], with: [q.AlbumToPhotos], order: [q.Asc(q.AlbumTitle)], limit: q.NoLimit))",
    )
  let plain = with_storage("gen/fixtures/relation", [photo, service], "[]")
  let assert Ok(text) = read_sql(plain, "db/queries/album_pick/items.sql")
  string.contains(
    text,
    "jsonb_build_object('caption',p.caption) ORDER BY p.\"order\",p.id",
  )
  |> should.be_true
  let declared =
    with_storage(
      "gen/fixtures/relation",
      [photo, service],
      "[Derived(entity: \"photo\", property: \"order\")]",
    )
  notes_of(declared) |> should.equal([])
  read_sql(declared, "db/queries/album_pick/items.sql") |> should.be_error
  sql_note(declared, "with の子 Photo の order は Derived(表の列に持たない Property)")
  |> should.be_true
}

/// `Split` / `Text` / `Array` との重ね掛けと、同じ `Derived` の 2 度書きも止める。
pub fn derived_overlaps_stop_test() {
  let notes =
    notes_of(storage_units(
      "[Derived(entity: \"article\", property: \"body\"), Text(entity: \"article\", property: \"body\", values: []), Derived(entity: \"staff\", property: \"name\"), Derived(entity: \"staff\", property: \"name\")]",
    ))
  has_note(
    notes,
    "storage article の Derived body に Column / Text / Split / Array / Derived を重ねている",
  )
  |> should.be_true
  has_note(
    notes,
    "storage staff の Derived name に Column / Text / Split / Array / Derived を重ねている",
  )
  |> should.be_true
}
