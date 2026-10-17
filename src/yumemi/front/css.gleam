import yumemi/front/track

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
  /// 左の辺の内側の余白だけ(`padding-left`、0.14.4)。見出しの帯と字の間など。
  PaddingLeft
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
  TopEdge
  BottomEdge
  /// 左の辺だけ(0.13.1)。見出しの帯・引用の縦線など。
  LeftEdge
  /// 右の辺だけ(0.13.1)。
  RightEdge
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

/// 行の中での折り返し(`overflow-wrap`)。`Anywhere` は長い URL のような切れ目の無い
/// 語も行の幅で折る(min-content の幅にも効く)。`BreakWord` は折るが min-content の
/// 幅には効かない。`WrapNormal` は既定(語の切れ目だけで折る)。
pub type OverflowWrap {
  Anywhere
  BreakWord
  WrapNormal
}

/// はみ出した中身の扱い(`overflow-x`、0.13.1)。`OverflowAuto` は溢れたときだけ横に送れる
/// (幅の広い表・コードの塊を本文の幅に収める)。
pub type Overflow {
  OverflowAuto
  OverflowHidden
  OverflowVisible
  OverflowScroll
}

/// 空白と改行の扱い(`white-space`、0.13.1)。`Pre` は空白も改行もそのまま描いて折らない(コードの塊)。
/// `PreWrap` はそのまま描いて行の幅で折る。`PreLine` は改行だけ残す。`NoWrap` は折らない。
pub type WhiteSpace {
  SpaceNormal
  Pre
  PreWrap
  PreLine
  NoWrap
}

/// 字の傾き(`font-style`、0.13.1)。
pub type FontSlant {
  Upright
  Italic
}

pub type Interaction {
  /// `:hover`。touch の端末では指で押した後も残る(地が残る)。
  Hover
  /// `:focus`。指やマウスで押した後も残る(枠が残る)。
  Focus
  /// `:focus-visible`。ブラウザがキーボードの焦点と見たときだけ(指やマウスで押した
  /// 後には出ない)。焦点の枠はこちらに掛ける。
  FocusVisible
  /// `@media (hover: hover) { :hover }`。hover が出来る端末(マウスなど)でだけ。
  /// touch の端末では押した後に地が残らない。
  HoverCapable
  Disabled
  /// 今いる所(`aria-current` が `false` 以外)。ナビの選択中の項目に掛ける。
  Current
  /// 祖先の interactive Component が送りを待っている(`:state(waiting)`)。`:state()` の
  /// 無い browser では runtime が写す `[data-yumemi-state~="waiting"]` で効く。
  Waiting
  /// 祖先の interactive Component の最後の送りが成功した(`:state(ok)`)。
  Succeeded
  /// 祖先の interactive Component の最後の送りが失敗した(`:state(error)`)。
  Failed
  /// 地の画像のある頁(framework が body に立てる `data-yumemi-theme-image` の内側)。
  ThemeImage
}

/// 色。字の素通しは無く、どの値も CSS の色の字を framework が組む。
pub type Paint {
  /// `#rrggbb` の literal(生成器が検査する、第 23 条)。形の合わない字は `unset`。
  Hex(String)
  /// `var(--<name>)`。名は `[a-z0-9-]+`(第 24 条)。合わない名は `unset`。
  Token(String)
  /// 頁の色(`--yumemi-theme-*`)。
  Theme(ThemeSlot)
  /// `color-mix(in oklab, a p%, b)`。`percent` は 0〜100(第 25 条、外れた値は端に寄せる)。
  Mix(a: Paint, b: Paint, percent: Int)
  Transparent
  CurrentColor
}

/// 頁の色の 3 色(地・字・差し色)。
pub type ThemeSlot {
  ThemeBackground
  ThemeText
  ThemeAccent
}

/// 行の中の揃え(`text-align`)。
pub type TextAlignment {
  TextStart
  TextCenter
  TextEnd
}

pub type Breakpoint {
  SP
  PC
  Tablet
}

pub type Style {
  Color(value: Paint)
  Background(value: Paint)
  Border(edge: BorderEdge, width: Length, style: BorderStyle, color: Paint)
  Outline(width: Length, offset: Length, color: Paint)
  Crop(fit: ObjectFit, ratio: Ratio)
  Sizing(box: BoxSizing)
  Marker(marker: ListMarker)
  Decoration(line: TextDecoration)
  Wrap(wrap: OverflowWrap)
  Space(property: SpaceProperty, value: Length)
  Text(
    family: FontFamily,
    size: Length,
    weight: FontWeight,
    line_height: Length,
  )
  Flow(flow: Flow)
  TextAlign(align: TextAlignment)
  /// 箱を親の幅の中で横の中央に置く(`margin-left` と `margin-right` を `auto`、0.13.1)。`MaxWidth` と組む。
  /// 上下の margin は触らない。
  Center
  /// 横にはみ出した中身の扱い(`overflow-x`、0.13.1)。
  OverflowX(overflow: Overflow)
  /// 空白と改行の扱い(`white-space`、0.13.1)。
  Spaces(white_space: WhiteSpace)
  /// 字の傾き(`font-style`、0.13.1)。
  Slant(slant: FontSlant)
  State(state: Interaction, styles: List(Style))
  Responsive(at: Breakpoint, styles: List(Style))
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
  /// 画面の下端に着く棒(`position: sticky; bottom: 0`)。safe area(iPhone の下端の
  /// バー)の分は棒の内側の下の余白(`padding-bottom: env(safe-area-inset-bottom, 0px)`)
  /// で持つ ── 棒の地は画面の下端まで届き、中身はバーに重ならない。`Bottom` は
  /// `bottom: env(safe-area-inset-bottom)` で浮いて止まる(出力は変えない)。
  BottomFlush
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

pub type Img(blob, media) {
  Img(blob: blob, media: media)
}

/// 要素に掛ける Style の束。`html.div(css.class(styles), ..)` のように要素の関数の第 1 引数で
/// 渡す。class 名は描くときに framework が Style から作る(同じ Style なら同じ名)。
pub opaque type Class {
  Class(styles: List(Style))
}

pub fn class(styles: List(Style)) -> Class {
  Class(styles)
}

@internal
pub fn class_styles(class: Class) -> List(Style) {
  class.styles
}
