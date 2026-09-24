import framework/front.{
  type Page, Area, ByKind, Fixed, Flow, Frame, Page, Widget,
}
import framework/front/css
import gen/blocks
import gen/service
import gleam/option.{None, Some}
import layout
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
      Area(
        name: "article-dialog",
        flow: css.Stack(gap: style.s1),
        pin: css.Overlay,
        style: [],
      ),
    ],
    placements: [
      Fixed(area: "page", block: blocks.Article, cell: Flow),
      Fixed(area: "article-dialog", block: blocks.Summary, cell: Flow),
      Widget(
        area: "rail",
        name: "article_kinds",
        of: service.WidgetList,
        render: ByKind(
          by: "kind",
          table: [
            #("Article", blocks.RowArticle),
            #("Summary", blocks.RowSummary),
          ],
        ),
      ),
    ],
    cols: [],
    rows: [],
    template: [["page"], ["rail"]],
  ),
  pc: Some(
    Frame(
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
        Area(
          name: "article-dialog",
          flow: css.Stack(gap: style.s1),
          pin: css.Overlay,
          style: [],
        ),
      ],
      placements: [],
      cols: [],
      rows: [],
      template: [],
    ),
  ),
  tablet: None,
  reads: [service.ArticleRead],
)
