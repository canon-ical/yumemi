import framework/front/css
import framework/front/track
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import sketch/css as sketch_css
import sketch/css/length
import sketch/css/media

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
    css.Space(property:, value:) -> [space(property, value)]
    css.Text(family:, size:, weight:, line_height:) -> [
      sketch_css.font_family(font_family(family)),
      sketch_css.font_size(to_length(size)),
      sketch_css.font_weight(font_weight(weight)),
      sketch_css.line_height(length_to_string(line_height)),
    ]
    css.Flow(flow) -> flow_style(flow)
    css.State(state, styles) -> state_style(state, styles)
    css.Responsive(at, styles) -> [
      sketch_css.media(breakpoint(at), list.flat_map(styles, to_sketch)),
    ]
    css.Animation(animation) -> [
      sketch_css.animation(animation_name(animation)),
    ]
  }
}

fn space(property: css.SpaceProperty, value: css.Length) -> sketch_css.Style {
  case property {
    css.Margin -> sketch_css.margin(to_length(value))
    css.Padding -> sketch_css.padding(to_length(value))
    css.Gap -> sketch_css.gap(to_length(value))
    css.Width -> sketch_css.width(to_length(value))
    css.Height -> sketch_css.height(to_length(value))
    css.Radius -> sketch_css.border_radius(to_length(value))
    css.MinWidth -> sketch_css.min_width(to_length(value))
    css.MinHeight -> sketch_css.min_height(to_length(value))
    css.MaxWidth -> sketch_css.max_width(to_length(value))
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

fn aspect_ratio(value: css.Ratio) -> String {
  float.to_string(value.width) <> " / " <> float.to_string(value.height)
}

fn flow_style(flow: css.Flow) -> List(sketch_css.Style) {
  case flow {
    css.Stack(gap:) -> [
      sketch_css.display("flex"),
      sketch_css.flex_direction("column"),
      sketch_css.gap(to_length(gap)),
    ]
    css.Row(gap:, wrap:) -> [
      sketch_css.display("flex"),
      sketch_css.flex_direction("row"),
      sketch_css.gap(to_length(gap)),
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
      sketch_css.gap(to_length(gap)),
    ]
    css.GridTracks(cols:, gap:) -> [
      sketch_css.display("grid"),
      sketch_css.grid_template_columns(
        cols
        |> list.map(track.to_css)
        |> string.join(" "),
      ),
      sketch_css.gap(to_length(gap)),
    ]
    css.Scroller -> [
      sketch_css.display("flex"),
      sketch_css.overflow_x("auto"),
    ]
  }
}

fn state_style(
  state: css.Interaction,
  styles: List(css.Style),
) -> List(sketch_css.Style) {
  let styles = list.flat_map(styles, to_sketch)
  case state {
    css.Hover -> [sketch_css.hover(styles)]
    css.Focus -> [sketch_css.focus(styles)]
    css.Disabled -> [sketch_css.disabled(styles)]
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

fn to_length(value: css.Length) -> length.Length {
  case value {
    css.Px(value) -> length.px_(value)
    css.Rem(value) -> length.rem(value)
  }
}

fn length_to_string(value: css.Length) -> String {
  case value {
    css.Px(value) -> float.to_string(value) <> "px"
    css.Rem(value) -> float.to_string(value) <> "rem"
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
