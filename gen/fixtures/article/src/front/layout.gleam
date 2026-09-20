import framework/front.{type Layout, Area, Frame, Layout}
import framework/front/css
import front/types
import gleam/option.{None}

pub const front: Layout(types.Service, types.Block) = Layout(
  sp: Frame(
    areas: [
      Area(
        name: "page",
        flow: css.Stack(gap: css.Px(16.0)),
        pin: css.NoPin,
        style: [],
      ),
    ],
    placements: [],
  ),
  pc: None,
  tablet: None,
)
