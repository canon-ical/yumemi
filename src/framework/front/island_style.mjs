// yumemi framework/front ── 島の sketch の stylesheet(0.11.4、H8)。生成の `priv/static/_yumemi/client.mjs` が
// 島を登録する前に `styled(app)` で包む。sketch の class 付きの要素(`html.div(class, ..)`)は描く時に global の
// stylesheet を要り、無いと `Stylesheet is not initialized` で panic する。島ごとに 1 つ stylesheet を持ち、
// view の間だけ current にして、その島が使った class の CSS を shadow の中の `<style>` に出す。
// class を 1 つも使わない島と、自分で `sketch_lustre.render` を呼ぶ島の DOM は変えない(`<style>` を足さない)。
import { Persistent, render as renderCss, stylesheet as newStylesheet } from "../../../sketch/sketch.mjs";
import {
  dismiss_current_stylesheet,
  get_stylesheet,
  set_current_stylesheet,
  set_stylesheet,
} from "../../../sketch_lustre/sketch/lustre/internals/global.mjs";
import { fragment } from "../../../lustre/lustre/element.mjs";
import { style } from "../../../lustre/lustre/element/html.mjs";
import { Result$isOk, Result$Ok$0, toList } from "../../gleam.mjs";

/// lustre の App の view を、島の stylesheet の下で描く形に包む。stylesheet が作れなければ app をそのまま返す。
export function styled(app) {
  const created = newStylesheet(new Persistent());
  if (!Result$isOk(created)) return app;
  const sheet = Result$Ok$0(created);
  set_stylesheet(sheet);
  const view = (model) => {
    set_current_stylesheet(sheet);
    try {
      const element = app.view(model);
      const current = get_stylesheet();
      // 島が自分で `sketch_lustre.render` を呼んだとき(current が島の stylesheet に替わる・外される)は触らない
      if (!Result$isOk(current) || Result$Ok$0(current).id !== sheet.id) return element;
      const css = renderCss(Result$Ok$0(current));
      return css === "" ? element : fragment(toList([style(toList([]), css), element]));
    } finally {
      dismiss_current_stylesheet();
    }
  };
  return { ...app, view };
}
