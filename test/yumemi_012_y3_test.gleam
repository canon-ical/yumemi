//// 0.12 段 C(便 yumemi-012-y3)── interactive Component の宣言と条文(51 v6 第 4〜6・9〜22・26・28〜31・41・43 条)、
//// 逃げ道の数えの抜け道、lock の照合、queue の consumer の基、runtime の Args の送り方。

import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import simplifile
import yumemi/front/attr
import yumemi/front/el
import yumemi/front/html
import yumemi/front/live as front_live
import yumemi/gen as yumemi_gen
import yumemi/gen/emit/back
import yumemi/gen/emit/front as front_emit
import yumemi/gen/emit/hash
import yumemi/gen/face
import yumemi/gen/raw_css
import yumemi/gen/reader
import yumemi/gen/reader/front
import yumemi/gen/source
import yumemi/gen/stop

const fixture = "gen/fixtures/article"

const public = "gen/fixtures/article/public"

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

fn replace(
  units: List(source.Unit),
  extra: List(source.Unit),
) -> List(source.Unit) {
  let paths = list.map(extra, fn(item) { item.path })
  units
  |> list.filter(fn(item) { !list.contains(paths, item.path) })
  |> list.append(extra)
}

/// fixture の public に `extra` を足して読んだ、reader・interactive・面の条文の停止を全部。
fn notes_at(package_path: String, extra: List(source.Unit)) -> List(stop.Note) {
  let assert Ok(back_units) = source.load(fixture)
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(units) = source.load(public)
  let units = replace(units, extra)
  let assert Ok(model) = front.read("public", units, app.services)
  let package =
    face.Package(
      name: "public",
      path: package_path,
      pages: face.UndeclaredPages,
      units: units,
    )
  list.flatten([
    front.notes(model, app.services),
    front_emit.interactive_notes(
      app,
      back_units,
      package,
      model,
      hash.of(back_units),
    ),
    front_emit.surface_notes(app, back_units, package, model),
  ])
}

fn notes_with(extra: List(source.Unit)) -> List(stop.Note) {
  notes_at(public, extra)
}

fn with(notes: List(stop.Note), text: String) -> List(stop.Note) {
  list.filter(notes, fn(note) { string.contains(note.text, text) })
}

/// 条文の印を持つ停止が 1 つ以上あり、停止コードが `code`。
fn stops(notes: List(stop.Note), clause: String, code: Int) -> Nil {
  let found = with(notes, clause)
  { found != [] } |> should.be_true
  stop.worst(found) |> should.equal(code)
}

/// body に出る live の別名だけを import する(余分な live の import は第 19 条に当たる)。
fn live_imports(body: String) -> String {
  [
    #("publish", "article_publish"),
    #("create", "article_create"),
    #("title", "article_title"),
    #("read", "article_read"),
    #("save", "article_blob_save"),
  ]
  |> list.filter(fn(pair) { string.contains(body, pair.0 <> ".") })
  |> list.map(fn(pair) {
    "import gen/live/" <> pair.1 <> " as " <> pair.0 <> "\n"
  })
  |> string.concat
}

const imports = "import gen/route
import gen/service
import gleam/option.{None, Some}
import yumemi/front/attr
import yumemi/front/css
import yumemi/front/el
import yumemi/front/html
import yumemi/front/live
"

fn component(name: String, body: String) -> source.Unit {
  unit("components/" <> name, live_imports(body) <> imports <> body)
}

const publish_calls = "pub const calls: List(service.Service) = [service.ArticlePublish]\n"

const publish_after = "pub const after_send: List(#(service.Service, live.After(route.Route))) = [#(service.ArticlePublish, live.After(ok: live.Stay, error: live.Stay))]\n"

const publish_view = "pub fn view(_p: publish.Args) -> el.Element { publish.send(css.class([]), [el.text(\"x\")]) }\n"

// ── 基準:正しい形の Component は止まらない ─────────────────────────────────

pub fn a_well_formed_component_does_not_stop_test() {
  let notes =
    notes_with([
      component("probe_one", publish_calls <> publish_after <> publish_view),
    ])
  with(notes, "probe_one") |> should.equal([])
  // fixture の Component 7 本も止まらない(entry を渡さない読みの [変数 2] は面の条文の外)
  list.filter(notes, fn(note) {
    note.class != stop.Warning && string.contains(note.text, "components/")
  })
  |> should.equal([])
}

// ── interactive Component(第 9〜18 条)──────────────────────────────────────

pub fn article_9_pub_fn_app_stops_test() {
  notes_with([
    component(
      "probe_one",
      publish_calls <> publish_after <> publish_view <> "pub fn app() { Nil }\n",
    ),
  ])
  |> stops("第 9 条", 4)
}

pub fn article_10_calls_literal_and_unique_test() {
  notes_with([
    component(
      "probe_one",
      "pub const calls: List(service.Service) = [service.ArticlePublish, service.ArticlePublish]\n"
        <> publish_after
        <> "pub fn view(_p: publish.Args, _q: publish.Args) -> el.Element { publish.send(css.class([]), []) }\n",
    ),
  ])
  |> stops("第 10 条", 4)
  notes_with([
    component(
      "probe_one",
      "pub const calls: List(service.Service) = []\n" <> publish_view,
    ),
  ])
  |> stops("第 10 条", 4)
}

pub fn article_11_view_takes_calls_args_in_order_test() {
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub fn view(_c: create.Args) -> el.Element { el.none() }\n",
    ),
  ])
  |> stops("第 11 条", 4)
  // 末尾の with は `With` の型で、名は with
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub type With { With(label: String) }\n"
        <> "pub fn view(_p: publish.Args, other: With) -> el.Element { publish.send(css.class([]), [el.text(other.label)]) }\n",
    ),
  ])
  |> stops("第 11 条", 4)
}

pub fn article_12_after_send_rows_test() {
  // 書きの Service の組が無い(3)
  notes_with([component("probe_one", publish_calls <> publish_view)])
  |> stops("第 12 条", 3)
  // 読みの Service の組(4)
  notes_with([
    component(
      "probe_one",
      "pub const calls: List(service.Service) = [service.ArticlePublish, service.ArticleTitle]\n"
        <> "pub const after_send: List(#(service.Service, live.After(route.Route))) = [#(service.ArticlePublish, live.After(ok: live.Stay, error: live.Stay)), #(service.ArticleTitle, live.After(ok: live.Stay, error: live.Stay))]\n"
        <> "pub fn view(_p: publish.Args, _t: title.Args) -> el.Element { el.fragment([publish.send(css.class([]), []), title.send(css.class([]), [])]) }\n",
    ),
  ])
  |> stops("第 12 条", 4)
}

pub fn article_13_bind_literal_and_one_per_element_test() {
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub fn view(p: publish.Args) -> el.Element { html.input_([publish.bind(publish.Slug, p.slug), publish.bind(publish.Slug, p.slug)]) |> fn(x) { el.fragment([x, publish.send(css.class([]), [])]) } }\n",
    ),
  ])
  |> stops("第 13 条", 4)
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub fn view(p: publish.Args) -> el.Element { let f = publish.Slug\n el.fragment([html.input_([publish.bind(f, p.slug)]), publish.send(css.class([]), [])]) }\n",
    ),
  ])
  |> stops("第 13 条", 4)
}

pub fn article_14_non_list_field_bound_twice_test() {
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub fn view(p: publish.Args) -> el.Element { el.fragment([html.input_([publish.bind(publish.Slug, p.slug)]), html.input_([publish.bind(publish.Slug, p.slug)]), publish.send(css.class([]), [])]) }\n",
    ),
  ])
  |> stops("第 14 条", 4)
}

pub fn article_15_goto_holes_come_from_out_test() {
  // article_blob_save の Out(saved)に slug が無い
  notes_with([
    component(
      "probe_one",
      "pub const calls: List(service.Service) = [service.ArticleBlobSave]\n"
        <> "pub const after_send: List(#(service.Service, live.After(route.Route))) = [#(service.ArticleBlobSave, live.After(ok: live.GoTo(route.ArticleArgSlug, notice: None), error: live.Stay))]\n"
        <> "pub fn view(_s: save.Args) -> el.Element { save.send(css.class([]), []) }\n",
    ),
  ])
  |> stops("第 15 条", 4)
  // article_publish の Out(Article)には slug がある
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> "pub const after_send: List(#(service.Service, live.After(route.Route))) = [#(service.ArticlePublish, live.After(ok: live.GoTo(route.ArticleArgSlug, notice: None), error: live.Stay))]\n"
        <> publish_view,
    ),
  ])
  |> with("第 15 条")
  |> should.equal([])
}

pub fn article_16_notice_needs_el_notice_in_layout_test() {
  notes_with([
    unit(
      "blocks/site_header",
      "import yumemi/front/css\nimport yumemi/front/el\nimport yumemi/front/html\npub type In = Nil\n"
        <> "pub fn view(_it: In) -> el.Element { html.header(css.class([]), [], [el.text(\"x\")]) }\n",
    ),
  ])
  |> stops("第 16 条", 3)
}

pub fn article_17_reloads_test() {
  // read が calls に無い
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub const reloads: live.Reloads(service.Service, title.Field) = live.Reloads(read: service.ArticleTitle, on: [title.Slug])\n"
        <> publish_view,
    ),
  ])
  |> stops("第 17 条", 4)
  // read が書きの Service
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub const reloads: live.Reloads(service.Service, publish.Field) = live.Reloads(read: service.ArticlePublish, on: [publish.Slug])\n"
        <> publish_view,
    ),
  ])
  |> stops("第 17 条", 4)
  // on が空
  notes_with([
    component(
      "probe_one",
      "pub const calls: List(service.Service) = [service.ArticleTitle]\n"
        <> "pub const reloads: live.Reloads(service.Service, title.Field) = live.Reloads(read: service.ArticleTitle, on: [])\n"
        <> "pub fn view(_t: title.Args) -> el.Element { el.none() }\n",
    ),
  ])
  |> stops("第 17 条", 4)
}

pub fn article_17_list_reloads_need_the_query_var_test() {
  // fixture の tag_filter(Layout の Feed に置く widget_list の一覧)の on を slug に替える。Page の slug は
  // Path なので Query の Var が無い
  let assert Ok(text) =
    simplifile.read(public <> "/src/components/tag_filter.gleam")
  let notes =
    notes_with([
      unit(
        "components/tag_filter",
        string.replace(text, "on: [widget.Widget]", "on: [widget.Slug]"),
      ),
    ])
  stops(notes, "第 17 条", 4)
  { with(notes, "Var(\"slug\", Query(\"slug\")) が無い") != [] }
  |> should.be_true
  // fixture のまま(Page に Var("widget", Query("widget")))は止まらない
  notes_with([]) |> with("第 17 条") |> should.equal([])
}

pub fn article_18_tag_name_and_collision_test() {
  // module 名に `_` が無いと custom element の名にならない
  notes_with([
    component("probe", publish_calls <> publish_after <> publish_view),
  ])
  |> stops("第 18 条", 4)
}

// ── 連鎖の検査(第 19〜22 条)────────────────────────────────────────────────

pub fn article_19_live_of_a_service_not_in_calls_test() {
  notes_with([
    component(
      "probe_one",
      // calls は publish だけで、create の live を import して bind する
      publish_calls
        <> publish_after
        <> "pub fn view(p: publish.Args) -> el.Element { el.fragment([html.input_([create.bind(create.Slug, p.slug)]), publish.send(css.class([]), [])]) }\n",
    ),
  ])
  |> stops("第 19 条", 4)
}

pub fn article_20_every_call_is_sendable_test() {
  // 書きに send が無い(3)
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub fn view(_p: publish.Args) -> el.Element { el.none() }\n",
    ),
  ])
  |> stops("第 20 条", 3)
  // 一覧の読み(article_read の Out に List)に send(4)
  notes_with([
    component(
      "probe_one",
      "pub const calls: List(service.Service) = [service.ArticleRead]\n"
        <> "pub fn view(_r: read.Args) -> el.Element { read.send(css.class([]), []) }\n",
    ),
  ])
  |> stops("第 20 条", 4)
}

pub fn article_21_out_inside_a_form_control_test() {
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub fn view(_p: publish.Args) -> el.Element { el.fragment([html.textarea_([], [publish.out(publish.OutSlug)]), publish.send(css.class([]), [])]) }\n",
    ),
  ])
  |> stops("第 21 条", 4)
}

pub fn article_22_with_cannot_carry_elements_or_live_types_test() {
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub type With { With(inner: el.Element) }\n"
        <> "pub fn view(_p: publish.Args, with: With) -> el.Element { el.fragment([with.inner, publish.send(css.class([]), [])]) }\n",
    ),
  ])
  |> stops("第 22 条", 4)
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub type With { With(next: List(create.Args)) }\n"
        <> "pub fn view(_p: publish.Args, with: With) -> el.Element { let _ = with\n publish.send(css.class([]), []) }\n",
    ),
  ])
  |> stops("第 22 条", 4)
}

// ── 記述面(第 4〜6 条)と src/gen の手置き ──────────────────────────────────

pub fn article_4_external_stops_test() {
  notes_with([
    unit(
      "blocks/probe",
      "pub type In = Nil\n@external(javascript, \"./x.mjs\", \"y\")\nfn y() -> Nil\n",
    ),
  ])
  |> stops("第 4 条", 4)
}

/// fixture の public を写した dir(逃げ道の JS と src の .mjs を足せる)。
fn copied_face(name: String, edit: fn(String) -> Nil) -> String {
  let dir = "build/012-y3-face/" <> name
  let _ = simplifile.delete(dir)
  let assert Ok(_) = simplifile.create_directory_all(dir <> "/src/escapes")
  let assert Ok(_) =
    simplifile.copy_directory(public <> "/priv", dir <> "/priv")
  let assert Ok(_) =
    simplifile.copy_file(public <> "/gleam.toml", dir <> "/gleam.toml")
  let assert Ok(_) =
    simplifile.copy_file(
      public <> "/src/escapes/clock.mjs",
      dir <> "/src/escapes/clock.mjs",
    )
  edit(dir)
  dir
}

pub fn article_5_and_6_escape_files_test() {
  let dir =
    copied_face("escapes", fn(dir) {
      let assert Ok(_) =
        simplifile.write(dir <> "/src/helper.mjs", "export const x = 1;\n")
      let assert Ok(_) =
        simplifile.write(
          dir <> "/src/escapes/Bad-Name.mjs",
          "export function mount() {}\n",
        )
      let assert Ok(_) =
        simplifile.write(
          dir <> "/src/escapes/no_mount.mjs",
          "export function other() {}\n",
        )
      Nil
    })
  let notes = notes_at(dir, [])
  stops(notes, "第 5 条", 4)
  let sixth = with(notes, "第 6 条")
  with(sixth, "Bad-Name.mjs") |> stop.worst |> should.equal(4)
  with(sixth, "no_mount.mjs") |> stop.worst |> should.equal(3)
}

pub fn hand_placed_file_in_src_gen_is_checked_as_star_test() {
  let dir = "build/012-y3-face/hand"
  let _ = simplifile.delete(dir)
  let assert Ok(_) = simplifile.create_directory_all(dir <> "/src/gen")
  let assert Ok(_) =
    simplifile.write(
      dir <> "/src/gen/hand.gleam",
      "import lustre/element\npub fn x() { Nil }\n",
    )
  let assert Ok(_) =
    simplifile.write(
      dir <> "/src/gen/made.gleam",
      "//// GENERATED from x [sha256:0] — 手で編集しない\nimport lustre/element\n",
    )
  let assert Ok(units) = source.load(dir)
  list.map(units, fn(item) { item.path }) |> should.equal(["gen/hand"])
  notes_with(units) |> stops("gen/hand: ★ が lustre を import している(第 1 条", 4)
}

/// 別名の unqualified import(`el.{raw_text as rt}`)で呼んでも第 3 条で止まる(柏木 ゲート 2、名の照合が
/// 別名のままだと抜けた)。
pub fn article_3_aliased_unqualified_import_stops_test() {
  let notes =
    notes_with([
      unit(
        "blocks/probe_alias",
        "import yumemi/front/el.{attribute as at, raw_text as rt}\nimport yumemi/front/html\n"
          <> "pub type In = Nil\n"
          <> "pub fn view(_it: In) -> el.Element {\n  html.div_([at(\"onclick\", \"x\")], [rt(\"script\", [], \"x\")])\n}\n",
      ),
    ])
  let found = with(notes, "第 3 条")
  list.length(found) |> should.equal(2)
  with(found, "el.raw_text") |> list.length |> should.equal(1)
  with(found, "el.attribute") |> list.length |> should.equal(1)
  stop.worst(found) |> should.equal(4)
}

// ── Css と生の CSS(第 26・28〜31・43 条)と逃げ道の数え ──────────────────────

pub fn article_26_non_literal_shell_color_is_exit_four_test() {
  notes_with([
    unit(
      "shell",
      "import gleam/option.{None}\nimport yumemi/front/theme\n"
        <> "const red = \"#ff0000\"\n"
        <> "pub const lang: String = \"ja\"\npub const title: String = \"t\"\n"
        <> "pub const theme: theme.Defaults = theme.Defaults(background: red, text: \"#3D2419\", accent: \"#A93632\", background_image: None)\n",
    ),
  ])
  |> stops("第 26 条", 4)
}

pub fn article_29_four_ways_to_name_generated_things_test() {
  [
    "[ data-yumemi-area ] { color: red }",
    "[data\\2d yumemi-area] { color: red }",
    "@scope ([data-yumemi-area=\"page\"]) { p { color: red } }",
    "[class*=\"css-\"] { color: red }",
    "a[class ^= css] { color: red }",
    ".css-0a1b2c3d { color: red }",
    "yumemi-escape { color: red }",
  ]
  |> list.each(fn(css) {
    { raw_css.scan(css).generated != [] } |> should.be_true
  })
  // 名指さないもの
  [
    "main [data-area] { color: red }",
    ".card { color: red }",
    "fan-edit-name { }",
  ]
  |> list.each(fn(css) { raw_css.scan(css).generated |> should.equal([]) })
}

pub fn article_31_pipe_and_function_reference_static_sheet_test() {
  let block = fn(body) {
    unit(
      "blocks/probe",
      "import gleam/list\nimport yumemi/front/el\npub type In = Nil\npub fn view(_it: In) -> el.Element {\n"
        <> body
        <> "\n}\n",
    )
  }
  // pipe で literal を渡すのは literal と同じに読み、数える
  let assert Ok(units) = source.load(public)
  let probe = block("\"fixture.css\" |> el.static_sheet |> el.stylesheet")
  let assert Ok(model) = front.read("public", replace(units, [probe]), [])
  list.contains(model.static_sheets, #("blocks/probe", "fixture.css"))
  |> should.be_true
  notes_with([probe]) |> with("第 31 条") |> should.equal([])
  // pipe で変数・関数参照は literal でない
  notes_with([
    block("let path = \"x.css\"\npath |> el.static_sheet |> el.stylesheet"),
  ])
  |> stops("第 31 条", 4)
  notes_with([
    block(
      "el.fragment(list.map(list.map([\"a.css\"], el.static_sheet), el.stylesheet))",
    ),
  ])
  |> stops("第 31 条", 4)
}

pub fn same_sheet_read_twice_counts_once_test() {
  // fixture.css は shell.stylesheets にもある。Block からもう一度読んでも 1 file
  let notes =
    notes_with([
      unit(
        "blocks/probe",
        "import yumemi/front/el\npub type In = Nil\npub fn view(_it: In) -> el.Element { el.stylesheet(el.static_sheet(\"/fixture.css\")) }\n",
      ),
    ])
  let assert [line] = with(notes, ": 逃げ道 ── ")
  string.contains(line.text, "生の CSS 2 file 4 規則") |> should.be_true
}

pub fn escape_line_counts_calls_inside_components_test() {
  let assert [line] = with(notes_with([]), ": 逃げ道 ── ")
  line.text
  |> should.equal(
    "public: 逃げ道 ── escape 1 種 2 か所(うち interactive Component の中 1)、生の CSS 2 file 4 規則、数える口の送り先 ToService 0",
  )
  line.class |> should.equal(stop.Warning)
}

pub fn article_43_static_src_test() {
  let block = fn(body) {
    unit(
      "blocks/probe",
      "import yumemi/front/css\nimport yumemi/front/el\npub type In = Nil\npub fn view(_it: In) -> el.Element {\n"
        <> body
        <> "\n}\n",
    )
  }
  notes_with([
    block(
      "let p = \"a.png\"\nel.img(css.class([]), el.static_src(p), \"a\", [])",
    ),
  ])
  |> stops("第 43 条", 4)
  notes_with([
    block("el.img(css.class([]), el.static_src(\"missing.png\"), \"a\", [])"),
  ])
  |> stops("第 43 条", 3)
}

// ── 第 41 条(lock の照合)と queue の consumer の基 ─────────────────────────

pub fn article_41_lock_mismatch_stops_test() {
  let dir = "build/012-y3-lock"
  let _ = simplifile.delete(dir)
  let assert Ok(_) = simplifile.create_directory_all(dir <> "/api")
  let assert Ok(_) = simplifile.create_directory_all(dir <> "/www")
  let assert Ok(_) = simplifile.create_directory_all(dir <> "/fresh")
  let assert Ok(_) =
    simplifile.write(
      dir <> "/api/manifest.toml",
      "packages = [\n  { name = \"yumemi\", version = \"0.12.0\", build_tools = [\"gleam\"], requirements = [], otp_app = \"yumemi\", source = \"hex\", outer_checksum = \"x\" },\n]\n",
    )
  let assert Ok(_) =
    simplifile.write(
      dir <> "/www/manifest.toml",
      "packages = [\n  { name = \"yumemi\", version = \"0.11.15\", build_tools = [\"gleam\"], requirements = [], otp_app = \"yumemi\", source = \"hex\", outer_checksum = \"x\" },\n]\n",
    )
  let notes =
    yumemi_gen.lock_notes("0.12.0", [
      dir <> "/api",
      dir <> "/www",
      dir <> "/fresh",
    ])
  let assert [note] = notes
  string.contains(note.text, dir <> "/www/manifest.toml") |> should.be_true
  string.contains(note.text, "第 41 条") |> should.be_true
  stop.worst(notes) |> should.equal(4)
  // 照合の外の package(生成器が渡さない auth の類)は見ない
  yumemi_gen.lock_notes("0.11.15", [dir <> "/www"]) |> should.equal([])
}

pub fn queue_consumer_base_does_not_change_silently_test() {
  back.consumer_roots_conflict("article_retract", [
    #("aaa_reserve", "reservation"),
    #("article_publish", "article"),
  ])
  |> option.is_some
  |> should.be_true
  back.consumer_roots_conflict("article_retract", [
    #("article_create", "article"),
    #("article_publish", "article"),
  ])
  |> should.equal(None)
}

// ── runtime の Args の送り方(interactive.mjs)──────────────────────────────

@external(javascript, "./yumemi_012_y3_test_ffi.mjs", "runtime_wire")
fn runtime_wire() -> String

/// 0.11.2 の送り方(Bool・Int・Float・Option・List・JSON)を runtime が表の型で守る。
pub fn runtime_wire_encodes_args_by_type_test() {
  let out = runtime_wire()
  string.contains(out, "NG ") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(12)
}

@external(javascript, "./yumemi_012_y3_test_ffi.mjs", "runtime_submit")
fn runtime_submit() -> String

/// 上げ口(attached の `BlobCopy`)は file を送りの本文で 1 回だけ上げ、Service の Blob の欄は上げた key を Args に
/// 入れる(柏木 ゲート 2、上げ口が先に /api/blobs へも上げて 2 回上がっていた)。
pub fn runtime_uploads_a_chosen_file_once_test() {
  let out = runtime_submit()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(4)
}

pub fn generated_live_module_has_no_update_or_state_test() {
  let assert Ok(text) =
    simplifile.read(public <> "/src/gen/live/article_publish.gleam")
  ["pub fn update", "pub type State", "pub type Event", "lustre", "json."]
  |> list.each(fn(word) { string.contains(text, word) |> should.be_false })
  [
    "pub type When {",
    "pub fn bind(field: Field, value: String) -> el.Attribute",
    "pub fn send(class: css.Class, children: List(el.Element)) -> el.Element",
    "pub fn out(slot: Slot) -> el.Element",
  ]
  |> list.each(fn(word) { string.contains(text, word) |> should.be_true })
  let _ = Some(Nil)
}

/// Spec の正規表現の escape は 1 回だけ写る ── `"^\\d+(\\.[a-z]+)?$"` の `pattern` は `\d+(\.[a-z]+)?`(柏木
/// ゲート 2、glance の字に quoted を重ねて `\\d`(backslash と d)になり、正しい値を制約検証が拒んでいた)。
pub fn bind_pattern_keeps_the_spec_regex_escapes_test() {
  let assert Ok(back_units) = source.load(fixture)
  let back_units =
    list.map(back_units, fn(item) {
      case item.path {
        "types" ->
          unit(
            "types",
            string.replace(
              item.text,
              "regex: \"^[a-z0-9]+(-[a-z0-9]+)*$\"",
              "regex: \"^\\\\d+(\\\\.[a-z]+)?$\"",
            ),
          )
        _ -> item
      }
    })
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(units) = source.load(public)
  let assert Ok(model) = front.read("public", units, app.services)
  let package =
    face.Package(
      name: "public",
      path: public,
      pages: face.UndeclaredPages,
      units: units,
    )
  let files =
    front_emit.emit(app, back_units, package, model, hash.of(back_units))
  let assert Ok(live) =
    list.find(files, fn(file) {
      file.path == "public/src/gen/live/article_publish.gleam"
    })
  string.contains(live.text, "live.Pattern(\"\\\\d+(\\\\.[a-z]+)?\")")
  |> should.be_true
  string.contains(live.text, "\\\\\\\\d") |> should.be_false
}

/// textarea の `bind` は初めの値を中身の字に描く ── `value` 属性は browser が読まず、空の textarea から送りが
/// 初めの値を "" で上書きしていた(柏木 ゲート 2)。中身を書いたなら中身が勝つ。
pub fn textarea_bind_renders_the_value_as_content_test() {
  html.textarea_(
    [front_live.bind("edit", "body", "\na<b", [front_live.Required])],
    [],
  )
  |> el.to_string
  |> should.equal("<textarea name=\"edit.body\" required>\n\na&lt;b</textarea>")
  html.textarea_([attr.value("x")], [el.text("中身")])
  |> el.to_string
  |> should.equal("<textarea>中身</textarea>")
  html.input_([attr.value("x")])
  |> el.to_string
  |> should.equal("<input value=\"x\">")
}

// ── r2(柏木 ゲート 2 の P1 5 件と P2 2 件)─────────────────────────────────────

/// P1-1:第 21 条は pipe・変数・同じ module の関数を通した out も止める。control の外の out は止めない。
pub fn article_21_out_through_pipe_variable_and_function_test() {
  [
    "pub fn view(_p: publish.Args) -> el.Element { el.fragment([html.select_([], [html.option_([], [publish.OutSlug |> publish.out])]), publish.send(css.class([]), [])]) }\n",
    "pub fn view(_p: publish.Args) -> el.Element { let o = publish.out(publish.OutSlug)\n let p = o\n el.fragment([html.select_([], [html.option_([], [p])]), publish.send(css.class([]), [])]) }\n",
    "fn slot() -> el.Element { publish.out(publish.OutSlug) }\npub fn view(_p: publish.Args) -> el.Element { el.fragment([html.textarea_([], [slot()]), publish.send(css.class([]), [])]) }\n",
    "pub fn view(_p: publish.Args) -> el.Element { let o = publish.out(publish.OutSlug)\n el.fragment([[o] |> html.option_([], _), publish.send(css.class([]), [])]) }\n",
  ]
  |> list.each(fn(view) {
    notes_with([component("probe_one", publish_calls <> publish_after <> view)])
    |> stops("第 21 条", 4)
  })
  // control の外の out と、out を持たない変数を option に入れるのは止まらない
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> publish_after
        <> "pub fn view(_p: publish.Args) -> el.Element { let o = publish.out(publish.OutSlug)\n let label = el.text(\"x\")\n el.fragment([o, html.select_([], [html.option_([], [label])]), publish.send(css.class([]), [])]) }\n",
    ),
  ])
  |> with("第 21 条")
  |> should.equal([])
}

/// P1-2:第 22 条は unqualified の import・同じ module の record の欄・型の別名も止める。
pub fn article_22_unqualified_record_and_alias_test() {
  [
    "import yumemi/front/el.{type Element as Node}\npub type With { With(inner: Node) }\n",
    "pub type Item { Item(label: String, icon: el.Element) }\npub type With { With(items: List(Item)) }\n",
    "pub type Icon = el.Element\npub type With { With(icon: Icon) }\n",
    "pub type Next = List(create.Args)\npub type With { With(next: Next) }\n",
  ]
  |> list.each(fn(types) {
    notes_with([
      component(
        "probe_one",
        types
          <> publish_calls
          <> publish_after
          <> "pub fn view(_p: publish.Args, with: With) -> el.Element { let _ = with\n publish.send(css.class([]), []) }\n",
      ),
    ])
    |> stops("第 22 条", 4)
  })
  // 字と字の List・同じ module の字だけの record は止まらない
  notes_with([
    component(
      "probe_one",
      "pub type Item { Item(label: String) }\npub type Label = String\npub type With { With(items: List(Item), label: Label) }\n"
        <> publish_calls
        <> publish_after
        <> "pub fn view(_p: publish.Args, with: With) -> el.Element { let _ = with\n publish.send(css.class([]), []) }\n",
    ),
  ])
  |> with("第 22 条")
  |> should.equal([])
}

/// P1-4:error 側の GoTo は穴の無い route に限る(失敗の本文で穴を埋めない)。
pub fn article_15_error_goto_needs_a_route_without_holes_test() {
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> "pub const after_send: List(#(service.Service, live.After(route.Route))) = [#(service.ArticlePublish, live.After(ok: live.Stay, error: live.GoTo(route.ArticleArgSlug, notice: None)))]\n"
        <> publish_view,
    ),
  ])
  |> stops("第 15 条", 4)
  notes_with([
    component(
      "probe_one",
      publish_calls
        <> "pub const after_send: List(#(service.Service, live.After(route.Route))) = [#(service.ArticlePublish, live.After(ok: live.Stay, error: live.GoTo(route.Status, notice: None)))]\n"
        <> publish_view,
    ),
  ])
  |> with("第 15 条")
  |> should.equal([])
}

/// P2(b):第 18 条は yumemi- で始まるタグを止める(runtime の `yumemi-escape` の define を奪う)。
pub fn article_18_yumemi_prefixed_tag_stops_test() {
  notes_with([
    component("yumemi_escape", publish_calls <> publish_after <> publish_view),
  ])
  |> stops("第 18 条", 4)
}

/// P1-3:live の Args は Service の Args の欄の型(List・Option)で、Block は初期値を型で書く。字への写しは
/// 生成物の args_json が持つ。
pub fn live_args_are_typed_and_blocks_write_values_test() {
  let assert Ok(create) =
    simplifile.read(public <> "/src/gen/live/article_create.gleam")
  string.contains(create, "tags: List(String)") |> should.be_true
  string.contains(create, "live.json_list(args.tags, live.json_string)")
  |> should.be_true
  let assert Ok(save) =
    simplifile.read(public <> "/src/gen/live/article_blob_save.gleam")
  string.contains(save, "existing: Option(String)") |> should.be_true
  let assert Ok(block) = simplifile.read(public <> "/src/blocks/article.gleam")
  string.contains(block, "tags: [\"fixture\"]") |> should.be_true
  string.contains(block, "\\\"") |> should.be_false
  front_live.json_object([
    #("a", front_live.json_list(["x", "y"], front_live.json_string)),
    #("b", front_live.json_option(None, front_live.json_int)),
    #("c", front_live.json_option(Some(3), front_live.json_int)),
    #("d", front_live.json_bool(True)),
    #("e", front_live.json_float(2.5)),
  ])
  |> should.equal(
    "{\"a\":[\"x\",\"y\"],\"b\":null,\"c\":3,\"d\":true,\"e\":2.5}",
  )
}

/// P2(a):when の包みは span(`<p>` の中で parser が p を閉じない)。
pub fn when_wraps_with_a_span_test() {
  html.p_([], [front_live.when("s", "idle", [el.text("x")])])
  |> el.to_document_string
  |> string.contains("<p><span data-yumemi-when=\"s.idle\">x</span></p>")
  |> should.be_true
}

@external(javascript, "./yumemi_012_y3_test_ffi.mjs", "runtime_r2")
fn runtime_r2() -> String

/// P1-1・P1-3・P1-4・P1-5 の runtime の側(偽の DOM)。
pub fn runtime_r2_closes_the_kashiwagi_p1_test() {
  let out = runtime_r2()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(9)
}
