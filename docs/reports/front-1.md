# front-1 実装報告

## 51 v4 の型対応

| # | 51 §型の一覧 | framework | article fixture | gen-5 の置き場 |
|---:|---|---|---|---|
| 1 | `Layout` | `src/framework/front.gleam` | `src/front/layout.gleam` の `front` | 開発者入力を読む。Layout の生成物は loader / style 側 |
| 2 | `Page` | `src/framework/front.gleam` | `src/front/pages/article/arg_id/page.gleam` の `page` | Page の folder tree から route / loader を生成 |
| 3 | `Frame` | `src/framework/front.gleam` | layout / page の `sp` | `src/gen/front/route.gleam` と loader が断点表を読む |
| 4 | `Area` | `src/framework/front.gleam` | layout / page の `areas` | style 生成で flow / pin / area を読む |
| 5 | `Placement` / `Render` | `src/framework/front.gleam` | page の `Fixed` 配置 | `WidgetKey` / loader / block list の入力 |
| 6 | `Element` | `src/framework/front/el.gleam` | blocks / component が `el.Element` を返す | 生成 view / client の型境界 |
| 7 | `Block` enum | fixture では framework に置かない | `src/front/types.gleam` の `Block` | `src/gen/front/blocks.gleam` |
| 8 | Block の `view(In) -> Element(Nil)` | framework の型は要求しない | `src/front/blocks/article.gleam`、`summary.gleam` | 開発者入力。Block list / SSR loader が呼ぶ |
| 9 | `In` | framework の型は要求しない | 各 Block module の `In` | `src/gen/out/<service>.gleam` |
| 10 | Component(静的) | framework の型は要求しない | Block view 内の要素関数 | 生成物なし。Block view に残る |
| 11 | Component(interactive) の view | `el.Element` + `live` を利用 | `src/front/components/like_button.gleam` | `src/gen/front/live/<service>.gleam` と client bundle |
| 12 | `State` / `Event` / `update` | `src/framework/front/live.gleam` | `live.State` / `live.Event` を concrete 化 | `src/gen/front/live/<service>.gleam` の具体化・update |
| 13 | `Style` / `Flow` / `Pin` / `Animation` / `Img` | 宣言は `front/css.gleam`、写しは `front/sketch_css.gleam` | Block module 内の Style const、`css.Stack` / `css.NoPin` | `src/gen/front/style.css` と SSR `<style>` |
| 14 | `WidgetKey` | framework に置かない | 今回は Widget 配置なし | `src/gen/front/widgets.gleam` |

`framework/page.gleam` の Cursor 用 `Page` は改名していない。`front/css.gleam` は import 0本で、lustre / sketch に依存しない。島の任意タグは fixture で `el.island` だけを使用し、`attribute.class` / `element.element_` の PoC 禁則を持ち込んでいない。

## 入口との接続

`framework/entry.gleam` に閉じた `Pages { AllPages NoPages }` を追加し、`Http` / `HttpApi` の両方へ `pages: Pages` と `frame_src: List(String)` を追加した。`pages()` / `frame_src()` は `credential()` と同じ constructor 分岐で読む。article fixture の2入口は `NoPages` / `[]`。reader、route 表生成、`gen/src/**` は変更していない。

## 51 v4 への記述案

1. 生成物一覧に11番目として `src/gen/service.gleam`（Page の `of:` と Component の calls が指す閉じた Service enum）を追加する。
2. §270 の道の頭を `gen/front/...` から `src/gen/front/...` へ統一する。現物の Gleam module tree は `src/` 起点。

## 実測値

- root `manifest.toml`: 1 → 10 packages。依存は Hex の lustre 5.7.1 / sketch 4.2.1 / sketch_lustre 3.1.2 とその Hex transitive のみ。
- `cd gen && gleam test`: 68 passed, no failures。front の Gleam source 6本を parse 対象に含めるため、既存の article source 件数 assertion を 11 → 17 に更新した。test 本数は 68 のまま。
- `cd gen && gleam run -m yumemi_gen -- fixtures/article _out/front-1-generate`: exit 0、55 files。front は reader が label を参照しないため生成物の数は基線から変わっていない。
- `node gen/scripts/verify-front-ssr.mjs`: workerd SSR、JS 無し本文、style tag 1本、Chromium の島クリックを全て pass。
- `node gen/scripts/verify-front-isolate.mjs`: `/article/first` / `/article/second` を交互に40回。style 長はそれぞれ 322 / 191 で各面一定、色 marker の混入なし。

## 再現環境

- Gleam `1.18.1`。root build は `gleam build`。
- scratch は `gen/scripts/front-scratch/` を雛形に `gen/_out/` へ展開し、fixture front とその依存だけを写す。
- client bundle は `npx esbuild`、Worker は `npx wrangler dev`（workerd）で起動する。
- Playwright import は `/home/yumemism/yumemi-front-poc/node_modules/playwright/index.mjs` の絶対パス。Chromium は Playwright の cache を使用する。
- 実行ログは `build/verify-front-ssr.txt`、`build/verify-front-isolate.txt`、scratch 内の `gleam-build.txt` / `esbuild.txt` / `wrangler.txt`。
