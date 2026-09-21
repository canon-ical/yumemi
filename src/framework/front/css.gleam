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
}

pub type FontFamily {
  System
  SansSerif
  Serif
  Monospace
}

pub type FontWeight {
  Normal
  Medium
  Bold
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
  Scroller
}

pub type Pin {
  Top
  Bottom
  NoPin
}

pub type Animation {
  Fade
  SlideUp
  Pulse
}

pub type Img(blob, media) {
  Img(blob: blob, media: media)
}
