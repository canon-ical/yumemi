import framework/front/css

pub type MediaVariant {
  Thumb
  W800
  W1600
  Cast
}

pub const ink: css.Style = css.Color("#2b1d3a")
pub const paper: css.Style = css.Color("#fffaff")
pub const accent: css.Style = css.Color("#7a3f8c")
pub const muted: css.Style = css.Color("#6f6574")

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

pub const s0: css.Length = css.Px(0.0)
pub const s1: css.Length = css.Px(8.0)
pub const s2: css.Length = css.Px(16.0)
pub const s3: css.Length = css.Px(24.0)

pub const sp: css.Breakpoint = css.SP
pub const pc: css.Breakpoint = css.PC
pub const tablet: css.Breakpoint = css.Tablet

pub const bar: List(css.Style) = [paper, css.Space(property: css.Padding, value: s2)]
pub const page: List(css.Style) = [paper]

pub const thumb: MediaVariant = Thumb
pub const w800: MediaVariant = W800
pub const w1600: MediaVariant = W1600
pub const cast: MediaVariant = Cast
