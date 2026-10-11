//// GENERATED from src/components/article_blob_copy.gleam [sha256:62df9e944a06] — 手で編集しない

import yumemi/front/css
import yumemi/front/el
import yumemi/front/live

pub type Args {
  Args(file: String, from: String)
}

pub type Field {
  File
  From
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
  OutKey
}

/// name="blob_copy.<field>" と、Spec から写せる制約検証の属性と value。
pub fn bind(field: Field, value: String) -> el.Attribute {
  case field {
    File -> live.bind("blob_copy", "file", value, [])
    From -> live.bind("blob_copy", "from", value, [])
  }
}

/// checkbox。
pub fn bind_check(field: Field, checked: Bool) -> el.Attribute {
  live.bind_check("blob_copy", field_name(field), checked)
}

/// select と radio の name(選択肢は attr.value / attr.selected)。
pub fn bind_choice(field: Field) -> el.Attribute {
  live.bind_choice("blob_copy", field_name(field))
}

/// file の control(Blob の欄)。送る前に runtime が上げ、key を Args に入れる。
pub fn bind_file(field: Field) -> el.Attribute {
  live.bind_file("blob_copy", field_name(field))
}

/// data-yumemi-when="blob_copy.<state>" の枝。
pub fn when(state: When, children: List(el.Element)) -> el.Element {
  live.when("blob_copy", state_name(state), children)
}

/// data-yumemi-out="blob_copy.<slot>" の空の span。
pub fn out(slot: Slot) -> el.Element {
  live.out("blob_copy", slot_name(slot))
}

/// 送りのボタン。叩くのはこの Service 1 本。
pub fn send(class: css.Class, children: List(el.Element)) -> el.Element {
  live.send("blob_copy", class, children)
}

/// `data-yumemi-args` の JSON(生成物の `gen/interactive` が使う)。
@internal
pub fn args_json(args: Args) -> String {
  live.json_object([
    #("file", live.json_string(args.file)),
    #("from", live.json_string(args.from)),
  ])
}

fn field_name(field: Field) -> String {
  case field {
    File -> "file"
    From -> "from"
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
    OutKey -> "key"
  }
}
