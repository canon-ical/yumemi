//// 0.11.3(yumemi-fix-0113)── commit の後に続きを持つ Service の live は 202 Accepted を成功として読む(H4)。

import glance
import gleam/list
import gleam/string
import gleeunit/should
import simplifile
import yumemi_gen/emit/accepted
import yumemi_gen/emit/front as front_emit
import yumemi_gen/emit/hash
import yumemi_gen/face
import yumemi_gen/reader
import yumemi_gen/reader/front as reader_front
import yumemi_gen/source

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
    simplifile.read("fixtures/article/src/service/article_publish.gleam")
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
    simplifile.read("fixtures/article/public/src/components/like_button.gleam")
  string.replace(
    text,
    "pub const after_send: front_live.After = front_live.Stay",
    "pub const after_send: front_live.After = front_live.ReloadPage",
  )
}

fn live_text(publish: String) -> String {
  let assert Ok(back_units) = source.load("fixtures/article")
  let back_units =
    replace(back_units, [unit("service/article_publish", publish)])
  let assert Ok(app) = reader.read(back_units)
  let assert Ok(face_units) = source.load("fixtures/article/public")
  let face_units =
    replace(face_units, [
      unit("components/like_button", reloading_component()),
    ])
  let assert Ok(front_model) =
    reader_front.read("public", face_units, app.services)
  let package =
    face.Package(
      name: "public",
      path: "fixtures/article/public",
      pages: face.UndeclaredPages,
      units: face_units,
    )
  let assert Ok(file) =
    front_emit.emit(app, back_units, package, front_model, hash.of(back_units))
    |> list.find(fn(file) {
      file.path == "public/src/gen/live/article_publish.gleam"
    })
  // 生成物は gleam の構文として読める
  let assert Ok(_) = glance.module(file.text)
  file.text
}

/// 宣言から決める:`step.commit(` を持つ Service は 202 を返す、持たない Service は返さない。
pub fn accepts_follows_commit_test() {
  let assert Ok(units) = source.load("fixtures/article")
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

/// H4:commit の後に続きを持つ Service の live は `Reply` を持ち、202 の 1 欄の本文を `Accepted(id)` に読んで
/// `Done(Ok(_))` にする(after_send の読み直しへ進む)。200 の Out は `Replied(out)`。
pub fn live_reads_accepted_as_success_test() {
  let text = live_text(committing_source())
  string.contains(
    text,
    "pub type Reply {\n  Replied(article_publish.Out)\n  Accepted(id: String)\n}",
  )
  |> should.be_true
  string.contains(
    text,
    "pub type State = live.State(Args, Nil, Reply, Failure)",
  )
  |> should.be_true
  string.contains(
    text,
    "pub type Event = live.Event(Field, Nil, Reply, Failure)",
  )
  |> should.be_true
  string.contains(text, "case decode.run(value, reply_decoder()) {")
  |> should.be_true
  string.contains(text, "Ok(reply) -> dispatch(live.Done(Ok(reply)))")
  |> should.be_true
  string.contains(
    text,
    "decode.one_of(decode.map(article_publish.decoder(), Replied), [",
  )
  |> should.be_true
  string.contains(
    text,
    "use fields <- decode.then(decode.dict(decode.string, decode.string))",
  )
  |> should.be_true
  string.contains(text, "[#(_, id)] -> decode.success(Accepted(id))")
  |> should.be_true
  string.contains(text, "import gleam/dict") |> should.be_true
  // Done(Ok(_)) は after_send(ReloadPage)へ
  string.contains(text, "Ok(_) -> #(next, reload_page())") |> should.be_true
  string.contains(text, "event.emit(\"yumemi-done\", json.null())")
  |> should.be_true
  // 読めない本文は今までどおり invalid response
  string.contains(
    text,
    "Error(_) -> dispatch(live.Done(Error(Broke(\"invalid response\"))))",
  )
  |> should.be_true
}

/// 202 を返さない Service の live は 0.11.2 と同じ(Out を持ち、Out の decoder だけ)。
pub fn live_without_commit_keeps_out_test() {
  let text = live_text(publish_source())
  string.contains(text, "Reply") |> should.be_false
  string.contains(text, "Accepted") |> should.be_false
  string.contains(text, "import gleam/dict") |> should.be_false
  string.contains(
    text,
    "pub type State = live.State(Args, Nil, article_publish.Out, Failure)",
  )
  |> should.be_true
  string.contains(text, "case decode.run(value, article_publish.decoder()) {")
  |> should.be_true
  string.contains(text, "Ok(out) -> dispatch(live.Done(Ok(out)))")
  |> should.be_true
}
