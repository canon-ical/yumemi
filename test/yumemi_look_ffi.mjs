// yumemi-look(0.11.7)── 島の shadow の <style> に新しい Style が出るかを、island_style.mjs の
// styled(app) の経路(gen/test/yumemi_fix_0114_test_ffi.mjs の H8 と同じ形)で確かめる。
import { styled } from "./framework/front/island_style.mjs";
import { element as sketchElement } from "../sketch_lustre/sketch/lustre/element.mjs";
import { text, to_string } from "../lustre/lustre/element.mjs";
import { toList } from "../prelude.mjs";

// class は Gleam 側で framework/front/sketch_css.class([Style, ..]) から作って渡す。
export function island_shadow_style(classValue) {
  const view = () =>
    sketchElement("div", classValue, toList([]), toList([text("look")]));
  const app = { init: () => null, update: (m) => m, view, config: {} };
  return to_string(styled(app).view(null));
}
