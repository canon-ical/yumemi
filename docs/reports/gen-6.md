# gen-6 ── 段 E: 面 ▲ 15 file の突合と報告

## 要旨

面 package の読み取りから、front の生成物 13 種を fixture と musearch snapshot へ出した。
fixture は 86 file、musearch は back 604 file を不変のまま面 119 file を出した。
snapshot の手書き ▲ 15 file と同名の生成物を全て `diff` し、意図差・▲ の古さ・生成器の穴へ分類した。
生成器本体と面の source は変更していない。生成器の穴は P1 に積み、直していない。

基点は yumemi `6cbc9dd` → branch `gen-6`、musearch は read-only snapshot `96fb8cc` (`ms-96fb8cc`)。
`~/yumemism_repo/musearch` は読んでいない。`$RUN/ms-96fb8cc` と `$RUN/out-ms10` は入力として固定し、再生成は `$RUN/out-fx11` / `$RUN/out-ms11` へ出した。

## 生成物 13 種の到達表

§308 の `load` は layout + Page loader、写しは `out / service / api` を個別種として数える。`blocks_preview.gleam` は `blocks.html` を動かす内部補助で、13 種とは別に数えない。

| # | 種 | fixture の現物 path | fixture | musearch の現物 / 本数 |
|---:|---|---|---:|---|
| 1 | route | `gen/fixtures/article/public/src/gen/route.gleam` | 出した / 1 | `www/src/gen/route.gleam` / 1 |
| 2 | load | `gen/fixtures/article/public/src/gen/load/layout.gleam`、`src/gen/load/article/arg_slug/page.gleam` | 出した / 2 | `www/src/gen/load/layout.gleam`、`load/muse/arg_handle/page.gleam` / 2 |
| 3 | blocks | `gen/fixtures/article/public/src/gen/blocks.gleam` | 出した / 1 | `www/src/gen/blocks.gleam` / 1 |
| 4 | widgets | `gen/fixtures/article/public/src/gen/widgets.gleam` | 出した / 1 | `www/src/gen/widgets.gleam` / 1 |
| 5 | out | `gen/fixtures/article/public/src/gen/out/*.gleam` | 出した / 6 | `www/src/gen/out/*.gleam` / 98 |
| 6 | service | `gen/fixtures/article/public/src/gen/service.gleam` | 出した / 1 | `www/src/gen/service.gleam` / 1 |
| 7 | api | `gen/fixtures/article/public/src/gen/api.gleam` | 出した / 1 | `www/src/gen/api.gleam` / 1 |
| 8 | live | `gen/fixtures/article/public/src/gen/live/*.gleam` | 出した / 2（補助 `transport_ffi.mjs` 1） | 島無し / 0 |
| 9 | shell | `gen/fixtures/article/public/src/gen/shell.mjs` | 出した / 1 | `www/src/gen/shell.mjs` / 1 |
| 10 | client + bundle | `gen/fixtures/article/public/priv/static/_yumemi/client.mjs` | 出した / 1 | 島無し / 0 |
| 11 | style + SSR style | `gen/fixtures/article/public/priv/static/_yumemi/style.css` | 出した / 1 | `www/priv/static/_yumemi/style.css` / 1 |
| 12 | skeleton | `gen/fixtures/article/public/src/gen/skeleton/*.gleam` | 出した / 6 | `www/src/gen/skeleton/*.gleam` / 11 |
| 13 | Block list | `gen/fixtures/article/public/build/blocks.html` | 出した / 1 | 本便では build していない / 0 |

14 種目の back 静的資料の写し（外部送信 6 件 / API v1 本文）は本便では吐いていない。P4 の ▲ が置かれた後の便へ送る。

## 束 1: 15 file の差分分類

raw の `diff` に出る `^[<>]` の数を併記する。先頭の sha256 header だけの差（各 2 arrow）は §340-2 の仕様差として分類対象から外した。下表の「箇所」は意味単位で、同型の行はまとめている。生出力は `gen/build/gen6-e-diff-<name>.txt` の 15 本。

| ▲ file | raw arrow | 分類対象の箇所 | a / b / c |
|---|---:|---:|---:|
| `route.gleam` | 2 | 0（header のみ） | 0 / 0 / 0 |
| `widgets.gleam` | 2 | 0（header のみ） | 0 / 0 / 0 |
| `load/layout.gleam` | 2 | 0（header のみ） | 0 / 0 / 0 |
| `blocks.gleam` | 12 | 1（5 variant の順序、10 arrow） | 0 / 1 / 0 |
| `service.gleam` | 93 | 1（同型 91 variant の追加） | 0 / 1 / 0 |
| `api.gleam` | 115 | 3（全 route 表の展開、route 意味差 2 群） | 0 / 1 / 2 |
| `load/muse/arg_handle/page.gleam` | 215 | 3（配置生成、Blob 表現、その他の古い手書き） | 1 / 2 / 0 |
| `shell.mjs` | 401 | 3（断点、generic shell、Block preview の欠落） | 1 / 1 / 1 |
| `out/article_list.gleam` | 21 | 1（透明な Held と alias の写し） | 0 / 1 / 0 |
| `out/link_list.gleam` | 30 | 1（同上、format を含む） | 0 / 1 / 0 |
| `out/space_list.gleam` | 19 | 1（同上） | 0 / 1 / 0 |
| `out/muse_heaven_list.gleam` | 11 | 1（alias の写し） | 0 / 1 / 0 |
| `out/subscription_read.gleam` | 11 | 1（alias / record format の写し） | 0 / 1 / 0 |
| `out/muse_read.gleam` | 99 | 2（型写し、decoder の既定値） | 0 / 1 / 1 |
| `out/widget_list.gleam` | 173 | 2（型写し、Row decoder） | 0 / 1 / 1 |

### file ごとの理由

- `route.gleam` / `widgets.gleam` / `load/layout.gleam`: 本文は同じ。sha256 header の有無だけなので分類対象 0。
- `blocks.gleam`: ▲ は `SiteHeader, SiteFooter, ...` の手書き順、生成物は名前順。variant の集合は同じで、名前付き構成子の順序は意味を変えない。b、5 variant の並び替えを 1 箇所にまとめた。
- `service.gleam`: ▲ は front の既存 7 Service だけ、生成物は `src/service/*.gleam` の全 98 Service。Page / Component / API の閉じた enum を source から再生成する形が正しく、▲ の古い絞り込みが消える。b、追加 91 variant を同型 1 箇所にまとめた。
- `api.gleam`: b は `www` の `services: All` から全 route 表と `Post` を出す generic 形で、▲ の GET 7 本だけより生成物が正しい。c は snapshot の `api/src/gen/registry.mjs` と照合すると、生成 87 route に method/path 不一致 48 件、registry の未出力 12 件がある。例は `muse_heaven_list` の `/muse_heaven` 対 `/heaven`、`heaven_unlink` の `POST .../unlink` 対 `DELETE .../:id`、`article_search` の `/articles/search` 対 `/search`。これは back の route source の問題を含むため P1、直さない。
- `load/muse/arg_handle/page.gleam`: b は `Data` の Service/Widget 名、Page/Layout の placement、型写し独立化、package default title を source から出す generic 化。a は `Frame` に断点値が無いため ▲ が `media.url` と `url("…")` を手書きし、生成物が `Blob` の `to_string` をそのまま CSS value にする差。51 の口に `media.url` が無いので生成物側を正とした。
- `shell.mjs`: a は ▲ の `@media 900px` / 固定 grid に対し、生成物が `css.Breakpoint` の SP / Tablet / PC の在否から CSS を組む差。b は Page table、source decoder、元 Request の APP forwarding、`SVELTE` fallback、`/_blocks` route を generic に出す差。c は `blocks_preview.gleam` の header/nav/footer が Layout の Block を置かず literal area text になる欠落で、P1 に残す。
- `out/article_list.gleam` / `out/link_list.gleam` / `out/space_list.gleam` / `out/muse_heaven_list.gleam` / `out/subscription_read.gleam`: ▲ の back import と旧 alias formatting をやめ、面 package が単独で使える透明な型写しにする差。再輸出禁止に沿うので b。
- `out/muse_read.gleam`: alias の再配置、`Phase`/`PageTheme` の写し、dynamic decoder の追加は b。Blob 2 本と Time 1 本が `parse("placeholder")` / `time("00:00")` を assert するため、invalid input で panic し得る既知 P1 を c とした。
- `out/widget_list.gleam`: alias、Held、全 Row 宣言の型写しは b。decoder は `Row` の先頭 `Text` だけを `decode.success` し、`Image / Articles / HeavenDiary / HeavenReview / Links` の分岐も `articles / links / heaven_public` の読みもない。実際の Row を Text として描くため c、同じ placeholder Blob の既知 P1 もこの file に含む。

`www/src/media.gleam` は生成しない（★、`gen/` の外）。15 file の突合対象から外した。

## front-1 / Y1c の未検証 5 件

- Page / Layout の配置表からの描画: `verify-front-ssr.mjs` の NO-JS / INITIAL / SELECTED が生成 loader と Page placement を通り、ALL PASS。
- 島の再訪問時の古い Model: 同じ URL の document request が初回 + 1 回だけで止まる `SSR RELOAD: PASS`。`verify-front-isolate.mjs` も 40 request、style の混入 0。
- 1 Block に島が複数: fixture の 1 Block に `like-button` と `pick-tag` があり、SSR 検査で両方を登録・操作し browser error 0、`13` と選択 POST を確認。
- 断点ごとの非表示: `front_emit_grid_css_has_breakpoint_pin_and_hidden_area_rules_test` が `@media 1024px`、`display: none`、sticky、area を確認し、fixture build も通った。これは生成 CSS 契約の検証で、実 viewport の visual QA まではしていない。
- WebSocket の push が `reloads` に無い: 本便でも閉じない。push は scope 外で、`reloads` は Page 再要求だけを扱う。

## P1

1. **E-1 route source の不一致** ── `www/src/gen/api.gleam` は snapshot registry と 48 route の method/path が違い、12 registry record を出さない。`gen/build/gen6-e-api-registry-compare.txt` に全行を残した。back route の裁定・修正後に `api.gleam` を再生成する。
2. **E-2 Row decoder の先頭 variant 固定** ── `out/widget_list.gleam` の decoder が `Text` だけを構築し、他 5 variant と variant 固有欄を失う。`custom_decoder` が fields 付き複数 variant の先頭だけを選ぶ問題として次便で直す。
3. **E-3 Block preview の Layout 欠落** ── `build/blocks.html` の header/nav/footer が Layout の Block を置かず literal area になる。page 区画へ全 Block を縦に置く部分は通過済み。
4. **E-4 opaque decoder の placeholder assert** ── `out/muse_read.gleam` と `out/widget_list.gleam` の計 4 箇所。`decode.failure` の既定値のために invalid Blob/Time を assert しており、primitive decoder の形へ直す余地がある。
5. **E-5 面 package の direct dependency** ── musearch の `www/gleam.toml` に `sketch` / `sketch_lustre` の直接依存がなく、生成 page の build が notice を出す。本便の snapshot face build では 56〜57 notice、source/生成器は変更しない。

## 基線と検証

| 検査 | 実測 |
|---|---|
| root `gleam build` | exit 0。既存 `src/framework/secret.gleam` の unused private constructor warning 1 件 |
| `cd gen && gleam test` | **128 passed, no failures** |
| fixture generator / diff | exit 0 / **86 file**、`diff -rq out-fx10 out-fx11` は空 |
| fixture face build | exit 0、`error` 0、`warning` 0 |
| musearch snapshot generator | **exit 4**、warning **30**、exit3 **0**、exit4 **18**、back **604**、面 **119** |
| musearch repeat diff | `diff -rq out-ms10 out-ms11` は空。back 本文 diff **0** |
| front SSR | **ALL PASS** |
| front isolate | **ALL PASS**、40 request、first/second style **2228/2228** |
| Block preview | **BLOCKS: PASS (6 blocks)** |
| sha256 header | fixture 86 + musearch 722 = **808 file**、欠け **0** |

証跡は `gen/build/gen6-e-*.txt`、15 本の raw diff、`gen/build/gen6-e-api-registry-compare.txt`、`gen/build/gen6-e-header-check.txt` に置いた。`git diff --stat 6cbc9dd..HEAD -- db/ gen/fixtures/article/db/` は空だった。live `~/yumemism_repo/musearch` の status は、snapshot 以外を読まない束0の制約により未実行。
