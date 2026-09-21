import framework/front.{type Layout, Area, Fixed, Frame, Layout, One, Widget}
import framework/front/css
import gen/blocks
import gen/service
import gleam/option.{None, Some}
import style

pub const www: Layout(service.Service, blocks.Block) = Layout(
  sp: Frame(
    areas: [
      Area(
        name: "header",
        flow: css.Stack(gap: style.s0),
        pin: css.Top,
        style: style.bar,
      ),
      Area(
        name: "page",
        flow: css.Stack(gap: style.s2),
        pin: css.NoPin,
        style: style.page,
      ),
      Area(
        name: "footer",
        flow: css.Row(gap: style.s0, wrap: False),
        pin: css.Bottom,
        style: style.bar,
      ),
    ],
    placements: [
      Fixed(area: "header", block: blocks.Summary),
      Widget(
        area: "page",
        name: "article_feed",
        of: service.ArticleList,
        render: One(blocks.Article),
      ),
    ],
  ),
  pc: Some(Frame(
    areas: [
      Area(
        name: "header",
        flow: css.Stack(gap: style.s0),
        pin: css.Top,
        style: style.bar,
      ),
      Area(
        name: "page",
        flow: css.Stack(gap: style.s2),
        pin: css.NoPin,
        style: style.page,
      ),
      Area(
        name: "aside",
        flow: css.Stack(gap: style.s1),
        pin: css.NoPin,
        style: [],
      ),
      Area(
        name: "footer",
        flow: css.Row(gap: style.s0, wrap: False),
        pin: css.Bottom,
        style: style.bar,
      ),
    ],
    placements: [],
  )),
  tablet: None,
)
