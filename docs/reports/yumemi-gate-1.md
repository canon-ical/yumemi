# yumemi-gate-1(門)── 面の入口の門・rewrite・CSP・pageview・route の順・client の入口を生成器へ(真壁、2026-09-26)

## r2(2026-09-26 05:16〜、載せ直しと直し、鷹野[PDM] の直書き)

**DDL:無し**(migration / schema に触れていない。staging / production にも触れていない)。

**結論:main `32604ca`(WGy)を merge し、門の session の口を WGy の `attached_roles` から引く形に直した。柏木の P2(空白だけの query)・生成器の穴 `transport_send`・WGy r4 の積み残し 2 つ(framework の JS の Staff、出力先が app を含む dir の全走)・版 0.11.1 を入れた。**musearch `4504b36`(F6 の後)の写しに WGy の star を 3-way で載せ直し、`gleam run -m yumemi_gen -- <写し>/api <写し>` の 1 手で back と 3 面が在るべき場所に出る(×2 で差 0)。写しの api `npm test` は **692 / 694**(新しい DB で 2 回同じ)── 落ちる 2 本は F6 が足した Service(`widget_list_mine` / `widget_read` / `widget_choices` / `space_read`)の WGy の生成器への載せ替えの残りで、下に名指しした。Workerd の門の表は 102 行で status・Location・CSP・pageview・描いた Page が前後全一致。証跡は `gen/build/gate2/`。

### 載せ直し(merge `32604ca`)の衝突と解き方

- 衝突は `results.md` の 1 file だけ(門の節を頭に、WGy の節をその後に)。`emit/front.gleam` は区画どおり自動で混ざった(WGy は `api_routes` / `face_service_names` / `blob_entry_live_text` の頭、門は route 表・shell・client・門の接続)。merge 直後の gen test **278 passed**(WGy 267 + 門 11)
- **門が宣言から読むものを WGy に合わせた:session の口。**r1 の `gate.mjs` は `/api/session` を直書きしていた。WGy r4 で framework は口の名を知らず `attached_roles` の `ReadSession` で渡す形になったので、門も同じ宣言から引く(`emit/front.gleam` の `session_path`、`const sessionPath = "<ReadSession の attached の path>"`)。門が session を読む(rules・redirects・pageview のどれかを持つ)のに `ReadSession` が無ければ **exit 3**(`<面>/gate: 門が session を読むのに src/server.gleam の attached_roles に ReadSession が無い`)、生成物は `sessionPath = null` で 502。fixture の `server.gleam` に `fixture_session` の口と `ReadSession` を足した(admin の既定の門が session を読むため)。`gate.mjs` の入力 hash に session の口を足した
- route 表:WGy の `api_routes` は `entry.routes` から直に引く形に変わったが、門が使う Page の route 表(`front_route_paths`)は面の Page から作るので影響なし

### 直したもの

| # | 何 | 在処 |
|---|---|---|
| 1 | **空白だけの query を None**(柏木 P2 / 鷹野の裁定 5)。生成 shell の Page の Query は `found === null \|\| found.trim() === ""` で None。空白でない値は trim せずそのまま送る(前の www は trim した値を送っていた ── 語の前後の空白だけ違う) | `emit/front.gleam` の `shell_runtime_text`、`gate_test` |
| 2 | **`transport_send` の穴。**`attached_live_text` の外部宣言に `blob_fields: List(String)`、呼び出しに `[]`。写しの www / muses の `gen/live/browser_adult.gleam` は sha256 ヘッダ付きの生成物に戻り、`www/test/external-arity.test.mjs` は 2 / 2 pass | `emit/front.gleam`、`gate_test.attached_entry_live_sends_blob_fields_test` |
| 3 (a) | **framework の JS から Staff を抜いた。**`runtime.mjs:129` の `kind==='staff'&&resolved?.staff` を消し、`outbox.mjs:41` の偽の Staff 行(`{id,party:'queue',name:'Queue'}`)を消した。偽の行は actor を組むためだけに在り、その actor は consumer の `SystemActor` で上書きされる ── 効いていたのは party `'queue'`(root の 1 文と verb の `party` の穴・audit)だけ。**新しい宣言 `roots` の `QueueParty(service, party)`** で consumer ごとに渡す(生成器は `queue_runtime.mjs` の consumer に `party:'queue'`)。生成器の `who が "Staff" で終わる` の判定も消した。musearch の宣言は star.patch の `api/src/server.gleam` に 1 行(`QueueParty(service: "store_request_notify", party: "queue")`)。写しで `2b-8 consumers write the Page path of the recipient face`(store_request_notify を consume する)が pass | `src/framework/server.gleam`・`server/{runtime,outbox}.mjs`、`emit/back.gleam`、`reader/server.gleam`、`wgy_test.queue_consumer_party_follows_the_declaration_test` |
| 4 (b) | **出力先が app か app を含む dir なら在るべき場所へ(`place`)。**`-- <root>/api <root>`:back は `api/src/gen/..`・`api/db/queries/..`、面は面の package(`www/src/gen/..`)。`-- <root>/api <root>/api`:back はそのまま、面は `../www/..`。別の dir なら従来の並び(`src/gen/..`・`<面>/..`)。`db/queries` へは既に在る GENERATED だけ(WGy の `into_app` を、同じ dir だけでなく含む dir にも)。`bundle_front` は面の出力の dir を受ける | `gen/src/yumemi_gen.gleam`(`Placement` / `place`)、`yumemi_gen_ffi.mjs`(`holds_dir` / `relative_dir`)、`wgy_test.place_puts_back_and_faces_where_they_live_test` |
| 5 | 版 `0.11.1`(root の `gleam.toml`)、gen の `manifest.toml` の path 依存の版も 0.11.1。CHANGELOG は無い(作っていない)。README の framework/server の節に `QueueParty` と門の session の口を 1 文 | `gleam.toml`、`gen/manifest.toml`、`README.md` |
| 足した | **`subject_free: List(String)`**(新しい const、型は増やしていない)── 入口の主体の集合(`Subjects([..])`)の検査を外す Service の名。F6 の `store_list_mine`(console の `/switch` が店でない主体のまま店の一覧を読む)は、0.11.0 の手書きの http_runtime に `sessionSubjectReads = new Set(['store_list_mine'])` を持っていた。WGy の framework `http.mjs` は Service の名を知らないので宣言から `subjectFree` で渡す。Service に無い名は exit 4 | `src/framework/server.gleam`(doc)・`server/http.mjs`、`model` / `reader/server` / `emit/http`、`wgy_test.subject_free_follows_the_declaration_test` |

### WGm に渡す patch

- `docs/reports/yumemi-gen-8-patches/star.patch`(645ec49 向け、WGy の 270 file)に `QueueParty` の 1 行を足した(`api/src/server.gleam` の hunk だけ)
- **新しい `docs/reports/yumemi-gen-8-patches/star-4504b36.patch`**(275 file、一覧は `star-4504b36-files.txt`)── musearch `4504b36` に WGy の star を 3-way で載せ直し、F6 の Service を 0.11.1 に合わせた ★ の直しを足したもの。`git apply --check` と `patch -p1 --dry-run` が `4504b36` の `git archive` に通る。載せ直しで手で解いたのは 3 file(`api/gen/sql_manifest.json` は両方の行、`api/test/sql-cases.mjs` は両方の define、`api/test/source_contract.test.mjs` は F6 の yumemi-6 の層を残して WGy の `starHash` に)と、F6 と star の両方が変えた ★ 4 本(`article_search` / `store_schedule_list` / `widget_list` / `user_do.mjs`)の `wgy-star-sha256.txt` の対を F6 の hash に付け替えたこと
- F6 の Service への ★ の直し(star-4504b36 だけに在る):`arg_widget_list_mine_space` の hook と `argWidgetListSpace` を F6 の `Option(Place)`(None / `top` / `all` / 置き場の id)に、`course_list` の `own_ledger` を `ManualRead` + hook、`store_list_mine` の `subjects` を `ManualRead` + hook(型 `Subject` は ★ `api/src/session_subject.gleam` へ、`store_list_mine` / `muse_list_mine` の pattern をそれに)、`widget_list_mine` / `widget_read` は自分の Root を `widget_list` の Root に詰め替えて `widget_list.place` へ、`failureStatus` に F6 の 404 の行(`widget_list_mine` / `widget_read` / `space_read` の `space_not_found`、`roster_read_mine` の `not_found`)、`subject_free = ["store_list_mine"]`、書き換えた ★ 4 本の hash の対

### 確かめたこと(r2)

| 検収 | 結果 | 証跡(`gen/build/gate2/`) |
|---|---|---|
| root `gleam build` | 0(warning 1、既存の `framework/secret.gleam:5`) | `root-build-final.txt` |
| `cd gen && gleam test` | **283 passed, no failures**(merge 後 278 + 新しい 5:ReadSession 無しの exit 3・Attached Entry の blob_fields・QueueParty・place・subject_free) | `test-final.txt` |
| `gleam format --check src test` | root・gen とも 0 | ── |
| Article fixture ×2 | 2 回とも exit 0、`diff -r` 0 行。tracked 66 file と `cmp` で不一致 0(本便で変えたのは入力の `src/server.gleam`(`fixture_session` の口と `ReadSession`)と、生成物の back 12 file(hash と attached の 1 行・`roles`・`subjectFree`)・面の `api.gleam` ×2・`gate.mjs` ×2・`shell.mjs` ×2・public の `client.mjs`) | `fx-one`、`fx-two` |
| `git diff v0.11.0 -- src/framework` | 11 file とも `A`(`gate.gleam` と WGy の `server*`)、+1339 / 削除 0。`src test gleam.toml` は `A` 11・`M` 1(`gleam.toml` の版だけ) | ── |
| Hex の package(`gleam export hex-tarball`、publish はしていない) | `build/yumemi-0.11.1.tar`、`metadata.config` の版 0.11.1、45 file(`src/framework/gate.gleam`・`server/*.mjs` 9 本・README・LICENSE を含む) | `hex-tarball.txt`、`hex/` |
| 写し(musearch `4504b36` + `star-4504b36.patch` + www / console の `src/gate.gleam` + 4 package の yumemi を path 依存に)の生成器 ×2、1 手(`-- <写し>/api <写し>`) | 2 回とも exit 3(www の島 7 本の `app()` 無し、r1 と同じ)・1255 file。`diff -r`(build・node_modules を除く)は npm test が書いた `api/manifest.toml` だけ。`<写し>/src`・`api/www` などの誤った置き場は 0。変わった file は api/src/gen 291・www 73・muses 96・console 76・db/queries 9(既に在る GENERATED) | `gen-snap{A,B}.log`、`snapA-status.txt` |
| 写しの api `npm test`(auth を先に build、dropdb からの新しい DB、PG 55540) | **692 / 694 を 2 回**(`api-test-4.txt`・`api-test-5.txt`)。落ちる 2 本は下の「F6 の Service の残り」 | `api-test-{4,5}.txt` |
| 3 面の `gleam build`(生成物の `src/gen` 全部、yumemi 0.11.1) | www / muses / console とも exit 0。warning の数は 4504b36 の面(Hex 0.11.0)と同じ(333 / 207 / 136) | `face-build-*.txt`、`base-build-*.txt` |
| 3 面の node test | 前(4504b36)www 48 / 2 fail・muses 16・console 18、後 www 49 / 2 fail・muses 16・console 18。前の 2 fail は archive に docs と wrangler が無い環境要因、後の 2 fail は下の「鷹野宛 1」 | `facetest-*.txt` |
| **Workerd の門の表**(r1 の 98 行の道具 + 空の検索 4 行、https) | **102 行で status・Location・CSP・pageview・描いた Page が前後全一致。**前 = 4504b36 の面(殻の `gates.mjs`、Hex 0.11.0)、後 = 写しの生成物に薄い `gates.mjs`(生成 shell の export default を出すだけ)。差は空の検索 6 行の読みの数と送った `q`(前は殻が短絡して API を呼ばない、後は `q` 無しで API へ ── `?q=%20` も `no-q` で送られる = P2)と body(adult の pageview の script の書き方・500 の頁の stack の path) | `workerd/table-{before,after}-https.tsv`、`workerd/compare.py` |

PG 55540 は本便で起こし(`snapA/api/test/build/pgdata-public`、pid 3033448)、終端で `kill 3033448`。`pg_isready -p 55540` は no response、pid は消えた。wrangler(9184 / 9182 / 9183、inspector 9632〜9634)は前後とも `pids-*.txt` の pid で止め、port が空いたのを見た。55541 / 55496 / 5552x / 55502 / 55503 / 55506 には触れていない。musearch は `git archive` で読み、node_modules を写しに cp しただけで、作業木には書いていない。

### F6 の Service の残り(WGm へ、名指し)

api の 2 fail(`N2: every API read place ...`・`yumemi-6 widget_list_mine / widget_read / widget_choices / space_read ...`)はどちらも F6 が足した Service で、WGy の生成器へ載せ替える形が決まっていない:

1. **root の 1 文が無い。**`widget_list_mine` / `widget_read` / `space_read` は 0.11.0 では手書きの `gen/root/*.gleam` が `widget_list.Root` の別名で、registry は `root_widget_list` の root を借りていた。WGy の生成器は Service ごとに Root を作り、`db/queries/<service>/root.sql` が無いと `sql:null` で実行時に `decodeMuse(null)`(WGy r3 の「届かないもの 6」── 生成器は名指ししない)。★ で root の SQL を足すなら manifest の semantic test が要る
2. **入口の食い違い。**WGy の registry は `faces` から `entry` を付ける。`widget_list_mine` / `widget_read` / `widget_choices` は `faces: [Muses]` なのに、F6 の N2 test は www の host から呼ぶ → `forbidden`(403)。0.11.0 の registry は `entry` を持たなかった。`faces` を直すか test を直すかは F6 の意図次第

### 鷹野宛(r2)

1. **空の検索の「API を呼ばない」要求が食い違う。**BRIEF(本便)は「F6 が `article_search.q` を `Option` にした後は back が空で返すので、短絡そのものが要らなくなる」。musearch の `docs/yumemi-5/exceptions.md` は「消した後も同じ要求(`q` 無しで 200、**API を呼ばない**)は生成 shell の試験として残す」。生成 shell は空・空白だけの `q` を None で **API に送る**(back が空で返す)ので、www の `test/entry-queries.test.mjs` の `search Page without q` 2 本は、殻を薄くすると落ちる。生成 shell に Page ごとの短絡の宣言を足すか、test を「`q` を付けずに送る」に直すかの裁き
2. **出力先が app を含む dir の全走は、生成器が出さなくなった file を消さない。**写しの api/src/gen に 4 本残る(`driver.mjs` / `contracts.mjs` は framework へ、`heaven_ffi.mjs` / `litlink_ffi.mjs` は ★ `api/src/` へ移ったもの)。WGm は 1 手の前に `rm -rf api/src/gen <面>/src/gen` を置く(面の ▲ の例外は本便の `transport_send` で 0 になった)。生成器に消させるのは本便でしていない
3. `QueueParty` と `subject_free` は 0.11.0 の公開型に足しただけ(`RootShape` は WGy で足した未公開の型、`subject_free` は const の約束だけで型は無い)

### WGm への申し送り(r1 の節の更新)

- **生成は 1 手:**`gleam run -m yumemi_gen -- musearch/api musearch`(その前に `rm -rf api/src/gen www/src/gen muses/src/gen console/src/gen`)。r1 / WGy の「別の出力先に出して写す」手順は要らない。api の `db/queries` は既に在る GENERATED だけが書き換わる
- musearch に当てる ★ は `star-4504b36.patch`(645ec49 向けの `star.patch` ではない)
- www / console の `src/gate.gleam` は r1 の本文のまま(写しでそのまま通った)。`src/gates.mjs` は `export default (await import("../build/dev/javascript/<package>/gen/shell.mjs")).default;` の 1 行で足りる(値の運びは F6 で消えた)。上の鷹野宛 1 の裁き次第で www の 2 test を直す
- `browser_adult.gleam` の ▲ 2 本(www / muses)は生成物に戻る。`external-arity.test.mjs` は残す
- 残り:www の島 7 本の `app()`(r1 から)、上の「F6 の Service の残り」2 つ、console の ★ `blob_copy*`

### 確かめていないこと(r2)

- 写しの api の 2 fail の中身の直し(F6 の Service の root と入口、上の名指し)
- 実 API(本物の PG・Neon)と本物の session での門。Workerd の APP は r1 の stub のまま
- `-- <root>/api <root>/api`(面を `../<面>` に書く形)の実走。test(`place`)では見たが、写しでは `-- <写し>/api <写し>` だけ回した
- http(`--local-protocol http`)の Workerd の表。r1 の `claim_anonymous` の Location の差の行は取り直していない
- `gleam publish` の実際の Hex 側の検査(`export hex-tarball` まで)
- auth の test(auth は build だけ)


基点 yumemi main `3209703`(v0.11.0 + docs)、branch `impl/yumemi-gate-1`。写しは musearch `645ec49` の `git archive`(`gen/build/gate/snap/`)。musearch には 1 file も書いていない。証跡は `gen/build/gate/`。

## 何を足したか

| 物 | 在処 | 中身 |
|---|---|---|
| 門の宣言の型(新しい module だけ) | `src/framework/gate.gleam` | `Gate(sign_in, rules, redirects, frame_src, pageview)`。Page 群は `Match` = `Exact(path)` / `Prefix(path)` / `Every` で指し、`Rule(pages, except, checks)` の `except` で除く Page を持つ。検査は `SignedIn` / `Adult` / `SubjectKind` / `Consent`、失敗の応答は `ToSignIn(status, back)` / `Deny(status, body)` / `RedirectTo(location)`。条件つきの redirect は `Redirect(pages, WhenAdult | WhenSignedIn, SafeParam(param, fallback) | Fixed(location))`。pageview は `Pageview(pages, endpoint, source_param, storage_key)` / `NoPageview`。**0.11.0 の `Page` / `Layout` / `Entry` と既存の構成子は 1 字も変えていない** |
| reader | `gen/src/yumemi_gen/reader/gate.gleam` | 面の `src/gate.gleam` の `pub const gate` を読む。無い面は入口 `Http` の `admit: Authenticated` + `subject: Subjects([..])` から既定の門(`Admitted(kinds)`)を組む。CSP の host は入口の `frame_src` 欄から読む(`model.gleam` は触らず entry の unit を直に読む)。`Exact` の Page が route に無い・`Prefix` の下に Page が無い・3xx でない `ToSignIn` などは exit 4、`gate` の const が無い file は exit 3 |
| emit | `gen/src/yumemi_gen/emit/gate.gleam` → 面の `src/gen/gate.mjs` | `before_route(request, env)` / `after_response(request, env, response)` / `serve(dispatch)`。前者は route 表で Page を引き、URL の段の `-` をフォルダの `_` に戻し、session を 1 回読み、rules → redirects の順に当てる。後者は CSP `frame-src` と pageview の script を足す。sha256 ヘッダ付き |
| 生成 shell | `emit/front.gleam` の `shell_*` | `export default gate.serve(async (request, env, before) => ..)`。門が読んだ session を `renderPage` に渡す(二度読まない)。**Page の query が空文字なら `None`**(空の検索の短絡を殻から消すための生成側の半分) |
| route 表の順 | `emit/front.gleam` の `route_text` / `route_order` | 段ごとに比べ、同じ位置で literal の段を param の段より先に。`prioritizeLiteralRoutes` は要らない |
| URL の綴り(裁定 1 (a)) | `gate.mjs` の `literalMatches` | route の literal の段 `a_b` は URL の `a-b` にも当たり、正規の綴り(`_`)に直して shell へ渡す。`/for-stores/api/v1` → `/for_stores/api/v1`、`/api-key` → `/api_key`。宣言は要らない |
| client の入口(裁定 2 (a)) | `emit/front.gleam` の `client_components` / `client_notes` | 登録の源を「`components/` のうち `pub fn app()` を持つもの全部」に直した(以前は `calls` の在る島だけで、`calls` の無い島 3 本を落としていた)。`calls` を持つのに `app()` の無い島は exit 3 で名指す |

`yumemi_gen.gleam` は front の診断の列に 2 行(`gate_notes` / `client_notes`)を足しただけ。

## 棚卸し ── 3 面の `gates.mjs` を行で割る(`gen/build/gate/inventory.tsv`、未分類 0)

| 面 | 行 | 本便 | F6(値の運び) | 名指しの残り |
|---|---|---|---|---|
| www | 407 | 285 | 122 | 0 |
| muses | 170 | 87 | 83 | 0 |
| console | 194 | 111 | 83 | 0 |

本便の行の置き場(block 単位の対応は tsv の `where` 列):`prioritizeLiteralRoutes` → route 表の順、`matchRoute` / `routeFor` / `routeParams` → `gate.mjs` の `matchRoute`、`shellPath` / `rewriteApiKeyPath` → URL の綴りの規則、`handleMe` / `handleClaim` / `gateResponse` / muses の `gate` → `Rule` と既定の `Admitted`、`safeReturn` → `SafeParam`、`withFramePageHeader` / `frameSrc` → `after_response` の CSP、`tracksPageview` / `htmlWithPageviewScript` → `Pageview`。F6 の行は `pageVars`・`queryValues`・`withPageValues`・`envWith*`・`withOwnLedger`・日付の既定・www の `entryReadNotFound`。名指しの残り(client entry の外の ★ `blob_copy*`)は `gates.mjs` の外なので表に行が無い。

## 写しで確かめたこと

写しに www / console の `src/gate.gleam`(下の「WGm への申し送り」の本文)を置き、生成器を 2 回当てた。面は写しの `src/gen` をそのまま使い、生成物の `gen/gate.mjs` と `gen/route.gleam` だけを重ねた(写しの Page は 0.11 の宣言に追随していないので、生成物の `src/gen` 全体では面が build できない ── 基線から同じ exit 1 × 3。F6 / WGm の仕事)。`gates.mjs` は F6 の射程の関数だけを原文のまま残した薄い ★ に縮めた。面は Hex の yumemi 0.9 のままなので、`framework/gate.gleam` を面の `src/framework/` に写して build した(0.11.1 を採れば要らない)。

| 検収 | 結果 | 証跡 |
|---|---|---|
| 生成器 ×2 | 2 回とも exit 4、`diff -r` は runtime build の記録の時間 1 行だけ。`_diagnostics.txt` は基線 + www の `app()` 無し 7 行(下) | `after-gen-{one,two}.log`、`after-gen-diff.txt` |
| 生成 shell と門の sha256 ヘッダ | 3 面とも `gate.mjs` / `shell.mjs` の 1 行目にヘッダ | `after-gen-one/*/src/gen/` |
| route の集合 | 3 面とも写しの `route.gleam` と同じ集合、順だけ literal-first | ― |
| `test/entry-gates.test.mjs`(門の assert) | before / after とも www 11 / muses 16 / console 18 pass | `before/test-*.txt`、`after/test-*.txt` |
| 面の node test 全部 | before / after とも www 48 pass 1 fail、muses 16、console 18。www の 1 fail は写しに `docs/api-v1.md` が無い環境要因で前後同じ test | `before/all-*.txt`、`after/all-*.txt` |
| **Workerd の status 表**(wrangler dev、www 9184 / muses 9182 / console 9183、inspector 9632〜9634、`--local-protocol https`) | **98 行で status・Location・CSP・pageview の有無・描いた Page・門の後の読みの数が前後全一致**。F5 の 23 行(`/muse/kanon/blog/article-1` は 404 のまま)、2b-7 の `/me/*` 11 Page × 3 主体、2b-8 の muses 3 Page × 4 主体・console 2 Page × 4 主体、CSP 5 行、pageview 4 行、URL の綴り 2 行、literal-first 6 行、session の失敗 3 行、route の外 2 行 | `workerd/table-{before,after}-https.tsv`、`workerd/compare.py` |
| body の sha256 | 200 の行で違うのは `/search?r=mail`(成人)の pageview の script だけ(下)。他の 15 行は 500 の Workerd のエラー頁で、stack に before / after の path が入るための差 | `workerd/bodies-*`、`workerd/pageview-script-diff.txt` |
| pageview の script | 差は追跡の判定の書き方だけ(正規表現 → route の表)。41370 path で前後の判定が選ぶ集合は同一(追跡 573、差 0) | `workerd/tracked-equiv.{mjs,txt}` |
| literal-first の 3 対 | `/articles/new`・`/page/widget/new`・`/rosters/new` と param の側が前後で同じ status・同じ Page・同じ読みの数 | table の `literal` 行 |
| 薄い ★ の残り | www 131 行 = F6 117 + dispatch の中の値の運びの呼び出し 8 + 生成物を呼ぶ口 4 + 札 2。muses 91 = 81 + 4 + 4 + 2。console 98 = 86 + 6 + 4 + 2(console の `failure` は `withOwnLedger` が使うので残した) | `thin-star.tsv`、`after/*/src/gates.mjs` |
| client の入口 | 生成器の束ねる前の `client.mjs` を写しの面の build に esbuild で束ね(`import-is-undefined` を error)、node で `customElements.define` を数えた。**muses 37 / 37 一致、console 14 / 15(差は名指しの残り `blob-copy`)**。www は 0 本(7 本とも `app()` が無い → exit 3 で名指す) | `client/{compare.py,defined.mjs,defined-*.json}` |

Workerd の APP は F5 の `yumemi-5-stub-server.mjs` の固定応答をそのまま写した stub。固定応答が今の decoder に合わない読み(11 種)の Page は、門を通った後の描画で前後とも 500 になる(`app_reads` 列が前後同じ数で、門の後まで進んだことを示す)。F5 の表で 200 だった `me_adult_pass` などがこの表では 500 なのはそのため。

## 前と変わるところ(鷹野宛)

1. **http で受けたときの `/claim` の `redirect_uri`。**前の www は `https://` + host に書き換えていたが、生成物は要求の URL のまま(console の前と同じ)。Workerd を http で起こすと `claim_anonymous` の Location が 1 行だけ `http%3A` になる(`workerd/table-*-http.tsv`)。本番の要求は https なので差は出ない。符号化も console の `encodeURIComponent` に揃えた(www の前の `URLSearchParams` とは `!'()~` と空白だけ違う)
2. **CSP を付ける Page は宣言の列挙(`frame_src: [Exact(..) ×3]`)。**前の 3 Page に合わせた。SvelteKit の頃は全 Page に meta を出していたので、`Every` にするかは鷹野の裁き
3. **muses の `adult-declare` と `article-list-actions` は送った後に reload する。**2 本とも `after_send = ReloadPage` を宣言し `yumemi-done` を出しているのに、手書きの入口が聞いていなかった。生成物は宣言どおり聞く
4. 門が session を読めなかった(例外)ときは 502 `session read failed`(前は www の `/me` が 500、他は素通り)。既定の門(`Admitted`)は主体に `handle` の文字列を求める(muses の前と同じ)
5. 空の検索:生成 shell は `?q=` を `None`(送らない)にする。`?q=%20` は前の殻が trim して短絡したが、生成物は `" "` を送る

## WGm への申し送り

- www の `src/gate.gleam`(写しで使った本文):

```gleam
import framework/gate.{
  Adult, Deny, Exact, Gate, Pageview, Prefix, Redirect, Rule, SafeParam,
  SignIn, SignedIn, ToSignIn, WhenAdult,
}

pub const gate: gate.Gate = Gate(
  sign_in: SignIn(path: "/auth/sign-in", fallback_origin: "https://auth.yumemism.dev"),
  rules: [
    Rule(pages: [Prefix("/me")], except: [], checks: [
      SignedIn(fail: ToSignIn(status: 302, back: False)),
      Adult(fail: Deny(status: 403, body: "adult declaration required")),
    ]),
    Rule(pages: [Exact("/claim/:code")], except: [], checks: [
      SignedIn(fail: ToSignIn(status: 303, back: True)),
    ]),
  ],
  redirects: [
    Redirect(pages: [Exact("/")], when: WhenAdult, to: SafeParam(param: "returnTo", fallback: "/search")),
  ],
  frame_src: [Exact("/"), Exact("/about/external"), Exact("/for_stores/api/v1")],
  pageview: Pageview(
    pages: [
      Exact("/search"), Exact("/muse/:handle"), Exact("/muse/:handle/article"),
      Exact("/muse/:handle/article/:id"), Exact("/muse/:handle/space/:id"),
      Exact("/muse/:handle/schedule"), Exact("/muse/:handle/reviews"),
      Exact("/store/:handle"), Exact("/store/:handle/cast/:id"),
    ],
    endpoint: "/api/pageviews",
    source_param: "r",
    storage_key: "musearch:last-pageview",
  ),
)
```

- console の `src/gate.gleam`:

```gleam
import framework/gate.{
  Consent, Every, Exact, Gate, NoPageview, RedirectTo, Rule, SignIn, SignedIn,
  SubjectKind, ToSignIn,
}

pub const gate: gate.Gate = Gate(
  sign_in: SignIn(path: "/auth/sign-in", fallback_origin: ""),
  rules: [
    Rule(pages: [Every], except: [], checks: [SignedIn(fail: ToSignIn(status: 302, back: True))]),
    Rule(pages: [Every], except: [Exact("/switch"), Exact("/consent")], checks: [
      SubjectKind(kinds: ["store"], fail: RedirectTo("/switch")),
      Consent(kind: "use", fail: RedirectTo("/consent")),
    ]),
  ],
  redirects: [],
  frame_src: [],
  pageview: NoPageview,
)
```

- muses は宣言を置かない(入口の `Authenticated` + `Subjects([Muse])` から既定の門)
- `gates.mjs` は F6 の後に消せる(生成 shell 0.11.1 の export default が門を持つ)。F6 の前に 0.11.1 を採るなら、写しの `after/*/src/gates.mjs` の形(`serve` の dispatch に値の運びだけ)で置ける
- www の島 7 本に `pub fn app()` を足す(muses / console と同じ形)。手書きの島 `reserve_flow_island` / `schedule_slots_island` は `components/` へ移して `app()` を持たせる。同意の 2 tag(`consent-give-use` / `-handling`)は `kind` / `version` の属性か component を 2 本に。これで ★ `client.gleam` / `client_ffi.mjs` / `web/browser_entry.mjs` は生成物の `priv/static/_yumemi/client.mjs` で置き換わる(面の build が生成物の `src/gen` で通った後)
- 空の検索:F6 r1(`75647a9`、読んだだけ)の `/search` の Page は `q` の Var をまだ宣言していない。宣言して `article_search.q: Option` が入れば、★ の `envWithSearchQuery` は消せる
- 名指しの残り:console の ★ `blob_copy*`(`roster_photo_put` の live module、Y1e 候補)

## WGy との重なり

`emit/front.gleam` で触ったのは `route_text` と `route_order`(新)、`shell_imports` の 1 行、`shell_runtime_text` の `renderPage` の頭 2 行・query の 1 行・export default、`emit` の files に 1 行(`gate_file`)、`gate_file` / `read_gate` / `gate_notes`(新、`shell_imports` の前)、`client_text` と `client_components` / `client_notes`(`island_components` を置き換え)。`yumemi_gen.gleam` は front の診断の列の 2 行。`api_routes` / `app.attached` の読み手 / `model.gleam` / `emit/entry.gleam` / back の emitter は触っていない。

## DDL

無し。

## 検証(コマンドと結果)

- root `gleam build`:exit 0、warning 1(既存の `framework/secret.gleam`)。`gen/build/gate/root-build-final.txt`
- `cd gen && gleam test`:**252 passed, no failures**(基線 241 + 新規 11、`gen/test/gate_test.gleam`)。`gen/build/gate/test-3.txt`
- `gleam format --check src test`:root / gen とも 0
- Article fixture ×2:exit 0、`diff -r` 0 行。tracked の生成物は byte 一致(本便で更新したのは `public` / `admin` の `shell.mjs` と新しい `gate.mjs`。`admin` は入口 `Authenticated` + `Subjects([Staff])` の既定の門が付く)
- 写し:上の表
