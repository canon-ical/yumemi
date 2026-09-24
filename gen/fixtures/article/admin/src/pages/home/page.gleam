import framework/front.{
  type Page, Area, Fixed, Flow, Frame, Page, Session, SubjectHandle, Var,
}
import framework/front/css
import gen/blocks
import gen/service
import gleam/option.{None}
import layout
import style

pub const page: Page(service.Service, blocks.Block) = Page(
  of: None,
  layout: layout.admin,
  theme: None,
  vars: [Var(name: "subject", from: Session(SubjectHandle))],
  sp: Frame(
    areas: [
      Area(
        name: "page",
        flow: css.Stack(gap: css.Px(0.0)),
        pin: css.NoPin,
        style: style.page,
      ),
    ],
    placements: [Fixed(area: "page", block: blocks.AdminHeader, cell: Flow)],
    cols: [],
    rows: [],
    template: [],
  ),
  pc: None,
  tablet: None,
)
