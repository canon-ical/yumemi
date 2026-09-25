//// yumemi-hw-1 ── back の宿題(逆向き矢印・無診断・allow 句・札の素通り・列の選択)。
//// fixture の units に合成の ★ を足して読み、SQL 層と型の層を同じ入力で見る。
//// `'draft'` 依存の直しの test は `yumemi_gen_test.gleam` の末尾(数える関数がそこに在る)。

import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import simplifile
import yumemi_gen/emit/hash
import yumemi_gen/emit/query
import yumemi_gen/emit/reads
import yumemi_gen/emit/sql
import yumemi_gen/emit/verb
import yumemi_gen/model
import yumemi_gen/reader
import yumemi_gen/source
import yumemi_gen/stop

const article_fixture = "fixtures/article"

const relation_fixture = "fixtures/relation"

const verb_fixture = "fixtures/verb_features"

// ── 下ごしらえ ──────────────────────────────────────────────────────────────

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

/// fixture の units に合成の units を足す(同じ path は置き換える)。
fn units_with(app_dir: String, extra: List(source.Unit)) -> List(source.Unit) {
  let assert Ok(units) = source.load(app_dir)
  let paths = list.map(extra, fn(item) { item.path })
  list.append(
    list.filter(units, fn(item) { !list.contains(paths, item.path) }),
    extra,
  )
}

type Out {
  Out(
    app: model.App,
    files: List(#(String, String)),
    skipped: List(sql.Skipped),
    notes: List(stop.Note),
  )
}

fn generate(units: List(source.Unit)) -> Out {
  let assert Ok(app) = reader.read(units)
  let hashes = hash.of(units)
  let #(sql_files, skipped) = sql.build(app, hashes)
  let files =
    list.flatten([
      sql_files,
      reads.emit(app, hashes),
      query.emit(app, hashes.entities),
    ])
    |> list.map(fn(file) { #(file.path, file.text) })
  Out(
    app: app,
    files: files,
    skipped: skipped,
    notes: list.append(sql.notes(app, hashes), verb.notes(app)),
  )
}

fn file(out: Out, path: String) -> String {
  let assert Ok(#(_, text)) = list.find(out.files, fn(item) { item.0 == path })
  text
}

fn has_file(out: Out, path: String) -> Bool {
  list.any(out.files, fn(item) { item.0 == path })
}

fn note_with(out: Out, text: String) -> stop.Note {
  let assert Ok(note) =
    list.find(out.notes, fn(note) { string.contains(note.text, text) })
  note
}

fn no_note_with(out: Out, text: String) -> Nil {
  list.any(out.notes, fn(note) { string.contains(note.text, text) })
  |> should.be_false
}

/// relation fixture の Service 1 本(Album / Photo を読む)。`body` は Select の const。
fn photo_service(name: String, body: String) -> source.Unit {
  unit("service/" <> name, "import entity/photo
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/face.{type Face, Test}
import gen/query as q
import gen/root/" <> name <> ".{type Actor, type Root, type Service, Service}

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

" <> body <> "

pub const service: Service(Args, Out, Error) = Service(allow: [], logic: logic)

pub fn logic(_by: Actor, _it: Root, _args: Args) -> Step(Out, Error, Start) {
  step.done(Out)
}
")
}

fn select(
  name: String,
  from: String,
  join: String,
  with: String,
  order: String,
  limit: String,
) -> String {
  "pub const "
  <> name
  <> ": q.Select(P) = "
  <> select_value(from, join, with, order, limit)
}

fn select_value(
  from: String,
  join: String,
  with: String,
  order: String,
  limit: String,
) -> String {
  "q.Select(
  from: q." <> from <> ",
  join: [" <> join <> "],
  where: [],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [" <> with <> "],
  order: [" <> order <> "],
  limit: " <> limit <> ",
)"
}

// ── 1. 逆向き矢印 ────────────────────────────────────────────────────────────

/// `with: [q.AlbumToPhotos]` の逆向きが型の層にも出る ── Arrow の末尾と、reads の組の末尾の List。
pub fn reverse_arrow_reaches_the_type_layer_test() {
  let out = generate(units_with(relation_fixture, []))
  let found = file(out, "src/gen/query.gleam")
  string.contains(found, "  PhotoToLabels\n  AlbumToPhotos\n}")
  |> should.be_true
  list.map(out.app.reverse_arrows, fn(arrow) {
    #(arrow.name, arrow.from_entity, arrow.prop, arrow.target_entity)
  })
  |> should.equal([#("AlbumToPhotos", "Album", "album", "Photo")])
  // 順向きの矢印の列には混ぜない(join / Has / root の矢印 read は順向きだけ)。
  model.arrow_by_name(out.app.arrows, "AlbumToPhotos") |> should.equal(None)
  let reads_text = file(out, "src/gen/reads/photo_filter.gleam")
  string.contains(reads_text, "List(#(album.Album, List(photo.Photo)))")
  |> should.be_true
  // SQL 層の欄と同じ並び(Album の列のあとに photos)。
  let sql_text = file(out, "db/queries/photo_filter/album_photos.sql")
  string.contains(sql_text, "SELECT a.*,COALESCE((SELECT jsonb_agg")
  |> should.be_true
}

/// 名が規則(`<親>To<子の短い名の複数形>`)に合わない with は、SQL 層も型の層も出さず exit 4。
pub fn misnamed_reverse_arrow_is_exit_four_on_both_layers_test() {
  let out =
    generate(
      units_with(relation_fixture, [
        photo_service(
          "album_pictures",
          select(
            "pictures",
            "Album",
            "",
            "q.AlbumToPictures",
            "q.Asc(q.AlbumId)",
            "q.NoLimit",
          ),
        ),
      ]),
    )
  let note = note_with(out, "album_pictures/pictures")
  note.class |> should.equal(stop.Conflict)
  string.contains(note.text, "with の逆向きが無い: AlbumToPictures")
  |> should.be_true
  has_file(out, "db/queries/album_pictures/pictures.sql") |> should.be_false
  string.contains(file(out, "src/gen/query.gleam"), "AlbumToPictures")
  |> should.be_false
  // 以前は候補が 1 本なら名を見ずに通していた。
  string.contains(
    file(out, "src/gen/reads/album_pictures.gleam"),
    "List(photo.Photo)",
  )
  |> should.be_false
}

// ── 2. 無診断 ────────────────────────────────────────────────────────────────

/// 構成子でない項(関数呼び出し・小文字の変数)は捨てずに exit 4 で名指しする。
pub fn unreadable_join_and_with_items_are_exit_four_test() {
  let out =
    generate(
      units_with(relation_fixture, [
        photo_service(
          "photo_odd",
          "const extra = q.PhotoToAlbum\n\n"
            <> select(
            "odd",
            "Photo",
            "extra",
            "q.AlbumToPhotos(1)",
            "q.Asc(q.PhotoId)",
            "q.NoLimit",
          ),
        ),
      ]),
    )
  let note = note_with(out, "photo_odd/odd")
  note.class |> should.equal(stop.Conflict)
  string.contains(note.text, "矢印として読めない項: join の 1 番目, with の 1 番目")
  |> should.be_true
  has_file(out, "db/queries/photo_odd/odd.sql") |> should.be_false
}

/// join に逆向き・Multi の矢印を書くと、型の層だけ組が伸びる形にせず exit 4。
pub fn join_of_reverse_or_multi_arrow_is_exit_four_test() {
  let out =
    generate(
      units_with(relation_fixture, [
        photo_service(
          "album_join",
          select(
            "reverse",
            "Album",
            "q.AlbumToPhotos",
            "",
            "q.Asc(q.AlbumId)",
            "q.NoLimit",
          )
            <> "\n\n"
            <> select(
            "multi",
            "Photo",
            "q.PhotoToLabels",
            "",
            "q.Asc(q.PhotoId)",
            "q.NoLimit",
          ),
        ),
      ]),
    )
  let reverse = note_with(out, "album_join/reverse")
  reverse.class |> should.equal(stop.Conflict)
  string.contains(reverse.text, "join に逆向きの矢印は書けない(with へ): AlbumToPhotos")
  |> should.be_true
  let multi = note_with(out, "album_join/multi")
  multi.class |> should.equal(stop.Conflict)
  string.contains(multi.text, "join の矢印が Multi(列が無い): PhotoToLabels")
  |> should.be_true
  // 型の層も同じ規則で解くので、解けない join を組に足さない。
  let reads_text = file(out, "src/gen/reads/album_join.gleam")
  string.contains(reads_text, "Label") |> should.be_false
}

// ── 3. allow 句 ──────────────────────────────────────────────────────────────

/// Article に Held、Staff(party が鍵)に Held を持つ合成の Entity。
fn memo_entity() -> source.Unit {
  unit(
    "entity/memo",
    "import entity/article.{type Article}
import entity/staff.{type Staff}
import framework/er.{type Held}
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
}

fn memo_service(
  name: String,
  allow_module: String,
  clauses: String,
) -> source.Unit {
  from_service(
    name,
    allow_module,
    clauses,
    "Memo",
    "q.Eq(q.MemoTitle, q.Param(Title))",
  )
}

fn from_service(
  name: String,
  allow_module: String,
  clauses: String,
  from: String,
  where: String,
) -> source.Unit {
  unit("service/" <> name, "import entity/article
import entity/memo
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/allow/" <> allow_module <> " as allow
import gen/face.{type Face, Public}
import gen/query as q
import gen/root/" <> name <> ".{type Actor, type Root, type Service, Service}

pub const effect: Effect = Read

pub const faces: List(Face) = [Public]

pub type Args {
  Args(title: String)
}

pub type Out {
  Out
}

pub type Error

pub type P {
  Title
}

pub const items: q.Select(P) = q.Select(
  from: q." <> from <> ",
  join: [],
  where: [" <> where <> "],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [],
  limit: q.NoLimit,
)

pub const service: Service(Args, Out, Error) = Service(
  allow: [" <> clauses <> "],
  logic: logic,
)

pub fn logic(_by: Actor, _it: Root, _args: Args) -> Step(Out, Error, Start) {
  step.done(Out)
}
")
}

/// root の無い Service の読みで、相と owner(`Via<Entity>Party`)を絞る allow 句が WHERE に入る。
/// from に居ない Entity は順向きの矢印 1 本の入れ子の EXISTS で辿る。穴は読みの穴の後ろ。
pub fn allow_clause_filters_phase_and_party_test() {
  let out =
    generate(
      units_with(article_fixture, [
        memo_entity(),
        memo_service(
          "memo_list",
          "article",
          "allow.Clause(who: allow.Anyone, at: allow.Only([article.Published]), owner: allow.ViaStaffParty),
    allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner)",
        ),
      ]),
    )
  let found = file(out, "db/queries/memo_list/items.sql")
  string.contains(found, "\n-- allow: clauses=$2 party=$3\nSELECT m.*\n")
  |> should.be_true
  string.contains(
    found,
    "WHERE m.title=$1 AND EXISTS(SELECT 1 FROM app.article a WHERE a.slug=m.article_id AND "
      <> "EXISTS(SELECT 1 FROM app.staff s WHERE s.party=m.staff_id AND "
      <> "EXISTS(SELECT 1 FROM jsonb_array_elements($2::jsonb) cl\n"
      <> " WHERE (cl->'phases'='null'::jsonb OR cl->'phases' ? a.phase)\n"
      <> " AND (cl->>'owner'='no_owner' OR (cl->>'owner'='via_staff_party' AND s.party=$3)))))",
  )
  |> should.be_true
  no_note_with(out, "memo_list/")
}

/// Article fixture の root の無い読み ── Only([Published]) の相だけを絞る(party の穴は無い)。
pub fn allow_clause_on_the_article_fixture_is_phase_only_test() {
  let out = generate(units_with(article_fixture, []))
  let found = file(out, "db/queries/article_list/items.sql")
  string.contains(found, "-- allow: clauses=$4\n") |> should.be_true
  string.contains(
    found,
    " AND EXISTS(SELECT 1 FROM jsonb_array_elements($4::jsonb) cl\n WHERE (cl->'phases'='null'::jsonb OR cl->'phases' ? a.phase))\nORDER BY",
  )
  |> should.be_true
  string.contains(found, "party") |> should.be_false
}

/// 絞らない allow(AnyPhase / NoOwner だけ)には入れない。
pub fn allow_without_restriction_adds_nothing_test() {
  let out =
    generate(
      units_with(article_fixture, [
        memo_entity(),
        memo_service(
          "memo_open",
          "article",
          "allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.NoOwner)",
        ),
      ]),
    )
  let found = file(out, "db/queries/memo_open/items.sql")
  string.contains(found, "allow") |> should.be_false
  string.contains(found, "jsonb_array_elements") |> should.be_false
}

/// 入れられない形は exit 4 ── Self の who が主体でない、Self の主体が allow の Entity と違い
/// from / join から辿れない(WGy r4)、相の無い Entity を Only で絞る、party の列が無い Entity、
/// from / join から辿れない Entity。どれも SQL を出さない。
pub fn allow_clause_that_cannot_be_placed_is_exit_four_test() {
  let out =
    generate(
      units_with(article_fixture, [
        memo_entity(),
        memo_service(
          "memo_self",
          "article",
          "allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.Self)",
        ),
        from_service(
          "staff_self_far",
          "memo",
          "allow.Clause(who: allow.AsArticle, at: allow.AnyPhase, owner: allow.Self)",
          "Staff",
          "",
        ),
        memo_service(
          "memo_phase",
          "staff",
          "allow.Clause(who: allow.Anyone, at: allow.Only([staff.Active]), owner: allow.NoOwner)",
        ),
        memo_service(
          "memo_party",
          "article",
          "allow.Clause(who: allow.Anyone, at: allow.AnyPhase, owner: allow.ViaCategoryParty)",
        ),
        from_service(
          "staff_far",
          "article",
          "allow.Clause(who: allow.Anyone, at: allow.Only([article.Published]), owner: allow.NoOwner)",
          "Staff",
          "",
        ),
      ]),
    )
  let self_note = note_with(out, "memo_self/items")
  self_note.class |> should.equal(stop.Conflict)
  string.contains(self_note.text, "owner Self の who が主体でない")
  |> should.be_true
  let self_far_note = note_with(out, "staff_self_far/items")
  self_far_note.class |> should.equal(stop.Conflict)
  string.contains(self_far_note.text, "allow 句の Article が from / join から辿れない")
  |> should.be_true
  let phase_note = note_with(out, "memo_phase/items")
  phase_note.class |> should.equal(stop.Conflict)
  string.contains(phase_note.text, "Staff に相が無い") |> should.be_true
  let party_note = note_with(out, "memo_party/items")
  party_note.class |> should.equal(stop.Conflict)
  string.contains(party_note.text, "Category に party の列が無い")
  |> should.be_true
  let far_note = note_with(out, "staff_far/items")
  far_note.class |> should.equal(stop.Conflict)
  string.contains(far_note.text, "allow 句の Article が from / join から辿れない")
  |> should.be_true
  ["memo_self", "staff_self_far", "memo_phase", "memo_party", "staff_far"]
  |> list.each(fn(name) {
    has_file(out, "db/queries/" <> name <> "/items.sql") |> should.be_false
  })
}

/// root を持つ Service(article_read)には入れない ── 句は root の 1 文(本便の外)の持ち分。
pub fn allow_clause_skips_rooted_services_test() {
  let out =
    generate(
      units_with(article_fixture, [
        memo_entity(),
        unit(
          "service/memo_rooted",
          "import entity/article
import entity/memo
import framework/effect.{type Effect, Read}
import framework/step.{type Start, type Step}
import gen/allow/article as allow
import gen/face.{type Face, Public}
import gen/query as q
import gen/root/memo_rooted.{type Actor, type Root, type Service, Service}
import gen/types/slug.{type Slug}

pub const effect: Effect = Read

pub const faces: List(Face) = [Public]

pub type Args {
  Args(slug: Slug)
}

pub type Out {
  Out
}

pub type Error

pub type P {
  Title
}

pub const items: q.Select(P) = q.Select(
  from: q.Memo,
  join: [],
  where: [q.Eq(q.MemoTitle, q.Param(Title))],
  group: [],
  having: [],
  agg: [],
  along: [],
  with: [],
  order: [],
  limit: q.NoLimit,
)

pub const service: Service(Args, Out, Error) = Service(
  allow: [allow.Clause(who: allow.Anyone, at: allow.Only([article.Published]), owner: allow.Self)],
  logic: logic,
)

pub fn logic(_by: Actor, _it: Root, _args: Args) -> Step(Out, Error, Start) {
  step.done(Out)
}
",
        ),
      ]),
    )
  let found = file(out, "db/queries/memo_rooted/items.sql")
  string.contains(found, "allow") |> should.be_false
  no_note_with(out, "memo_rooted/items")
}

// ── 4. 札の素通り(manual_verbs)─────────────────────────────────────────────

fn with_entity_constant(
  app_dir: String,
  path: String,
  constant: String,
) -> List(source.Unit) {
  let assert Ok(units) = source.load(app_dir)
  let assert Ok(found) = list.find(units, fn(item) { item.path == path })
  units_with(app_dir, [unit(path, found.text <> "\n" <> constant <> "\n")])
}

/// 生成候補を持たない手書き verb は manual_verbs に載せると警告が消え、ヘッダの `handwritten:` に載る。
pub fn manual_verbs_are_quiet_and_listed_in_the_header_test() {
  let units =
    with_entity_constant(
      article_fixture,
      "entity/article",
      "pub const manual_verbs: List(String) = [\"rebuild_article_index\"]",
    )
  let assert Ok(app) = reader.read(units)
  let assert Some(article) = model.entity_by_name(app.entities, "Article")
  article.manual_verbs |> should.equal(["rebuild_article_index"])
  verb.notes(app)
  |> list.filter(fn(note) {
    string.contains(note.text, "rebuild_article_index")
  })
  |> should.equal([])
  let assert [generated] = verb.emit(app, hash.of(units))
  string.contains(generated.text, "//// manual: rebuild_article_index\n")
  |> should.be_true
}

/// ER の外の module の manual_verbs も同じ(ヘッダに載り、警告は出ない)。
pub fn external_manual_verbs_are_quiet_test() {
  let units =
    with_entity_constant(
      verb_fixture,
      "ledger",
      "pub const manual_verbs: List(String) = [\"rollup_ledger\"]",
    )
  let assert Ok(app) = reader.read(units)
  app.manual_verbs |> should.equal([#("ledger", ["rollup_ledger"])])
  verb.notes(app)
  |> list.any(fn(note) { string.contains(note.text, "rollup_ledger") })
  |> should.be_false
  let assert [generated] = verb.emit(app, hash.of(units))
  string.contains(generated.text, "rollup_ledger") |> should.be_true
}

/// manual_verbs の名が生成候補と一致したら exit 4(打ち間違いを黙って通さない)。
pub fn manual_verb_matching_a_candidate_is_exit_four_test() {
  let units =
    with_entity_constant(
      article_fixture,
      "entity/article",
      "pub const manual_verbs: List(String) = [\"pin_article\"]",
    )
  let assert Ok(app) = reader.read(units)
  let assert [note] =
    verb.notes(app)
    |> list.filter(fn(note) { string.contains(note.text, "pin_article") })
  note.class |> should.equal(stop.Conflict)
  string.contains(note.text, "article: manual_verbs の名が生成候補と一致する: pin_article")
  |> should.be_true
}

/// handwritten_verbs の未一致の警告は残し、文言で manual_verbs を名指しする。
pub fn handwritten_mismatch_warning_names_manual_verbs_test() {
  let units =
    with_entity_constant(
      article_fixture,
      "entity/article",
      "pub const handwritten_verbs: List(String) = [\"rebuild_article_index\"]",
    )
  let assert Ok(app) = reader.read(units)
  let assert [note] =
    verb.notes(app)
    |> list.filter(fn(note) {
      string.contains(note.text, "rebuild_article_index")
    })
  note.class |> should.equal(stop.Warning)
  string.contains(note.text, "handwritten_verbs に生成名が無い")
  |> should.be_true
  string.contains(note.text, "manual_verbs へ") |> should.be_true
}

// ── 6. 列の選択(q.Pick)─────────────────────────────────────────────────────

fn pick(name: String, columns: String, inner: String) -> String {
  "pub const "
  <> name
  <> ": q.Select(P) = q.Pick(columns: ["
  <> columns
  <> "], select: "
  <> inner
  <> ")"
}

/// 選んだ列だけを返し、reads の戻りは選んだ列の record。欄の名は SQL の AS と同じ。
pub fn pick_returns_only_the_chosen_columns_test() {
  let out =
    generate(
      units_with(relation_fixture, [
        photo_service(
          "photo_pick",
          pick(
            "captions",
            "q.PhotoId, q.PhotoCaption, q.PhotoOrder, q.AlbumTitle",
            select_value(
              "Photo",
              "q.PhotoToAlbum",
              "",
              "q.Asc(q.PhotoOrder)",
              "q.NoLimit",
            ),
          ),
        ),
      ]),
    )
  let found = file(out, "db/queries/photo_pick/captions.sql")
  string.contains(
    found,
    "SELECT p.id AS id,p.caption AS caption,p.\"order\" AS \"order\",a.title AS album_title\nFROM app.photo p\nJOIN app.album a ON a.id=p.album_id\n",
  )
  |> should.be_true
  string.contains(found, "p.*") |> should.be_false
  string.contains(found, "to_jsonb") |> should.be_false
  let reads_text = file(out, "src/gen/reads/photo_pick.gleam")
  string.contains(
    reads_text,
    "pub type CaptionsRow {\n  CaptionsRow(\n    id: PhotoId,\n    caption: PhotoCaption,\n    order: PhotoOrder,\n    album_title: AlbumTitle,\n  )\n}",
  )
  |> should.be_true
  string.contains(reads_text, "then then: fn(List(CaptionsRow))")
  |> should.be_true
  no_note_with(out, "photo_pick/")
}

/// with と Pick ── 子の List は record の末尾の欄(SQL の AS と同じ名)。from の key は要る。
pub fn pick_keeps_with_children_as_a_field_test() {
  let out =
    generate(
      units_with(relation_fixture, [
        photo_service(
          "album_pick",
          pick(
            "listed",
            "q.AlbumId, q.AlbumTitle",
            select_value(
              "Album",
              "",
              "q.AlbumToPhotos",
              "q.Asc(q.AlbumTitle)",
              "q.NoLimit",
            ),
          ),
        ),
      ]),
    )
  let found = file(out, "db/queries/album_pick/listed.sql")
  string.contains(
    found,
    "SELECT a.id AS id,a.title AS title,COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.\"order\",p.id)",
  )
  |> should.be_true
  string.contains(found, "),'[]'::jsonb) AS photos\n") |> should.be_true
  let reads_text = file(out, "src/gen/reads/album_pick.gleam")
  string.contains(
    reads_text,
    "  ListedRow(\n    id: AlbumId,\n    title: AlbumTitle,\n    photos: List(photo.Photo),\n  )",
  )
  |> should.be_true
}

/// 選べない形は exit 4 で SQL を出さない。
pub fn pick_that_cannot_be_chosen_is_exit_four_test() {
  let out =
    generate(
      units_with(relation_fixture, [
        photo_service(
          "photo_bad",
          string.join(
            [
              pick("empty", "", select_value("Photo", "", "", "", "q.NoLimit")),
              pick(
                "outside",
                "q.PhotoId, q.AlbumTitle",
                select_value("Photo", "", "", "", "q.NoLimit"),
              ),
              pick(
                "unordered",
                "q.PhotoId",
                select_value(
                  "Photo",
                  "",
                  "",
                  "q.Asc(q.PhotoCaption)",
                  "q.NoLimit",
                ),
              ),
              pick(
                "paged",
                "q.PhotoCaption",
                select_value(
                  "Photo",
                  "",
                  "",
                  "q.Asc(q.PhotoCaption)",
                  "q.Paged(size: q.Num(20), after: q.Param(Name))",
                ),
              ),
              pick(
                "children",
                "q.AlbumTitle",
                select_value("Album", "", "q.AlbumToPhotos", "", "q.NoLimit"),
              ),
              pick(
                "twice",
                "q.PhotoId, q.PhotoId",
                select_value("Photo", "", "", "", "q.NoLimit"),
              ),
            ],
            "\n\n",
          ),
        ),
      ]),
    )
  [
    #("photo_bad/empty", "列の選択が空"),
    #("photo_bad/outside", "列 AlbumTitle の Entity が from にも join にも無い"),
    #("photo_bad/unordered", "列の選択が order の要る列を落とす: PhotoCaption"),
    #("photo_bad/paged", "列の選択が keyset の要る列を落とす: PhotoId"),
    #("photo_bad/children", "列の選択が with の要る列を落とす: AlbumId"),
    #("photo_bad/twice", "列の選択に重複: PhotoId"),
  ]
  |> list.each(fn(entry) {
    let #(where, text) = entry
    let note = note_with(out, where <> ":")
    note.class |> should.equal(stop.Conflict)
    string.contains(note.text, text) |> should.be_true
  })
  list.filter(out.files, fn(item) {
    string.starts_with(item.0, "db/queries/photo_bad/")
  })
  |> should.equal([])
}

/// 非破壊 ── Pick を使わない読みの SQL と reads は変わらない(`q.Select` の literal はそのまま)。
/// 語彙の側は `Select` に `Pick` の構成子が 1 つ増えるだけ。
pub fn pick_is_non_destructive_for_plain_selects_test() {
  let out = generate(units_with(relation_fixture, []))
  string.contains(
    file(out, "src/gen/query.gleam"),
    "    limit: Limit(p),\n  )\n  Pick(columns: List(Field), select: Select(p))\n}\n",
  )
  |> should.be_true
  out.app.services
  |> list.flat_map(fn(service) { service.queries })
  |> list.all(fn(query) { query.select.columns == None })
  |> should.be_true
  string.contains(
    file(out, "db/queries/photo_filter/related.sql"),
    "SELECT p.*\n",
  )
  |> should.be_true
}

// ── r2 P0-1 allow 句を定数に包む・spread で書く ──────────────────────────────────

/// Service の module に const を足す(`pub const service` の直前)。
fn with_prelude(found: source.Unit, prelude: String) -> source.Unit {
  unit(
    found.path,
    string.replace(
      found.text,
      "pub const service",
      prelude <> "\n\npub const service",
    ),
  )
}

const published_only = "allow.Clause(who: allow.Anyone, at: allow.Only([article.Published]), owner: allow.NoOwner)"

/// 句を module の const に包むと、中身を読まずに「絞らない句」と取り違えていた
/// (allow 句が SQL から消えて exit 0)。読めない句として exit 4 で名指しし、SQL を出さない。
pub fn allow_clause_wrapped_in_a_constant_is_exit_four_test() {
  let out =
    generate(
      units_with(article_fixture, [
        memo_entity(),
        memo_service("memo_const", "article", "published_only")
          |> with_prelude("const published_only = " <> published_only),
        memo_service("memo_foreign", "article", "shared.published_only"),
        memo_service(
          "memo_call",
          "article",
          "allow.clause_of(article.Published)",
        ),
      ]),
    )
  let note = note_with(out, "memo_const/items")
  note.class |> should.equal(stop.Conflict)
  string.contains(note.text, "allow の句が読めない: allow の句 published_only")
  |> should.be_true
  string.contains(
    note_with(out, "memo_foreign/items").text,
    "allow の句が読めない: allow の句 published_only",
  )
  |> should.be_true
  string.contains(
    note_with(out, "memo_call/items").text,
    "allow の句が読めない: allow の句 clause_of",
  )
  |> should.be_true
  ["memo_const", "memo_foreign", "memo_call"]
  |> list.each(fn(name) {
    has_file(out, "db/queries/" <> name <> "/items.sql") |> should.be_false
  })
}

/// `allow: [allow.staff, ..public_clauses]` の spread の後ろは読めない ── exit 4、SQL を出さない。
/// `Only([..])` の spread も同じ。
pub fn allow_clause_spread_is_exit_four_test() {
  let out =
    generate(
      units_with(article_fixture, [
        memo_entity(),
        memo_service("memo_spread", "article", "allow.staff, ..public_clauses")
          |> with_prelude("const public_clauses = [" <> published_only <> "]"),
        memo_service(
          "memo_phases",
          "article",
          "allow.Clause(who: allow.Anyone, at: allow.Only([article.Published, ..more]), owner: allow.NoOwner)",
        ),
      ]),
    )
  let note = note_with(out, "memo_spread/items")
  note.class |> should.equal(stop.Conflict)
  string.contains(note.text, "allow の句が読めない: allow の spread(..)")
  |> should.be_true
  string.contains(
    note_with(out, "memo_phases/items").text,
    "allow の at が読めない: Only の引数",
  )
  |> should.be_true
  has_file(out, "db/queries/memo_spread/items.sql") |> should.be_false
  has_file(out, "db/queries/memo_phases/items.sql") |> should.be_false
}

/// 略記として読む形(大文字の構成子、allow の import の句)は今までどおり通る。
pub fn allow_shorthand_is_still_read_test() {
  let out =
    generate(
      units_with(article_fixture, [
        memo_entity(),
        memo_service(
          "memo_short",
          "article",
          "allow.staff, allow.Anyone, Anyone, " <> published_only,
        ),
      ]),
    )
  no_note_with(out, "memo_short/")
  string.contains(
    file(out, "db/queries/memo_short/items.sql"),
    "-- allow: clauses=$2\n",
  )
  |> should.be_true
}

// ── r2 P1-4 join / with / where が List の literal でない ─────────────────────

fn photo_select(name: String, join: String, where: String, with: String) {
  "pub const " <> name <> ": q.Select(P) = q.Select(
  from: q.Album,
  join: " <> join <> ",
  where: " <> where <> ",
  group: [],
  having: [],
  agg: [],
  along: [],
  with: " <> with <> ",
  order: [q.Asc(q.AlbumId)],
  limit: q.NoLimit,
)"
}

/// 定数の参照・spread・読めない条件は、読めた項だけで SQL を出すと絞りや欄が黙って消える。
/// 両方の層で exit 4 にし、SQL を出さない。
pub fn non_literal_select_lists_are_exit_four_test() {
  let named = "q.Eq(q.AlbumTitle, q.Param(Name))"
  let out =
    generate(
      units_with(relation_fixture, [
        photo_service(
          "album_loose",
          "const narrow = [q.Eq(q.AlbumTitle, q.Param(Name))]\n\n"
            <> "const one = q.Eq(q.AlbumTitle, q.Param(Name))\n\n"
            <> photo_select("by_const", "[]", "narrow", "[]")
            <> "\n\n"
            <> photo_select(
            "by_spread",
            "[]",
            "[" <> named <> ", ..narrow]",
            "[]",
          )
            <> "\n\n"
            <> photo_select("by_item", "[]", "[one]", "[]")
            <> "\n\n"
            <> photo_select(
            "by_has",
            "[]",
            "[q.Has(q.PhotoToAlbum, narrow)]",
            "[]",
          )
            <> "\n\n"
            <> photo_select("with_const", "[]", "[]", "children")
            <> "\n\n"
            <> photo_select("with_spread", "[]", "[]", "[..children]")
            <> "\n\n"
            <> photo_select("join_const", "joins", "[]", "[]"),
        ),
      ]),
    )
  [
    #("by_const", "読めない項: where が List の literal でない"),
    #("by_spread", "読めない項: where の spread(..)"),
    #("by_item", "読めない項: where の 1 番目(条件として読めない)"),
    #("by_has", "読めない項: where の 1 番目 の条件が List の literal でない"),
    #("with_const", "読めない項: with が List の literal でない"),
    #("with_spread", "読めない項: with の spread(..)"),
    #("join_const", "読めない項: join が List の literal でない"),
  ]
  |> list.each(fn(pair) {
    let note = note_with(out, "album_loose/" <> pair.0)
    note.class |> should.equal(stop.Conflict)
    string.contains(note.text, pair.1) |> should.be_true
    has_file(out, "db/queries/album_loose/" <> pair.0 <> ".sql")
    |> should.be_false
  })
}

// ── r2 3 framework の Select と生成の Select を 1 対 1 に戻す ─────────────────────

/// 構成子の名とラベル(ラベルの無い欄は "_")。
fn variants_of(
  module: glance.Module,
  name: String,
) -> List(#(String, List(String))) {
  let assert Ok(found) =
    list.find(module.custom_types, fn(definition) {
      definition.definition.name == name
    })
  list.map(found.definition.variants, fn(variant) {
    #(
      variant.name,
      list.map(variant.fields, fn(field) {
        case field {
          glance.LabelledVariantField(label: label, ..) -> label
          glance.UnlabelledVariantField(..) -> "_"
        }
      }),
    )
  })
}

/// framework/query.gleam の語彙と生成の gen/query.gleam の語彙は、構成子の名とラベルが
/// 1 対 1(Operand は生成側が PhaseOf / KeyOf を足すので、framework の構成子を含むこと)。
/// `Select` の `Pick` も framework に在る(役員 人見 09-25 の裁定)。
pub fn framework_query_is_one_to_one_with_the_generated_query_test() {
  let assert Ok(framework_text) =
    simplifile.read("../src/framework/query.gleam")
  let assert Ok(framework) = glance.module(framework_text)
  let out = generate(units_with(relation_fixture, []))
  let assert Ok(generated) = glance.module(file(out, "src/gen/query.gleam"))
  [
    "Cond", "Agg", "CondAgg", "Unit", "Group", "Order", "Along", "Limit",
    "Select",
  ]
  |> list.each(fn(name) {
    variants_of(generated, name) |> should.equal(variants_of(framework, name))
  })
  variants_of(framework, "Select")
  |> should.equal([
    #("Select", [
      "from", "join", "where", "group", "having", "agg", "along", "with",
      "order", "limit",
    ]),
    #("Pick", ["columns", "select"]),
  ])
  let generated_operands = variants_of(generated, "Operand")
  variants_of(framework, "Operand")
  |> list.all(fn(variant) { list.contains(generated_operands, variant) })
  |> should.be_true
}

// ── r2 4 Pick を with の子に届かせる ──────────────────────────────────────────

/// columns に with の子の列を混ぜると、子は `jsonb_build_object` で選んだ列だけを返し、
/// reads の欄は子の record の List になる。子の列を選ばなければ従来どおり `to_jsonb`(全列)。
pub fn pick_reaches_with_children_test() {
  let out =
    generate(
      units_with(relation_fixture, [
        photo_service(
          "album_thin",
          pick(
            "listed",
            "q.AlbumId, q.AlbumTitle, q.PhotoCaption, q.PhotoOrder",
            select_value(
              "Album",
              "",
              "q.AlbumToPhotos",
              "q.Asc(q.AlbumTitle)",
              "q.NoLimit",
            ),
          ),
        ),
      ]),
    )
  let found = file(out, "db/queries/album_thin/listed.sql")
  string.contains(
    found,
    "SELECT a.id AS id,a.title AS title,COALESCE((SELECT jsonb_agg(jsonb_build_object('caption',p.caption,'order',p.\"order\") ORDER BY p.\"order\",p.id)\nFROM app.photo p\nWHERE p.album_id=a.id),'[]'::jsonb) AS photos\n",
  )
  |> should.be_true
  string.contains(found, "to_jsonb") |> should.be_false
  let reads_text = file(out, "src/gen/reads/album_thin.gleam")
  string.contains(
    reads_text,
    "  ListedRow(\n    id: AlbumId,\n    title: AlbumTitle,\n    photos: List(ListedPhotosRow),\n  )",
  )
  |> should.be_true
  string.contains(
    reads_text,
    "pub type ListedPhotosRow {\n  ListedPhotosRow(\n    caption: PhotoCaption,\n    order: PhotoOrder,\n  )\n}",
  )
  |> should.be_true
  no_note_with(out, "album_thin/")
}

/// 子の列を選べない形は exit 4 ── 同じ Entity が行と子に居て列の持ち主が決まらない、
/// from / join / with のどれにも無い列。どれも SQL を出さない。
pub fn pick_of_child_columns_that_cannot_be_chosen_is_exit_four_test() {
  let out =
    generate(
      units_with(relation_fixture, [
        photo_service(
          "album_odd",
          string.join(
            [
              pick(
                "twice",
                "q.AlbumId, q.PhotoCaption",
                select_value(
                  "Album",
                  "",
                  "q.AlbumToPhotos, q.AlbumToPhotos",
                  "",
                  "q.NoLimit",
                ),
              ),
              pick(
                "stray",
                "q.AlbumId, q.ShelfName",
                select_value("Album", "", "q.AlbumToPhotos", "", "q.NoLimit"),
              ),
            ],
            "\n\n",
          ),
        ),
      ]),
    )
  string.contains(
    note_with(out, "album_odd/stray:").text,
    "列 ShelfName の Entity が from にも join にも無い(with の子にも無い)",
  )
  |> should.be_true
  string.contains(
    note_with(out, "album_odd/twice:").text,
    "列の選択の列 PhotoCaption の Entity が from / join と with の子(または with の子 2 本)に居て",
  )
  |> should.be_true
  has_file(out, "db/queries/album_odd/stray.sql") |> should.be_false
  has_file(out, "db/queries/album_odd/twice.sql") |> should.be_false
}

/// owner `Self` で、句の `As<X>` の X が allow の Entity と違う形(WGy の裁定 4、r4)── 「その行の X が
/// 自分」の意味なので主体の鍵の穴 `subject=$K` を足し、X の key の列と比べる。柏木の再現
/// (`gen/allow/memo` × `AsStaff` × `Self`)と、allow が別の Entity の形(`gen/allow/article`)の 2 つ。
pub fn allow_clause_self_on_another_entity_uses_the_subject_key_hole_test() {
  let out =
    generate(
      units_with(article_fixture, [
        memo_entity(),
        memo_service(
          "memo_self",
          "memo",
          "allow.Clause(who: allow.AsStaff, at: allow.AnyPhase, owner: allow.Self)",
        ),
        memo_service(
          "memo_self_article",
          "article",
          "allow.Clause(who: allow.AsStaff, at: allow.AnyPhase, owner: allow.Self)",
        ),
      ]),
    )
  ["memo_self", "memo_self_article"]
  |> list.each(fn(name) {
    let found = file(out, "db/queries/" <> name <> "/items.sql")
    string.contains(found, "-- allow: clauses=$2 subject=$3") |> should.be_true
    string.contains(found, "->>'owner'='self' AND ") |> should.be_true
    string.contains(found, "=$3)") |> should.be_true
    no_note_with(out, name <> "/items")
  })
}

/// owner `Self` で、どの句の `As<X>` も allow の Entity そのもの(主体の行 = allow の行)の形(WGy r3)──
/// `Self` は主体(actor)を絞る句で、読みの行を絞らない(基点の SQL と同じ意味)。穴の契約も持たない。
pub fn allow_clause_self_on_the_subject_entity_leaves_rows_open_test() {
  let out =
    generate(
      units_with(article_fixture, [
        memo_entity(),
        memo_service(
          "memo_self",
          "staff",
          "allow.Clause(who: allow.AsStaff, at: allow.AnyPhase, owner: allow.Self)",
        ),
      ]),
    )
  let found = file(out, "db/queries/memo_self/items.sql")
  string.contains(found, "-- allow:") |> should.be_false
  string.contains(found, "->>'owner'") |> should.be_false
  no_note_with(out, "memo_self/items")
}
