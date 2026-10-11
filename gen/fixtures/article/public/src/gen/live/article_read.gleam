//// GENERATED from src/components/tag_filter.gleam [sha256:bcd31ba125a3] — 手で編集しない

import yumemi/front/css
import yumemi/front/el
import yumemi/front/live

pub type Args {
  Args(slug: String)
}

pub type Field {
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

pub type Slot {
  OutArticle
  OutCategory
  OutTheme
}

/// name="article_read.<field>" と、Spec から写せる制約検証の属性と value。
pub fn bind(field: Field, value: String) -> el.Attribute {
  case field {
    Slug ->
      live.bind("article_read", "slug", value, [
        live.MinLength(1),
        live.Required,
        live.MaxLength(64),
        live.Pattern("[a-z0-9]+(-[a-z0-9]+)*"),
      ])
  }
}

/// checkbox。
pub fn bind_check(field: Field, checked: Bool) -> el.Attribute {
  live.bind_check("article_read", field_name(field), checked)
}

/// select と radio の name(選択肢は attr.value / attr.selected)。
pub fn bind_choice(field: Field) -> el.Attribute {
  live.bind_choice("article_read", field_name(field))
}

/// file の control(Blob の欄)。送る前に runtime が上げ、key を Args に入れる。
pub fn bind_file(field: Field) -> el.Attribute {
  live.bind_file("article_read", field_name(field))
}

/// data-yumemi-when="article_read.<state>" の枝。
pub fn when(state: When, children: List(el.Element)) -> el.Element {
  live.when("article_read", state_name(state), children)
}

/// data-yumemi-out="article_read.<slot>" の空の span。
pub fn out(slot: Slot) -> el.Element {
  live.out("article_read", slot_name(slot))
}

/// 送りのボタン。叩くのはこの Service 1 本。
pub fn send(class: css.Class, children: List(el.Element)) -> el.Element {
  live.send("article_read", class, children)
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
    _ -> ""
  }
}

fn slot_name(slot: Slot) -> String {
  case slot {
    OutArticle -> "article"
    OutCategory -> "category"
    OutTheme -> "theme"
  }
}
