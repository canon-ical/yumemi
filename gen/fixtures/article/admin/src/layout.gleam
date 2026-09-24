import framework/front.{type Layout, Area, Frame, Layout}
import framework/front/css
import gen/blocks
import gen/service
import gleam/option.{None}
import style

pub const admin: Layout(service.Service, blocks.Block) = Layout(
  vars: [],
  sp: Frame(
    areas: [
      Area(
        name: "page",
        flow: css.Stack(gap: css.Px(0.0)),
        pin: css.NoPin,
        style: style.page,
      ),
    ],
    placements: [],
    cols: [],
    rows: [],
    template: [],
  ),
  pc: None,
  tablet: None,
)
