import gleam/list
import lustre/attribute.{type Attribute}
import sketch/css.{type Class}
import sketch/lustre/element
import sketch/lustre/element/html

pub type Element(message) =
  element.Element(message)

pub const text = element.text

pub fn img(
  class: Class,
  attributes: List(Attribute(message)),
) -> Element(message) {
  html.img(class, attributes)
}

pub fn each(
  items: List(item),
  view: fn(item) -> Element(message),
) -> Element(message) {
  items
  |> list.map(view)
  |> element.fragment
}

pub fn island(
  component: String,
  attributes: List(Attribute(message)),
) -> Element(message) {
  element.element_(component, attributes, [])
}
