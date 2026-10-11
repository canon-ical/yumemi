# 真壁[IM]へ ── yumemi 0.12 段 A(便 yumemi-012-y1、名前空間を `yumemi/*` に、生成器を本体の module `yumemi/gen` に移す、直書き、鷹野[PDM] 2026-10-12)

便: yumemi-012-y1(yumemi リポ、Opus 真壁の直書き、終端で柏木のゲートを便に 1 回 ── `KASHIWAGI_ROUTE=opus`)

**1 session で直に書く。細かい設計は真壁さんが決める(役員 人見 2026-10-12)。**作業木 `~/yumemism_repo/yumemi-012-y1`(branch `impl/012-y1`、基点は本 BRIEF の commit = forgejo main `076d6db`(0.11.15)の上)。記録は `briefs/results-yumemi-012-y1.md`、証跡は `build/012-y1-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版の行は `0.12.0-dev` にし、tag しない。止め線は経過 1 時間 30 分。**

**親:** tech `_drafts/gleam-framework/51-front-types.v6.md` の「名前空間」「生成器」の 2 節、`76-distribution.v0.md` の形 1、`70-brief-front-rethink.md` 末尾の段 6 の裁き。

**親ゴール:** yumemi の生成器が Hex の `yumemi` 1 つで届き、app が lock した版と同じ生成器が走る。0.12.0 の他の便(段 B の Y2・Y4・Y5、段 C の Y3)は全部この名前と置き場の上に書く。
- 障害:生成器が Hex に無く、yumemi のリポを clone して tag を取り出さないと回せない(musearch `docs/runbook.md:306-309`、cloud の起動処理)。`gen/gleam.toml` は本体を path で引く
- 障害:生成器が `npx --yes esbuild` で版を固定しない esbuild をその場で取り、同じ本体の版から別の client が出うる
- 障害:名前の移動と中身の変更を段 B の 3 便が同じ file で同時にやり、merge で崩れる。名前と置き場はこの便で確定させ、後の便は動かさない

## 現在地
- 本体は `src/framework/` の 45 file、module の頭は `framework/*`。package 名は `yumemi`。README:13 は「generator .. ship from 0.3.0」と書くが、Hex の tarball は `src/framework/` だけを持つ
- 生成器は `gen/` の別 package `yumemi_gen` 0.1.0(Hex に無い)。入口は `gleam run -m yumemi_gen -- <app dir> <out dir>`。test は `gen/test` の 17 本、fixture は `gen/fixtures`、補助は `gen/scripts`
- 生成器が出力に焼く import や path にも `framework/` がある(`emit/*` の文字列、`.mjs` の相対 path)
- DB の schema 名 `framework`(`framework/schema` の const)と、app が書く `db/queries/framework/*.sql`・SQL の鍵 `framework/outbox_claim` 等は、module 名ではなく app の DDL と SQL の名

## どこまで
1. 本体の module の頭を `framework/` から `yumemi/` に替える。生成器が出力に焼く import・path も同じに替える。生成物の振る舞いは変えない(変わるのは名前だけ)
2. 生成器を本体の module `yumemi/gen` に移し、app の package から `gleam run -m yumemi/gen -- <app dir> <out dir>` で起こせるようにする。生成器の依存は本体の `[dependencies]` へ。`gen/gleam.toml` の path 依存は無くす
3. `gen/test` を本体の test に寄せ、root の `gleam test` 1 つで全部回る。fixture・scripts の置き場は真壁さんの選択で、Hex の tarball に入れない
4. 面の bundle は app の lockfile の esbuild(面の `node_modules`)を使う。無ければ名指して止める(51 v6 第 38 条)。npx に黙って落ちない
5. README:13 と、README の module 名・生成器の起こし方を現物に直す

**しないこと:**lustre を外す・要素の木(Y2)、navigate.mjs(Y4)、門と CMS(Y5)、島(Y3)、`yumemi/new`、lock の照合(51 v6 第 37 条)、DB の schema 名・`db/queries/framework/`・SQL の鍵名を替えること、CHANGELOG の分割、musearch の source(写しだけ)、tag・publish・push。

## 失敗例(差し戻し)
- 置き換えが DB の schema 名や SQL の鍵・`db/queries/framework/` まで替え、app の DDL と食い違う
- `gleam run -m yumemi/gen` が yumemi のリポの中からしか走らず、app の package から起こせない
- fixture・scripts・test が Hex の tarball に入る。または生成器の依存が tarball の依存から漏れる
- gen の test を移す途中で本数が減る(落ちた test を消して通す)
- musearch の写しで、名前の置き換え以外の手直しが ★ に要る

## 検収
- root `gleam test` が通り、本数は移す前の root と gen の和から減っていない(before / after を results に)。`gleam format --check` 0
- `gleam export hex-tarball` の中身の一覧と寸法を results に。`src/` の下は `yumemi/` だけで、fixture・scripts・test が無い
- **musearch の写しで名前の置き換えだけ**:origin/main(`~/yumemism_repo/musearch`)を `.scratch/musearch` に置き、api と 4 面の ★ の `framework/` の import(Gleam の import と `.mjs` の `yumemi/framework/` の path)だけを置き換え、yumemi を本作業木への path にする。api の package から `gleam run -m yumemi/gen` で全面を生成して停止コード 0・2 回目の差 0。基点の生成物に同じ置き換えを掛けたものとの差 0(client の bundle の差は esbuild の版で説明して results に)。api の `npm test`(新しい port の PG)と 4 面の `npm run build`・`npm test` が通る。auth(0.7 系)は触らない。写しは捨てる
- 面の `node_modules` から esbuild を外した写しで、生成器が名指して止まる 1 回(停止コードを results に)

## 鷹野の裁き(2026-10-12)
1. 版は `0.12.0-dev` のまま tag しない。段 B・C の便は版の行に触らず、段 C の後に鷹野が `0.12.0` に替えて tag・publish する
2. lock の照合(51 v6 第 37 条)は本便に入れず、段 C の Y3 に載せる。生成器が触らない package(musearch の auth)は段 D で 0.12 に揃うまで照合の外
3. DB の schema 名 `framework` と `db/queries/framework/` は 0.12 で替えない。1.0 の前に揃えるかは段 E で起案する
4. `docs/runbook.md` の追随は段 D、harness-core の `docs/cloud-session.md` は段 C の publish の後に鷹野が Claude 側で直す
