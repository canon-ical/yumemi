# yumemi front-1 真壁 作業結果

## 状態

- branch: `front-1`、開始 HEAD: `b64df221d0da8dde0c2ddba4be435904fd77f33d`。
- framework の front 型、入口欄、article fixture、scratch 検証、報告を作業域へ追加した。
- commit: framework `88f6bd5`、fixture `92466f1`、verification `7209c95`。報告書とこの結果書きは次の commit に含める。
- generator 本体 `gen/src/**`、route 表の生成処理、musearch、canonical は変更していない。

## DDL

無し。migration / schema変更は無く、staging / productionへ適用していない。

## 検証証拠

- root build: `build/framework-build.txt` ── `gleam build` exit 0。既存 `framework/secret.gleam:5` の unused private constructor warning 1件のみ。
- gen regression: `gen/build/gen-test.txt` ── `cd gen && gleam test`、`68 passed, no failures`。
- generation: `gen/build/generate.txt` ── `cd gen && gleam run -m yumemi_gen -- fixtures/article _out/front-1-generate` exit 0、出力 `55` files。
- SSR / island: `build/verify-front-ssr.txt` ── workerd + Playwright、本文の名前・本文、`<style>` 1本、クリック `❤ 12 -> ❤ 13`、`ALL PASS`。
- isolate: `build/verify-front-isolate.txt` ── workerd、2面を交互に40回、first `322` bytes / second `191` bytes、`ALL PASS`。

## 依存

- root `manifest.toml`: 変更前 `1` package（gleam_stdlib）→変更後 `10` packages。追加した直接依存は lustre 5.7.1、sketch 4.2.1、sketch_lustre 3.1.2。root に path / git 依存は無い。
- gen `manifest.toml`: yumemi path package の版を `0.3.0` → `0.4.0`へ再解決し、root front の transitive package も含めた。

## gen-5 申し送り

- front の手書き enum は fixture `src/front/types.gleam`だけに置いた。gen-5 の出力先は `src/gen/front/blocks.gleam`、`src/gen/front/widgets.gleam`、`src/gen/out/<service>.gleam`、`src/gen/service.gleam`、`src/gen/front/live/<service>.gleam`。
- WebSocket push は `reloads` に無い。外から起きる合図の入口は未実装で、後段の設計が要る。
- 島の再訪問時に古い Model が残る挙動は未検証。`count` は初期属性としての実機確認まで。
- `blocks-<layout>.html` と client bundle / style の生成は gen-5 の仕事。今回の fixture はその入力互換を確認しただけ。

## 残差

- `gleam publish` は未実行。Hex publish は鷹野さんの作業域。
