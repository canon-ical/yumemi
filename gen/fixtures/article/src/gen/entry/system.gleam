//// GENERATED from framework session / credential_floor contract [sha256:bbf198d7f83a] — 手で編集しない

import framework/io.{type Promise}
import gen/entry/auth.{type Database}

pub type Issued

@external(javascript, "../runtime.mjs", "issueSession")
pub fn session(
  database: Database,
  party: String,
  expires_at: String,
  credential_version: Int,
) -> Promise(Issued)

@external(javascript, "../runtime.mjs", "revokeParty")
pub fn revoke(database: Database, party: String, floor: Int) -> Promise(Int)
