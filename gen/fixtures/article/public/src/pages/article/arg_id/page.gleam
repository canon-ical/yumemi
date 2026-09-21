import framework/front.{type Page, Area, ByKind, Fixed, Frame, Page, Widget}
import framework/front/css
import gen/blocks
import gen/service
import layout
import gleam/option.{None, Some}
import style

pub const page: Page(service.Service, blocks.Block) = Page(
  of: Some(service.ArticleRead),
  layout: layout.public,
  theme: Some("theme"),
  sp: Frame(
    areas: [
      Area(
        name: "page",
        flow: css.Stack(gap: style.s2),
        pin: css.NoPin,
        style: style.page,
      ),
      Area(
        name: "rail",
        flow: css.Stack(gap: style.s1),
        pin: css.NoPin,
        style: [],
      ),
    ],
    placements: [
      Fixed(area: "page", block: blocks.Summary),
      Widget(
        area: "rail",
        name: "article_kinds",
        of: service.ArticleRead,
        render: ByKind(
          by: "kind",
          table: [
            #("Article", blocks.Article),
            #("Summary", blocks.Summary),
          ],
        ),
      ),
    ],
  ),
  pc: Some(Frame(
    areas: [
      Area(
        name: "page",
        flow: css.Stack(gap: style.s2),
        pin: css.NoPin,
        style: style.page,
      ),
      Area(
        name: "rail",
        flow: css.Stack(gap: style.s1),
        pin: css.NoPin,
        style: [],
      ),
      Area(
        name: "aside",
        flow: css.Stack(gap: style.s1),
        pin: css.NoPin,
        style: [],
      ),
    ],
    placements: [],
  )),
  tablet: None,
)
