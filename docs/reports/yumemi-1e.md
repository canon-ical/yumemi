# yumemi-1e 束 A 実測

作業 branch: `impl/yumemi-1e`。基点: `8875df6`。snapshot: musearch `a109b47`。

## DDL

無し。`out-fx-base/db` と fixture の生成先、`out-ms-base/db` と snapshot の生成先をそれぞれ `diff -r` で比較し、両方とも差分なし(exit 0)。証跡は `gen/build/y1e-a-ddl-fx-diff.txt` と `gen/build/y1e-a-ddl-ms-diff.txt`。

## 実装した5件

1. 生成する各ページの `<head>` に `name="viewport"` と `width=device-width, initial-scale=1, viewport-fit=cover` を追加。shell の定数は増やしていない。`front_emit_shell_includes_viewport_meta_test` で確認。
2. Blob の `--bg-image` は face の `media.url(value, media.W1600)` に委譲した。media が key の path segment encoding と `?v=w1600` を所有しており、既存の media URL と同じ規則を二重実装しないため。試験 key `season one+猫/夏祭り 2026+top.jpg` は `/media/season%20one%2B%E7%8C%AB/%E5%A4%8F%E7%A5%AD%E3%82%8A%202026%2Btop.jpg?v=w1600` になった。`front_blob_theme_media_url_matches_segment_encoding_test`。
3. `docs/api-v1.md` の原文を単一 text node にせず、見出し・表・行・inline code・fenced code・段落・一覧を要素へ変換する。snapshot ▲ `www/src/gen/doc/api_v1.gleam` と構造数を合わせた。

   | 要素 | `docs/api-v1.md` | 生成物 |
   |---|---:|---:|
   | 見出し | 3 | 3 |
   | 表 | 2 | 2 |
   | 表の行 | 11 | 11 |
   | inline code | 67 | 67 |
   | fenced code (`pre`) | 1 | 1 |
   | 一覧 | 0 | 0 |

   入力を1字変える試験も維持し、未対応の Markdown block quote は parser がエラーにする。原文の黙った脱落はない。
4. face の `yumemi` を path dependency に直すとき、`manifest.toml` は削除しない。他の Hex package の locked version を保持し、path dependency の枝だけを除く。`yumemi` 行は root `gleam.toml` の版と絶対 path を持つ local dependency にする。online fixture 生成後、`unshare -rn` の offline 2回目も exit 0・88 file、2回の `diff -r` は空。証跡: `gen/build/y1e-a-fixture-online-final1.txt`, `gen/build/y1e-a-fixture-offline-final2.txt`, `gen/build/y1e-a-fixture-final-diff.txt`。
5. live / decoder / page input を修正した。
   - Service Error の variant を `Failure.Refused(Error)` に保持し、transport / decode failure は `Broke(String)` にする。Error variant が無い service は `Broke` だけにし、空の Refused branch を追加しない。F5 で `claim_button` は compile する。
   - `entity/visit.Source` decoder は back の `api/src/gen/source.mjs` と同じ表現を読む。`Tagged` は `{source_kind: "tagged", source_key: string}`、`Direct` / `Internal` / `External` は各 kind と `source_key: null`。`Source` 専用 decoder があるため、共通 multi-variant 診断からも除外した。`front_emit_decodes_visit_source_from_codec_fields_test` と診断試験で確認。
   - Page が持つ非optional Service `Out` を、単一 variant の Block `In` に field ごとに渡す。`muses` の unclaim page は `unclaim_confirm.In(rosters: it.roster_list_mine)` を生成し、F5 で compile する。
   - `AttachedCall` も live target として処理する。service-backed な `consent_give` / `fan_onboard` と static attached route の `browser_adult` を生成し、transport を共有する。0引数 Service の `live.Set` も網羅する。
   - `gen/out/roster_read` の `MusePublic` 等を Service 出力に入れ、F5 の `cast_profile` mismatch を解消。Blocks preview は import alias を解決して Service `Out` を構築し、Blob / Party の `parse` はそれぞれ別名 import にした。

## F5 相当の写し

`probe-final1.sh` 相当を3面に実行。各 face の `gleam build --target javascript` の stdout/stderr 全文は以下にある。

| 面 | errors | files | 生成器起因 | ▲ 残り | ★ 入力起因 |
|---|---:|---:|---:|---:|---:|
| www | 5 | 5 | 0 | 0 | 5 |
| muses | 14 | 13 | 0 | 0 | 14 |
| console | 18 | 12 | 0 | 0 | 18 |

生成した `gen/live`, `gen/blocks_preview`, `gen/out` に起因する error は0件。残る `gen/load` 上の型 error は、Page が block の必要な `Out` / URL parameter / environment value を宣言していない ★ 面 source に帰属させた。`src/gen` は写しから削除済みなので ▲ 残りは0件。F5 の compiler 自体は ★ の入力不足により上表の件数で失敗する。file:line と最小追随は後段に列挙した。

証跡:

- `/home/yumemism/.codex-agents/runs/niekawa-20260924-135307-601740-3464/evidence/probe-final1-www.txt`
- `/home/yumemism/.codex-agents/runs/niekawa-20260924-135307-601740-3464/evidence/probe-final1-muses.txt`
- `/home/yumemism/.codex-agents/runs/niekawa-20260924-135307-601740-3464/evidence/probe-final1-console.txt`

直の snapshot run では Hex の yumemi 0.7.0 が `framework/front.Target` を持たず、www の診断に出る。F5 写しは指定通り local path dependency に切り替え、root の `framework/front.Target` が解決するため、この error は写しには残らない。実際の root `gleam.toml:2` は `version = "0.8.0"`。依頼文の 0.9.0 とは一致しないが、root manifest は今回の作業範囲外なので変更していない。

## snapshot 再生成

最終コードで `out-ms-final1` と `out-ms-final2` を2回生成した。`find -type f` は各1347 file、`diff -r` は空(exit 0)。

| 分類 | 基線 | 最終 |
|---|---:|---:|
| `[exit 0` 行 | 43 | 43 |
| exit 1 | 5 | 3 |
| exit 2 | 0 | 0 |
| exit 3 | 1 | 1 |
| exit 4 | 20 | 20 |
| file 数 | 1340 | 1347 |

exit 1 の減少2行は `metrics_muse` / `metrics_store` の `entity/visit.Source` 汎用 discriminator 診断。codec と一致させて解消した。残る3行は console `session_switch.view(Nil)`、muses `settings.view(Nil)`、Hex 0.7.0 の www `front.Target`。`_diagnostics.txt` と face ごとの `_diagnostics/*-runtime.txt` に全文を保持し、短縮表示にも sidecar path を出す。

証跡: `gen/build/y1e-a-snapshot-final1.txt`, `gen/build/y1e-a-snapshot-final2.txt`, `gen/build/y1e-a-snapshot-final-diff.txt`。生成出力は `/home/yumemism/.codex-agents/runs/niekawa-20260924-135307-601740-3464/out-ms-final1`。

## ★ 追随便への申し送り

以下は F5 の残り error の発生行と、その原因を持つ snapshot face source。表中 `reads` は Page/Layout の `reads` field を指す。scalar、route parameter、multi-variant constructor の選択は現行 `reads` だけでは表現できない。

### www

| F5 file:line | 原因 source / 最小追随 |
|---|---|
| `www/src/blocks/store_schedule.gleam:41` | `store_schedule_list.Out` に `grid` が増えた。利用列だけ読む pattern を `store_schedule_list.Out(schedules: schedules, ..)` にする。 |
| `www/src/components/adult_declare.gleam:12`, `www/src/components/consent_give.gleam:16`, `www/src/components/fan_onboard.gleam:16` | `api.Target` は `front.Target(...)` の alias なので `api.Entry` constructor を再exportしない。`framework/front as front` を import し、`api.Entry(api.X)` を `front.Entry(api.X)` にする。 |
| `www/src/layout.gleam:8` | 現行 `Layout` constructor に `reads` が必要。無読みなら `reads: []` を加える。 |

### muses

| F5 error | 原因 source / 最小追随 |
|---|---|
| `muses/src/components/adult_declare.gleam:15`, `muses/src/components/onboard_wizard.gleam:39` | `api.Entry(api.BrowserAdult)` を `front.Entry(api.BrowserAdult)` にし、`framework/front as front` を import。 |
| `muses/src/pages/articles/new/page.gleam:10` | `ArticleForm.In` は `New | Edit(...)`。この route は `ArticleForm.New` を明示して渡す入力契約が必要。 |
| `muses/src/pages/articles/arg_id/page.gleam:10` | 同じ block の `Edit(article, phase)` を組み立てる `ArticleRead` と route id が必要。multi-variant constructor 選択も明示する。 |
| `muses/src/pages/heaven/page.gleam:10` | `HeavenPanel.In` の `muse_read.Out` は `Page.of` から取れる。`muse_heaven_list.Out` を `reads` に加える。 |
| `muses/src/pages/links/page.gleam:10` | `LinkList.In` に `link_list.Out` と `link_import_read.Out` を渡す。両Serviceの `Out` を `reads` に加える。 |
| `muses/src/pages/metrics/page.gleam:10` | `MetricsDashboard.In` は `metrics_muse.Out` と `from` / `to` を要する。metrics Service と期間値の出所(固定初期値か query)を明示する。 |
| `muses/src/pages/page.gleam:10` | `Home.In` は `muse_read`, `notification_inbox`, `metrics_muse` の3つの `Out` を要する。後2つを `reads` に加える。 |
| `muses/src/pages/page/page.gleam:10` | `SpaceSelector` と `WidgetList` 用に `space_list.Out` / `widget_list.Out` と `selected` の値が必要。Service reads と selected の出所を追加する。 |
| `muses/src/pages/page/widget/new/page.gleam:10`, `muses/src/pages/page/widget/arg_id/page.gleam:10` | `WidgetForm.In` に `space_list.Out`, `muse_heaven_list.Out` と `Mode.New` / `Mode.Edit` を渡す。reads と mode / route id の選択を明示する。 |
| `muses/src/pages/settings/page.gleam:10` | `Settings.In` は `muse_read.Out`, `roster_list_mine.Out`, subjects, consents を要する。Roster read と subjects / consents の session source を明示する。今回直した `/settings/unclaim/:id` の `UnclaimConfirm.In` とは別のページ。 |
| `muses/src/layout.gleam:8` | `Layout` constructor に `reads` field を加える。 |

### console

| F5 error | 原因 source / 最小追随 |
|---|---|
| `console/src/layout.gleam:8` と複数ページの `console_header.view(Nil)` | `Layout` に `reads` field が必要。ただし `ConsoleHeader.In(idp_origin: String)` は Service `Out` ではないため、`idp_origin` の environment/config source も要る。空文字の捏造では閉じない。対象ページ: `api_key`, `consent`, `metrics`, root `page`, rosters (`arg_id`, `arg_id/photos/.../remove`, `arg_id/remove`, `new`, list), `schedule`, `switch`。 |
| `console/src/pages/api_key/page.gleam:10` | `ApiKeyPage.In(www_origin: String)` に www origin の config を渡す。 |
| `console/src/pages/consent/page.gleam:10` | `ConsentPage.In(idp_origin: String)` に IdP origin の config を渡す。 |
| `console/src/pages/rosters/arg_id/page.gleam:10` | `RosterEditor.In` は roster row と `www_origin` が必要。route id に対応した read と config を明示する。 |
| `console/src/pages/rosters/arg_id/photos/arg_order/remove/page.gleam:10` | `RosterPhotoRemoveConfirm.In(id, order)` に route parameter `id` / `order` を渡す。 |
| `console/src/pages/rosters/arg_id/remove/page.gleam:10` | `RosterRemoveConfirm` は String id を直接受ける。route parameter mapping を追加する。 |
| `console/src/pages/switch/page.gleam:10` | `SessionSwitch.In(has_store, idp_origin)` に session/context と IdP origin を渡す。Page は `of: None`, `reads: []`。 |

## 検証記録

- `cd gen && gleam test`: **168 passed, no failures**。証跡 `gen/build/y1e-a-source-decoder-diagnostic-test.txt`。
- root `gleam build`: exit 0, `Compiled in 0.03s`。既存 warning は `src/framework/secret.gleam:5` の未使用 private constructor 1件。証跡 `gen/build/y1e-a-root-build.txt`。
- fixture: online / network off (`unshare -rn`) とも88 file、`diff -r` 空。`gleam format --check build/out-fx-final1/src/gen build/out-fx-final1/public/src/gen`: exit 0。証跡 `gen/build/y1e-a-fixture-online-final1.txt`, `gen/build/y1e-a-fixture-offline-final2.txt`, `gen/build/y1e-a-fixture-final-diff.txt`, `gen/build/y1e-a-fixture-format-check.txt`。
- root `gleam.toml`、`src/framework/`、root `test/`、musearch、`yumemi-gen-7` は変更していない。staging / production DB への適用も無し。
