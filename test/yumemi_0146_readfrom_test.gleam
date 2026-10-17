//// yumemi-readfrom(0.14.6)── `server.storage` の `ReadFrom`(Entity の読みを表とは別の relation から引く)。
//// 宣言の無い App の生成物は変わらない(fixture の全生成物は 0.14.5 と 1 字も違わない ── 便の RESULTS が比べた)。
//// ここは宣言のある App の生成物と条文を見る:読みの SQL だけが relation を引き、verb の SQL は表のまま。
//// `ReadFrom` のある Entity では 0.14.5 の読みの側の条文(行をまるごと、Derived の名指し)が外れる。

import glance
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import yumemi/gen/emit/hash
import yumemi/gen/emit/sql
import yumemi/gen/emit/verb
import yumemi/gen/reader
import yumemi/gen/reader/server as server_reader
import yumemi/gen/source

const article_fixture = "gen/fixtures/article"

const relation_fixture = "gen/fixtures/relation"

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

/// fixture の server を storage だけの宣言に替え、`extra` の unit を足す・差し替える(`[]` は宣言なし)。
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
        "import yumemi/server.{Derived, DurableObject, InObject, InSchema, ReadFrom}\n\n"
          <> "pub const durable_objects: List(server.DurableObject) = [DurableObject(class: \"TagDo\", module: \"tag_do\", adapter: \"TagDoAdapter\", methods: [])]\n"
          <> "pub const storage: List(server.Storage) = "
          <> storage
          <> "\n",
      ),
    ],
  ])
}

/// verb の SQL(path, 本文)。
fn verb_files(units: List(source.Unit)) -> List(#(String, String)) {
  let assert Ok(app) = reader.read(units)
  verb.sql(app, hash.of(units))
  |> list.map(fn(file) { #(file.path, file.text) })
}

/// 生成の読みの SQL(path, 本文)── Service の読みと矢印の読み。
fn read_files(units: List(source.Unit)) -> List(#(String, String)) {
  let assert Ok(app) = reader.read(units)
  sql.emit(app, hash.of(units))
  |> list.map(fn(file) { #(file.path, file.text) })
}

fn file(files: List(#(String, String)), path: String) -> String {
  let assert Ok(#(_, text)) = list.find(files, fn(item) { item.0 == path })
  text
}

fn read_sql(units: List(source.Unit), path: String) -> Result(String, Nil) {
  read_files(units)
  |> list.find(fn(item) { item.0 == path })
  |> result.map(fn(item) { item.1 })
}

fn notes_of(units: List(source.Unit)) -> List(String) {
  let assert Ok(app) = reader.read(units)
  server_reader.notes(app) |> list.map(fn(note) { note.text })
}

fn sql_notes(units: List(source.Unit)) -> List(String) {
  let assert Ok(app) = reader.read(units)
  sql.notes(app, hash.of(units)) |> list.map(fn(note) { note.text })
}

fn has_note(notes: List(String), text: String) -> Bool {
  list.any(notes, fn(note) { string.contains(note, text) })
}

/// 表の名 `app.<table> ` を `app.<table>_view ` に替えた本文(読みの SQL の期待値)。
fn viewed(text: String, tables: List(String)) -> String {
  list.fold(tables, text, fn(acc, table) {
    string.replace(acc, "app." <> table <> " ", "app." <> table <> "_view ")
  })
}

fn read_from_all(tables: List(String)) -> String {
  "["
  <> string.join(
    list.map(tables, fn(table) {
      "ReadFrom(entity: \""
      <> table
      <> "\", relation: \""
      <> table
      <> "_view\")"
    }),
    ", ",
  )
  <> "]"
}

// ── 読みだけが relation を引く ──────────────────────────────────────────────

/// 宣言のある Entity の生成の読み(from・join・矢印・with の子・`has`)は relation を引き、差はその名だけ。
/// verb の SQL は 1 字も変わらない(表を書き、表を掴む)。`Derived` の無い Entity の `ReadFrom` は通る。
pub fn read_from_moves_only_the_reads_test() {
  list.each(
    [
      #(article_fixture, ["article", "category", "staff"]),
      #(relation_fixture, ["album", "photo", "shelf", "label"]),
    ],
    fn(pair) {
      let #(app_dir, tables) = pair
      let plain = with_storage(app_dir, [], "[]")
      let declared = with_storage(app_dir, [], read_from_all(tables))
      notes_of(declared) |> should.equal([])
      sql_notes(declared) |> should.equal(sql_notes(plain))
      verb_files(declared) |> should.equal(verb_files(plain))
      let before = read_files(plain)
      let after = read_files(declared)
      list.map(after, fn(item) { item.0 })
      |> should.equal(list.map(before, fn(item) { item.0 }))
      list.each(before, fn(item) {
        file(after, item.0) |> should.equal(viewed(item.1, tables))
      })
      // 差が 0 でないことと、読みに表の名が残らないこと
      list.any(before, fn(item) { viewed(item.1, tables) != item.1 })
      |> should.be_true
      list.each(after, fn(item) {
        list.each(tables, fn(table) {
          string.contains(item.1, "app." <> table <> " ") |> should.be_false
        })
      })
    },
  )
}

/// 読みの 6 か所の現物:矢印・from・join(article)、`has`・with の子(relation)。allow の経路は下。
pub fn read_from_writes_the_relation_in_each_read_test() {
  let joined =
    read_service(
      "article_joined",
      "",
      "",
      "q.Select(from: q.Article, join: [q.ArticleToCategory], where: [], group: [], having: [], agg: [], along: [], with: [], order: [], limit: q.NoLimit)",
    )
  let plain = with_storage(article_fixture, [joined], "[]")
  let assert Ok(before) = read_sql(plain, "db/queries/article_joined/items.sql")
  string.contains(before, "\nFROM app.article a\nJOIN app.category c ON ")
  |> should.be_true
  let article =
    read_files(with_storage(
      article_fixture,
      [joined],
      read_from_all(["article", "category"]),
    ))
  file(article, "db/queries/article_list/items.sql")
  |> string.contains("\nFROM app.article_view a")
  |> should.be_true
  file(article, "db/queries/article_joined/items.sql")
  |> should.equal(viewed(before, ["article", "category"]))
  file(article, "db/queries/article_read/to_category.sql")
  |> string.contains("JOIN app.category_view t ON t.")
  |> should.be_true
  let relation =
    read_files(with_storage(
      relation_fixture,
      [],
      read_from_all(["album", "photo", "shelf"]),
    ))
  let related = file(relation, "db/queries/photo_filter/related.sql")
  string.contains(related, "  SELECT 1 FROM app.album_view a\n")
  |> should.be_true
  string.contains(related, "  SELECT 1 FROM app.shelf_view s\n")
  |> should.be_true
  file(relation, "db/queries/photo_filter/album_photos.sql")
  |> string.contains("\nFROM app.photo_view p\n")
  |> should.be_true
}

/// allow 句の経路(入れ子の EXISTS)も relation を引く。
pub fn read_from_writes_the_relation_in_the_allow_path_test() {
  let memo =
    unit(
      "entity/memo",
      "import entity/article.{type Article}
import entity/staff.{type Staff}
import yumemi/er.{type Held}
import gen/types/title.{type Title}

pub type Memo {
  Memo(title: Title, article: Held(Article), staff: Held(Staff))
}

pub fn key(it: Memo) -> Title {
  it.title
}

pub const collection: String = \"memos\"
",
    )
  let service =
    read_service(
      "memo_list",
      "import entity/article\nimport gen/allow/article as allow\n",
      "allow.Clause(who: allow.Anyone, at: allow.Only([article.Published]), owner: allow.ViaStaffParty)",
      "q.Select(from: q.Memo, join: [], where: [], group: [], having: [], agg: [q.Count], along: [], with: [], order: [], limit: q.NoLimit)",
    )
  let plain = with_storage(article_fixture, [memo, service], "[]")
  let assert Ok(before) = read_sql(plain, "db/queries/memo_list/items.sql")
  string.contains(before, "EXISTS(SELECT 1 FROM app.article a WHERE ")
  |> should.be_true
  string.contains(before, "EXISTS(SELECT 1 FROM app.staff s WHERE ")
  |> should.be_true
  let declared =
    with_storage(
      article_fixture,
      [memo, service],
      read_from_all(["article", "staff", "memo"]),
    )
  let assert Ok(after) = read_sql(declared, "db/queries/memo_list/items.sql")
  after |> should.equal(viewed(before, ["article", "staff", "memo"]))
  string.contains(after, "EXISTS(SELECT 1 FROM app.staff_view s WHERE ")
  |> should.be_true
}

/// `InSchema` と重ねると、relation は Entity の schema の中に在る(`public.category_view`)。verb は `public.category`。
pub fn read_from_lives_in_the_entity_schema_test() {
  let units =
    with_storage(
      article_fixture,
      [],
      "[InSchema(entity: \"category\", schema: \"public\"), ReadFrom(entity: \"category\", relation: \"category_view\")]",
    )
  notes_of(units) |> should.equal([])
  file(read_files(units), "db/queries/article_read/to_category.sql")
  |> string.contains("JOIN public.category_view t ON ")
  |> should.be_true
  file(verb_files(units), "db/queries/verb/create_category.sql")
  |> string.contains("INSERT INTO public.category(")
  |> should.be_true
}

// ── Derived と重ねる ────────────────────────────────────────────────────────

fn read_service(
  name: String,
  imports: String,
  allow: String,
  select: String,
) -> source.Unit {
  unit("service/" <> name, "import yumemi/effect.{type Effect, Read}
import yumemi/step.{type Start, type Step}
" <> imports <> "import gen/face.{type Face, Public}
import gen/query as q
import gen/root/" <> name <> ".{type Actor, type Root, type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [Public]

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

/// 0.14.5 で止まった読み ── 行をまるごと(`t.*`)、Derived の名指し(Pick・where)── が `ReadFrom` で出る。
/// verb の側の条文(create・update から外す)は残る。
pub fn read_from_lets_derived_reads_through_test() {
  let service =
    read_service(
      "article_bodies",
      "",
      "",
      "q.Pick(columns: [q.ArticleSlug, q.ArticleBody], select: q.Select(from: q.Article, join: [], where: [q.Eq(q.ArticleBody, q.Param(Name))], group: [], having: [], agg: [], along: [], with: [], order: [], limit: q.NoLimit))",
    )
  let derived_only =
    with_storage(
      article_fixture,
      [service],
      "[Derived(entity: \"article\", property: \"body\")]",
    )
  let both =
    with_storage(
      article_fixture,
      [service],
      "[Derived(entity: \"article\", property: \"body\"), ReadFrom(entity: \"article\", relation: \"article_view\")]",
    )
  notes_of(derived_only) |> should.equal([])
  notes_of(both) |> should.equal([])
  // 0.14.5 のまま:Derived だけなら 3 本(行をまるごと 2、名指し 1)が止まる
  let stopped = sql_notes(derived_only)
  has_note(
    stopped,
    "article_list/items: Article の行を生成の読みで渡せない ── Derived の Property(body)",
  )
  |> should.be_true
  has_note(stopped, "widget_list/items: Article の行を生成の読みで渡せない")
  |> should.be_true
  has_note(stopped, "article_bodies/items: 列 ArticleBody は Derived")
  |> should.be_true
  // ReadFrom を足すと止まらず、読みは relation を引いて body を名で読む
  sql_notes(both) |> should.equal([])
  let reads = read_files(both)
  file(reads, "db/queries/article_list/items.sql")
  |> string.contains("SELECT a.*\nFROM app.article_view a")
  |> should.be_true
  let bodies = file(reads, "db/queries/article_bodies/items.sql")
  string.contains(bodies, "a.body") |> should.be_true
  string.contains(bodies, "\nFROM app.article_view a") |> should.be_true
  // verb は Derived だけのときと同じ(表を書き、body を書かない)
  verb_files(both) |> should.equal(verb_files(derived_only))
  let create = file(verb_files(both), "db/queries/verb/create_article.sql")
  string.contains(create, "INSERT INTO app.article(") |> should.be_true
  string.contains(create, "body") |> should.be_false
}

/// 矢印の読み(`to_<prop>`)の先が Derived を持つ:0.14.5 は止める、`ReadFrom` があれば relation から出る。
pub fn read_from_lets_derived_arrows_through_test() {
  let derived_only =
    with_storage(
      relation_fixture,
      [],
      "[Derived(entity: \"album\", property: \"title\")]",
    )
  let both =
    with_storage(
      relation_fixture,
      [],
      "[Derived(entity: \"album\", property: \"title\"), ReadFrom(entity: \"album\", relation: \"album_view\")]",
    )
  read_sql(derived_only, "db/queries/photo_read/to_album.sql")
  |> should.be_error
  has_note(sql_notes(derived_only), "photo_read/to_album: Album の行を生成の読みで渡せない")
  |> should.be_true
  sql_notes(both) |> should.equal([])
  let assert Ok(arrow) = read_sql(both, "db/queries/photo_read/to_album.sql")
  string.contains(arrow, "JOIN app.album_view t ON t.id=keys.value")
  |> should.be_true
}

/// `column` を通らない 2 か所(allow 句の owner の `party`、with の子の `order`)も `ReadFrom` で出る。
pub fn read_from_lets_derived_party_and_order_through_test() {
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
  let count =
    read_service(
      "memo_count",
      "import gen/allow/article as allow\n",
      "allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.ViaMemoParty)",
      "q.Select(from: q.Memo, join: [], where: [], group: [], having: [], agg: [q.Count], along: [], with: [], order: [], limit: q.NoLimit)",
    )
  let derived_only =
    with_storage(
      article_fixture,
      [memo, count],
      "[Derived(entity: \"memo\", property: \"party\")]",
    )
  read_sql(derived_only, "db/queries/memo_count/items.sql") |> should.be_error
  let both =
    with_storage(
      article_fixture,
      [memo, count],
      "[Derived(entity: \"memo\", property: \"party\"), ReadFrom(entity: \"memo\", relation: \"memo_view\")]",
    )
  notes_of(both) |> should.equal([])
  let assert Ok(text) = read_sql(both, "db/queries/memo_count/items.sql")
  string.contains(text, "\nFROM app.memo_view m") |> should.be_true
  string.contains(text, "m.party=$") |> should.be_true

  let assert Ok(units) = source.load(relation_fixture)
  let assert Ok(photo) =
    list.find(units, fn(item) { item.path == "entity/photo" })
  // order を並び(OrderedBy)にしない Photo ── 並びの列は Derived にできない(条文)ので外す
  let assert [head, ..] = string.split(photo.text, "\n/// 順序列は値域つき")
  let photo = unit("entity/photo", head <> "\n")
  let pick =
    unit(
      "service/album_pick",
      "import yumemi/effect.{type Effect, Read}
import yumemi/step.{type Start, type Step}
import gen/face.{type Face, Test}
import gen/query as q
import gen/root/album_pick.{type Actor, type Root, type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [Test]

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

pub const items: q.Select(P) = q.Pick(columns: [q.AlbumId, q.AlbumTitle, q.PhotoCaption], select: q.Select(from: q.Album, join: [], where: [], group: [], having: [], agg: [], along: [], with: [q.AlbumToPhotos], order: [q.Asc(q.AlbumTitle)], limit: q.NoLimit))

pub const service: Service(Args, Out, Error) = Service(allow: [], logic: logic)

pub fn logic(_by: Actor, _it: Root, _args: Args) -> Step(Out, Error, Start) {
  step.done(Out)
}
",
    )
  let derived_only =
    with_storage(
      relation_fixture,
      [photo, pick],
      "[Derived(entity: \"photo\", property: \"order\")]",
    )
  read_sql(derived_only, "db/queries/album_pick/items.sql") |> should.be_error
  let both =
    with_storage(
      relation_fixture,
      [photo, pick],
      "[Derived(entity: \"photo\", property: \"order\"), ReadFrom(entity: \"photo\", relation: \"photo_view\")]",
    )
  notes_of(both) |> should.equal([])
  let assert Ok(text) = read_sql(both, "db/queries/album_pick/items.sql")
  string.contains(text, "\nFROM app.photo_view p\n") |> should.be_true
  string.contains(text, "ORDER BY p.\"order\",p.id") |> should.be_true
}

/// `ReadFrom` は宣言した Entity だけに効く:他の Entity の Derived の読みは 0.14.5 のまま止まる。
pub fn read_from_does_not_reach_other_entities_test() {
  let units =
    with_storage(
      article_fixture,
      [],
      "[Derived(entity: \"article\", property: \"body\"), ReadFrom(entity: \"category\", relation: \"category_view\")]",
    )
  notes_of(units) |> should.equal([])
  read_sql(units, "db/queries/article_list/items.sql") |> should.be_error
  has_note(sql_notes(units), "article_list/items: Article の行を生成の読みで渡せない")
  |> should.be_true
}

// ── 条文 ────────────────────────────────────────────────────────────────────

/// relation の名は SQL の素の識別子だけ。同じ Entity に 2 つ・`InObject` の Entity・無い Entity は止める。
pub fn read_from_stops_test() {
  let notes =
    notes_of(with_storage(
      article_fixture,
      [],
      "[ReadFrom(entity: \"article\", relation: \"Article_View\"), ReadFrom(entity: \"category\", relation: \"app.category_view\"), ReadFrom(entity: \"staff\", relation: \"a\"), ReadFrom(entity: \"staff\", relation: \"b\"), InObject(entity: \"tag\", object: \"TagDo\"), ReadFrom(entity: \"tag\", relation: \"tag_view\"), ReadFrom(entity: \"ghost\", relation: \"ghost_view\")]",
    ))
  [
    "storage article の ReadFrom の relation が SQL の素の識別子でない: Article_View",
    "storage category の ReadFrom の relation が SQL の素の識別子でない: app.category_view",
    "storage staff に ReadFrom が 2 つ以上",
    "storage tag は InObject(PG の表が無い)なのに ReadFrom がある",
    "storage の Entity が無い: ghost",
  ]
  |> list.each(fn(text) { has_note(notes, text) |> should.be_true })
  list.length(notes) |> should.equal(5)
}
