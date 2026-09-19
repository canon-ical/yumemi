// ★ src/entity/path_only.gleam ── path_key を key として使う Entity。
pub type PathOnly {
  PathOnly(path: String, value: String)
}

pub fn path_key(it: PathOnly) -> String {
  it.path
}
