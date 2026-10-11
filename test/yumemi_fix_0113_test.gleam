//// 0.11.3(yumemi-fix-0113)── commit の後に続きを持つ Service の live は 202 Accepted を成功として読む(H4)。

import glance
import gleam/list
import gleam/string
import gleeunit/should
import simplifile
import yumemi/gen/emit/accepted
import yumemi/gen/emit/front as front_emit
import yumemi/gen/emit/hash
import yumemi/gen/face
import yumemi/gen/reader
import yumemi/gen/reader/front as reader_front
import yumemi/gen/source

fn unit(path: String, text: String) -> source.Unit {
  let assert Ok(module) = glance.module(text)
  source.Unit(path: path, text: text, module: module)
}

fn replace(
  units: List(source.Unit),
  extra: List(source.Unit),
) -> List(source.Unit) {
  let paths = list.map(extra, fn(item) { item.path })
  list.append(
    list.filter(units, fn(item) { !list.contains(paths, item.path) }),
    extra,
  )
}

fn publish_source() -> String {
  let assert Ok(text) =
    simplifile.read("gen/fixtures/article/src/service/article_publish.gleam")
  text
}

/// fixture の `article_publish` を、commit の後に続きを持つ形にする(runtime の commit は outbox を書いて
/// `False` を返すので、HTTP は 202 Accepted で終わる)。
fn committing_source() -> String {
  publish_source()
  |> string.replace(
    "      step.done(it.article)\n",
    "      use article <- step.commit(it.article)\n      step.done(article)\n",
  )
}

/// like_button(`article_publish` を呼ぶ)を、送った後に頁を読み直す形にする。
fn reloading_component() -> String {
  let assert Ok(text) =
    simplifile.read(
      "gen/fixtures/article/public/src/components/like_button.gleam",
    )
  // 0.12 段 C:書きの送りの成功の後は頁の読み直し(After の組)
  string.replace(
    text,
    "live.After(ok: live.Stay, error: live.Stay)",
    "live.After(ok: live.ReloadPage(notice: None), error: live.Stay)",
  )
  |> string.replace(
    "import gen/service\n",
    "import gen/service\nimport gleam/option.{None}\n",
  )
}

fn live_text(publish: String) -> String {
  let assert Ok(back_units) = source.load("gen/fixtures/article")
  let back_units =
    replace(back_units, [unit("service/article_publish", publish)])
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("gen/fixtures/article/public")
  let face_units =
    replace(face_units, [
      unit("components/like_button", reloading_component()),
    ])
  let assert Ok(front_model) =
    reader_front.read("public", face_units, app.services)
  let package =
    face.Package(
      name: "public",
      path: "gen/fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let files =
    front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
  let assert Ok(file) =
    list.find(files, fn(file) {
      file.path == "public/src/gen/live/article_publish.gleam"
    })
  // 生成物は gleam の構文として読める
  let assert Ok(_) = glance.module(file.text)
  // 0.12 段 C:202 の扱いは runtime の表(client.mjs)に移ったので、live と表を並べて返す
  let assert Ok(client) =
    list.find(files, fn(file) {
      file.path == "public/priv/static/_yumemi/client.mjs"
    })
  file.text <> "\n----\n" <> client.text
}

/// 宣言から決める:`step.commit(` を持つ Service は 202 を返す、持たない Service は返さない。
pub fn accepts_follows_commit_test() {
  let assert Ok(units) = source.load("gen/fixtures/article")
  let assert Ok(app) = reader.read(units)
  let assert Ok(publish) =
    list.find(app.services, fn(service) { service.module == "article_publish" })
  accepted.accepts(app, units, publish) |> should.be_false

  let units =
    replace(units, [unit("service/article_publish", committing_source())])
  let assert Ok(app) = reader.read(units)
  let assert Ok(publish) =
    list.find(app.services, fn(service) { service.module == "article_publish" })
  accepted.accepts(app, units, publish) |> should.be_true
  // 他の Service は変わらない
  app.services
  |> list.filter(fn(service) { accepted.accepts(app, units, service) })
  |> list.map(fn(service) { service.module })
  |> should.equal(["article_publish"])
}

/// H4:commit の後に続きを持つ Service は 202 と 1 欄の本文(`{<root>: id}`)を成功として読み、after_send の
/// 読み直しへ進む。0.12 段 C:読み方は runtime(ok の応答を Out として out と GoTo の穴に使う)で、表が
/// `"accepted": true` を持ち、GoTo の穴の検査(第 15 条)を外す。期待を live の Reply 型から表の行に替えた。
pub fn live_reads_accepted_as_success_test() {
  let text = live_text(committing_source())
  string.contains(text, "pub type Reply") |> should.be_false
  string.contains(
    text,
    "\"article_publish\": { \"method\": \"POST\", \"path\": \"/api/articles/:slug/publish\", \"read\": false, \"upload\": false, \"accepted\": true,",
  )
  |> should.be_true
  string.contains(
    text,
    "\"ok\": { \"then\": \"reload\" }, \"error\": { \"then\": \"stay\" }",
  )
  |> should.be_true
}

/// 202 を返さない Service の live は 0.11.2 と同じ(Out を持ち、Out の decoder だけ)。
/// 0.12 段 C:表の `"accepted": false`(期待を替えた)。
pub fn live_without_commit_keeps_out_test() {
  let text = live_text(publish_source())
  string.contains(text, "Reply") |> should.be_false
  string.contains(text, "Accepted") |> should.be_false
  string.contains(text, "import gleam/dict") |> should.be_false
  string.contains(
    text,
    "\"article_publish\": { \"method\": \"POST\", \"path\": \"/api/articles/:slug/publish\", \"read\": false, \"upload\": false, \"accepted\": false,",
  )
  |> should.be_true
}
