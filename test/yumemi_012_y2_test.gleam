//// 0.12 段 B(便 yumemi-012-y2)── 要素の木の細目と柵、Css の語彙、頁の色、生成器の条文
//// (51 v6「生成器が止めるもの」第 1〜3・7・8・23〜31 条)の 1 条ずつの止まり方。

import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import simplifile
import yumemi/blob
import yumemi/front/attr
import yumemi/front/color
import yumemi/front/css
import yumemi/front/el
import yumemi/front/html
import yumemi/front/sketch_css
import yumemi/front/theme
import yumemi/gen/emit/front as front_emit
import yumemi/gen/face
import yumemi/gen/raw_css
import yumemi/gen/reader
import yumemi/gen/reader/front
import yumemi/gen/source
import yumemi/gen/stop

const fixture = "gen/fixtures/article"

const public = "gen/fixtures/article/public"

// ── 要素の木の細目 3 つと URL の柵 ───────────────────────────────────────────

pub fn invalid_attribute_names_are_dropped_not_panicked_test() {
  html.div_(
    [
      attr.data("Bad Name", "x"),
      attr.data("x\" onfocus=\"alert(1)", "y"),
      attr.aria("", "z"),
      attr.data("ok-name2", "kept"),
    ],
    [],
  )
  |> el.to_string
  |> should.equal("<div data-ok-name2=\"kept\"></div>")
}

pub fn raw_text_cannot_leave_the_style_element_test() {
  // 生成物の `<style>` の中身(`el.styled` の CSS)に `</style><script>` が入っても要素を出られない
  let rendered =
    el.styled(
      fn() { el.text("body") },
      "a{}</style><script>alert(1)</script><!--",
    )
    |> el.to_string
  string.contains(rendered, "</style><script>") |> should.be_false
  string.contains(rendered, "<\\/style><script>alert(1)<\\/script><\\!--")
  |> should.be_true
}

pub fn same_attribute_name_keeps_the_last_one_test() {
  html.input_([attr.type_("text"), attr.name("n"), attr.type_("number")])
  |> el.to_string
  |> should.equal("<input name=\"n\" type=\"number\">")
}

pub fn unsafe_url_schemes_are_not_rendered_test() {
  [
    "javascript:alert(1)", "JaVaScript:alert(1)", " javascript:alert(1)",
    "java\tscript:alert(1)", "data:text/html,x", "vbscript:x",
  ]
  |> list.each(fn(url) {
    html.a_([attr.href(url)], [el.text("x")])
    |> el.to_string
    |> should.equal("<a>x</a>")
  })
  [
    "https://example.com/a?b=c", "http://x", "mailto:a@example.com", "tel:+81-3",
    "/relative", "page.html", "#top", "?q=a:b", "./a:b",
  ]
  |> list.each(fn(url) {
    html.a_([attr.href(url)], [])
    |> el.to_string
    |> string.contains("href=")
    |> should.be_true
  })
  // 0.12 段 C:img の src は Src(`el.static_src` / `gen/media.src`)だけが作り、属性の列の
  // `attr.src` より勝つ。外へ出る字の static_src は何も指さない `/` になる。
  el.img(css.class([]), el.static_src("javascript:x"), "a", [
    attr.src("https://evil.example/x.png"),
  ])
  |> el.to_string
  |> should.equal("<img alt=\"a\" src=\"/\">")
}

pub fn element_tree_renders_like_lustre_where_it_should_test() {
  // void・escape・真偽値・Fragment の印が無いこと・textarea の先頭の改行・SVG の名前空間
  el.fragment([
    html.br_([]),
    html.p_([attr.title("\"<&>'")], [el.text("<b>&")]),
    html.input_([attr.disabled(False), attr.required(True)]),
    el.each([1, 2], fn(_) { html.span_([], []) }),
    html.textarea_([], [el.text("\nfirst")]),
    html.svg_([attr.view_box("0 0 1 1")], [html.path("M0 0")]),
  ])
  |> el.to_string
  |> should.equal(
    "<br><p title=\"&quot;&lt;&amp;&gt;&#39;\">&lt;b&gt;&amp;</p><input required>"
    <> "<span></span><span></span><textarea>\n\nfirst</textarea>"
    <> "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1 1\"><path d=\"M0 0\"></path></svg>",
  )
}

/// 0.12 段 C:`el.legacy_island` は消えた。代わりに `static_sheet` の実行時の柵(Y2 柏木 P1-2)。
pub fn static_sheet_refuses_outside_paths_test() {
  ["//host/x.css", "\\\\host\\x.css", "a:b.css", "/../x.css", "https://h/x.css"]
  |> list.each(fn(path) {
    el.stylesheet(el.static_sheet(path))
    |> el.to_string
    |> should.equal("<link href=\"/\" rel=\"stylesheet\">")
  })
}

pub fn stylesheet_escape_renders_a_link_test() {
  el.stylesheet(el.static_sheet("fonts/mincho.css"))
  |> el.to_string
  |> should.equal("<link href=\"/fonts/mincho.css\" rel=\"stylesheet\">")
}

// ── 色の Type と頁の色 ─────────────────────────────────────────────────────

pub fn color_parses_only_six_hex_digits_test() {
  color.parse("#fff;}</style>") |> should.equal(Error(Nil))
  color.parse("#fff") |> should.equal(Error(Nil))
  color.parse("red") |> should.equal(Error(Nil))
  color.parse("#12345g") |> should.equal(Error(Nil))
  color.parse(" #123456") |> should.equal(Error(Nil))
  let assert Ok(value) = color.parse("#ABCDEF")
  color.to_css(value) |> should.equal("#abcdef")
}

pub fn page_theme_renders_four_custom_properties_test() {
  let assert Ok(background) = color.parse("#112233")
  let assert Ok(image) = blob.parse("k")
  let rule =
    theme.body_rule(
      Some(theme.PageTheme(
        background: Some(background),
        background_image: Some(image),
        text: None,
        accent: None,
      )),
      theme.Defaults("#FAF7F0", "#3D2419", "#A93632", None),
      fn(value) { "/media/" <> blob.to_string(value) },
    )
  rule
  |> should.equal(
    "body {\n  --yumemi-theme-bg: #112233;\n  --yumemi-theme-bg-image: url(\"/media/k\");\n"
    <> "  --yumemi-theme-text: #3d2419;\n  --yumemi-theme-accent: #a93632;\n}",
  )
  theme.has_image(
    Some(theme.PageTheme(None, Some(image), None, None)),
    theme.Defaults("#000000", "#000000", "#000000", None),
  )
  |> should.be_true
  theme.has_image(None, theme.Defaults("#000000", "#000000", "#000000", None))
  |> should.be_false
  // Shell の既定の地の画像は `/` の無い path でも頁の URL からの相対にしない
  theme.body_rule(
    None,
    theme.Defaults("#000000", "#000000", "#000000", Some("bg/paper.png")),
    blob.to_string,
  )
  |> string.contains("--yumemi-theme-bg-image: url(\"/bg/paper.png\");")
  |> should.be_true
}

// ── Css の語彙 ───────────────────────────────────────────────────────────

fn css_of(styles: List(css.Style)) -> String {
  let #(text, _) =
    sketch_css.collect(fn() { sketch_css.class_name(css.class(styles)) })
  text
}

pub fn paint_renders_only_framework_built_colors_test() {
  let text =
    css_of([
      css.Color(css.Hex("#A1B2C3")),
      css.Background(css.Mix(
        css.Theme(css.ThemeAccent),
        css.Token("ma-color-paper"),
        12,
      )),
      css.Border(css.TopEdge, css.Px(1.0), css.Solid, css.Transparent),
      css.Outline(css.Px(1.0), css.Px(0.0), css.CurrentColor),
      css.TextAlign(css.TextCenter),
    ])
  string.contains(text, "color: #a1b2c3;") |> should.be_true
  string.contains(
    text,
    "background-color: color-mix(in oklab, var(--yumemi-theme-accent) 12%, var(--ma-color-paper));",
  )
  |> should.be_true
  string.contains(text, "border-top: 1.0px solid transparent;")
  |> should.be_true
  string.contains(text, "outline-color: currentcolor;") |> should.be_true
  string.contains(text, "text-align: center;") |> should.be_true
  // 形の合わない Hex・Token は宣言の外へ出る字を書かない
  let bad = css_of([css.Color(css.Hex("#fff;}x")), css.Color(css.Token("a;b"))])
  string.contains(bad, "}x") |> should.be_false
  string.contains(bad, "a;b") |> should.be_false
  string.contains(bad, "color: unset;") |> should.be_true
}

pub fn component_states_render_two_ways_test() {
  let text = css_of([css.State(css.Waiting, [css.Color(css.Hex("#ff0000"))])])
  string.contains(text, "@supports selector(:state(waiting)) {")
  |> should.be_true
  string.contains(text, ":is(:state(waiting) *)") |> should.be_true
  string.contains(text, "@supports not selector(:state(waiting)) {")
  |> should.be_true
  string.contains(text, ":is([data-yumemi-state~=\"waiting\"] *)")
  |> should.be_true
  let ok = css_of([css.State(css.Succeeded, [css.Color(css.Hex("#00ff00"))])])
  string.contains(ok, ":state(ok)") |> should.be_true
  let error = css_of([css.State(css.Failed, [css.Color(css.Hex("#00ff00"))])])
  string.contains(error, ":state(error)") |> should.be_true
  let image =
    css_of([css.State(css.ThemeImage, [css.Background(css.Transparent)])])
  string.contains(image, ":is([data-yumemi-theme-image] *)") |> should.be_true
  // 断点の中では @supports で包まずに 2 通りの選択子を並べる(sketch は media の中の at-rule を落とす)
  let inside =
    css_of([
      css.Responsive(css.PC, [
        css.State(css.Failed, [css.Color(css.Hex("#0000ff"))]),
      ]),
    ])
  string.contains(inside, ":is(:state(error) *)") |> should.be_true
  string.contains(inside, ":is([data-yumemi-state~=\"error\"] *)")
  |> should.be_true
}

// ── 生成器の条文(reader の検査)─────────────────────────────────────────────

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

/// fixture の public の units に `extra` を足して(同じ path は置き換えて)読んだ停止。
fn notes_with(extra: List(source.Unit)) -> List(stop.Note) {
  let assert Ok(units) = source.load(public)
  let paths = list.map(extra, fn(item) { item.path })
  let units =
    units
    |> list.filter(fn(item) { !list.contains(paths, item.path) })
    |> list.append(extra)
  let assert Ok(model) = front.read("public", units, [])
  front.notes(model, [])
}

fn conflicts_with(notes: List(stop.Note), text: String) -> List(stop.Note) {
  list.filter(notes, fn(note) {
    note.class == stop.Conflict && string.contains(note.text, text)
  })
}

fn block(body: String) -> source.Unit {
  unit(
    "blocks/probe",
    "import yumemi/front/attr\nimport yumemi/front/css\nimport yumemi/front/el\n"
      <> "import yumemi/front/html\npub type In = Nil\n"
      <> "pub fn view(_it: In) -> el.Element {\n"
      <> body
      <> "\n}\n",
  )
}

pub fn article_1_lustre_import_stops_outside_legacy_components_test() {
  let notes =
    notes_with([
      unit(
        "blocks/probe",
        "import lustre/attribute\nimport sketch/lustre/element/html\npub type In = Nil\n",
      ),
    ])
  let found = conflicts_with(notes, "第 1 条")
  list.length(found) |> should.equal(2)
  stop.worst(found) |> should.equal(4)
  // 0.12 段 C:第 1・2 条の例外(0.11 の lustre の interactive Component)は無くなった。fixture の Component は
  // lustre を import せず止まらない(期待を「例外の数の警告」から替えた)
  conflicts_with(notes, "components/") |> should.equal([])
  list.filter(notes, fn(note) { string.contains(note.text, "第 1・2 条の例外") })
  |> should.equal([])
}

pub fn article_3_internal_calls_stop_test() {
  let notes =
    notes_with([block("  html.div_([el.attribute(\"onclick\", \"x\")], [])")])
  let assert [note] = conflicts_with(notes, "第 3 条")
  string.contains(note.text, "el.attribute") |> should.be_true
  stop.code(note.class) |> should.equal(4)
}

pub fn article_7_literal_data_name_stops_test() {
  let notes =
    notes_with([block("  html.div_([attr.data(\"Bad_Name\", \"x\")], [])")])
  let assert [note] = conflicts_with(notes, "第 7 条")
  stop.code(note.class) |> should.equal(4)
  notes_with([block("  html.div_([attr.data(\"good-name\", \"x\")], [])")])
  |> conflicts_with("第 7 条")
  |> should.equal([])
}

pub fn article_8_static_duplicate_attribute_stops_test() {
  let notes =
    notes_with([
      block(
        "  html.div_([attr.id(\"a\"), attr.data(\"k\", \"1\"), attr.id(\"b\"), attr.data(\"k\", \"2\")], [])",
      ),
    ])
  let assert [note] = conflicts_with(notes, "第 8 条")
  string.contains(note.text, "id") |> should.be_true
  string.contains(note.text, "data-k") |> should.be_true
  stop.code(note.class) |> should.equal(4)
  notes_with([
    block("  html.div_([attr.data(\"a\", \"1\"), attr.data(\"b\", \"2\")], [])"),
  ])
  |> conflicts_with("第 8 条")
  |> should.equal([])
}

pub fn article_23_to_25_css_literals_stop_test() {
  let notes =
    notes_with([
      unit(
        "blocks/probe",
        "import yumemi/front/css\npub type In = Nil\n"
          <> "const a = [css.Color(css.Hex(\"#fff\"))]\n"
          <> "const b = [css.Color(css.Token(\"Bad_Token\"))]\n"
          <> "const c = [css.Color(css.Mix(css.Transparent, css.CurrentColor, 120))]\n"
          <> "const d = [css.Color(css.Hex(\"#a1b2c3\")), css.Color(css.Token(\"ma-color-1\")), css.Color(css.Mix(css.Transparent, css.CurrentColor, 100))]\n",
      ),
    ])
  list.length(conflicts_with(notes, "第 23 条")) |> should.equal(1)
  list.length(conflicts_with(notes, "第 24 条")) |> should.equal(1)
  list.length(conflicts_with(notes, "第 25 条")) |> should.equal(1)
  stop.worst(conflicts_with(notes, "第 2")) |> should.equal(4)
}

pub fn article_31_static_sheet_path_must_be_literal_test() {
  let notes =
    notes_with([
      unit(
        "blocks/probe",
        "import yumemi/front/el\npub type In = String\n"
          <> "pub fn view(it: In) -> el.Element { el.stylesheet(el.static_sheet(it)) }\n",
      ),
    ])
  let assert [note] = conflicts_with(notes, "第 31 条")
  stop.code(note.class) |> should.equal(4)
}

// ── 生成器の条文(面の file を見る検査)─────────────────────────────────────

/// fixture の public を temp の面に写し、`edit` で面の file を書き換えてから surface_notes を取る。
fn surface_notes_with(
  name: String,
  edit: fn(String) -> Nil,
  extra: List(source.Unit),
) -> List(stop.Note) {
  let dir = "build/012-y2-surface/" <> name
  let _ = simplifile.delete(dir)
  let assert Ok(_) = simplifile.create_directory_all(dir <> "/priv/static")
  let assert Ok(toml) = simplifile.read(public <> "/gleam.toml")
  let assert Ok(_) = simplifile.write(dir <> "/gleam.toml", toml)
  let assert Ok(_) =
    simplifile.copy_file(
      public <> "/priv/static/fixture.css",
      dir <> "/priv/static/fixture.css",
    )
  let assert Ok(_) =
    simplifile.copy_file(
      public <> "/priv/static/article_font.css",
      dir <> "/priv/static/article_font.css",
    )
  // 0.12 段 C:逃げ道の JS も写す(数えの 1 行が escape の種類を数える)
  let assert Ok(_) = simplifile.create_directory_all(dir <> "/src/escapes")
  let assert Ok(_) =
    simplifile.copy_file(
      public <> "/src/escapes/clock.mjs",
      dir <> "/src/escapes/clock.mjs",
    )
  edit(dir)
  let assert Ok(back_units) = source.load(fixture)
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(units) = source.load(public)
  let paths = list.map(extra, fn(item) { item.path })
  let units =
    units
    |> list.filter(fn(item) { !list.contains(paths, item.path) })
    |> list.append(extra)
  let assert Ok(model) = front.read("public", units, app.services)
  front_emit.surface_notes(
    app,
    back_units,
    face.Package(
      name: "public",
      path: dir,
      pages: face.UndeclaredPages,
      units: units,
    ),
    model,
  )
}

fn write(path: String, text: String) -> Nil {
  let assert Ok(_) = simplifile.write(path, text)
  Nil
}

fn shell(extra: String, theme_body: String) -> source.Unit {
  unit(
    "shell",
    "import gleam/option.{None, Some}\nimport yumemi/front/theme\n"
      <> "pub const lang: String = \"ja\"\npub const title: String = \"t\"\n"
      <> "pub const theme: theme.Defaults = theme.Defaults("
      <> theme_body
      <> ")\n"
      <> extra,
  )
}

pub fn fixture_surface_counts_rules_once_per_face_test() {
  let notes = surface_notes_with("clean", fn(_) { Nil }, [])
  let assert [count] = notes
  count.class |> should.equal(stop.Warning)
  // 0.12 段 C:逃げ道の数えは面ごとに 1 行(escape・生の CSS・ToService、51 v6「逃げ道の数え方」)
  count.text
  |> should.equal(
    "public: 逃げ道 ── escape 1 種 2 か所(うち interactive Component の中 1)、生の CSS 2 file 4 規則、数える口の送り先 ToService 0",
  )
}

pub fn raw_css_rules_are_counted_by_top_level_block_test() {
  let scan =
    raw_css.scan(
      "/* c { } */ a { b: c } @media (min-width: 1px) { d { e: f } g { h: i } }\n"
      <> "x, y { z: \"}\" }",
    )
  scan.rules |> should.equal(3)
  scan.generated |> should.equal([])
  scan.imports |> should.be_false
}

/// 0.12 段 C:第 1・2 条の例外(0.11 の lustre の interactive Component)は無くなった。fixture の面は lustre を
/// 依存に持たず、gleam.toml に足せば止まる。期待を「例外のある面では止めない」から替えた。
pub fn article_2_lustre_dependency_stops_without_legacy_components_test() {
  surface_notes_with("article-2-clean", fn(_) { Nil }, [])
  |> conflicts_with("第 2 条")
  |> should.equal([])
  let notes =
    surface_notes_with(
      "article-2",
      fn(dir) {
        let assert Ok(toml) = simplifile.read(dir <> "/gleam.toml")
        let assert Ok(_) =
          simplifile.write(
            dir <> "/gleam.toml",
            string.replace(
              toml,
              "[dependencies]\n",
              "[dependencies]\nlustre = \">= 5.7.1 and < 6.0.0\"\n",
            ),
          )
        Nil
      },
      [],
    )
  let assert [note] = conflicts_with(notes, "第 2 条")
  string.contains(note.text, "lustre") |> should.be_true
  stop.code(note.class) |> should.equal(4)
}

pub fn article_26_shell_theme_literals_test() {
  let notes =
    surface_notes_with("article-26", fn(_) { Nil }, [
      shell(
        "",
        "background: \"red\", text: \"#3D2419\", accent: \"#A93632\", background_image: Some(\"bg/missing.png\")",
      ),
    ])
  let assert [color_note] = conflicts_with(notes, "第 26 条")
  string.contains(color_note.text, "theme.background \"red\"") |> should.be_true
  let assert [image_note] =
    list.filter(notes, fn(note) {
      note.class == stop.Missing && string.contains(note.text, "第 26 条")
    })
  stop.code(image_note.class) |> should.equal(3)
  // 在る path なら止めない
  surface_notes_with(
    "article-26-ok",
    fn(dir) { write(dir <> "/priv/static/bg.png", "x") },
    [
      shell(
        "",
        "background: \"#000000\", text: \"#3D2419\", accent: \"#A93632\", background_image: Some(\"bg.png\")",
      ),
    ],
  )
  |> list.filter(fn(note) { string.contains(note.text, "第 26 条") })
  |> should.equal([])
}

pub fn article_27_page_theme_must_be_the_framework_type_test() {
  // Out の theme を app の型(型名だけ PageTheme)にすると拾わず止める
  let assert Ok(back_units) = source.load(fixture)
  let back_units =
    list.map(back_units, fn(item) {
      case item.path == "service/article_read" {
        True ->
          unit(
            item.path,
            item.text
            |> string.replace(
              "    theme: Option(theme.PageTheme),\n",
              "    theme: Option(PageTheme),\n",
            )
              <> "\npub type PageTheme {\n  PageTheme(background: Option(String))\n}\n",
          )
        False -> item
      }
    })
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(units) = source.load(public)
  let assert Ok(model) = front.read("public", units, app.services)
  let notes =
    front_emit.surface_notes(
      app,
      back_units,
      face.Package(
        name: "public",
        path: public,
        pages: face.UndeclaredPages,
        units: units,
      ),
      model,
    )
  let assert [note] = conflicts_with(notes, "第 27 条")
  string.contains(note.text, "pages/article/arg_slug/page") |> should.be_true
  stop.code(note.class) |> should.equal(4)
}

pub fn article_28_to_30_raw_css_files_test() {
  let notes =
    surface_notes_with(
      "article-28",
      fn(dir) {
        write(
          dir <> "/priv/static/bad.css",
          "@import url(\"x.css\");\n"
            <> "[data-yumemi-area=\"page\"] { color: red }\n"
            <> "@media (min-width: 1px) { .css-1A2B3C4D { color: red } }\n"
            <> "main > yumemi-escape { display: none }\n"
            <> "fan-edit-name:state(ok) .x { color: var(--yumemi-theme-bg) }\n",
        )
      },
      [
        shell(
          "pub const stylesheets: List(String) = [\"/bad.css\", \"/missing.css\"]\n",
          "background: \"#000000\", text: \"#000000\", accent: \"#000000\", background_image: None",
        ),
      ],
    )
  let assert [missing] =
    list.filter(notes, fn(note) { string.contains(note.text, "第 28 条") })
  stop.code(missing.class) |> should.equal(3)
  string.contains(missing.text, "/missing.css") |> should.be_true
  list.length(conflicts_with(notes, "第 29 条")) |> should.equal(3)
  list.length(conflicts_with(notes, "第 30 条")) |> should.equal(1)
  // 島のタグ名と :state()、custom property の値は名指してよい
  conflicts_with(notes, "fan-edit-name") |> should.equal([])
  stop.worst(notes) |> should.equal(4)
}
