//// GENERATED from framework session contract [sha256:73a68a69ea55] — 手で編集しない

import yumemi/io.{type Promise}

pub type Database

pub type Resolved

@external(javascript, "../runtime.mjs", "resolveSession")
pub fn resolve(database: Database, id: String, at: String) -> Promise(Resolved)
