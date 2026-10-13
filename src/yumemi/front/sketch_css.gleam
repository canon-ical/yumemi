import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import sketch
import sketch/css as sketch_css
import sketch/css/length
import sketch/css/media
import sketch/internals/cache/cache as sketch_style
import yumemi/front/css
import yumemi/front/track

@external(javascript, "./sheet_ffi.mjs", "add")
fn add_rule(name: String, css: String) -> Nil

@external(javascript, "./sheet_ffi.mjs", "start")
fn start_collecting() -> Dynamic

@external(javascript, "./sheet_ffi.mjs", "finish")
fn finish_collecting(previous: Dynamic) -> String

/// `css.Class` の class 名。Style の列を sketch で CSS の字にし、その字(class 名を伏せたもの)の
/// FNV-1a の hash から名を作る(0.12 段 C)。sketch の名は Style の `string.inspect` の hash で、
/// bundle や minify で構成子の名が替わると変わる(78、Y2 の実測)。CSS の字は構成子の名に依らない
/// ので、node・Worker・minify の bundle のどこで描いても同じ Style は同じ名になる。いま集めている
/// 所(`collect`)があれば規則を足す。
@internal
pub fn class_name(class: css.Class) -> String {
  case css.class_styles(class) {
    [] -> ""
    _ -> stable_class_name(class)
  }
}

fn stable_class_name(class: css.Class) -> String {
  let #(sheet, raw) =
    css.class_styles(class)
    |> list.flat_map(to_sketch)
    |> sketch_css.class
    |> sketch.class_name(new_sheet())
  let template = string.replace(sketch.render(sheet), raw, "\u{1}")
  let name = "css-" <> stable_hash(template)
  add_rule(name, string.replace(template, "\u{1}", name))
  name
}

/// `body` を描く間に使った class の CSS を集める。戻りは #(CSS の字, body の値)。
@internal
pub fn collect(body: fn() -> a) -> #(String, a) {
  let previous = start_collecting()
  let value = body()
  #(finish_collecting(previous), value)
}

fn new_sheet() -> sketch.StyleSheet {
  let assert Ok(sheet) = sketch.stylesheet(strategy: sketch.Ephemeral)
  sheet
}

/// FNV-1a(32 bit)を UTF-8 の byte に掛け、16 進 8 桁の大文字にする。JS の数で 2^53 を
/// 超えないよう、掛け算は 2^24 の項と 403 の項に割る。
@internal
pub fn stable_hash(text: String) -> String {
  fnv(<<text:utf8>>, 2_166_136_261)
  |> int.to_base16
  |> string.pad_start(8, "0")
}

fn fnv(bytes: BitArray, hash: Int) -> Int {
  case bytes {
    <<byte, rest:bytes>> -> {
      let low = hash % 256
      let mixed = hash - low + int.bitwise_exclusive_or(low, byte)
      fnv(rest, { mixed % 256 * 16_777_216 + mixed * 403 } % 4_294_967_296)
    }
    _ -> hash
  }
}

/// 色を CSS の字にする。形の合わない Hex・Token は `unset`(宣言の外へ出る字を書かない)。
pub fn paint_to_string(paint: css.Paint) -> String {
  case paint {
    css.Hex(value) ->
      case valid_hex(value) {
        True -> string.lowercase(value)
        False -> "unset"
      }
    css.Token(name) ->
      case valid_var_name(name) {
        True -> "var(--" <> name <> ")"
        False -> "unset"
      }
    css.Theme(slot) -> "var(" <> theme_variable(slot) <> ")"
    css.Mix(a:, b:, percent:) ->
      "color-mix(in oklab, "
      <> paint_to_string(a)
      <> " "
      <> int.to_string(int.clamp(percent, 0, 100))
      <> "%, "
      <> paint_to_string(b)
      <> ")"
    css.Transparent -> "transparent"
    css.CurrentColor -> "currentcolor"
  }
}

/// 頁の色の custom property の名(body に framework が出す)。
pub fn theme_variable(slot: css.ThemeSlot) -> String {
  case slot {
    css.ThemeBackground -> "--yumemi-theme-bg"
    css.ThemeText -> "--yumemi-theme-text"
    css.ThemeAccent -> "--yumemi-theme-accent"
  }
}

/// `#` と 16 進 6 桁か。
pub fn valid_hex(value: String) -> Bool {
  case string.to_graphemes(value) {
    ["#", ..digits] ->
      list.length(digits) == 6
      && list.all(digits, fn(digit) {
        string.contains("0123456789abcdefABCDEF", digit)
      })
    _ -> False
  }
}

pub fn to_sketch(style: css.Style) -> List(sketch_css.Style) {
  case style {
    css.Color(value) -> [sketch_css.color(paint_to_string(value))]
    css.Background(value) -> [
      sketch_css.background_color(paint_to_string(value)),
    ]
    css.Border(edge:, width:, style:, color:) -> [
      border(edge, width, style, color),
    ]
    css.Outline(width:, offset:, color:) -> [
      sketch_css.outline_style("solid"),
      sketch_css.outline_width(length_to_string(width)),
      sketch_css.outline_offset(length_to_string(offset)),
      sketch_css.outline_color(paint_to_string(color)),
    ]
    css.Crop(fit:, ratio:) -> [
      sketch_css.object_fit(object_fit(fit)),
      sketch_css.aspect_ratio(aspect_ratio(ratio)),
    ]
    css.Sizing(box:) -> [sketch_css.box_sizing(box_sizing(box))]
    css.Marker(marker:) -> [sketch_css.list_style(list_marker(marker))]
    css.Decoration(line:) -> [
      sketch_css.text_decoration(text_decoration(line)),
    ]
    css.Wrap(wrap:) -> [sketch_css.overflow_wrap(overflow_wrap(wrap))]
    css.Space(property:, value:) -> [space(property, value)]
    css.Text(family:, size:, weight:, line_height:) -> [
      sketch_css.font_family(font_family(family)),
      sketch_css.font_size_(length_to_string(size)),
      sketch_css.font_weight(font_weight(weight)),
      sketch_css.line_height(length_to_string(line_height)),
    ]
    css.Flow(flow) -> flow_style(flow)
    css.TextAlign(align) -> [sketch_css.text_align(text_align(align))]
    css.Center -> [
      sketch_css.margin_left_("auto"),
      sketch_css.margin_right_("auto"),
    ]
    css.OverflowX(overflow:) -> [
      sketch_css.overflow_x(overflow_value(overflow)),
    ]
    css.Spaces(white_space:) -> [
      sketch_css.white_space(white_space_value(white_space)),
    ]
    css.Slant(slant:) -> [sketch_css.font_style(slant_value(slant))]
    css.State(state, styles) -> state_style(state, styles)
    css.Responsive(at, styles) -> {
      let #(hovers, styles) = list.partition(styles, is_hover_capable)
      [
        sketch_css.media(breakpoint(at), list.flat_map(styles, in_media)),
        ..list.flat_map(hovers, fn(style) {
          hover_capable_in(media.to_string(breakpoint(at)) <> " and", style)
        })
      ]
    }
  }
}

fn space(property: css.SpaceProperty, value: css.Length) -> sketch_css.Style {
  case property {
    css.Margin -> sketch_css.margin_(length_to_string(value))
    css.Padding -> sketch_css.padding_(length_to_string(value))
    css.Gap -> sketch_css.gap_(length_to_string(value))
    css.Width -> sketch_css.width_(length_to_string(value))
    css.Height -> sketch_css.height_(length_to_string(value))
    css.Radius -> sketch_css.border_radius_(length_to_string(value))
    css.MinWidth -> sketch_css.min_width_(length_to_string(value))
    css.MinHeight -> sketch_css.min_height_(length_to_string(value))
    css.MaxWidth -> sketch_css.max_width_(length_to_string(value))
  }
}

fn border(
  edge: css.BorderEdge,
  width: css.Length,
  style: css.BorderStyle,
  color: css.Paint,
) -> sketch_css.Style {
  let value =
    length_to_string(width)
    <> " "
    <> border_style(style)
    <> " "
    <> paint_to_string(color)
  case edge {
    css.AllEdges -> sketch_css.border(value)
    css.TopEdge -> sketch_css.border_top(value)
    css.BottomEdge -> sketch_css.border_bottom(value)
    css.LeftEdge -> sketch_css.border_left(value)
    css.RightEdge -> sketch_css.border_right(value)
  }
}

fn overflow_value(value: css.Overflow) -> String {
  case value {
    css.OverflowAuto -> "auto"
    css.OverflowHidden -> "hidden"
    css.OverflowVisible -> "visible"
    css.OverflowScroll -> "scroll"
  }
}

fn white_space_value(value: css.WhiteSpace) -> String {
  case value {
    css.SpaceNormal -> "normal"
    css.Pre -> "pre"
    css.PreWrap -> "pre-wrap"
    css.PreLine -> "pre-line"
    css.NoWrap -> "nowrap"
  }
}

fn slant_value(value: css.FontSlant) -> String {
  case value {
    css.Upright -> "normal"
    css.Italic -> "italic"
  }
}

fn text_align(value: css.TextAlignment) -> String {
  case value {
    css.TextStart -> "start"
    css.TextCenter -> "center"
    css.TextEnd -> "end"
  }
}

fn border_style(value: css.BorderStyle) -> String {
  case value {
    css.Solid -> "solid"
    css.Dashed -> "dashed"
    css.Dotted -> "dotted"
  }
}

fn object_fit(value: css.ObjectFit) -> String {
  case value {
    css.Cover -> "cover"
    css.Contain -> "contain"
    css.Fill -> "fill"
    css.ScaleDown -> "scale-down"
    css.FitNone -> "none"
  }
}

fn box_sizing(value: css.BoxSizing) -> String {
  case value {
    css.BorderBox -> "border-box"
    css.ContentBox -> "content-box"
  }
}

fn list_marker(value: css.ListMarker) -> String {
  case value {
    css.NoMarker -> "none"
  }
}

fn text_decoration(value: css.TextDecoration) -> String {
  case value {
    css.NoDecoration -> "none"
    css.Underline -> "underline"
  }
}

fn overflow_wrap(value: css.OverflowWrap) -> String {
  case value {
    css.Anywhere -> "anywhere"
    css.BreakWord -> "break-word"
    css.WrapNormal -> "normal"
  }
}

fn aspect_ratio(value: css.Ratio) -> String {
  float.to_string(value.width) <> " / " <> float.to_string(value.height)
}

fn flow_style(flow: css.Flow) -> List(sketch_css.Style) {
  case flow {
    css.Stack(gap:) -> [
      sketch_css.display("flex"),
      sketch_css.flex_direction("column"),
      sketch_css.gap_(length_to_string(gap)),
    ]
    css.Row(gap:, wrap:) -> [
      sketch_css.display("flex"),
      sketch_css.flex_direction("row"),
      sketch_css.gap_(length_to_string(gap)),
      sketch_css.flex_wrap(case wrap {
        True -> "wrap"
        False -> "nowrap"
      }),
    ]
    css.Grid(cols:, gap:) -> [
      sketch_css.display("grid"),
      sketch_css.grid_template_columns(
        "repeat(" <> int.to_string(cols) <> ", minmax(0, 1fr))",
      ),
      sketch_css.gap_(length_to_string(gap)),
    ]
    css.GridTracks(cols:, gap:) -> [
      sketch_css.display("grid"),
      sketch_css.grid_template_columns(
        cols
        |> list.map(track.to_css)
        |> string.join(" "),
      ),
      sketch_css.gap_(length_to_string(gap)),
    ]
    css.Scroller -> [
      sketch_css.display("flex"),
      sketch_css.overflow_x("auto"),
    ]
  }
}

/// `aria-current` の値のうち `false` だけが「今ではない」(WAI-ARIA)。`page` に絞らず、
/// `step`・`location`・`true` などの今いる所も同じ状態にする。
const current_selector = "[aria-current]:not([aria-current=\"false\"])"

fn state_style(
  state: css.Interaction,
  styles: List(css.Style),
) -> List(sketch_css.Style) {
  let styles = list.flat_map(styles, to_sketch)
  case state {
    css.Hover -> [sketch_css.hover(styles)]
    css.Focus -> [sketch_css.focus(styles)]
    css.FocusVisible -> [sketch_css.focus_visible(styles)]
    css.HoverCapable -> [
      sketch_style.Media(hover_capable_query, [sketch_css.hover(styles)]),
    ]
    css.Disabled -> [sketch_css.disabled(styles)]
    css.Current -> [sketch_css.selector(current_selector, styles)]
    css.Waiting -> component_state("waiting", styles)
    css.Succeeded -> component_state("ok", styles)
    css.Failed -> component_state("error", styles)
    css.ThemeImage -> [sketch_css.selector(theme_image_selector, styles)]
  }
}

/// 地の画像のある頁の内側。framework が body に立てる。
const theme_image_selector = ":is([data-yumemi-theme-image] *)"

/// 祖先の interactive Component の custom state。`:state()` を持つ browser には
/// `@supports selector(:state(x))` の中の `:state(x)` で、持たない browser には runtime が
/// 写す `data-yumemi-state` の属性で効かせる(2 通りの規則)。
fn component_state(
  name: String,
  styles: List(sketch_css.Style),
) -> List(sketch_css.Style) {
  [
    sketch_style.Media("@supports selector(:state(" <> name <> "))", [
      sketch_css.selector(state_selector(name), styles),
    ]),
    sketch_style.Media("@supports not selector(:state(" <> name <> "))", [
      sketch_css.selector(state_attribute_selector(name), styles),
    ]),
  ]
}

fn state_selector(name: String) -> String {
  ":is(:state(" <> name <> ") *)"
}

fn state_attribute_selector(name: String) -> String {
  ":is([data-yumemi-state~=\"" <> name <> "\"] *)"
}

/// `Responsive` の中の状態。sketch は media の中の at-rule を落とすので、`@supports` で
/// 包まずに 2 通りの選択子を並べる(`:is()` は読めない選択子を含んでも規則を捨てない)。
fn component_state_in_media(
  state: css.Interaction,
  styles: List(css.Style),
) -> List(sketch_css.Style) {
  let styles = list.flat_map(styles, to_sketch)
  let name = case state {
    css.Waiting -> "waiting"
    css.Succeeded -> "ok"
    _ -> "error"
  }
  [
    sketch_css.selector(state_selector(name), styles),
    sketch_css.selector(state_attribute_selector(name), styles),
  ]
}

/// hover が出来る端末だけの media。sketch の `media.Query` に `hover` が無いので、
/// sketch の `Media` を字で組む(`css.media` と同じ形 ── `@media` の中は class の
/// `:hover` で、詳細度は `Hover` と同じ)。
const hover_capable_query = "@media (hover: hover)"

fn is_hover_capable(style: css.Style) -> Bool {
  case style {
    css.State(css.HoverCapable, _) -> True
    _ -> False
  }
}

fn in_media(style: css.Style) -> List(sketch_css.Style) {
  case style {
    css.State(css.Waiting as state, styles)
    | css.State(css.Succeeded as state, styles)
    | css.State(css.Failed as state, styles) ->
      component_state_in_media(state, styles)
    _ -> to_sketch(style)
  }
}

/// `Responsive` の中の `HoverCapable`。sketch は media の中の media を落とすので、
/// 幅の media と `(hover: hover)` を `and` で 1 つの media にする。
fn hover_capable_in(
  prefix: String,
  style: css.Style,
) -> List(sketch_css.Style) {
  case style {
    css.State(css.HoverCapable, styles) -> [
      sketch_style.Media(prefix <> " (hover: hover)", [
        sketch_css.hover(list.flat_map(styles, to_sketch)),
      ]),
    ]
    _ -> to_sketch(style)
  }
}

fn breakpoint(value: css.Breakpoint) -> media.Query {
  case value {
    css.SP -> media.max_width(length.px(767))
    css.PC -> media.min_width(length.px(1024))
    css.Tablet ->
      media.and(
        media.min_width(length.px(768)),
        media.max_width(length.px(1023)),
      )
  }
}

/// 長さを CSS の値の字にする。`Px`・`Rem` は sketch の `length.to_string` と同じ字
/// (`8.0px`)で、0.11.8 までの出力を変えない。
pub fn length_to_string(value: css.Length) -> String {
  case value {
    css.Px(value) -> float.to_string(value) <> "px"
    css.Rem(value) -> float.to_string(value) <> "rem"
    css.Var(name) ->
      case valid_var_name(name) {
        True -> "var(--" <> name <> ")"
        False -> "unset"
      }
    css.Env(edge) -> "env(safe-area-inset-" <> safe_area(edge) <> ", 0px)"
    css.Dvh(value) -> float.to_string(value) <> "dvh"
  }
}

/// `Var` の名が `[a-z0-9-]` だけで、空でないか。
pub fn valid_var_name(name: String) -> Bool {
  name != ""
  && list.all(string.to_utf_codepoints(name), fn(codepoint) {
    let code = string.utf_codepoint_to_int(codepoint)
    { code >= 97 && code <= 122 } || { code >= 48 && code <= 57 } || code == 45
  })
}

fn safe_area(edge: css.SafeArea) -> String {
  case edge {
    css.SafeTop -> "top"
    css.SafeRight -> "right"
    css.SafeBottom -> "bottom"
    css.SafeLeft -> "left"
  }
}

/// 書体の並びを CSS の値の字にする。`Named` の字は `valid_font_family` の柵を通る。
pub fn font_family(value: css.FontFamily) -> String {
  case value {
    css.System -> "system-ui"
    css.SansSerif -> "sans-serif"
    css.Serif -> "serif"
    css.Monospace -> "monospace"
    css.Named(value) ->
      case valid_font_family(value) {
        True -> value
        False -> "unset"
      }
  }
}

/// `Named` の書体の名の並び(`,` 区切り)が、項ごとに `var(--<name>)`・引用符で囲んだ名・引用符の無い名
/// (`[A-Za-z0-9_-]` の語を空白 1 つで繋いだもの)のどれかか。合わなければ `unset`(`Hex`・`Token` と同じ扱い。
/// DB の値が流れても宣言の外へ出る字を書かない)。
pub fn valid_font_family(value: String) -> Bool {
  value
  |> string.split(",")
  |> list.all(fn(item) { font_family_item(string.trim(item)) })
}

fn font_family_item(item: String) -> Bool {
  case item {
    "var(--" <> rest ->
      case string.ends_with(rest, ")") {
        True -> valid_var_name(string.drop_end(rest, 1))
        False -> False
      }
    "\"" <> rest -> quoted_font_name(rest, "\"")
    "'" <> rest -> quoted_font_name(rest, "'")
    _ ->
      item != ""
      && list.all(string.split(item, " "), fn(word) {
        word != ""
        && list.all(string.to_utf_codepoints(word), fn(codepoint) {
          let code = string.utf_codepoint_to_int(codepoint)
          { code >= 97 && code <= 122 }
          || { code >= 65 && code <= 90 }
          || { code >= 48 && code <= 57 }
          || code == 45
          || code == 95
        })
      })
  }
}

/// 引用符の中の名。空でなく、引用符・`\\`・`;`・`{`・`}`・`<`・`>`・`(`・`)`・`/`・`*`・制御文字を持たない。
fn quoted_font_name(rest: String, quote: String) -> Bool {
  case string.ends_with(rest, quote) {
    False -> False
    True -> {
      let name = string.drop_end(rest, 1)
      name != ""
      && list.all(string.to_utf_codepoints(name), fn(codepoint) {
        let code = string.utf_codepoint_to_int(codepoint)
        code >= 32
        && code != 127
        && !list.contains(
          [34, 39, 92, 59, 123, 125, 60, 62, 40, 41, 47, 42],
          code,
        )
      })
    }
  }
}

fn font_weight(value: css.FontWeight) -> String {
  case value {
    css.Normal -> "400"
    css.Medium -> "500"
    css.SemiBold -> "600"
    css.Bold -> "700"
  }
}
