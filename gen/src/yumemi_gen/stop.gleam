//// 止まり方。20「差し戻しは『書けない』ことで、型・生成器・不在の3段で成立する」の
//// exit code 表をそのまま持つ。**出力が不整合なら 0 で終わってはならない**(柏木 P2-2)。
////
//// | exit | 分類 | 誰が直すか |
//// |---|---|---|
//// | 0 | 成功 | ── |
//// | 1 | 生成器の内部エラー / 未実装 | 生成器の作者 |
//// | 2 | 構文が読めない | 生成器の作者 |
//// | 3 | 宣言の不足 | 書き手(Agent) |
//// | 4 | 宣言の矛盾 | 書き手(Agent) |
//// | 5 | 語彙の不足 | framework 保守者(役員 人見) |
//// | 6 | 不可逆な差分 | framework 保守者(役員 人見) |

import gleam/int
import gleam/list
import gleam/string

pub type Class {
  /// 0 ── 止めない。生成物はそのまま書く。
  Warning
  /// 1 ── 生成器がまだ書けない。★ からは導けるのに出せないものもここ。
  NotImplemented
  /// 2 ── glance が parse できない。
  Syntax
  /// 3 ── 宣言が足りない(`key` が無い、`collection` が無い)。
  Missing
  /// 4 ── 宣言が矛盾している(from から到達できない列、`order` 無しの `Paged`、名前の衝突)。
  Conflict
  /// 5 ── 語彙が足りない。人へ上げる。
  Vocabulary
  /// 6 ── 情報を捨てる差分。人へ上げる。
  Irreversible
}

pub type Note {
  Note(class: Class, text: String)
}

pub fn code(class: Class) -> Int {
  case class {
    Warning -> 0
    NotImplemented -> 1
    Syntax -> 2
    Missing -> 3
    Conflict -> 4
    Vocabulary -> 5
    Irreversible -> 6
  }
}

pub fn label(class: Class) -> String {
  case class {
    Warning -> "警告"
    NotImplemented -> "生成器の不足"
    Syntax -> "構文が読めない"
    Missing -> "宣言の不足"
    Conflict -> "宣言の矛盾"
    Vocabulary -> "語彙の不足"
    Irreversible -> "不可逆な差分"
  }
}

/// 1行の綴り。`_diagnostics.txt` と stderr の両方で同じ形を使う。
pub fn line(note: Note) -> String {
  "[exit "
  <> int.to_string(code(note.class))
  <> " "
  <> label(note.class)
  <> "] "
  <> note.text
}

/// 止まる理由が複数あるときは、**人へ上げる側を先に返す**(6 → 5 → 4 → 3 → 2 → 1)。
/// CI は exit code だけを見て振り分けるので、一番遠くへ運ぶ理由を残す。
pub fn worst(notes: List(Note)) -> Int {
  let codes = list.map(notes, fn(note) { code(note.class) })
  case list.contains(codes, 6) {
    True -> 6
    False ->
      case list.contains(codes, 5) {
        True -> 5
        False ->
          case list.contains(codes, 4) {
            True -> 4
            False ->
              case list.contains(codes, 3) {
                True -> 3
                False ->
                  case list.contains(codes, 2) {
                    True -> 2
                    False ->
                      case codes {
                        [] -> 0
                        _ -> 0
                      }
                  }
              }
          }
      }
  }
}

pub fn report(notes: List(Note)) -> String {
  notes
  |> list.map(line)
  |> string.join("\n")
}
