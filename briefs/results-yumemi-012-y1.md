# results ── yumemi-012-y1(0.12 段 A、名前空間 `yumemi/*` と生成器 `yumemi/gen`、真壁 r1)

基点 `17f1374`(BRIEF の commit、forgejo main `076d6db` = 0.11.15 の上)。branch `impl/012-y1`。証跡は `build/012-y1-*`(git の外)。musearch の写しは `.scratch/musearch`(musearch origin/main `df5ec4bbb` の `git archive`、独立した git、5 package で `npm ci`)と、基点の生成器を回した `.scratch/musearch-base`。写しは検収の後に捨てた。

## やったこと

- **版の行** `0.12.0-dev`(`gleam.toml`)。tag しない
- **(1) module の頭** `src/framework/` → `src/yumemi/`(45 file を `git mv`)。置き換えは module 名の一覧(`blob|connector|effect|entry|er|front|gate|io|page|party|query|require|schema|sealed|secret|server|spec|step|time|vector|verb|verbs` と `*_ffi`)の前の `framework/` だけを `yumemi/` にする正規表現で、前に字・`-`・`.` がある所は触らない(`gleam-framework/56` 等)
  - 生成器が出力に焼く import(`emit/*` の文字列)、型の出所(`TyRef(Some("yumemi/time"), ..)`)、`.mjs` の相対 path(`../../yumemi/framework/server/` → `../../yumemi/yumemi/server/`、`emit/codec.gleam` の `"../../yumemi/framework/"` は正規表現に掛からないので手で)、★ の import の許可(`"framework/"` → `"yumemi/"`)を同じ置き換えで
  - **替えていないもの**:DB の schema 名 `framework`(`yumemi/schema` の `pub const framework = "framework"`)、SQL の鍵 `framework/outbox_claim`・`framework/session_*`・`framework/browser`・`framework/audit` ほか、`db/queries/framework/`、SQL 本文の `framework.require_rows` / `framework.outbox`、生成物の import の別名 `framework_page`(局所の名前で、出力の差を増やさないため)。置き換え後に残る `framework/<字>` は SQL の鍵だけ(`rg -P '(?<![\w.-])framework/[A-Za-z0-9_]+'` で数えた 18 種、すべて `outbox_*`・`session_*`・`browser`・`audit`・`api_key_resolve`・`credential_floor`)
  - fixture の偽の module `framework/idp`(`gen/fixtures/article/src/entity/staff.gleam`)も `yumemi/idp` に(★ の import の許可が `yumemi/` に替わるので、残すと読みの振る舞いが変わる)
- **(2) 生成器を本体の module `yumemi/gen` に**:`gen/src/yumemi_gen.gleam` → `src/yumemi/gen.gleam`、`gen/src/yumemi_gen/*` → `src/yumemi/gen/*`、`gen/src/yumemi_gen_ffi.mjs` → `src/yumemi/gen_ffi.mjs`。FFI の相対 path を深さに合わせた(`./gleam.mjs` → `../gleam.mjs`、`static_source_ffi.mjs` の `../gleam.mjs` → `../../gleam.mjs`、`../yumemi/framework/server/contracts.mjs` → `./server/contracts.mjs`、`@external` の `../../yumemi_gen_ffi.mjs` → `../../gen_ffi.mjs`)
  - 依存を本体の `[dependencies]` へ:`glance = "7.0.0"`(gen のまま)・`simplifile`・`argv`、それと **`glexer`**(`reader/allow.gleam` などが `glexer/token` を直に import している ── gen の時から「Transitive dependency imported」の警告が 4 件出ていた。tarball の依存に名指しで載せるため足した)。`gen/gleam.toml`・`gen/manifest.toml` は消した
  - **入口で引数を絶対 path に直す**(`yumemi/gen.main` → `gen_ffi.absolute`)。面は `parent(app_dir)` の文字列で探すので、`cd api && gleam run -m yumemi/gen -- . ..` だと `parent(".")` が `.` になり 4 面とも「フォルダの無い Http 入口」(exit 3)で止まった(基点でも同じ、runbook は絶対 path で回している)。生成物は絶対 path で回したものと同じ
- **(3) test を root へ**:`gen/test/*` の 17 file を `test/` に平置き(深さが同じなので test の FFI の `../gleam_stdlib/..` 等はそのまま効く)。root の `yumemi_test.main` が 25 groups の後に `gleeunit.main()` を呼び、gleeunit が `test/` の `*_test` を拾う。`yumemi_gen_test.main` は消した。`[dev-dependencies] gleeunit`
  - **fixture と scripts は `gen/fixtures`・`gen/scripts` に残した**(`gen/` は gleam が compile しない dir。fixture の面の path 依存 `../../../..` がそのまま root を指す)。test の path は `"fixtures/` → `"gen/fixtures/`、`"../src/` → `"src/"`、`yumemi_01115_stage_check.mjs` の `../../src/` → `../src/`
  - `gen/scripts` の 2 つの `.patch`(y1f-f5min・y1f-f6)は過去の差分の記録なので基点のまま戻した。他の scripts は同じ置き換えだけで、走るかは見ていない
- **(4) 面の bundle の esbuild**:`npx --yes esbuild` をやめ、`<面>/node_modules/.bin/esbuild` を起こす。無ければ bundle の前に「`<面>: 面の node_modules に esbuild が無い (<path>)。面の package.json の devDependencies に esbuild を足し、面で npm ci する`」を返し、`bundle_notes` が `stop.Missing`(exit 3)に分ける(51 v6 第 42 条)
  - test のため root に `package.json`(private、`esbuild` 0.28.2 を devDependencies)と `package-lock.json` を置き、bundle の test は temp の面の `node_modules/.bin/esbuild` に root の esbuild を symlink する。root に esbuild が無ければ test が「yumemi の root で npm ci する」で落ちる。`node_modules/`・`.scratch/` を `.gitignore` へ
  - 新しい test `client_bundle_stops_without_face_esbuild_test`(esbuild の無い面で 1 件の名指し・path を含む・束ねない入口が残らない、`bundle_notes` が `Missing`・exit 3)
- **(5) README**:13 行目(「namespace is still `framework/*`」「generator .. ship from 0.3.0」)を現物に、Layout の表に `yumemi/front`・`yumemi/server`・`yumemi/gate`・`yumemi/gen`、「The generator」(起こし方・esbuild の要件)と「Developing yumemi」(`npm ci` → `gleam test`、fixture・scripts は Hex に入らない)の節

## 検収

- **test の本数**(`build/012-y1-before-{root,gen}.txt`、`build/012-y1-after-test.txt`)
  - before:root `Framework checks passed: 25 groups`、gen `344 passed, no failures`
  - after:root `gleam test` 1 つで `Framework checks passed: 25 groups` と `345 passed, no failures`(344 + 新しい 1 本)。減っていない
- `gleam format --check src test`:0(`build/012-y1-fmt.txt`)
- `gleam build` の警告は `Unused private constructor`(`yumemi/secret.gleam`、基点から在る)1 件だけ。glexer の警告 4 件は消えた
- **Hex の tarball**(`gleam export hex-tarball` → `build/yumemi-0.12.0-dev.tar` 304,640 B、`contents.tar.gz` 294,833 B、展開 1,209,398 B。一覧と寸法は `build/012-y1-tarball-list.txt`)
  - 91 file:`LICENSE`・`README.md`・`gleam.toml`・`src/yumemi/**` 88。`src/` の下は `yumemi/` だけ。fixture・scripts・test・`package.json` は無い(`grep -cE 'fixtures|scripts|_test|test/'` 0)
  - requirements 8 つ:gleam_stdlib・lustre・sketch・sketch_lustre・glance・glexer・simplifile・argv。gleeunit は載らない
- **musearch の写し**(origin/main `df5ec4bbb`)
  - 基点:`.scratch/yumemi-base`(`git archive 076d6db`)の `gen` で `gleam run -m yumemi_gen -- <絶対>/api <絶対>`、停止コード 0。生成物は origin/main と `diff -rq` で差 0(`build/012-y1-ms-gen-base.txt`)
  - 写しの ★ の置き換え:api と 4 面の `src`・`test`・`compile_fail` で、`.gleam` の `import framework/<module>` の行、`.gleam` の `"framework/<module>` の文字列(`server.gleam` の `imports: ["framework/time.{type Date}"]` 等、生成器が生成物に写す import)、JS の `yumemi/framework/` の path だけ。5 package の `gleam.toml` の `yumemi` を本作業木への path に。**★ の差はこの 3 種と `gleam.toml` の 1 行と生成 SQL の頭の hash だけ**(`build/012-y1-ms-star.diff`、差の行 4,603(+ と − の計、873 file)のうち他の種類 0 行)。auth は触らない
  - path 依存にしたので 5 package で `gleam deps download`(manifest に glance ほかが lock される。Hex で上げるときの `gleam update yumemi` に当たる)
  - **api の package から `gleam run -m yumemi/gen -- . ..`**:1 回目 停止コード 0、4 面とも `client Out decoder build PASS; runtime build and esbuild PASS`、書いた 2023 file。2 回目 停止コード 0、`git status` 0 行(`build/012-y1-ms-gen-new{1,2}.txt`)
  - **基点の生成物に同じ置き換えを掛けたものとの差**(`build/012-y1-ms-cmp-*`):そのまま比べると 2018 file が違う。中身は 3 種で、どれも名前の替えから来る
    1. 生成物の頭の `[sha256:…]`(★ の本文の hash。★ の import 行が変わったので変わる)── 伏せると 1317 file
    2. Gleam の import の並び(生成器が `gleam format` に掛け、`framework/…` と `yumemi/…` で並ぶ位置が変わる)── import 文を並べ直して比べると 4 file
    3. 残る 4 file:www・muses の `client.mjs` は `let assert` の失敗の報告に焼かれる byte の位置(`start` / `end` / `pattern_start` / `pattern_end`、`24e3` も同じ数の esbuild の綴り)だけ。`framework/` → `yumemi/` で 1 行 3 byte 縮むので位置がずれる(例 4688 → 4676 は import 4 行分)。www・console の `_diagnostics/*-runtime.txt` は今回の生成器が書かない古い file(origin/main のまま)で、比べる側に置き換えを掛けたので差が出た
    - **client の bundle に esbuild の版の差は出ていない。**基点は `npx --yes esbuild`(npx の cache に 0.28.1 と 0.28.2)、新は面の lock の 0.28.2。上の位置の差の外は一致
  - 4 面 `npm run build`:www・muses・console・admin すべて EXIT 0(`build/012-y1-ms-build-*.txt`)。`build/dev/javascript/yumemi/yumemi/` に本作業木が build されたことを見た
  - 4 面 `npm test`:www 428/428、muses 475/475、console 89/89、admin 21/21(`build/012-y1-ms-test-*.txt`)
  - api `npm test`(PG を新しい port 55493 で `api/test/postgres.sh`):1697 本中 1693 pass、4 fail(`build/012-y1-ms-test-api.txt`)
    - `2a-6`・`3-1b-idp`:写しに auth の build が無い(`auth/build/dev/javascript/musearch_auth/gen/auth.mjs`)。auth を手を入れずに `npm ci`・`gleam build` して回し直し pass
    - `compile_fail: subject_type`:Hex の rate limit(下)。回し直し pass。3 本で 13/13(`build/012-y1-ms-test-api-rerun.txt`)
    - `source_contract`:★ の byte を sha256 で固定する test が、置き換えた ★(`api/src/service/article_search.gleam` が最初)で落ちる。基点の写しでは 8/8(`build/012-y1-ms-source-contract-base.txt`)。写しで ★ の hash だけを置き換え前の byte から取る写しの test にすると 8/8(`build/012-y1-ms-source-contract-basehash.txt`)── 落ちる理由は ★ の byte の固定だけ。musearch が 0.12 に上げる便では pin の層を 1 つ足すことになる
  - **esbuild を外した面**:写しの www の `node_modules/.bin/esbuild` と `node_modules/esbuild` を外して回し、**停止コード 3**、`[exit 3 宣言の不足] www: 面の node_modules に esbuild が無い (…/www/node_modules/.bin/esbuild)。…`。他の 3 面は PASS(`build/012-y1-ms-gen-noesbuild.txt`)。戻して `0.28.2`
  - PG を止め、写しを捨てた

## BRIEF との食い違い

- BRIEF の (4) は「51 v6 第 38 条」と書くが、51 v6 で esbuild の条は**第 42 条**(第 38 条は `csp` の host の綴り)。42 条として実装し、コードの注釈も 42 条
- 起こし方:BRIEF と 76 は `gleam run -m yumemi/gen -- <app dir> <out dir>`。`. ..` の相対 path は基点の生成器で面を見つけられなかったので、入口で絶対 path に直した(上の (2))。生成物は変わらない

## 確かめていないこと

- Hex に上げた tarball を別の package から `gleam add yumemi` して起こすこと(publish は鷹野。写しは path 依存で見た。依存は tarball の requirements 8 つで足りることを metadata で見ただけ)
- `gen/scripts` の各 script が置き換えの後に走るか(走らせていない)
- Windows の `node_modules/.bin/esbuild.cmd`(見ていない、`.bin/esbuild` だけを探す)
- 面が npm の workspaces で esbuild を root に hoist する形(面の `node_modules` だけを見る。musearch は面ごとに持つ)

## 残り・気づき

- **写しの面を path 依存にすると、bundle の一時 package が毎回 Hex に版を解きに行く**(`manifestForPathDependency` が manifest の path を絶対 path に書き換え、gleam が解き直す)。4 面 × 2 回(Out decoder と runtime)で Hex の API の rate limit に当たり、1 回目は 4 面とも exit 1、api の `compile_fail` も同じで落ちた。間を置いて回し直して通った。Hex の版を引く面(path 依存でない)では一時 package は manifest をそのまま写すので起きない。生成器で直すなら manifest の path を元の相対のまま残す形(本便では触っていない)
- glance を `"7.0.0"` の固定のまま本体の依存にした(gen のまま)。app が別の glance を要ると解けない。上げ下げの幅を広げるかは段 B 以降
- `docs/` の過去の報告は `framework/` の綴りのまま(記録なので触っていない)

## DDL

無し
