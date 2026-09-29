import framework/front/track

pub type Length {
  Px(Float)
  Rem(Float)
}

pub type SpaceProperty {
  Margin
  Padding
  Gap
  Width
  Height
  Radius
  MinWidth
  MinHeight
  MaxWidth
}

pub type FontFamily {
  System
  SansSerif
  Serif
  Monospace
  Named(String)
}

pub type FontWeight {
  Normal
  Medium
  SemiBold
  Bold
}

pub type BorderEdge {
  AllEdges
  BottomEdge
}

pub type BorderStyle {
  Solid
  Dashed
  Dotted
}

pub type ObjectFit {
  Cover
  Contain
  Fill
  ScaleDown
  FitNone
}

pub type Ratio {
  Ratio(width: Float, height: Float)
}

/// 箱の寸法の数え方(`box-sizing`)。`BorderBox` は width・min-height に padding と
/// border を含める ── `min-height: 48px` と padding を持つ入力が 48px のまま出る。
pub type BoxSizing {
  BorderBox
  ContentBox
}

/// 並びの印(`list-style`)。いま書けるのは印を消す `NoMarker` だけ。
pub type ListMarker {
  NoMarker
}

/// 文字の飾り(`text-decoration`)。
pub type TextDecoration {
  NoDecoration
  Underline
}

pub type Interaction {
  Hover
  Focus
  Disabled
}

pub type Breakpoint {
  SP
  PC
  Tablet
}

pub type Style {
  Color(value: String)
  Background(value: String)
  Border(edge: BorderEdge, width: Length, style: BorderStyle, color: String)
  Outline(width: Length, offset: Length, color: String)
  Crop(fit: ObjectFit, ratio: Ratio)
  Sizing(box: BoxSizing)
  Marker(marker: ListMarker)
  Decoration(line: TextDecoration)
  Space(property: SpaceProperty, value: Length)
  Text(
    family: FontFamily,
    size: Length,
    weight: FontWeight,
    line_height: Length,
  )
  Flow(flow: Flow)
  State(state: Interaction, styles: List(Style))
  Responsive(at: Breakpoint, styles: List(Style))
  Animation(animation: Animation)
}

pub type Flow {
  Stack(gap: Length)
  Row(gap: Length, wrap: Bool)
  Grid(cols: Int, gap: Length)
  GridTracks(cols: List(track.Track), gap: Length)
  Scroller
}

pub type Pin {
  Top
  Bottom
  NoPin
  Overlay
}

pub type Animation {
  Fade
  SlideUp
  Pulse
}

pub type Img(blob, media) {
  Img(blob: blob, media: media)
}
