//// GENERATED from framework session contract [sha256:6a5b1b1c95d8] — 手で編集しない

import yumemi/io.{type Promise}

pub type Database

pub type Resolved

@external(javascript, "../runtime.mjs", "resolveSession")
pub fn resolve(database: Database, id: String, at: String) -> Promise(Resolved)
