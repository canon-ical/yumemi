# BRIEF yumemi-gate-1(門)── 面の wrapper が持つ門・rewrite・CSP・pageview・route の順を生成器が書く(entry の lifecycle hook)(草案、2026-09-26、水無瀬[PL] 起草 → 鷹野[PDM] が裁く)

便: yumemi-gate-1(門)

**真壁さんへ。本便は 1 session で直に書き、終端で柏木のゲートを 1 回だけ受けます(贄川は通しません)。**基点は yumemi main `b8ee337`(v0.11.0 + report 1 本)、作業木は `~/yumemism_repo/yumemi-gate-1`(branch `impl/yumemi-gate-1`、鷹野が切る)。**WGy(yumemi-gen-8)が同じ基点から並走し、merge は WGy が先**です。本便は WGy の merge の後に載せ直し、`emit/front.gleam` の衝突は区画で畳みます(「WGy との分け方」)。Hex は両方の merge の後に 0.11.1 を 1 回(鷹野)。**musearch へは 1 file も書きません** ── 確かめは musearch `645ec49` の写し(`gen/build/gate/snap/`)の上だけ。採用は WGm(musearch-yumemi-7)。記録は `results.md` の先頭の節と `docs/reports/yumemi-gate-1.md`(`## DDL` は「無し」)、証跡は `gen/build/gate/`。commit は `git-as makabe`(path 指定)、`main` に触らない、push と publish は鷹野。柏木の P0 があれば、鷹野が真壁を新しい session で 1 回起こす。

**版(役員 人見 09-26「0.11.x の patch でいい」):**0.11.1 で出す。0.11.0 の公開型の既存の欄と構成子は変えない ── 門の宣言は `Page` / `Layout` / `Entry` の欄に足さず、**面ごとの新しい const**(例 `src/gate.gleam` の `pub const gate`)に置く。

**親ゴール:** yumemi の生成器が musearch の 3 面と back の両方を書き切り、`src/gen` と `api/src/gen` に手書きが残らない状態で閉じる(役員 人見 09-26)。本便はそのうち**面の入口の門**を持つ ── 3 面の ★ `src/gates.mjs`(www 407 行 / muses 170 / console 194、札 `入口の門 → Y 候補`)を生成物に置き換えられる形にする。

**障害:**

- **F6 の持ち分まで取る。**`gates.mjs` には門と、F6 が消す値の運び(ALS、`envWithSessionHandle`、`envWithEntryQueries`、`withOwnLedger`)が同居している。本便が値の運びまで生成すると F6 と二重になり、F6 の merge で食い違う。本便の射程は F5 の `docs/yumemi-5/gates.md` の門の行と、rewrite・CSP・pageview・route の順だけ
- **門の条件を面の Page の数だけ書く。**console の D-2 は `/switch` `/consent` 以外の全 Page、www の `/me` は前方一致(2b-7 の裁定)。Page ごとに書くと Page を足すたびに漏れる
- **門を消す** ── 未ログインの 302 / 303、成人でない 403、店でない `/switch`、同意の無い `/consent` のどれかが生成物で落ちる。F5 の前後比較の 23 行と 2b の行が正

## 棚卸し ── 3 面の `gates.mjs` のうち本便の行(musearch `645ec49`)

| 面 | 門 / 仕組み | 在処 | 本便の形 |
|---|---|---|---|
| www | `/me`, `/me/*`(前方一致):未ログイン → 302 sign-in、成人でない → 403 | `gates.mjs` の門 | 宣言(面の門:前方一致の Page 群 × 条件 × 失敗の応答) |
| www | `/claim/:code`:未ログイン → 303 sign-in(`redirect_uri` 付き) | 同 | 同上 |
| www | `/`:成人 session → 302 `returnTo`(安全化、既定 `/search`) | `gates.mjs:375` | 宣言(条件つきの redirect) |
| www | `/for-stores/api/v1` → `/for_stores/api/v1` | `gates.mjs:77` | **URL の綴りの規則**(フォルダの `_` と URL の `-`)か宣言の rewrite(問い 1) |
| www | CSP `frame-src`(`entry.gleam` の `frame_src` が既に宣言) | `gates.mjs:32` | 生成(宣言は既に在る) |
| www | pageview の script(成人 session、対象 Page、`r` の source key) | `gates.mjs:283-330` | `after_response` の hook、対象 Page は宣言 |
| www | 空の検索の短絡(札 `空の検索 → Y 候補 W-P08a`) | `gates.mjs:189-201` | 生成 shell が空文字の Query を None で送る。F6 が `article_search.q` を `Option` にした後は back が空で返すので、短絡そのものが要らなくなる(確かめる) |
| muses | session の読みの失敗(403 / 404 / 他)、subject が muse でない → 403 | `gates.mjs:147` | 生成 shell の既定(面の `admit` と subject から) |
| console | D-2:未ログイン → 302 sign-in、店でない → `/switch`、同意 `use` が無い → `/consent`(`/switch` `/consent` は除く) | `gates.mjs:153-173` | 宣言(面の門:除く Page × 条件) |
| console | `/api-key` → `/api_key` | `gates.mjs:65-67` | 上の URL の綴りと同じ |
| 3 面 | literal-first(`/articles/new` を `/articles/:id` より先に) | `prioritizeLiteralRoutes` | **生成器の route 表の順を直す**(宣言は要らない。生成器の不具合) |

**射程の外(F6 が消す):**ALS の import と `pageVars.run`、`envWithSessionHandle` / `envWithEntryQueries` / `withOwnLedger`、muses `/metrics` `/schedule` の query の運び。**射程の外(名指しの残り、問い 2):**★ `client.gleam` / `client_ffi.mjs` / `web/browser_entry.mjs`(島の登録と bundle の入口、札 `★ client entry`)、console の ★ `blob_copy*`(Y1e 候補、`roster_photo_put` の live module)。

## どこまで

1. **行単位の棚卸し** ── 3 面の `gates.mjs` を「本便 / F6 / 名指しの残り」に割る。未分類 0
2. **宣言** ── 面の門(Page 群 × 条件 × 失敗の応答、除く Page)、条件つきの redirect、pageview の対象、URL の綴り(問い 1)。新しい module と const だけ
3. **生成** ── 生成 shell に `before_route(request, env)` と `after_response(request, env, response)` の lifecycle hook(F5 `gates.md`「根治」の形)、門と rewrite と CSP と pageview をその中へ。route 表を literal-first に
4. **写しで確かめる** ── 写しの 3 面の `gates.mjs` を、F6 の射程の行(値の運び)だけを残した薄い ★ に縮め、門は生成物で

**しないこと:**値の運び(F6)、back と registry と面の Route(WGy)、musearch への書き込み、0.11.0 の公開型の既存の欄と構成子、DDL、tag と publish と push。

## WGy との分け方

- **本便の持ち分:**`emit/front.gleam` の `shell_*`(4564 行前後から)と route 表の順、lifecycle hook、門の宣言の module と reader
- **WGy の持ち分:**`emit/front.gleam` の `api_routes` と `app.attached` の読み手、`yumemi_gen.gleam` の `attached_routes`、`model.gleam`、`emit/entry.gleam`、back の emitter
- 区画の外を触りたくなったら止めて鷹野宛に書く

## 失敗例

- 値の運び(ALS・`withOwnLedger` ほか)を生成して F6 と二重にする
- 門を Page ごとに列挙し、前方一致(`/me/*`)と除く Page(`/switch` `/consent`)を宣言で持たない
- literal-first を宣言や wrapper で直す(生成器の route 表の順の不具合)
- `Page` / `Layout` / `Entry` に欄を足す(0.11.0 を壊す)
- 写しを musearch の作業木に向ける、status 表を stub だけで測る

## 検収(真壁さんが自分で回す)

- root `gleam build` 0、`cd gen && gleam test` が基線以上 + 新規、`gleam format --check src test` 0、Article fixture ×2 で diff 0
- **写しで:**生成器 ×2 で diff 空、生成 shell と門が sha256 ヘッダ付き。**Workerd の門の前後の status と `Location` が F5 の 23 行 + 2b-7 / 2b-8 の行で全行一致**(`/muse/:handle/blog` の 404 は F5 の期待値のまま)。www の CSP、pageview の script と条件、`/api-key` と `/for-stores/api/v1`、literal-first の 3 対(`/articles/new` / `/page/widget/new` / `/rosters/new`)が前後一致。3 面の `test/entry-gates.test.mjs` の門の assert が生成物で通る
- 写しの薄い ★ に残った行が F6 の射程(値の運び)だけであることを行で示す
- Workerd の port は www `9184` / muses `9182` / console `9183`(inspector `9632`〜`9634`)、実 API を使うなら PG `55542`(柏木 `55543`)。55496・5552x・55502/55503・55540/55541 を使わない・止めない

## 見積

**推定:最短 2:30 / 中央 3:30 / 最長 6:10。**棚卸し 0:30、宣言と reader 0:45、lifecycle hook と生成 1:15、route の順 0:20、空の検索の確かめ 0:10、写しの Workerd の status 表 0:30。問い 2 で client entry を足すなら + 0:45(中央 4:15)。

**直書きの壁時計:**hw の比(0.09〜0.11)で真壁 0:19〜0:23、2b-8 の比(0.36)で 1:16。**見張りの止め線 2:00。**柏木 0:15、P0 があれば + 0:15。

## 鷹野への問い ── 起動前に裁く

1. **URL の `-` とフォルダの `_`(`/api-key` → `api_key`、`/for-stores/api/v1` → `for_stores/api/v1`)。**(a) 生成器の規則にする ── URL の段の `-` はフォルダの `_` に対応(Gleam の module 名に `-` が使えないため)── **推奨**、(b) 面の門の宣言に rewrite を 1 行ずつ
2. **★ client entry(島の登録と bundle の入口、3 面)と console の ★ `blob_copy*`(Y1e 候補)を本便に入れるか。**(a) client entry は入れる(+ 0:45)、`blob_copy` は名指しの残り ── **推奨**。client entry は生成 shell と同じ面の入口の仕事で、人見の「中途半端にしない」に当たる。`blob_copy` は `roster_photo_put` の live module の生成で、Blob の 2 段の upload の型が要る別の仕事、(b) 両方入れる(+ 1:30 前後)、(c) 両方名指しの残り

## 鷹野の裁定(2026-09-26 02:2x)

版は 0.11.1(patch、役員 人見 09-26)。問いは推奨で採る。
1. **(a)** URL の段の `-` はフォルダの `_` に対応させる規則を生成器に置く
2. **(a)** client entry は本便に入れる(+ 0:45)。`blob_copy*` は名指しの残り
- WGy(yumemi-gen-8)と並走する。`emit/front.gleam` は区画で持ち分を分け、merge は WGy が先。本便は WGy の merge 後に載せ直してから merge
