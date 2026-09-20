import framework/front.{type Page, Area, Fixed, Frame, Page}
import framework/front/css
import front/layout
import front/types
import gleam/option.{None, Some}

pub const page: Page(types.Service, types.Block) = Page(
  of: Some(types.ArticleRead),
  layout: layout.front,
  theme: None,
  sp: Frame(
    areas: [
      Area(
        name: "page",
        flow: css.Stack(gap: css.Px(16.0)),
        pin: css.NoPin,
        style: [],
      ),
    ],
    placements: [
      Fixed(area: "page", block: types.ArticleBody),
      Fixed(area: "page", block: types.ArticleSummary),
    ],
  ),
  pc: None,
  tablet: None,
)
