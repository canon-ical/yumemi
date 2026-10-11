//// GENERATED from framework session contract [sha256:5a7812900d2a] — 手で編集しない

import yumemi/io.{type Promise}

pub type Database

pub type Resolved

@external(javascript, "../runtime.mjs", "resolveSession")
pub fn resolve(database: Database, id: String, at: String) -> Promise(Resolved)
