//// yumemi-live-1(0.14)── 他人の書き込みを画面に届ける合図の器と札(api の側)。
//// 生成器は registry に合図の宛先の表(`live`、root の Entity を持つ Service -> [Entity, root の行の id の列])を
//// 書き、http_runtime がそれを入口へ渡し、shell が合図の器 `YumemiLive` を export する。★ の宣言と型は増えない。
//// 器・札・socket の口は workerd で回す(`yumemi_live_check.mjs`)。

import glance
import gleam/list
import gleam/string
import gleeunit/should
import yumemi/gen/emit/back
import yumemi/gen/emit/hash
import yumemi/gen/reader
import yumemi/gen/reader/server as server_reader
import yumemi/gen/source
import yumemi/gen/stop

@external(javascript, "./yumemi_live_test_ffi.mjs", "live_check")
fn live_check() -> String

fn files_of(units: List(source.Unit)) -> List(#(String, String)) {
  let assert Ok(app) = reader.read(units)
  back.emit(app, units, hash.of(units), [], []).files
  |> list.map(fn(file) { #(file.path, file.text) })
}

fn text_of(files: List(#(String, String)), path: String) -> String {
  let assert Ok(#(_, text)) = list.find(files, fn(file) { file.0 == path })
  text
}

/// 宛先は root の Entity を持つ Service だけ(読みも書きも)。作る Service(root の無い `note_create`)と
/// 一覧(`note_list`)は表に無い。
pub fn registry_has_the_live_table_test() {
  let assert Ok(units) = source.load("gen/fixtures/notes")
  let files = files_of(units)
  let registry = text_of(files, "src/gen/registry.mjs")
  string.contains(
    registry,
    "export const live = {\n  note_delete: ['note', 'id'],\n  note_edit: ['note', 'id'],\n  note_read: ['note', 'id'],\n};\n",
  )
  |> should.be_true
  string.contains(registry, "note_create: [") |> should.be_false
  string.contains(registry, "note_list: [") |> should.be_false
  let http = text_of(files, "src/gen/http_runtime.mjs")
  string.contains(http, "import { registry, live } from './registry.mjs';")
  |> should.be_true
  string.contains(http, "http({Ok,Error,registry,live,attached,")
  |> should.be_true
  let shell = text_of(files, "src/gen/shell.mjs")
  string.contains(
    shell,
    "export { YumemiLive } from '../../yumemi/yumemi/server/worker.mjs';\n",
  )
  |> should.be_true
}

/// ★ の器に `YumemiLive` の名は使えない(生成の shell が同じ名を export する)── 宣言の矛盾(exit 4)。
pub fn the_class_name_is_reserved_test() {
  let assert Ok(units) = source.load("gen/fixtures/notes")
  let text =
    "import yumemi/server.{DurableObject}\n\npub const durable_objects: List(server.DurableObject) = [DurableObject(class: \"YumemiLive\", module: \"live_do\", adapter: \"LiveDo\", methods: [])]\n"
  let assert Ok(module) = glance.module(text)
  let units =
    list.filter(units, fn(unit) { unit.path != "server" })
    |> list.append([source.Unit(path: "server", text: text, module: module)])
  let assert Ok(app) = reader.read(units)
  server_reader.notes(app)
  |> list.any(fn(note) {
    note.class == stop.Conflict
    && string.contains(note.text, "class の名 YumemiLive は合図の器の名")
  })
  |> should.be_true
}

/// workerd:札・socket の口(署名・期限・party・Origin)・合図・合図の失敗が書きの応答を変えないこと。
/// r2:張った socket が札の期限で閉じる・party の無い札は browser に結ぶ・前の鍵・API key の入口・★ の origin
/// hook・commit の後に投げた書き・DO の fetch が投げた socket。
pub fn live_on_workerd_test() {
  let out = live_check()
  string.contains(out, "NG ") |> should.be_false
  string.contains(out, "STDERR") |> should.be_false
  string.split(out, "\n") |> list.length |> should.equal(89)
}
