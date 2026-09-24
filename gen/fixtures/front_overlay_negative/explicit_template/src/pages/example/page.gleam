import framework/front.{type Page, Area, Frame, Page}
import framework/front/css
import gleam/option.{None}

pub const page: Page(Nil, Nil) = Page(
  of: None,
  layout: None,
  theme: None,
  sp: Frame(
    areas: [
      Area(
        name: "article-dialog",
        flow: css.Stack(gap: css.Px(0.0)),
        pin: css.Overlay,
        style: [],
      ),
    ],
    placements: [],
    cols: [],
    rows: [],
    template: [["article-dialog"]],
  ),
  pc: None,
  tablet: None,
  reads: [],
)
