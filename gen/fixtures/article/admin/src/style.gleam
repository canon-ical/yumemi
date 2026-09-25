import framework/front/css

pub const ink: css.Style = css.Color("#2b1d3a")

pub const body: css.Style = css.Text(
  family: css.System,
  size: css.Rem(1.0),
  weight: css.Normal,
  line_height: css.Rem(1.5),
)

pub const heading: css.Style = css.Text(
  family: css.Serif,
  size: css.Rem(1.5),
  weight: css.Bold,
  line_height: css.Rem(1.8),
)

pub const page: List(css.Style) = [css.Color("#fffaff")]
