import gleam/option.{None}
import yumemi/front/theme

pub const lang: String = "ja"

pub const title: String = "yumemi front fixture"

pub const theme: theme.Defaults = theme.Defaults(
  background: "#FAF7F0",
  text: "#3D2419",
  accent: "#A93632",
  background_image: None,
)

pub const stylesheets: List(String) = ["/fixture.css"]
