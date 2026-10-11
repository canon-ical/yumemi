// yumemi yumemi/front ── いま class を集めている sketch の stylesheet を 1 つ持つ(sketch_lustre の
// global の代わり)。`sketch_css.collect` が頁を描く間だけ差し替える。値は Gleam の Result のまま持つ。
import { Result$Error } from "../../gleam.mjs";

let sheet = Result$Error(undefined);

export function current() {
  return sheet;
}

export function set_current(value) {
  sheet = value;
}
