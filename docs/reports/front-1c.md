# front-1c ── 面の `www/` 木へ道具を向け直した結果

## 結果

`front-harness.mjs` の写し元を `gen/fixtures/article/www/src`、写し先を
scratch の `src/` に変更した。面の `www/src/gen/**` も同じ一括コピーで
scratch に入る。scratch の import は `front/blocks` / `front/components` から
`blocks` / `components` へ 1 段浅くした。

面の実物を使った SSR / isolate verify は両方 PASS した。back の
`gen/fixtures/article/src/**` と生成器の source / test はこの便では変更していない。

## 51 v5 §32 の 14 型対応表

下表の `www/src` は実物、`gen-6` は v5 が定める将来の生成器の置き場である。
現在の便で手書き ▲ として存在するのは `src/gen/service.gleam`、
`src/gen/blocks.gleam`、`src/gen/widgets.gleam`、`src/gen/out/article_read.gleam`。

| # | 型 | framework の置き場 | 面 (`www/`) の置き場 | 生成器 (`gen-6`) の置き場 |
|---:|---|---|---|---|
| 1 | `Layout` | `src/framework/front.gleam` | `www/src/layout.gleam` の `pub const www` | `src/gen/load/layout.gleam` と面の shell / style の入力 |
| 2 | `Page` | `src/framework/front.gleam` | `www/src/pages/article/arg_id/page.gleam` の `pub const page` | `src/gen/route.gleam`、`src/gen/load/<page の道>/page.gleam` |
| 3 | `Frame` | `src/framework/front.gleam` | `layout.gleam` / `pages/**/page.gleam` の `sp` / `pc` / `tablet` | Page / Layout loader と route / style の入力 |
| 4 | `Area` | `src/framework/front.gleam` と `src/framework/front/css.gleam` | 各 `Frame.areas` の `name` / `flow` / `pin` / `style` | `src/gen/load/**` と `priv/static/_yumemi/style.css` / SSR `<style>` |
| 5 | `Placement` / `Render` | `src/framework/front.gleam` | 各 `Frame.placements` の `Fixed` / `Widget`、`One` / `ByKind` | loader、`src/gen/widgets.gleam`、shell の描画手順 |
| 6 | `Element` | `src/framework/front/el.gleam` | `www/src/blocks/*.gleam` の `el.Element` | 個別 enum は作らず、`src/gen/shell.mjs` / client が framework の型を使う |
| 7 | `Block` enum | framework には置かない | `www/src/gen/blocks.gleam` の `Block` | `src/gen/blocks.gleam` |
| 8 | `Block` の `view(In) -> Element(Nil)` | framework には要求しない | `www/src/blocks/article.gleam`、`summary.gleam` | `src/gen/skeleton/<block>.gleam` は初回だけ。以後 loader / shell が呼ぶ |
| 9 | `In` (`Service` の `Out` の写し) | framework には要求しない | Block の `pub type In`。現在は `article_read.Out` | `src/gen/out/<service>.gleam` |
| 10 | Component (静的) | framework には要求しない | Block 内の関数、または `www/src/components/<name>.gleam` | 生成物なし。Block / Component の手書きに残す |
| 11 | Component (interactive) の `view(State) -> Element(Event)` | `src/framework/front/el.gleam`、`src/framework/front/live.gleam` を利用 | `www/src/components/like_button.gleam` | `src/gen/live/<service>.gleam` と `priv/static/_yumemi/client.mjs` |
| 12 | `State` / `Event` / `update` | `src/framework/front/live.gleam` | 現在は `like_button.gleam` が concrete type と `update` を持つ | `src/gen/live/<service>.gleam` に具体化・`update`・送信前検査を置く |
| 13 | `Style` / `Flow` / `Pin` / `Animation` / `Img` | `src/framework/front/css.gleam`、写しは `src/framework/front/sketch_css.gleam` | `www/src/style.gleam` と各 Block の Style const | `priv/static/_yumemi/style.css` と SSR の `<style>` |
| 14 | `WidgetKey` | framework には置かない | `www/src/gen/widgets.gleam` | `src/gen/widgets.gleam`。Page / Layout の `Widget.name` から閉じた集合を作る |

## v4 → v5 で動いた点

14 型の宣言は **1 行も動いていない**。動いたのは次の 3 点だけである。

1. fixture の置き場を同居した `src/front/**` から兄弟 package `www/` へ移し、
   `front/` の段を消した。
2. ★ `src/front/types.gleam` に置いていた enum を、▲
   `src/gen/{blocks,widgets}.gleam` へ移した。
3. 道具の写し元・写し先を `fixtures/article/src/front` → `work/src/front` から、
   `fixtures/article/www/src` → `work/src` へ向け直した。これに合わせて scratch の
   import の段を 1 つ減らした。

これは front の型の変更ではない。なお yumemi 0.6.0 の `entry.gleam` には、別途
破壊的な入口 API の変更がある。

> yumemi 0.6.0 に上げる app の `entry.gleam` は、`Http` / `HttpApi` の全入口に
> `pages` と `frame_src` の 2 欄が要る。

## 56 との差

56 の正規の木は `article/api/` と `article/www/` だが、本便は back を
`gen/fixtures/article/` の `src/**` のまま置いた。これは生成器の CLI 契約と
86 test を動かさないための **鷹野の裁定 2** による。`api/` への組み直しは
`yumemi new` の便で行う。本便の `www/gleam.toml` はその面 package として置き、
依存は `yumemi` だけにしている。

## 数字と実測

- `src/framework/` の差分は新規 5 file・297 行（`front.gleam`、`front/css.gleam`、
  `front/el.gleam`、`front/live.gleam`、`front/sketch_css.gleam`）に、既存の
  `entry.gleam` **+23 行**。既存 module の変更は 0。
- root `gleam.toml` は依存の net **+3 行**、版は **0.6.0**。追加した direct
  dependency は lustre / sketch / sketch_lustre。
- root `manifest.toml` は **10 packages**。`lustre 5.7.1`、`sketch 4.2.1`、
  `sketch_lustre 3.1.2`。`gen/manifest.toml` は 18 packages で、local `yumemi`
  は 0.6.0。
- `gleam build` は compile 完了（`build/root-gleam-build-front-1c.txt`）。既存の
  `src/framework/secret.gleam` の unused private constructor warning 1 件は残る。
- `cd gen && gleam test` は **86 passed, no failures**。
- `gleam run -m yumemi_gen -- fixtures/article _out/front-1c-report` は
  **57 files**。入力 units は back の `gen/fixtures/article/src/**/*.gleam` **11**。
- `node gen/scripts/verify-front-ssr.mjs` は **ALL PASS**。JS 無しで title/body、
  `<style>` **1 本**、body 先頭を確認し、島は `❤ 1 -> ❤ 13`、browser error **0**。
- `node gen/scripts/verify-front-isolate.mjs` は **ALL PASS**。`/article/first` と
  `/article/second` を交互に **40 回**、style 長は first **322** / second **191**、
  面を跨ぐ色 marker の混入 **0**。
- verify の全ログは `build/verify-front-ssr.txt`、
  `build/verify-front-isolate.txt` に残した。生成・test のログは
  `build/generate-front-1c.txt`、`build/gen-gleam-test-front-1c.txt` に残した。

## P1 (`musearch-front-1`) への申し送り

### 面 package の実物

実物 1 本は `gen/fixtures/article/www/` である。

```text
www/
├── gleam.toml                 # 依存は yumemi だけ
├── manifest.toml
└── src/
    ├── layout.gleam           # pub const www
    ├── style.gleam
    ├── pages/article/arg_id/page.gleam  # pub const page
    ├── blocks/article.gleam
    ├── blocks/summary.gleam
    ├── components/like_button.gleam
    ├── components/like_button_ffi.mjs
    └── gen/
        ├── service.gleam
        ├── blocks.gleam
        ├── widgets.gleam
        └── out/article_read.gleam
```

▲ 4 本の先頭はすべて `//// GENERATED from … — 手で編集しない` で、**sha256 は
付けない**。Block の `In` は `src/gen/out/<service>.gleam` を指す。名前は
`page` / `www` の const を固定する。

`api/` を 0.6.0 に上げるなら、`entry.gleam` の全入口に `pages` と `frame_src` の
2 欄が要る。現物の `musearch/api/gleam.toml` は `yumemi >= 0.3.0 and < 0.4.0`。
F3 が 0.5.x に上げ、**0.6.0 への bump と 2 欄は F4 / D1 の便**である。P1 は
`www/` だけ `yumemi >= 0.6.0 and < 0.7.0` にする。

verify の Playwright import は
`/home/yumemism/yumemi-front-poc/node_modules/playwright/index.mjs` の**絶対 path**に
依存し、Chromium は Playwright cache を使う。

## Y2 (`gen-6`) への申し送り

### 手書き ▲ の道と名前

生成器が再現すべき現在の 4 本は次のとおり。

- `src/gen/service.gleam`
- `src/gen/blocks.gleam`
- `src/gen/widgets.gleam`
- `src/gen/out/article_read.gleam`

§340 の縛り 8 つはそのまま満たすこと。

1. 生成物は面 package の `src/gen/**` と `priv/static/_yumemi/` に置き、back の
   `api/src/gen/**` に front の生成物を置かない。
2. 先頭は `//// GENERATED from <入力> — 手で編集しない` とし、sha256 を付けない。
3. module 名は package の `src/` からの path と一致させる。
4. enum variant は元名から PascalCase にする。
5. Block は `pub fn view(it: In) -> Element(Nil)`、interactive Component は
   `pub fn view(it: State) -> Element(Event)` と `pub const calls` / 任意の
   `reloads`、見本は任意の `pub const sample: In` に固定する。
6. Page は `pub const page`、Layout は `pub const <face>` を固定する。
7. route 表は手で編集せず生成する。
8. 生成器は exit 0 のままにする。front の parse 不能 1 file で束全体を通さない。

### front-1 からの残り 5 件

1. Page / Layout の配置表からの描画は未検証。
2. 島の再訪問時に古い Model が残る挙動は未検証。
3. 1 Block に島が複数ある形は未検証。
4. 断点ごとの非表示は未検証。
5. WebSocket の push は `reloads` に無い。

### 本便で残った 2 件（gen-6 で閉じる）

- interactive Component の `update` が ★ の手書きのまま。51 v5 §32 は `update` を
  「人は書かない」とし、`src/gen/live/<service>.gleam` に置く。本便では live の
  器を動かさないため残した。
- `like_button` の `pub const calls` が **空**で、島の通信は
  `like_button_ffi.mjs` の FFI 直呼びのまま。`calls` が Service を指し、
  `src/gen/api.gleam` が path を持つ形は gen-6 の仕事。

### 本便で閉じたもの

`WidgetKey`、`Render` の `One` / `ByKind`、`Area.pin`、SP / PC の 2 枚の
`Frame`（tablet は `None`）を const に載せる形は閉じた。`www/src/gen/widgets.gleam`
には `ArticleFeed` / `ArticleKinds` が載り、Page は `ByKind`、Layout は `One` を
実物で持つ。
