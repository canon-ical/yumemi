import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{type Attribute}
import sketch/css.{type Class}
import sketch/lustre/element
import sketch/lustre/element/html

pub type Element(message) =
  element.Element(message)

pub const text = element.text

/// Prefix for area overlay ids. Append the exact area name to form the id.
pub const overlay_id_prefix = "yumemi-overlay-"

/// A button that opens the overlay belonging to `area`.
pub fn opener(area: String, child: List(Element(message))) -> Element(message) {
  html.button_(
    [
      attribute.attribute("type", "button"),
      attribute.attribute("data-yumemi-overlay-opener", ""),
      attribute.attribute("popovertarget", overlay_id(area)),
      attribute.attribute("popovertargetaction", "show"),
    ],
    child,
  )
}

/// A button that closes the overlay belonging to `area`.
pub fn closer(area: String, child: List(Element(message))) -> Element(message) {
  html.button_(
    [
      attribute.attribute("type", "button"),
      attribute.attribute("data-yumemi-overlay-closer", ""),
      attribute.attribute("popovertarget", overlay_id(area)),
      attribute.attribute("popovertargetaction", "hide"),
    ],
    child,
  )
}

/// A badge marker whose optional count is always represented by one element.
pub fn badge(
  count: Option(Int),
  child: List(Element(message)),
) -> Element(message) {
  html.span_(
    [
      attribute.attribute("data-yumemi-badge", ""),
      attribute.attribute("data-count", badge_count(count)),
    ],
    child,
  )
}

/// A popover and its controls for one row rendered inside `each`.
///
/// `scope` identifies the `each` call site and `row_key` identifies one row
/// within that scope. A generator should provide stable, distinct tokens for
/// both. The id format is `yumemi-row-overlay-{scope length}-{scope}-{key
/// length}-{key}`. The length fields make the pair unambiguous. The id is
/// constructed here, so callers provide neither an id nor an id attribute.
pub fn each_modal(
  scope: String,
  row_key: String,
  opener_child: List(Element(message)),
  closer_child: List(Element(message)),
  child: List(Element(message)),
) -> Element(message) {
  let id = each_modal_id(scope, row_key)
  let open_button =
    html.button_(
      [
        attribute.attribute("data-yumemi-each-modal-opener", ""),
        attribute.attribute("type", "button"),
        attribute.attribute("popovertarget", id),
        attribute.attribute("popovertargetaction", "show"),
      ],
      opener_child,
    )
  let close_button =
    html.button_(
      [
        attribute.attribute("data-yumemi-each-modal-closer", ""),
        attribute.attribute("type", "button"),
        attribute.attribute("popovertarget", id),
        attribute.attribute("popovertargetaction", "hide"),
      ],
      closer_child,
    )
  let popover =
    html.div_(
      [
        attribute.attribute("id", id),
        attribute.attribute("popover", ""),
        attribute.attribute("data-yumemi-each-modal", ""),
      ],
      [close_button, ..child],
    )

  html.div_([attribute.attribute("data-yumemi-each-modal-host", "")], [
    open_button,
    popover,
  ])
}

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

fn badge_count(count: Option(Int)) -> String {
  case count {
    None -> ""
    Some(value) -> int.to_string(value)
  }
}

fn overlay_id(area: String) -> String {
  overlay_id_prefix <> area
}

fn each_modal_id(scope: String, row_key: String) -> String {
  "yumemi-row-overlay-"
  <> int.to_string(string.length(scope))
  <> "-"
  <> scope
  <> "-"
  <> int.to_string(string.length(row_key))
  <> "-"
  <> row_key
}
