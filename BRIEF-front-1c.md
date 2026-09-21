# BRIEF front-1c ── yumemi:front 層の型を 51 v5 / 56 の形で 0.6.0 に再掲載(2026-09-21、鷹野[PDM] → 贄川[ORC])

便: yumemi-front-1c

**前提:** 基点は yumemi main `c39a0c4`(0.5.0、Y1b 後)。作業木は `~/yumemism_repo/yumemi-front-1c`(branch `front-1c`、贄川が作る)。musearch は**読むだけ**。**DDL は書かない。**経路は Y1b の型:贄川 = Claude opus(`claude-niekawa`)、柏木 = Codex sol(ゲート 1 / 2 は便に各 1 回)、真壁 = luna(ゲート 2 の P0 を直す巡だけ sol)。1 巡 = 1 session。真壁名義で commit、**push しない**。**merge と Hex publish は鷹野**(便の中で publish も版の再変更もしない)。

**親ゴール:** tech `_drafts/gleam-framework/00-goal.md` の G2 の front 側 ── 面が back の客になる形([51 v5](../../canonical/tech/_drafts/gleam-framework/51-front-types.v5.md)、[56](../../canonical/tech/_drafts/gleam-framework/56-repo-shape.v0.md))を framework の型と fixture 1 本で成立させ、**P1(musearch-front-1)が Hex から引ける 0.6.0** を作る。

**障害:**

- 51 v5 の front 型は **Hex 0.4.0 という死に版にしか無く、main にも 0.5.0 にも 0 本**。このままでは P1 が手書き便の中で framework を書く(2 リポ同時編集)か、0.4.0 と 0.5.0 を混ぜる
- backup 枝は verb-1 / verb-1b の**前**の木なので、front 以外が 1 file でも混ざると Y1 / Y1b が退行する(`ordered_by.within` が String に戻る、`emit/verb.gleam` が 1667 行巻き戻る)
- v4(= backup 枝の実物)は面が back に同居する前提だったので、置き場のまま再掲載すると P1 と gen-6 が別の木を見る
- Hex 以外の依存を混ぜると publish できない(便の出口は鷹野の 0.6.0 publish)

## 現在地

- yumemi main `c39a0c4` = **0.5.0**(Hex 公開済み)。`src/framework/` に front の module は **0 本**。`cd gen && gleam test` **86**、`gleam run -m yumemi_gen -- fixtures/article <out>` は **exit 0 / 57 file**、`source.load` の units は **11**(`gen/test/yumemi_gen_test.gleam:106` の assertion、鷹野実測 2026-09-21)
- 素材は backup 枝 `main-with-front-1-20260921`(便 yumemi-front-1 の成果、Hex **0.4.0 = 死に版、再利用不可**)── front 5 file **297 行**(`front.gleam` 39 / `front/css.gleam` 76 / `front/el.gleam` 33 / `front/live.gleam` 11 / `front/sketch_css.gleam` 138)、`entry.gleam` **23 行**(`Pages` 型 + `pages` / `frame_src` 欄 + 読み手 2 関数)、道具 **394 行**(`gen/scripts/verify-front-ssr.mjs` 67 / `verify-front-isolate.mjs` 53 / `front-harness.mjs` 128 / `front-scratch/` 146)、fixture `gen/fixtures/article/src/front/` **7 file**、`docs/reports/front-1.md`
- **型の宣言は v4 と v5 で 1 行も動いていない**(51 v5 冒頭「front の型そのものは動いていない」── 6 型 14 個、`Fixed` / `Widget`、`One` / `ByKind`、`Area.pin`、`Page.theme`、`of: Option`、Css 6 群は v4 のまま)。動くのは置き場と道具だけ:

| 節 | v4(backup 枝の実物) | v5 / 56(本便の形) |
|---|---|---|
| 型の宣言 | `framework/front{,/css,/el,/live,/sketch_css}` 297 行 | **同じ。byte 同一で写す**(0 行の差) |
| fixture の置き場 | `fixtures/article/src/front/**`(back と同居、★ の `front/types.gleam` に enum 2 つ) | **兄弟の面 package `fixtures/article/www/`**、`src/{layout,style,pages,blocks,components}`(`front/` の段が消える)、enum は `www/src/gen/` の手書き ▲ |
| 道具 | scratch へ `fixtures/article/src/front` を `src/front/` として写す、import は `front/blocks/article` | 面の `www/src` を scratch の `src/` へ写す、import は `blocks/article`(段が 1 つ減る) |
| 変わらないもの | — | 型引数 2 つ、`framework/page.gleam` の `Page` は改名しない、package は割らない、Css の 2 module 分割、SSR は `render(stylesheet, in:, after:)`、`<style>` は body 先頭、禁則は `el.island` と Style で消す |

- **gen-5 の route 導出(main に在る)と front の接点は `entry.gleam` の 2 欄だけ。**reader は `g.labelled` で欄を名指しで読むので**未知の label は素通りする**(front-1 の実測:2 欄を足しても生成物の数は不変)。Page 行の route 生成は **gen-6 = Y2** で、本便は生成器を 1 行も触らない
- 依存の実測(front-1):lustre 5.7.1 / sketch 4.2.1 / sketch_lustre 3.1.2 は全部 **Hex 公開物**、root の `manifest.toml` は 1 → 10 package
- musearch main `e4420fb`(読むだけ)。生成器の基線は **exit 4 = 5 本 / 警告 21 / 635 file**。**`api/gleam.toml` は yumemi `>= 0.3.0 and < 0.4.0`**(P1 BRIEF の「0.5.0」は現物と違う ── 鷹野宛、裁定 4)
- rates:claude 45(残り気味)/ codex 27 / kimi 47。通常経路

## どこまで

1. **framework の 5 module を再掲載。**backup 枝の 297 行を**そのまま**(欄名・構成子名・型引数が 51 v5 §32「型の一覧」/ §53「型引数」と 1 対 1。食い違いは「鷹野宛」に出し、実装の都合で変えない)。`framework/page.gleam` の `Page` は改名しない、package は割らない、`front/css.gleam` は **import 0 本**のまま。`gleam.toml` に lustre / sketch / sketch_lustre を足し、版を **0.6.0** に(**publish は鷹野**)
2. **`entry.gleam` の 2 欄**(`Pages { AllPages NoPages }`、`Http` / `HttpApi` に `pages` / `frame_src`、読み手 `pages()` / `frame_src()` は `credential()` と同じ構成子分岐)。これは **Entry の破壊的変更**で、0.6.0 に上げた ★ の `entry.gleam` は全部 2 欄が要る ── 報告に 1 行で明記。**`pwa` 欄は足さない**(裁定 1)、reader / emit / `gen/src/**` は触らない
3. **fixture を v5 の形へ。**back は `gen/fixtures/article/`(`src/**`)のまま、面は**兄弟の package `gen/fixtures/article/www/`**(`gleam.toml` の依存は path の `yumemi` だけ)── `src/layout.gleam` の `pub const www`、`src/style.gleam`、`src/pages/article/arg_id/page.gleam` の `pub const page`、`src/blocks/{article,summary}.gleam`、`src/components/like_button.gleam`(+ ffi)。**`src/front/` の段は消える**(裁定 2)
4. **写し 3 束と面の enum を手書き ▲ で置く** ── `www/src/gen/service.gleam` / `gen/blocks.gleam` / `gen/widgets.gleam` / `gen/out/article_read.gleam`。**51 v5 §340 の縛り 8 つを全部満たす**(頭 1 行 `//// GENERATED from … — 手で編集しない`、**sha256 は付けない**、module 名 = その package の `src/` からの道、variant は PascalCase、★ 側の関数名 `view(it: In)` と const 名 `page` / `www` の固定)。backup の ★ `src/front/types.gleam` は**消える**、Block の `In` は写しを指す
5. **const で書けることを型で取る。**Page / Layout に `Widget`(`One` 1 本と `ByKind` 1 本)、`pin: Top` の area、`pc: Some(Frame(…))` を足す ── **front-1 で未検証だった型 14 の `WidgetKey` / `Render` / `pin` / 断点 2 枚を閉じる**(front-1 報告「今回は Widget 配置なし」)
6. **道具 4 本を面の木へ向け直し、報告を書く。**`front-harness.mjs` は `fixtures/article/www/src` を scratch の `src/` へ写す形に(import の段が 1 つ減る)。verify 2 本は **ALL PASS**。報告は `docs/reports/front-1c.md`(型 14 の対応表 = v5 の置き場、**v4 → v5 で動いた点**、数字、P1 と Y2 への申し送り)

## しないこと

生成器に front の出力(route / load / blocks / widgets / live / shell / style / `build/blocks.html`)を足す(gen-6 = Y2)、reader / emit / `gen/src/**` の変更、backup 枝から front 以外を写すこと(`emit/verb.gleam` / `reader.gleam` / `verbs.gleam` / `fixtures/*` の verb 系 / `verify-*-sql.mjs` / `results.md` / 旧 BRIEF)、fixture の back を `api/` に組み直すこと(56 の木の左半分は `yumemi new` の便)、`pwa` 欄と PWA の生成物、live spec の器、musearch への書き込み、Hex publish と版の再変更、DDL、`main` への commit、push、`.claude/_core` `~/.codex` `~/.claude`。

## 失敗例

- 型の欄名・構成子名・型引数を 51 v5 と変える(`Fixed` / `Widget` / `One` / `ByKind` / `pin` / `theme` / `of: Option` を「実装の都合」で動かす)
- `framework/front/css.gleam` を sketch に依存させる(宣言と写しを 1 module に畳む)、package を `yumemi_front` に割る、`framework/page.gleam` の `Page` を改名する
- 面の fixture を back の `src/**` の下に置く(v4 に戻る)── `source.load` が拾って units 11 と生成 57 が動く
- `www/src/gen/**` に **sha256 付きのヘッダ**を書く(手書き ▲ との唯一の見分けが消える)、13 種以外を置く、`route.gleam` に手で Page 行を足す
- `attribute.class` / `attribute.style` / `element.element` の直呼び、島のタグを `el.island` 以外で出す、生 HTML / CSS / JS
- backup 枝の `ordered_by.within`(String)や verb 系 fixture を一緒に写して Y1 / Y1b を退行させる、`gleam test` 86 を割る、musearch の基線(exit 4 = 5 本 / 警告 21 / 635)を動かす
- Hex 以外の依存を足す、版を 0.4.0 や 0.7.0 にする、便の中で publish する
- 同 persona の同秒起動、`^session_id:` での終了判定、push

## 検収

- root `gleam build` **0**、`cd gen && gleam test` **86 以上**、`cd gen/fixtures/article/www && gleam build` **0**
- `cd gen && gleam run -m yumemi_gen -- fixtures/article <out>` が **exit 0 / 57 file**、`source.load` の units **11** ── **面を足しても back の生成は 1 file も動かない**
- musearch main `api/`(`~/yumemism_repo/musearch/api`、`e4420fb`、読むだけ)への clean run が **exit 4 = 5 本 / 警告 21 / 635 file** で基線一致
- `node gen/scripts/verify-front-ssr.mjs` と `verify-front-isolate.mjs` が **ALL PASS** ── SSR 本文に **JS 無しで**文字が出る / `<style>` が **1 本** / 島が Chromium で押せて表示が変わる(ページ error 0)/ isolate 跨ぎ 40 回で `<style>` 長が面ごとに一定・混入 0
- **`src/framework/` の差分の行数**(期待:新規 5 file **297 行** + `entry.gleam` **+23 行**、既存 module の変更 **0**)と `gleam.toml` の +3 行 / 版 0.6.0
- 依存は **Hex 公開物だけ**(root `manifest.toml` の package 数と 3 本の版を数字で)、`www/gleam.toml` の依存は `yumemi` のみ
- `results.md` の `## DDL`(**無し**)、`docs/reports/front-1c.md` の path。終端は承認かエスカレーション

## 申し送り(報告に必ず書く)

- **P1(musearch-front-1、BRIEF は musearch main `BRIEF-front-1.md`)へ:**面 package の実物 1 本(`gleam.toml` の形 / 木 / ▲ のヘッダ / const 名 / Block の `In` の指し方)、**`api/` を 0.6.0 に上げるなら `entry.gleam` の全入口に 2 欄が要る**(現物は 0.3.0)、verify の Playwright が `~/yumemi-front-poc/node_modules` の絶対 path に依存していること
- **Y2(gen-6)へ:**手書き ▲ の道と名前の一覧(生成器が再現すべき出力)、front-1 が残した 5 件(Page / Layout の配置表からの描画は未検証、島の再訪問時の Model、1 Block に島が複数、断点ごとの非表示、WebSocket の push は `reloads` に無い)

## 鷹野の裁定(2026-09-21 16:20、役員 人見の追認「残りは How、追認でよい」)

1. **`pwa` 欄は足さない、2 欄だけ。**`Pwa` の消費者が無い型は閉じない(front-1 の障害 2 と同じ)。3 欄目は PWA の生成物を出す便で
2. **fixture の木は back を `gen/fixtures/article/` のまま、面を兄弟 package `gen/fixtures/article/www/` に。**生成器の CLI 契約と 86 test を動かさない。56 の木(`article/api/` + `article/www/`)への組み直しは `yumemi new` の便、報告に「56 との差」として名指し
3. **`Pages` の構成子名は `AllPages` / `NoPages`。**51 v5 の例文 `pages: All` は鷹野が直す(便の外)
4. **0.6.0 の受け先:musearch `api/` は F3 の merge 後の `>= 0.5.0 and < 0.6.0` のまま据え置き**(現物 e4420fb は 0.3.0、F3 が 0.5.x に上げる)。**0.6.0 への bump と `entry.gleam` の 2 欄は F4 / D1 の便で。**P1 は `www/` だけ `>= 0.6.0 and < 0.7.0`
5. **エスカレーションは裁けるものを裁いて BRIEF に commit → `-f BRIEF --resume-run <run_dir>`**(run_dir の findings への追記は読まれない)
