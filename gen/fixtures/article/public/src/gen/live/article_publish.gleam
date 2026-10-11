//// GENERATED from src/components/article_manage.gleam [sha256:457d64aa5779] — 手で編集しない

import yumemi/front/css
import yumemi/front/el
import yumemi/front/live

pub type Args {
  Args(slug: String)
}

pub type Field {
  Slug
}

pub type Error {
  AlreadyPublished
  AlreadyRetracted
}

pub type When {
  Idle
  Waiting
  Succeeded
  Failed
  Refused(Error)
}

pub type Slot {
  OutSlug
  OutTitle
  OutBody
  OutVersion
  OutOrder
  OutCategory
  OutTags
}

/// name="article_publish.<field>" と、Spec から写せる制約検証の属性と value。
pub fn bind(field: Field, value: String) -> el.Attribute {
  case field {
    Slug ->
      live.bind("article_publish", "slug", value, [
        live.MinLength(1),
        live.Required,
        live.MaxLength(64),
        live.Pattern("[a-z0-9]+(-[a-z0-9]+)*"),
      ])
  }
}

/// checkbox。
pub fn bind_check(field: Field, checked: Bool) -> el.Attribute {
  live.bind_check("article_publish", field_name(field), checked)
}

/// select と radio の name(選択肢は attr.value / attr.selected)。
pub fn bind_choice(field: Field) -> el.Attribute {
  live.bind_choice("article_publish", field_name(field))
}

/// file の control(Blob の欄)。送る前に runtime が上げ、key を Args に入れる。
pub fn bind_file(field: Field) -> el.Attribute {
  live.bind_file("article_publish", field_name(field))
}

/// data-yumemi-when="article_publish.<state>" の枝。
pub fn when(state: When, children: List(el.Element)) -> el.Element {
  live.when("article_publish", state_name(state), children)
}

/// data-yumemi-out="article_publish.<slot>" の空の span。
pub fn out(slot: Slot) -> el.Element {
  live.out("article_publish", slot_name(slot))
}

/// 送りのボタン。叩くのはこの Service 1 本。
pub fn send(class: css.Class, children: List(el.Element)) -> el.Element {
  live.send("article_publish", class, children)
}

/// `data-yumemi-args` の JSON(生成物の `gen/interactive` が使う)。
@internal
pub fn args_json(args: Args) -> String {
  live.json_object([
    #("slug", live.json_string(args.slug)),
  ])
}

fn field_name(field: Field) -> String {
  case field {
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
    AlreadyPublished -> "already-published"
    AlreadyRetracted -> "already-retracted"
  }
}

fn slot_name(slot: Slot) -> String {
  case slot {
    OutSlug -> "slug"
    OutTitle -> "title"
    OutBody -> "body"
    OutVersion -> "version"
    OutOrder -> "order"
    OutCategory -> "category"
    OutTags -> "tags"
  }
}
