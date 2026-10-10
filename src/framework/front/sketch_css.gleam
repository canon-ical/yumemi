import framework/front/css
import framework/front/track
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import sketch/css as sketch_css
import sketch/css/length
import sketch/css/media
import sketch/internals/cache/cache as sketch_style

pub fn class(styles: List(css.Style)) -> sketch_css.Class {
  styles
  |> list.flat_map(to_sketch)
  |> sketch_css.class
}

pub fn to_sketch(style: css.Style) -> List(sketch_css.Style) {
  case style {
    css.Color(value) -> [sketch_css.color(value)]
    css.Background(value) -> [sketch_css.background_color(value)]
    css.Border(edge:, width:, style:, color:) -> [
      border(edge, width, style, color),
    ]
    css.Outline(width:, offset:, color:) -> [
      sketch_css.outline_style("solid"),
      sketch_css.outline_width(length_to_string(width)),
      sketch_css.outline_offset(length_to_string(offset)),
      sketch_css.outline_color(color),
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
    css.State(state, styles) -> state_style(state, styles)
    css.Responsive(at, styles) -> {
      let #(hovers, styles) = list.partition(styles, is_hover_capable)
      [
        sketch_css.media(breakpoint(at), list.flat_map(styles, to_sketch)),
        ..list.flat_map(hovers, fn(style) {
          hover_capable_in(media.to_string(breakpoint(at)) <> " and", style)
        })
      ]
    }
    css.Animation(animation) -> [
      sketch_css.animation(animation_name(animation)),
    ]
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
  color: String,
) -> sketch_css.Style {
  let value =
    length_to_string(width) <> " " <> border_style(style) <> " " <> color
  case edge {
    css.AllEdges -> sketch_css.border(value)
    css.BottomEdge -> sketch_css.border_bottom(value)
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
  }
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

fn font_family(value: css.FontFamily) -> String {
  case value {
    css.System -> "system-ui"
    css.SansSerif -> "sans-serif"
    css.Serif -> "serif"
    css.Monospace -> "monospace"
    css.Named(value) -> value
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

fn animation_name(value: css.Animation) -> String {
  case value {
    css.Fade -> "fade"
    css.SlideUp -> "slide-up"
    css.Pulse -> "pulse"
  }
}
