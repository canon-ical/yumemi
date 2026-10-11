//// GENERATED from src/components/tag_filter.gleam [sha256:2061651af7cb] — 手で編集しない

import gleam/option.{type Option}
import yumemi/front/css
import yumemi/front/el
import yumemi/front/live

pub type Args {
  Args(widget: Option(String), slug: Option(String))
}

pub type Field {
  Widget
  Slug
}

pub type Error

pub type When {
  Idle
  Waiting
  Succeeded
  Failed
  Refused(Error)
}

pub type Slot

/// name="widget_list.<field>" と、Spec から写せる制約検証の属性と value。
pub fn bind(field: Field, value: String) -> el.Attribute {
  case field {
    Widget -> live.bind("widget_list", "widget", value, [])
    Slug -> live.bind("widget_list", "slug", value, [])
  }
}

/// checkbox。
pub fn bind_check(field: Field, checked: Bool) -> el.Attribute {
  live.bind_check("widget_list", field_name(field), checked)
}

/// select と radio の name(選択肢は attr.value / attr.selected)。
pub fn bind_choice(field: Field) -> el.Attribute {
  live.bind_choice("widget_list", field_name(field))
}

/// file の control(Blob の欄)。送る前に runtime が上げ、key を Args に入れる。
pub fn bind_file(field: Field) -> el.Attribute {
  live.bind_file("widget_list", field_name(field))
}

/// data-yumemi-when="widget_list.<state>" の枝。
pub fn when(state: When, children: List(el.Element)) -> el.Element {
  live.when("widget_list", state_name(state), children)
}

/// data-yumemi-out="widget_list.<slot>" の空の span。
pub fn out(slot: Slot) -> el.Element {
  live.out("widget_list", slot_name(slot))
}

/// 送りのボタン。叩くのはこの Service 1 本。
pub fn send(class: css.Class, children: List(el.Element)) -> el.Element {
  live.send("widget_list", class, children)
}

/// `data-yumemi-args` の JSON(生成物の `gen/interactive` が使う)。
@internal
pub fn args_json(args: Args) -> String {
  live.json_object([
    #("widget", live.json_option(args.widget, live.json_string)),
    #("slug", live.json_option(args.slug, live.json_string)),
  ])
}

fn field_name(field: Field) -> String {
  case field {
    Widget -> "widget"
    Slug -> "slug"
  }
}

fn state_name(state: When) -> String {
  case state {
    Idle -> "idle"
    Waiting -> "waiting"
    Succeeded -> "succeeded"
    Failed -> "failed"
    Refused(error) -> "refused-" <> error_code(error)
  }
}

fn error_code(error: Error) -> String {
  case error {
    _ -> ""
  }
}

fn slot_name(slot: Slot) -> String {
  case slot {
    _ -> ""
  }
}
