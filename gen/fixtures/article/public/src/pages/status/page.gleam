import yumemi/front.{type Page, Area, Fixed, Flow, Frame, Page, Query, Var}
import yumemi/front/css
import gen/blocks
import gen/service
import gleam/option.{None}
import layout
import style

pub const page: Page(service.Service, blocks.Block) = Page(
  of: None,
  layout: layout.public,
  theme: None,
  // 0.12 段 C:Layout の Feed に置いた tag_filter(reloads の一覧)が `?widget=` で取り直す
  vars: [Var("widget", Query("widget"))],
  sp: Frame(
    areas: [
      Area(
        name: "page",
        flow: css.Stack(gap: css.Px(0.0)),
        pin: css.NoPin,
        style: style.page,
      ),
    ],
    placements: [Fixed(area: "page", block: blocks.SiteHeader, cell: Flow)],
    cols: [],
    rows: [],
    template: [],
  ),
  pc: None,
  tablet: None,
)
