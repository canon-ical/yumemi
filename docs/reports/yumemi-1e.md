# yumemi-1e 結果

## DDL

無し。`git diff --stat 8875df6 -- db/ gen/fixtures/article/db/` は空(基点)。fresh fixture は各92 files、`db/queries` は32 files、2回生成の差分は空。tracked `public/src/gen` と `_yumemi` (client を含む) は fresh 出力と一致。証跡: `gen/build/y1e-n-ddl-diff.txt`、`gen/build/y1e-n-fixture-{a,b}.txt`、`gen/build/y1e-n-fixture-diff.txt`、`gen/build/y1e-n-fixture-tracked-public-{gen,assets}-diff.txt`。

## 鷹野宛

- `impl/yumemi-1e-bp` を `impl/yumemi-1e` に merge。競合3件を解消し、merge commit は `763c7f6`。生成 Live の型は束 A の `Service.Error` と `Failure { Refused(Error) | Broke(String) }` を採った。Blob upload の失敗は `Broke("file upload failed")` となり、Service request より前に止まる。
- API Markdown は fixture を `8875df6` の内容へ戻し、生成 helper と `gleam/list` import は実際に使う heading / paragraph / code / table / list に合わせる。未対応構文の停止試験は維持。
- PageTheme は `Out` がその型を持つ service module から参照する。Block `In` の必須 `Out` field をページ source に加え、`muse_header.In(page: muse_read, subscription: None)` を生成する。`Option(Out)` は source が無いとき `None` を構築する。
- F5 の www 生成 load に残る型 error は route parameter `arg_code` / `arg_id` の2件だけ。`claim_head.String` と `space_title.FreeSpace` は値の出所として扱い、snapshot の既存生成例を `### 値の出所の穴` に追加した。
- generated live の `gleam_json` / `lustre` transitive warning は、F5 面 manifest の直接依存を補った同じ probe で3面とも0。`sketch_lustre` の face-source warning は gen-6 P1-4 の追随事項に残す。
- `musearch` は書いていない。開始 snapshot は `a109b47`、終了時 `git status --short` は空、HEAD は `8eed4d8`。
- root `gleam.toml` と `gen/manifest.toml`、fixture manifest の `yumemi` lock はすべて 0.9.0。

検証:

- root `gleam build`: exit 0、warning 1件 (`src/framework/secret.gleam:5`)。`gen/build/y1e-n-root-build.txt`
- `cd gen && gleam test`: **178 passed, no failures**。`gen/build/y1e-n-generator-test-tag.txt`
- fixture 生成を2回: 各 exit 0 / 92 files、fresh 同士 diff 0行。tracked `public/src/gen` / `_yumemi` と fresh 出力の差分は各0行。`db/queries` は32 files。
- `gleam format --check`: fixture 56 `.gleam`、snapshot 951 `.gleam` とも exit 0。`gen/build/y1e-n-format-{fixture,snapshot}.txt`
- `verify-front-ssr`, `-isolate`, `-given`, `-file`, `-overlay`: ALL PASS。初回に SSR/isolate を並列実行したときは Wrangler の port bind が衝突し、順番に再実行して両方 ALL PASS。Block preview は `BLOCKS: PASS (6 blocks)`。各 `gen/build/y1e-n-verify-front-*.txt`、`gen/build/y1e-n-build-blocks.txt`
- snapshot `a109b47` を2回生成: 各 exit 4 / 1347 files / exit 1=3 / exit 2=0 / exit 3=1 / exit 4=20 / warnings=43。生成先 diff は0行。`gen/build/y1e-n-snapshot-final{5,6}.txt`、`gen/build/y1e-n-snapshot-final56-diff.txt`
- snapshot runtime の全診断は www=4、muses=9、console=18。Hex 0.7.0 の `framework/front.Target` 不在と、Page load の値不足に分け、F5 の face-side と `値の出所` の表に転記した。summary の3行はすべて `[exit 1 値の出所]`。

## 追随便への申し送り

### F5 の ★ 手書き例外3本

| 元ファイル | Page / Block | Y1e 側の形 | 置き換わる手作業 |
|---|---|---|---|
| `muses/src/components/blob_copy.gleam` と旧 FFI | `/settings` / `Settings` | `muse_edit_profile` Service の Blob 欄 | `document` からの属性書き込みと島間イベント。Blob 欄の Service に畳む |
| `muses/src/components/article_blob_copy.gleam` と旧 FFI | `/articles/new`, `/articles/:id` / `ArticleForm` | `Target.Entry(api.BlobCopy)` | File 保持・upload FFI。Entry が key を返して島内に表示 |
| `console/src/blob_copy.gleam` と旧 FFI | `/rosters/:id` / `RosterEditor` | `roster_photo_put` Service の Blob 欄 | BlobCopy POST と Photo PUT の二段 FFI。runtime upload 後に Service を1回呼ぶ |

### F5 面側の最小修正

| 面のファイル:行 | 現在の不一致 | F5 での修正 |
|---|---|---|
| `www/gleam.toml:6`, `muses/gleam.toml:6`, `console/gleam.toml:6` | yumemi が `>= 0.7.0 and < 0.8.0` | `>= 0.9.0 and < 0.10.0` へ更新 |
| `www/src/gen/api.gleam:42`, `muses/src/gen/api.gleam:40`, `console/src/gen/api.gleam:40` | snapshot の Hex yumemi 0.7.0 に `framework/front.Target` が無い | 上記の版上げ |
| `www/src/components/adult_declare.gleam:12`, `consent_give.gleam:16`, `fan_onboard.gleam:16`; `muses/src/components/adult_declare.gleam:15`, `onboard_wizard.gleam:39` | `api.Entry` は生成 `api` module に無い | `framework/front as front` を import し `front.Entry(...)` にする |
| `www/src/layout.gleam:8:56`, `muses/src/layout.gleam:8:58`, `console/src/layout.gleam:8:60` | `Layout` に `reads` が必要 | 各 `Layout(...)` に実際の reads を渡す。空なら `reads: []` |
| `www/src/blocks/store_schedule.gleam:41` | `store_schedule_list.Out` に `grid: Option(Grid)` が加わった | `grid: _` を受けるか表示に使う |

### generated live の直接依存

F5 copy の `gleam.toml` に次を直接依存として置く。これで generated `gen/live` の `gleam_json` / `lustre` に対する `Transitive dependency imported` は3面とも0になった。`sketch_lustre` の face-source 警告は gen-6 P1-4 の追随事項として残す。

| 面 | 追加する直接依存 |
|---|---|
| www | `gleam_json = ">= 3.0.0 and < 4.0.0"`; `lustre = ">= 5.7.1 and < 6.0.0"` |
| muses | `lustre = ">= 5.7.1 and < 6.0.0"` (`gleam_json` は既に直接依存) |
| console | `lustre = ">= 5.7.1 and < 6.0.0"` (`gleam_json` は既に直接依存) |

### snapshot exit 1 の読み替え

| 面 | raw exit 1 summary の行 | 札と `▲` の既存生成例 |
|---|---|---|
| www | `space_title.view(it.space_list)` (F5 output `space/arg_id/page.gleam:204`) | 値の出所: route `arg_id`; ▲ `www/src/gen/load/muse/arg_handle/space/arg_id/page.gleam:145` は `space_list.FreeSpace` を渡す |
| muses | `settings.view(Nil)` (F5 output `settings/page.gleam:130`) | 値の出所: `subjects`, `consents`; ▲ の値不足行は下表 |
| console | `session_switch.view(Nil)` (F5 output `switch/page.gleam:110`) | 値の出所: `has_store`, `idp_origin`; ▲ の値不足行は下表 |

final5 では raw summary の3行をすべて `[exit 1 値の出所]` と出す。全 runtime diagnostic にある face-side は Hex 0.7.0 の `framework/front.Target` 不在 (Y1e output `www/src/gen/api.gleam:42`, `muses/src/gen/api.gleam:40`, `console/src/gen/api.gleam:40`) と www `src/blocks/store_schedule.gleam:41` の `grid` field 不足。残りは route / config / session / variant / period の値の出所で、下表に `▲` の file:line を付けた。生成器不足の行は残らない。

各 `gleam build` は face-side と値の出所の不足で exit 1 のまま。F5 copy は www `0 生成器不足 / 2 値の出所 / 5 ★`、muses `0 / 8 / 3`、console `0 / 17 / 1`。warnings は www `246 generated / 47 ★ / 15 dependency・framework`、muses `93 / 58 / 15`、console `75 / 34 / 15`。前回値 (errors `24 / 14 / 18`, warnings `415 / 452 / 250`) より muses / console は悪化していない。証跡: `gen/build/y1e-n-f5-final5-{www,muses,console}.txt`、準備 `gen/build/y1e-n-f5-prepare-final.txt`、集計 `gen/build/y1e-n-final-counts.txt`。

### 値の出所の穴 (yumemi-1f と F5 の起点)

snapshot にある Block `In` と、生成 load が現在渡している式の対応。F5 はこれらを手書き例外として保持し、出所の語彙は Y1f で裁く。

| 出所 | Page の元ファイル | ▲ の行と現在の式 |
|---|---|---|
| route parameter | `console/src/pages/rosters/arg_id/page.gleam` | `console/src/gen/load/rosters/arg_id/page.gleam:115` — `roster_editor.view(Nil)` (`id`から row を選び `www_origin` も要る) |
| route parameter | `console/src/pages/rosters/arg_id/remove/page.gleam` | `console/src/gen/load/rosters/arg_id/remove/page.gleam:115` — `roster_remove_confirm.view(Nil)` (`id`) |
| route parameter | `console/src/pages/rosters/arg_id/photos/arg_order/remove/page.gleam` | `console/src/gen/load/rosters/arg_id/photos/arg_order/remove/page.gleam:115` — `roster_photo_remove_confirm.view(Nil)` (`id`, `order`) |
| config origin (`console_header.idp_origin`) | `console/src/pages/api_key/page.gleam` | `console/src/gen/load/api_key/page.gleam:106` — `console_header.view(Nil)` |
| config origin (`console_header.idp_origin`) | `console/src/pages/consent/page.gleam` | `console/src/gen/load/consent/page.gleam:106` — `console_header.view(Nil)` |
| config origin (`console_header.idp_origin`) | `console/src/pages/metrics/page.gleam` | `console/src/gen/load/metrics/page.gleam:107` — `console_header.view(Nil)` |
| config origin (`console_header.idp_origin`) | `console/src/pages/page.gleam` | `console/src/gen/load/page.gleam:107` — `console_header.view(Nil)` |
| config origin (`console_header.idp_origin`) | `console/src/pages/rosters/arg_id/page.gleam` | `console/src/gen/load/rosters/arg_id/page.gleam:111` — `console_header.view(Nil)` |
| config origin (`console_header.idp_origin`) | `console/src/pages/rosters/arg_id/photos/arg_order/remove/page.gleam` | `console/src/gen/load/rosters/arg_id/photos/arg_order/remove/page.gleam:111` — `console_header.view(Nil)` |
| config origin (`console_header.idp_origin`) | `console/src/pages/rosters/arg_id/remove/page.gleam` | `console/src/gen/load/rosters/arg_id/remove/page.gleam:111` — `console_header.view(Nil)` |
| config origin (`console_header.idp_origin`) | `console/src/pages/rosters/new/page.gleam` | `console/src/gen/load/rosters/new/page.gleam:106` — `console_header.view(Nil)` |
| config origin (`console_header.idp_origin`) | `console/src/pages/rosters/page.gleam` | `console/src/gen/load/rosters/page.gleam:107` — `console_header.view(Nil)` |
| config origin (`console_header.idp_origin`) | `console/src/pages/schedule/page.gleam` | `console/src/gen/load/schedule/page.gleam:107` — `console_header.view(Nil)` |
| config origin (`console_header.idp_origin`) | `console/src/pages/switch/page.gleam` | `console/src/gen/load/switch/page.gleam:106` — `console_header.view(Nil)` |
| config origin | `console/src/pages/api_key/page.gleam` | `console/src/gen/load/api_key/page.gleam:110` — `api_key_page.view(Nil)` (`www_origin`) |
| config origin | `console/src/pages/consent/page.gleam` | `console/src/gen/load/consent/page.gleam:110` — `consent_page.view(Nil)` (`idp_origin`) |
| session value | `console/src/pages/switch/page.gleam` | `console/src/gen/load/switch/page.gleam:110` — `session_switch.view(Nil)` (`has_store`, `idp_origin`) |
| route parameter | `muses/src/pages/articles/arg_id/page.gleam` | `muses/src/gen/load/articles/arg_id/page.gleam:115` — `article_form.view(Nil)` (`Edit(article, phase)`) |
| route parameter / variant | `muses/src/pages/page/widget/arg_id/page.gleam` | `muses/src/gen/load/page/widget/arg_id/page.gleam:128` — `widget_form.view(Nil)` (`Mode.Edit`, widget id) |
| variant selection | `muses/src/pages/articles/new/page.gleam` | `muses/src/gen/load/articles/new/page.gleam:110` — `article_form.view(Nil)`; ★ は `article_form.New` を渡す |
| variant selection | `muses/src/pages/page/widget/new/page.gleam` | `muses/src/gen/load/page/widget/new/page.gleam:128` — `widget_form.view(Nil)` (`Mode.New`) |
| variant selection | `muses/src/pages/page/page.gleam` | `muses/src/gen/load/page/page.gleam:141`, `:149` — `space_selector.view(Nil)`, `block_widget_list.view(Nil)` (`selected`) |
| session value | `muses/src/pages/settings/page.gleam` | `muses/src/gen/load/settings/page.gleam:130` — `settings.view(Nil)` (`subjects`, `consents`) |
| period value | `muses/src/pages/metrics/page.gleam` | `muses/src/gen/load/metrics/page.gleam:111` — `metrics_dashboard.view(Nil)` (`from`, `to`) |
| route parameter | `www/src/pages/claim/arg_code/page.gleam` | ▲ `www/src/gen/load/claim/arg_code/page.gleam:66` — `claim_head.view(code)`; Y1e F5 output still passes `Nil` at `:125`, but `claim_head.In` is `String` |
| route parameter | `www/src/pages/muse/arg_handle/space/arg_id/page.gleam` | ▲ `www/src/gen/load/muse/arg_handle/space/arg_id/page.gleam:145` — `space_title_block.view(space)` receives `space_list.FreeSpace`; Y1e F5 output passes `space_list.Out` at final `:204` (pre-fix probe `:210`), so `arg_id` must select the row |

Console の snapshot は load Page が11本あり、共通 `console_header` の `idp_origin` が全11本で欠ける。BRIEF の「約9」より実ファイルでは2本多いため、上表に11本すべて載せた。

Block `In` の必須 `Out` field からは service source を生成し、`home` は `home.In(...)` を渡す。値の出所が必要な残件は上表に記載した。

Y1f には役員 人見 09-24 16:52 の裁定(A 案:Page が取りに行く Service は並んだ Block の In の型から生成器が導き、Page.reads は根治後に消す)も同居させる ── 同じ『Page と Block の間の読みの語彙』の問いである。

### G7 の P1

| 項目 | 状態 / 行き先 |
|---|---|
| G2-2 grid 欄を名前付き const から読む | F5 は field 値を literal で保持 |
| G2-3 default cols の2箇所差 | 留。F5 の見た目を変えず、本便は触らない |
| G2-4 `--bg-image` を media URL にする | 閉。生成値は `media.url(value, media.W1600)` と同形 |
| G2-5 Markdown 原文1本出力 | 閉。heading/table/inline-code/code/list を element として出し、未対応構文は停止。helper は使用分のみ |
| G2-6 付属入口表の源 | 留。`api/src/gen/http_runtime.mjs` は GENERATED source。back 生成世代を揃える便で扱う |
| G2-7 app dir 末尾 `/` | 留。CLI convenience。F5 の検収外 |
| G2-8 temporary package が manifest を消す | 閉。input manifest を写した probe、再生成 diff 空 |
| G2-9 `At` が一覧 Block で重なる | 留。Y1e 射程外 |
| P1-G1-1 Page/Layout/Frame/Fixed の新しい fields | 生成器側は対応。F5 は `reads`, `cell`, `cols`, `rows`, `template` を各面に明示 |
| P1-G1-2 14種目の付属入口表の source が生成物 | 留。back runtime source の世代揃えへ |
| P1-G1-3 add/edit/remove の URL 23本 | 閉 (add 9 / edit 7 / remove 6、gen-7 束 E) |
| P1-E-1 route registry の service 数87固定 | 留。snapshot の103と合わず、registry audit 便で直す |
| gen-6 P1-4 direct deps / `sketch_lustre` | 留。F5 face manifest の direct dependency |
| gen-6 P1-6 minify | 留。F5/client 次便 |
| gen-6 P1-9 `framework/page` 3 imports | 留。F5 handoff |
| gen-6 P1-11 named query の P enum | 留。query 列の次便 |
| gen-6 P1-13 per-element given | 留。Lustre の対応待ち |
| transport sha256 の一度だけの変化 | 同一 input 2回は byte 一致。B′ reader model の serialization が変わった際の一度の変化は履歴上の説明として残す |
| decoder exit 1 (`metrics_muse`, `metrics_store`) | 閉。`visit.Source` variant decoder。snapshot exit 1 の baseline 5 から該当2件を除いた |
| route/config/session/variant/period の値 | 留。Y1f と F5 に hand-coded exception として渡す |

未分類: **0**。

## 51 v5 に足す文

`Pin.Overlay` は popover top layer の `<div popover>` / `::backdrop`。overlay area は `resolved_template` に渡す Frame から生成器が除くため grid template に現れず、`z-index` / `position` は ★ に出ない。`el.opener` / `el.closer` は `popovertarget` / `popovertargetaction` を生成し、JS・島 state を使わない。`el.badge(count: Option(Int), child)` は None / 0 をCSSで隠し、正数だけ表示する。`el.each_modal(scope, row_key, ...)` の `row_key` は Out の安定した key を渡し、id に不適合な字はescapeしない。

File input は Service の `Blob` / `Option(Blob)` field ごとに `<field>_file_input()` を生成する。選択 File はruntime内で札(String)にし、`Send` 時に `/api/blobs` へ上げて返った key を Blob field に入れてからServiceを呼ぶ。上げ失敗は `Failure.Broke`、Service は呼ばない。`Target.Entry(api.BlobCopy)` は直接Entryとして同じruntimeを使う。shell `<head>` には `width=device-width, initial-scale=1, viewport-fit=cover` を固定で出す。「書けないもの」の重なりで残るのはドロワー / tooltip / 浮くボタン。

## 基線と最終値

| 指標 | 基線 | 最終値 |
|---|---:|---:|
| `cd gen && gleam test` | 159 | 178 passed |
| fixture generated files | 88 | 92 |
| snapshot exit 1 summary | 5 (decoder 2 + face 3) | 3 (console / muses / www; all three tagged `値の出所`) |
| snapshot exit 2 | 0 | 0 |
| snapshot exit 3 | 1 | 1 |
| snapshot exit 4 | 20 | 20 (exit4 line diff 0) |
| snapshot warnings (`exit 0 警告`) | 43 | 43 |
| snapshot generated files | 1340 | 1347 |

snapshot raw run log は face ごとの exit 1 summary を3行出す。基線 exit1=5 はその3 face errorsに decoder errors 2件を加えた数で、decoder errors 2件は解消済み。final5 の full runtime diagnostics は www 4 / muses 9 / console 18 errors で、Hex 0.7.0 の面側と上表の値の出所に全行を分類した。

F5 face build の診断内訳 (各 `gleam build` は face-side と値の出所の不足で exit 1):

| 面 | errors: 生成器不足 / 値の出所 / ★ (合計) | warnings: generated / ★ / dependency・framework (合計) |
|---|---:|---:|
| www | 0 / 2 / 5 (7) | 246 / 47 / 15 (308) |
| muses | 0 / 8 / 3 (11) | 93 / 58 / 15 (166) |
| console | 0 / 17 / 1 (18) | 75 / 34 / 15 (124) |

F5 写しの generated `gen/live` では `gleam_json` / `lustre` の `Transitive dependency imported` が各面0。`Unused imported*` も3面とも0。警告15件は依存・framework 側で同数。証跡の一覧は `gen/build/y1e-n-final-counts.txt`。

確かめたこと: root build exit 0 / warning 1、gen test 178 passed、fixture 2回92 files / diff 0、SSR / isolate / given / file / overlay / block preview ALL PASS、format check 56 + 951 files、snapshot 2回 exit 4 / 1347 files / diff 0、F5 3面の errors / warnings は上表のとおり。

確かめていないこと: F5 consumer manifest への直接依存追加は probe copy のみ。`musearch` への適用、Hex publish、staging / production build は未実施。
