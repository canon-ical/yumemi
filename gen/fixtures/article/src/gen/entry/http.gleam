//// GENERATED from entry.gleam / service declarations [sha256:f61fc5acf538] — 手で編集しない

import entry
import framework/entry.{type Entry} as entry_types
import framework/io.{type Promise}

pub type Credential {
  Session
  ApiKey
}

pub type Route {
  Route(
    face: String,
    method: String,
    path: String,
    service: String,
    path_keys: List(String),
    credential: Credential,
  )
}

pub const routes: List(Route) = [
  Route(
    face: "public",
    method: "POST",
    path: "/api/articles/{slug}/blob_save",
    service: "article_blob_save",
    path_keys: ["slug"],
    credential: Session,
  ),
  Route(
    face: "admin",
    method: "POST",
    path: "/api/admin/articles",
    service: "article_create",
    path_keys: [],
    credential: Session,
  ),
  Route(
    face: "public",
    method: "POST",
    path: "/api/articles",
    service: "article_create",
    path_keys: [],
    credential: Session,
  ),
  Route(
    face: "admin",
    method: "GET",
    path: "/api/admin/articles",
    service: "article_list",
    path_keys: [],
    credential: Session,
  ),
  Route(
    face: "public",
    method: "GET",
    path: "/api/articles",
    service: "article_list",
    path_keys: [],
    credential: Session,
  ),
  Route(
    face: "admin",
    method: "POST",
    path: "/api/admin/articles/{slug}/publish",
    service: "article_publish",
    path_keys: ["slug"],
    credential: Session,
  ),
  Route(
    face: "public",
    method: "POST",
    path: "/api/articles/{slug}/publish",
    service: "article_publish",
    path_keys: ["slug"],
    credential: Session,
  ),
  Route(
    face: "admin",
    method: "GET",
    path: "/api/admin/articles/{slug}",
    service: "article_read",
    path_keys: ["slug"],
    credential: Session,
  ),
  Route(
    face: "public",
    method: "GET",
    path: "/api/articles/{slug}",
    service: "article_read",
    path_keys: ["slug"],
    credential: Session,
  ),
  Route(
    face: "admin",
    method: "POST",
    path: "/api/admin/articles/{slug}/retract",
    service: "article_retract",
    path_keys: ["slug"],
    credential: Session,
  ),
  Route(
    face: "admin",
    method: "GET",
    path: "/api/admin/widgets",
    service: "widget_list",
    path_keys: [],
    credential: Session,
  ),
  Route(
    face: "public",
    method: "GET",
    path: "/api/widgets",
    service: "widget_list",
    path_keys: [],
    credential: Session,
  ),
]

pub type Request

pub type Response

pub type State

@external(javascript, "../http_runtime.mjs", "host")
fn host(
  request: Request,
  entries: List(Entry(subject, host)),
) -> Promise(Result(State, Response))

@external(javascript, "../http_runtime.mjs", "route")
fn route(state: State) -> Promise(Result(State, Response))

@external(javascript, "../http_runtime.mjs", "origin")
fn origin(state: State) -> Promise(Result(State, Response))

@external(javascript, "../http_runtime.mjs", "browser")
fn browser(state: State) -> Promise(Result(State, Response))

@external(javascript, "../http_runtime.mjs", "admit")
fn admit(state: State) -> Promise(Result(State, Response))

@external(javascript, "../http_runtime.mjs", "resolve")
fn resolve(state: State) -> Promise(Result(State, Response))

@external(javascript, "../http_runtime.mjs", "subject")
fn subject(state: State) -> Promise(Result(State, Response))

@external(javascript, "../http_runtime.mjs", "decode")
fn decode(state: State) -> Promise(Result(State, Response))

@external(javascript, "../http_runtime.mjs", "judge")
fn judge(state: State) -> Promise(Result(State, Response))

@external(javascript, "../http_runtime.mjs", "execute")
fn execute(state: State) -> Promise(Response)

fn next(
  result: Promise(Result(State, Response)),
  then: fn(State) -> Promise(Response),
) -> Promise(Response) {
  use value <- io.then(result)
  case value {
    Ok(state) -> then(state)
    Error(response) -> io.resolve(response)
  }
}

pub fn dispatch(request: Request) -> Promise(Response) {
  use state <- next(host(request, entry.entries))
  use state <- next(route(state))
  use state <- next(origin(state))
  use state <- next(browser(state))
  use state <- next(admit(state))
  use state <- next(resolve(state))
  use state <- next(subject(state))
  use state <- next(decode(state))
  use state <- next(judge(state))
  execute(state)
}
