//// 0.11.3(H4)── HTTP の応答が 202 Accepted になる Service を宣言から決める。
////
//// runtime の `commit` は、commit を解釈の境だけにする consumer(`boundaries`)でなければ outbox を
//// 書いて `False` を返し、step は `Accepted` で終わる。HTTP はそれを 202 と `{<root>: id}` で返す
//// (framework `server/http.mjs` の `outcomeResponse`。欄の名は ★ `respond` が替えてよい)。
//// だから「source に `step.commit(` が在り、boundary でない Service」が 202 を返す。

import gleam/list
import gleam/string
import yumemi_gen/model.{type App, type Service}
import yumemi_gen/source.{type Unit}

@external(javascript, "../../yumemi_gen_ffi.mjs", "queue_calls")
fn queue_calls(source: String) -> List(String)

/// commit の後に続きを持ち、HTTP で 202 Accepted を返す Service。
pub fn accepts(app: App, units: List(Unit), service: Service) -> Bool {
  let source = source_of(units, service.module)
  string.contains(source, "step.commit(")
  && !{
    queued(app, units, service.module) && boundary(app, units, service.module)
  }
}

/// queue の kind(`step.call_write(queue.<kind>(` で呼ばれる Service)のうち、send の connector を
/// import するもの。commit は解釈の境だけで、受け手へ送り終えてから outbox を閉じる(runtime の `boundaries`)。
pub fn boundary(app: App, units: List(Unit), kind: String) -> Bool {
  let source = source_of(units, kind)
  app.server.connectors
  |> list.filter(fn(connector) {
    list.any(connector.ports, fn(port) {
      case port {
        model.SendPort(..) -> True
        _ -> False
      }
    })
  })
  |> list.map(fn(connector) { "gen/connector/" <> connector.name })
  |> list.any(fn(path) {
    string.contains(source, "import " <> path)
    || string.contains(source, "import " <> string.drop_start(path, 4))
  })
}

fn queued(app: App, units: List(Unit), kind: String) -> Bool {
  list.any(app.services, fn(service) {
    list.contains(queue_calls(source_of(units, service.module)), kind)
  })
}

fn source_of(units: List(Unit), module: String) -> String {
  case list.find(units, fn(unit) { unit.path == "service/" <> module }) {
    Ok(unit) -> unit.text
    Error(_) -> ""
  }
}
