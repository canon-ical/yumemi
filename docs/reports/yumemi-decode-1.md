# yumemi-decode-1

branch impl/yumemi-decode-1、base e9dca4b。root package version 0.9.1。証跡は gen/build/yd1-*(gitignore、作業木に残す)。

## DDL

無し。schema / migration は変更していない(`git diff --stat e9dca4b -- db/ gen/fixtures/article/db/` 空)。実 API の検証で PG 55496 に一時 DB を clone し、終了時に drop した(実 API 節)。

## 鷹野宛

- **実 API の未達 3 Page は decoder の外。**www の space / roster / schedule の 400 は、API が Args の検証で弾いた応答(下の表)。本便の生成 decoder には届く前に止まっている。Args を harness 側で補うと 3 Page とも 200 になり、生成 decoder が実 API の応答を読めることも確かめた。直していない。F5 への申し送りに原因ごとに書いた。
- **fixture public の cold build が lock の不整合で止まる。**root `gleam.toml` を 0.9.1 にしたが、`gen/fixtures/article/public/manifest.toml:20` は yumemi 0.9.0 の lock のまま。そのため木を写しての cold build は `yumemi is specified with the requirement == 0.9.1, but it is locked to 0.9.0` で exit 1 になる(gen/build/yd1-r8-fixture-public-cold.txt)。既存の木の warm build は exit 0。`gen/manifest.toml` は 0.9.1 に上げた。v0.9.0 の release(4f43a9f)では両方の manifest を上げていたが、贄川さんの指示書で fixture の public の manifest は「書いてはいけない所」なので触っていない。直すなら lock の 1 行。
- D1: `missing_row_enum_tag` は `discriminator_field` が返す欄の名前を使い、`tagged_variant_tag` と同じ `discriminator_enum` で型を判定する。`enum_aliases` 内の union で enum に同名の構成子が無いものは `stop.Conflict`(exit 4)で止め、unit path・宣言型・構成子を名指しする。欄名を `tag` にした不足構成子の test を 1 本足した。`row_enum_aliases` の条件は変えていない。
- P1-1(据え置き): musearch の api は Hex yumemi 0.7.0 に固定されている(`api/manifest.toml`、`>= 0.7.0 and < 0.8.0`)。往復 test は repo の 0.9.x の framework で値を作るので、framework が動くと test は緑のまま実 API が割れる。今は往復が使う型の形は同じ。本便では手を入れていない。
- P1-2(据え置き): `tagged_variant_decoder` は位置の欄を `"value"` で読むが(`gen/src/yumemi_gen/emit/front.gleam:6149-6151`)、encode は `"0"` を出す。今は面が compile しない潜在の穴で、本便の範囲外。直していない。
- 守りの木: F5 `c27f75d` status 0 行。musearch と yumemi main は本便の間に他の人の docs commit で進んだ(musearch 728adfa → 40d38c5 は庵野と鷹野、yumemi main e9dca4b → 6581524 は水無瀬と鷹野、どちらも status 0 行)。本便からは書いていない。

## 追随便への申し送り

### F5

F5 c27f75d を `git archive` で gen/build/yd1-snapshot に写した(`test ! -e gen/build/yd1-snapshot/.git` PASS)。

- 本便と v0.9.0 の生成器で各 2 回生成した。各出力 1377 files(`_diagnostics.txt` 込み)の SHA256 集合は 2 回とも一致し、4 実行とも exit 4。停止報告は新旧で全行一致(SHA256 e6977d05…5631e)。
- 2 つの生成器の差は 30 files(www 9 / muses 19 / console 2)。差分行は関係の decoder 414、`kind` の分岐 24、その他 0 で、型宣言の差は 0。gen/build/yd1-snapshot-diff.txt。
- **再生成で変わる file:**本便の生成器の出力と F5 c27f75d の tracked の比較は gen/build/yd1-f5-regen-files.txt(606 paths: MODIFY 298 / ADD 308)。
- 本便の生成物の 30 files で `decode.field("value"` は 0 件。www / muses の `widget_list` の kind は 6 種とも snake_case。
- **生成物に戻せる例外:**muses `widget_list` の ▲ 例外(F5 r28)。生成物に戻して 3 面の `gleam build` が exit 0(gen/build/yd1-snapshot-build-<面>.txt)。

### 実 API の Page

道具は F5 の a6(api worker / Neon PG bridge / fixtures / pages)を snapshot 側で使った。DB は `musearchyd1api` / `musearchyd1idp` で、`musearchyumemi5` / `idpyumemi5` から `createdb -T` で clone した。port は bridge 8890、api 8891、muses 8892、www 8894。

| 面 | path | v0.9.0 | 本便 | 本便 + Args 補(実験) | データ |
|---|---|---:|---:|---:|---|
| www | /muse/:handle/article | 500 | 200 | 200 | 2 articles |
| www | /muse/:handle/article/:id | 500 | 200 | 200 | 1 article |
| www | /muse/:handle/space/:id | 500 | 400 | 200 | 1 space, 1 widget |
| www | /store/:handle/cast/:id | 400 | 400 | 200 | 1 roster, 1 schedule |
| www | /muse/:handle/schedule | 400 | 400 | 200 | 2 schedules |
| www | /muse/:handle | 500 | 200 | 200 | 1 muse, 2 widgets |
| muses | /page | 500 | 200 | 200 | 1 muse, 2 widgets |
| muses | /page/widget/:id | 500 | 200 | 200 | 1 widget |

v0.9.0 の列は前の巡の実測(gen/build/yd1-snapshot/build/yd1-real-api-v090.tsv)。本便の列は r8 で取り直した(gen/build/yd1-r8/pages-current.tsv、非 200 の body は pages-current-bodies.txt)。

**未達 3 Page の切り分け(API worker の応答ログ gen/build/yd1-r8/api-requests.txt、Page の body はどれも `widget read failed` / `root read failed`):**

| Page | Page が送った要求 | API の応答 | 原因 | 在処 |
|---|---|---|---|---|
| space | `GET /api/muse/{h}/widgets?widget=space_main` | 400 `{"code":"invalid_argument","field":"widget"}` | ★ Page が枠名 `space_main` を名乗るが、api の `WidgetKey` は `MuseTopMain` だけ。置き場 `InSpace(space id)` も送っていない | ★ `www/src/pages/muse/arg_handle/space/arg_id/page.gleam:36` と api `src/widget_key.gleam` |
| roster | `GET /api/rosters/{id}` | 400 `{"code":"invalid_argument","field":"handle"}` | `roster_read.Args` は handle と id が要るが、route `/api/rosters/:id` の穴は id だけで、Page の `:handle` が届かない | 面 → api の Args の encode(生成の route 表 `www/src/gen/api.gleam:272`) |
| schedule | `GET /api/muse/{h}/schedule` | 400 `{"code":"invalid_argument","field":"from"}` | `schedule_list.Args` の `from` は必須だが、Page に値の出所が無い | Args の値の出所(Y1f の reads / vars の射程) |
| roster(2 本目) | (roster_read が先に落ちるので未送信) | 直呼びで `from` 無しは 400 `field: from` | `store_schedule_list` は from/to か days が要る | schedule と同じ |

**decoder が原因でないことの確かめ:**API worker の harness(gen/build/yd1-r8/yd1-api-worker-argfix.mjs)で、上の 4 要求にだけ Args を足した(`space=<id>`、`handle=<store>`、`from=2026-09-25&to=2026-10-01`、`from=2026-09-25`)。生成物と Page は変えていない。これで 8 Page とも 200 になった(pages-current-argfix.tsv、api-argfix-requests.txt)。描いた HTML に widget の本文「置き場…」、roster 名「ID競合」、出勤の日付が出ている(argfix-content.txt)。API を直接呼ぶと、Args 付きは 200、Page と同じ形は 400(direct-api.tsv)。

**後片付け:**起こした process は pid を指定して止めた。bridge 2157837、api の wrangler 2157836(logged)と 2160317(argfix)、www の wrangler 2158026、muses の wrangler 2158794(gen/build/yd1-r8/pids.txt)。停止後、snapshot の workerd / esbuild の残りは 0、8890–8894 の listener も 0。一時 DB 2 つは `dropdb` した。55496 に残る DB は idpsvelteout1b / idpyumemi5 / musearchsvelteout1b / musearchyumemi5 / postgres / template0 / template1 だけ。fixture の cookie JSON(`build/yumemi-5-a6-fixtures.json`)は消した。ログに cookie は入っていない(grep で 0)。

### Y1f

本便を main に取り込んだ後、`node gen/scripts/verify-decode-roundtrip.mjs` を再実行する。schedule の `from` の出所は Y1f の射程(上の表)。

## 基線と最終値

| 指標 | 基線 | 本便 |
|---|---:|---:|
| root gleam build | 0 / warning 1 | 0 / warning 1 |
| gen test | 181 | 185 passed / 0 failures |
| 往復 verify-decode-roundtrip | — | 本便 29 PASS / 0 FAIL、v0.9.0 24 PASS / 5 FAIL(想定: Has, Held, Multi, enum kind Articles / HeavenDiary) |
| encode の写し vs codec.mjs | — | tag / encode の本文、空白を除いた diff 0(MATCH) |
| fixture 生成 | 92 files | 92 files、2 回 byte 一致、tracked 31 と byte 差 0 |
| root manifest packages | 10 | 10 |
| src/framework の diff | — | 0 行 |

fixture public の `sketch` の Transitive warning 2 件は基線 e9dca4b から在る(本便の悪化ではない、gen/build/yd1-base-fixture-public-build.txt)。

## 確かめたこと

- r8 で打ち直した: root `gleam build` exit 0 / warning 1(yd1-r8-root-build.txt)、`cd gen && gleam test` 185 passed / no failures(yd1-r8-gen-test.txt)、往復は本便 29/0、v0.9.0 24/5 の想定どおりの赤(yd1-r8-roundtrip.txt)、encode の写し MATCH(yd1-r8-encode-copy.txt、snapshot の codec.mjs と比較)。
- fixture を木の外に 2 回生成して、92 files の SHA256 が一致。tracked の 31 と byte 差 0、生成後も `git status --short` はこの記録以外 0 行(yd1-r8-fixture-compare.txt)。
- 実 API の 8 Page(本便 / Args を補った実験)と、400 の body と API のログ(gen/build/yd1-r8/)。
- 守り: F5 c27f75d status 0、src/framework diff 0、DDL の diff 空、gleam.toml 0.9.1、package 10(yd1-r8-guards.txt)。
- snapshot の 2 生成器の比較と 3 面 build は前の巡の証跡(yd1-snapshot-*)。本便の生成器の本体は 82fcd3a から変えていない。

## 確かめていないこと

- www の space / roster / schedule が生成物のまま(Args を補わずに)200 になること。原因は decoder の外で、直していない。
- fixture public の cold build。lock の不整合で compile の前に止まる(鷹野宛)。
- v0.9.0 の生成物での実 API は r8 で打ち直していない(前の巡の実測を使った)。
