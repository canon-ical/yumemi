// ★ src/entity/chunk.gleam ── 複合 key の回帰 fixture。
pub type Chunk {
  Chunk(a: Int, b: Int, c: Int, text: String)
}

pub fn key(it: Chunk) -> #(Int, Int, Int) {
  #(it.a, it.b, it.c)
}

pub const collection: String = "chunks"
