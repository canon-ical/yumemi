import framework/front/css
import gleam/option.{type Option}

pub type Layout(service, block) {
  Layout(
    sp: Frame(service, block),
    pc: Option(Frame(service, block)),
    tablet: Option(Frame(service, block)),
  )
}

pub type Page(service, block) {
  Page(
    of: Option(service),
    layout: Layout(service, block),
    theme: Option(String),
    sp: Frame(service, block),
    pc: Option(Frame(service, block)),
    tablet: Option(Frame(service, block)),
  )
}

pub type Frame(service, block) {
  Frame(areas: List(Area), placements: List(Placement(service, block)))
}

pub type Area {
  Area(name: String, flow: css.Flow, pin: css.Pin, style: List(css.Style))
}

pub type Placement(service, block) {
  Fixed(area: String, block: block)
  Widget(area: String, name: String, of: service, render: Render(block))
}

pub type Render(block) {
  One(block: block)
  ByKind(by: String, table: List(#(String, block)))
}
