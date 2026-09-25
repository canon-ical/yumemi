import framework/front.{
  type Layout, Area, AuthOrigin, Fixed, Flow, Frame, Layout, One, Origin, Var,
  Widget,
}
import framework/front/css
import gen/blocks
import gen/service
import gleam/option.{None, Some}
import style

pub const public: Layout(service.Service, blocks.Block) = Layout(
  vars: [
    Var("www_origin", Origin("public")),
    Var(name: "auth_origin", from: AuthOrigin),
  ],
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
      Fixed(area: "header", block: blocks.SiteHeader, cell: Flow),
      Widget(area: "page", of: service.WidgetList, render: One(blocks.Feed)),
    ],
    cols: [],
    rows: [],
    template: [],
  ),
  pc: Some(
    Frame(
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
      cols: [],
      rows: [],
      template: [],
    ),
  ),
  tablet: None,
)
