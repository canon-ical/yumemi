# yumemi-1e 巡 5 結果

## DDL

無し。`git diff --stat 046cf9c -- db/ gen/fixtures/article/db/` は空。fresh fixture の generated `db/` は32 files、fresh1/fresh2 の差分は空。tracked face `public/src/gen` と `_yumemi` (client を含む) も fresh 出力と一致。証跡: `gen/build/y1e-m-ddl-diff.txt`、`gen/build/y1e-m-fixture-final-fresh-diff.txt`、`gen/build/y1e-m-fixture-tracked-diff.txt`。

## 鷹野宛

- `impl/yumemi-1e-bp` を `impl/yumemi-1e` に merge。競合3件を解消し、merge commit は `763c7f6`。生成 Live の型は束 A の `Service.Error` と `Failure { Refused(Error) | Broke(String) }` を採った。Blob upload の失敗は `Broke("file upload failed")` となり、Service request より前に止まる。
- API Markdown は fixture を `8875df6` の内容へ戻し、生成 helper と `gleam/list` import は実際に使う heading / paragraph / code / table / list に合わせる。未対応構文の停止試験は維持。
- `gen/load/*` はページ本文と配置 Block の参照から import を組む。F5 写しで `src/gen/load` の unused-import 診断は www / muses / console 各0。
- 生成 live の unused-import 診断も3面とも0。BRIEF が「unused 3件」とした `browser_adult` / `subscription_*` の各3件は、実際には使用中の module に対する `Transitive dependency imported` だった。元の F5 probe manifest は www に `gleam_json` / `lustre` が無く、muses / console は `gleam_json` があり `lustre` が無い。run_dir 内だけの別 probe に www `gleam_json` + `lustre`、muses / console `lustre` を直接依存として加えたところ、generated `gen/live` の unused / transitive import 警告は3面とも0。3 build は Page 型エラーで exit 1 のまま。snapshot と `src/framework/` は変更していない。証跡: `gen/build/y1e-m-f5-directdeps-{www,muses,console}.txt`。
- `verify-front-file` は既存 key の upload skip、選択 File の BlobCopy→Service 順序、upload失敗時の Service 未呼び出し、Entry upload1回を確認。
- root `gleam.toml` と `gen/manifest.toml`、fixture manifest の `yumemi` lock はすべて 0.9.0。
- `musearch` には書いていない。終了時 `git status --short` は空、HEAD `086c62e`。

検証:

- root `gleam build`: exit 0、warning 1件 (`src/framework/secret.gleam:5`)。`gen/build/y1e-m-root-final.txt`
- `cd gen && gleam test`: **178 passed, no failures**。A の168試験と B′側の追加試験を保持。`gen/build/y1e-m-test-final.txt`
- fixture 生成: final code で in-place 2回とも exit 0 / 92 files、保存した tracked diff は同一。fresh 出力2回も `diff -qr` 0行。fresh の face `public/src/gen` と client は tracked 生成物と一致。fresh `db/` は32 files。`gen/build/y1e-m-fixture-final-{a,b}.txt`、`gen/build/y1e-m-fixture-final-{fresh,fresh2}.txt`、`gen/build/y1e-m-fixture-final-fresh-diff.txt`、`gen/build/y1e-m-fixture-tracked-diff.txt`
- `gleam format --check`: fixture fresh 56 `.gleam`、snapshot 951 `.gleam` とも exit 0。証跡 `gen/build/y1e-m-format-fixture-final.txt`、`gen/build/y1e-m-format-snapshot.txt`。
- `verify-front-ssr`, `-isolate`, `-given`, `-file`, `-overlay`: ALL PASS。Block preview: `build-blocks.mjs` は `BLOCKS: PASS (6 blocks)`。証跡は `gen/build/y1e-m-verify-front-*.txt` と `gen/build/y1e-m-build-blocks.txt`。
- snapshot `a109b47` を2回生成: 各 generator exit 4、file 1347、exit 0 warnings 43、exit 1 の残件3、exit 2 = 0、exit 3 = 1、exit 4 = 20。出力間 `diff -qr` は0行。exit 4 の行は本便前の生成結果と同一で、追加0 / 削除0。証跡 `gen/build/y1e-m-snapshot-final{3,4}.txt`、`gen/build/y1e-m-snapshot-final34-diff.txt`、`gen/build/y1e-m-snapshot-exit4-diff.txt`。
- snapshot の generator exit 1 の残り3行は console `session_switch`, muses `settings`, www `space_title`。2件の `entity/visit.Source` decoder error は解消。

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
| `www/src/gen/api.gleam:42` | yumemi 0.7.0 に `framework/front.Target` が無い | 上記の版上げ |
| `www/src/components/adult_declare.gleam:12`, `consent_give.gleam:16`, `fan_onboard.gleam:16` | `api.Entry` は生成 `api` module に無い | `framework/front as front` を import し `front.Entry(...)` にする |
| `www/src/layout.gleam:8:56`, `muses/src/layout.gleam:8:58`, `console/src/layout.gleam:8:60` | `Layout` に `reads` が必要 | 各 `Layout(...)` に実際の reads を渡す。空なら `reads: []` |
| `www/src/blocks/store_schedule.gleam:41` | `store_schedule_list.Out` に `grid: Option(Grid)` が加わった | `grid: _` を受けるか表示に使う |

F5 写しは `www` 24 errors (generated 19 / ★ 5)、`muses` 14 (11 / 3)、`console` 18 (17 / 1)。warning はそれぞれ `www` 415 (generated 322 / ★ 78 / dependency・framework 15)、`muses` 452 (205 / 232 / 15)、`console` 250 (123 / 112 / 15)。各 `gleam build` は exit 1。証跡: `gen/build/y1e-m-f5-final3-{www,muses,console}.txt`、準備ログ `gen/build/y1e-m-f5-final3-prepare.txt`。`gleam build` が示した generated / ★ の warning 内訳を数え、残る15件は face source 以外の依存・framework warning。

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
| route parameter / variant | `muses/src/pages/page/widget/arg_id/page.gleam` | `muses/src/gen/load/page/widget/arg_id/page.gleam:115` — `widget_form.view(Nil)` (`Mode.Edit`, widget id) |
| variant selection | `muses/src/pages/articles/new/page.gleam` | `muses/src/gen/load/articles/new/page.gleam:110` — `article_form.view(Nil)`; ★ は `article_form.New` を渡す |
| variant selection | `muses/src/pages/page/widget/new/page.gleam` | `muses/src/gen/load/page/widget/new/page.gleam:115` — `widget_form.view(Nil)` (`Mode.New`) |
| variant selection | `muses/src/pages/page/page.gleam` | `muses/src/gen/load/page/page.gleam:134`, `:145` — `space_selector.view(Nil)`, `widget_list.view(Nil)` (`selected`) |
| session value | `muses/src/pages/settings/page.gleam` | `muses/src/gen/load/settings/page.gleam:118` — `settings.view(Nil)` (`subjects`, `consents`) |
| period value | `muses/src/pages/metrics/page.gleam` | `muses/src/gen/load/metrics/page.gleam:110` — `metrics_dashboard.view(Nil)` (`from`, `to`) |

Console の snapshot は load Page が11本あり、共通 `console_header` の `idp_origin` が全11本で欠ける。BRIEF の「約9」より実ファイルでは2本多いため、上表に11本すべて載せた。

`home`, `heaven`, `links`, `settings`, `page` の Block `In` には Page.of 以外の Service.Out もある。例: `muses/src/gen/load/page.gleam:111` (`home.view(Nil)`)、`muses/src/gen/load/heaven/page.gleam:111`、`muses/src/gen/load/links/page.gleam:111`。これは出所の新語彙を足さず、Y1f の Service 読み推論で扱う。

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
| snapshot exit 1 | 5 (decoder 2 + face 3) | 3 (face 3) |
| snapshot exit 2 | 0 | 0 |
| snapshot exit 3 | 1 | 1 |
| snapshot exit 4 | 20 | 20 (exit4 line diff 0) |
| snapshot warnings (`exit 0 警告`) | 43 | 43 |
| snapshot generated files | 1340 | 1347 |

snapshot raw run log は face ごとの exit 1 summary を3行出す。基線 exit1=5 はその3 face errorsに decoder errors 2件を加えた数で、最終値から decoder 2件が消えた。

F5 face build の診断内訳 (各 `gleam build` は既存型エラーで exit 1):

| 面 | errors: generated / ★ | warnings: generated / ★ / dependency・framework |
|---|---:|---:|
| www | 19 / 5 | 322 / 78 / 15 |
| muses | 11 / 3 | 205 / 232 / 15 |
| console | 17 / 1 | 123 / 112 / 15 |

F5 写しに `Unused imported*` として出る generated `gen/load` / `gen/live` の診断は各面0。指定された browser_adult / subscription_* の3件ずつは live が実際に使う transitive modules への警告なので、unused ではない。direct dependency は F5 の面 manifest で扱う。
