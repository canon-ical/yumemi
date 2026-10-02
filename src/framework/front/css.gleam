import framework/front/track

pub type Length {
  Px(Float)
  Rem(Float)
  /// `var(--name)`。名は `[a-z0-9-]` だけを通す ── 他の字を含む名は `unset` になる
  /// (宣言の外へ出る字 `;`・`}`・`)`・空白を CSS に書かないため)。
  Var(name: String)
  /// `env(safe-area-inset-<辺>, 0px)`。safe area を持たない端末では 0px。
  Env(edge: SafeArea)
  /// `<n>dvh`(動的な viewport の高さに対する割合)。
  Dvh(Float)
}

/// safe area の 4 辺(`env(safe-area-inset-*)`)。
pub type SafeArea {
  SafeTop
  SafeRight
  SafeBottom
  SafeLeft
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
  /// 今いる所(`aria-current` が `false` 以外)。ナビの選択中の項目に掛ける。
  Current
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
  /// 開いた `el.opener` の下か上へ寄せて開く Overlay(CSS anchor positioning)。
  /// 支えの無い browser では `Overlay` と同じく中央に開く。backdrop は暗くしない。
  AnchoredOverlay(side: OverlaySide, align: OverlayAlign)
}

/// 寄せた Overlay をボタンのどちら側に開くか。
pub type OverlaySide {
  Below
  Above
}

/// 寄せた Overlay の横の揃え。`AlignStart` はボタンの始端に、`AlignEnd` は終端に
/// そろえる。
pub type OverlayAlign {
  AlignStart
  AlignEnd
}

pub type Animation {
  Fade
  SlideUp
  Pulse
}

pub type Img(blob, media) {
  Img(blob: blob, media: media)
}
