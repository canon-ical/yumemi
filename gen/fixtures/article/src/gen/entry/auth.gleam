//// GENERATED from framework session contract [sha256:e7c15d777523] — 手で編集しない

import framework/io.{type Promise}

pub type Database

pub type Resolved

@external(javascript, "../runtime.mjs", "resolveSession")
pub fn resolve(database: Database, id: String, at: String) -> Promise(Resolved)
