//// 入力ハッシュの計算。sha256 の先頭 12 桁だけを使う(header の1行に収めるため)。

@external(javascript, "./digest_ffi.mjs", "sha256_short")
pub fn short(text: String) -> String
