## DDL

無し。`git diff --stat 355a93a -- db/ gen/fixtures/article/db/` は空。

## 鷹野宛

- Query を必須 Args へ流す6行(4 Page)は既定を Page に書けないため back の Args の形の区分へ移した(贄川の当てはめ、巡 5)。

### P0

- **R19-P0-1:** 63 の `Var("handle", Path("muse"))` / `Origin("www")` を reader が読めず、F6 で `Vars(vars[0]: String)` を出した。巡4で贄川さんが検収時に拾い差し戻し。reader を位置引数・ラベル付き・合法な混在形に対応させ、非リテラル名は安全な `invalid_var_<n>` に置き換えた。位置引数の `Var` / `Origin`、ラベル付き `Origin`、exit 4 の負例を test で確認。`Page` / `Layout`、`Frame` / `Area` / `Fixed` / `Widget`、`Minmax` / `GridTracks` / `Span` / `At` / `CellSpan` / `ByKind` は引き続き `g.labelled` で読むため、位置引数は未対応。今回は変更していない。

### P1

- **G1-P1-1:** `reads:` を消した後、reader が未知欄を黙って読み飛ばす。
- **G1-P1-2:** 殻の `/api/session` は back の付属入口に依存する(repo をまたぐ契約)。
- **R2-P1-1:** exit 4 でも生成器は `Nil` を埋めた出力を書くため、後段で `[exit 1 生成器の不足]` が重なる。
- **R2-P1-2:** Gleam の namespace 制約により `TrackSize.Auto` は `TrackSize.AutoSize`。`Track.Auto` はそのまま。
- **R3-P1-1:** `/api/session` の非 ok / 例外を匿名と同様に扱い、Authenticated 面では back の 5xx が401に化ける。

### 贄川の当てはめ

- (a) snapshot (ii) を F5 最小 patch と F6 patch の2段に分けて計測。F5 前 snapshot に F6 だけを当てても3面 build に届かない。
- (b) Widget の枠名は `Placement.Widget.name` だけを除き、配置は保持する。
- (c) constructor 名は `Track.Auto` / `TrackSize.AutoSize`。

## 追随便への申し送り

### F6 対象表

F6 対象表の元21 Pageに、HomeMetrics の Query Args 2行がある muses/src/pages/page.gleam を加えると22 file。指定の合計21とは1 fileずれるため、どの既存行をまとめるかは未決。

区分数（実ファイル数）: 語彙12 / back の1行読み6 / back の Args の形4 / 合計22 / 未分類0。

| Page file | Page `vars` | Block `Arg` | 割る Block | 要る back の Service | 区分 |
|---|---|---|---|---|---|


| `console/src/pages/rosters/arg_id/page.gleam` | `handle: Session(SubjectHandle)`, `id: Path("id")` | `roster_editor(id: String, www_origin: String)`; `console_header(idp_origin: String)` | `roster_editor(In: Option(store_roster_list.Row))` → `In = store_roster_read.Out` | `store_roster_read(id) → Out(roster: roster.Owned, phase: roster.Phase, photos: List(roster_photo.RosterPhoto))` | back の1行読み |
| `console/src/pages/rosters/arg_id/remove/page.gleam` | `id: Path("id")` | `roster_remove_confirm(id: String)`; header は `idp_origin` | `roster_remove_confirm(In: String)` → `In = Nil` | 無し | 語彙だけ |
| `console/src/pages/rosters/arg_id/photos/arg_order/remove/page.gleam` | `id: Path("id")`, `order: Path("order")` | `roster_photo_remove_confirm(id: String, order: String)`; header は `idp_origin` | `roster_photo_remove_confirm(In: {id, order})` → `In = Nil` | 無し | 語彙だけ |
| `console/src/pages/api_key/page.gleam` | `[]` | `console_header(idp_origin: String)`, `api_key_page(www_origin: String)` | 無し | 無し | 語彙だけ |
| `console/src/pages/consent/page.gleam` | `[]` | `console_header(idp_origin: String)`, `consent_page(idp_origin: String)` | 無し | 無し | 語彙だけ |
| `console/src/pages/metrics/page.gleam` | `handle: Session(SubjectHandle)`, `from: Query("from")`, `to: Query("to")` | header は `idp_origin` | `metrics_page(In: metrics_store.Out)` はそのまま | 無し | 語彙だけ |
| `console/src/pages/page.gleam` | `handle: Session(SubjectHandle)` | header は `idp_origin` | 無し | 無し | 語彙だけ |
| `console/src/pages/rosters/new/page.gleam` | `[]` | header は `idp_origin` | 無し | 無し | 語彙だけ |
| `console/src/pages/rosters/page.gleam` | `handle: Session(SubjectHandle)` | `roster_list(handle: String)`; header は `idp_origin` | 無し | 無し | 語彙だけ |
| `console/src/pages/schedule/page.gleam` | `handle: Session(SubjectHandle)` | header は `idp_origin` | 無し | 無し | 語彙だけ |
| `console/src/pages/switch/page.gleam` | `[]` | `session_switch(idp_origin: String)`; header は `idp_origin` | `session_switch(In: {has_store: Bool, idp_origin: String})` → `In = subject_list.Out`; 空判定は `stores` の空/非空 | `subject_list() → Out(stores: List(Store))` | back の1行読み |
| `muses/src/pages/articles/arg_id/page.gleam` | `handle: Session(SubjectHandle)`, `id: Path("id")` | `article_edit(handle: String, id: String)` | `article_form(Edit(...))` → `article_edit(In: article_read.Out)`、新規は `article_new(In: Nil)`。共通フォームは Component | 既存 `article_read(id, handle) → Out(article, phase, muse)`。`api/src/service/article_read.gleam` の AsMuse / AnyPhase により Draft も読める | back の1行読み |
| `muses/src/pages/page/widget/arg_id/page.gleam` | `handle: Session(SubjectHandle)`, `id: Path("id")`, `selected: Query("space")` | `widget_form_edit(handle: String, id: String)` | `widget_form(Mode.Edit(...))` → `widget_form_edit(In: widget_read.Out)`; 新規フォームと編集フォームを分け、共通フォームは Component | `widget_read(handle, id) → Out(row: widget_list.Row)` | back の1行読み |
| `muses/src/pages/articles/new/page.gleam` | `handle: Session(SubjectHandle)` | `article_new` は引数なしの view | `article_form(New)` → `article_new(In: Nil)`、共通フォームは Component | 無し | 語彙だけ |
| `muses/src/pages/page/widget/new/page.gleam` | `handle: Session(SubjectHandle)`, `kind: Query("kind")`, `space: Query("space")`, `selected: Query("space")` | `widget_form(handle: String, kind: Option(String), space: Option(String))` | `widget_form` は new、`widget_form_edit` は edit。共通フォームは Component | 無し | 語彙だけ |
| muses/src/pages/page/page.gleam | handle: Session(SubjectHandle), selected: Query(space), space: Query(space) | widget_list(space: Place) | widget_list(In: widget_list.Out) | widget_list.Args(space: Place) → back accepts space: Option(Place), default AllPlaces | back の Args の形を変える |
| `muses/src/pages/settings/page.gleam` | `handle: Session(SubjectHandle)` | 設定の分割 Block は back Out を直接読む | `settings(In: {muse, rosters, subjects, consents})` → `settings_profile(In: muse_read.Out)`, `settings_rosters(In: roster_list_mine.Out)`, `settings_subjects(In: subject_settings_read.Out)`。同意表示と同意用 Block / Service は削除 | `subject_settings_read() → Out(subjects: List(#(String, String, Bool)))`。consents は含めない | back の1行読み |
| muses/src/pages/metrics/page.gleam | handle: Session(SubjectHandle), from/to: Query | metrics_dashboard(from/to: Option(String)) | metrics_dashboard(In: metrics_muse.Out) | metrics_muse.Args(from: Date, to: Date) → both Option(Date), defaults DefaultMetricsFrom/DefaultMetricsTo held by back | back の Args の形を変える |
| muses/src/pages/page.gleam | handle: Session(SubjectHandle), from/to: Query | home_metrics(from/to: Option(String)) | home_metrics(In: metrics_muse.Out) | metrics_muse.Args(from: Date, to: Date) → both Option(Date), same back period defaults | back の Args の形を変える |
| `www/src/pages/claim/arg_code/page.gleam` | `code: Path("code")` | `claim_head(code: String)` | `claim_head(In: String)` → `In = Nil` | 無し | 語彙だけ |
| www/src/pages/muse/arg_handle/space/arg_id/page.gleam | handle/id/space: Path | space_title plus ByKind Widget | space_title(In: space_read.Out); Widget(of: SpaceWidgetList, render: ByKind), Blocks In widget_list.Row | space_read(handle,id); space_widget_list(handle,space) | back の1行読み |
| www/src/pages/muse/arg_handle/page.gleam | current F6: handle Path, space Query; 22:30 target: muse=[handle] | widget_list.Args(handle: Handle, space: Place, widget: Option(WidgetKey)) | Widget(of: WidgetList, render: ByKind), slot name removed | proposed muse_widget_list.Args(muse: Handle), back default Top | back の Args の形を変える |

記事編集 Page は保存済み Article を1件読むため back の1行読みに分類。既存 article_read(id, handle) があり、Out は article, phase, muse。

Query Args 6行の要件。URL に値がなくても Page に既定値を書かず、欠落時の既定は back が持つ。

| Page file | 現行 Service Args | Query / Page vars | back Args 案と欠落時の既定 |
|---|---|---|---|
| muses/src/pages/metrics/page.gleam | metrics_muse.Args(from: Date, to: Date) | MetricsDashboard from/to: Option(String); handle Session, from/to Query | from/to: Option(Date); DefaultMetricsFrom / DefaultMetricsTo |
| muses/src/pages/page.gleam | metrics_muse.Args(from: Date, to: Date) | HomeMetrics from/to: Option(String); handle Session, from/to Query | from/to: Option(Date); 同じ期間既定を back が補う |
| muses/src/pages/page/page.gleam | widget_list.Args(space: Place) | WidgetList space: Option(String); handle Session, selected/space Query(space) | space: Option(Place); 欠落時 AllPlaces |
| www/src/pages/muse/arg_handle/page.gleam | widget_list.Args(handle: Handle, space: Place, widget: Option(WidgetKey)) | Widget space: Option(String); current handle Path + space Query; 22:30 target muse=[handle] | proposed muse_widget_list.Args(muse: Handle); handle alone returns Muse TOP widget, missing default Top in back |

ByKind の実物走査: www は2 Page / 2 table、muses は0。5つの Widget renderer Block は widget_list.Row を受け、view(it, _arg) の2引数を保つ。space Page も Widget(of: SpaceWidgetList, render: ByKind) とし、Fixed(SpaceMain) は置かない。slot name は削除。
Widget の裁定: `Placement.Widget` は `Widget(area, of, render)`。`www /muse/{handle}` の Widget Service Args は Page の `Var("handle", Path("handle"))` から渡す。`www /muse/{handle}/space/{id}` の `space_main` は `SpaceMain` Block と `space_widget_list` Service に分け、space id を渡す。`api/src/gen/http_runtime.mjs:152` の `widgetKeys`(枠名の列)は F6 で消える。

`muses /settings` では同意の表示を扱わない。`settings_subjects` は subjects のみを表示し、表の Service Out にも consents を含めない。

### `In` の全件監査と分割

`audit-in.txt` は snapshot の `www/muses/console/src/blocks/*.gleam` を module 名順に走査した記録。132 module のうち `Nil` / 単一 Service `.Out` 以外は32件。うち `www/placeholder` は `view` を持たない表示 helper、`muses/onboard_wizard` は `view(_it: Nil)` だが `In` alias が無い。残る30 Blockを次の形に揃え、`onboard_wizard` は `In = Nil` を明記する。

| Block | snapshot `In` | F6 の形 |
|---|---|---|
| `www/claim_head` | `String` | `Nil`, `Arg(code: String)` |
| `www/muse_header` | `muse_read.Out` + `Option(subscription_read.Out)` | `muse_header(In: muse_read.Out)` + `subscription_action(In: subscription_read.Out)` |
| `www/placeholder` | `In` なし、`view` なし | Block ではなく表示 helper |
| `www/roster_list` | `handle: String` + `roster_list.Out` | `roster_list.Out`, `Arg(handle: String)` |
| `www/space_title` | `space_list.FreeSpace` | `space_read.Out`, `Arg(handle: String, id: String)` |
| `www/store_schedule` | `title: String` + `store_schedule_list.Out` | title を Page に置かず、`store_schedule` / `cast_schedule` の各 `.Out` Block に分ける |
| `www/widget_articles` | `widget_list.Row` | `widget_list.Out`, `Arg(handle: String, space: Option(String))` |
| `www/widget_heaven` | `widget_list.Row` | `widget_list.Out`, `Arg(handle: String, space: Option(String))` |
| `www/widget_image` | `widget_list.Row` | `widget_list.Out`, `Arg(handle: String, space: Option(String))` |
| `www/widget_links` | `widget_list.Row` | `widget_list.Out`, `Arg(handle: String, space: Option(String))` |
| `www/widget_text` | `widget_list.Row` | `widget_list.Out`, `Arg(handle: String, space: Option(String))` |
| `muses/article_form` | `New` / `Edit(article, phase)` | 共通 Component にし、`article_new(In: Nil)` / `article_edit(In: article_read.Out)` に分ける |
| `muses/heaven_panel` | `muse_read.Out` + `muse_heaven_list.Out` | `heaven_panel(In: muse_read.Out)` + `heaven_list(In: muse_heaven_list.Out)` |
| `muses/home` | `muse_read.Out` + `notification_inbox.Out` + `metrics_muse.Out` | `home`, `home_inbox`, `home_metrics` の各 `.Out` Block |
| `muses/link_list` | `link_list.Out` + `link_import_read.Out` | `link_list(In: link_list.Out)` + `link_import(In: link_import_read.Out)` |
| `muses/metrics_dashboard` | `metrics_muse.Out`, `from: String`, `to: String` | `metrics_muse.Out`, `Arg(from: Option(String), to: Option(String))` |
| `muses/onboard_wizard` | alias なし (`view(_it: Nil)`) | `In = Nil` を明記 |
| `muses/settings` | `muse_read.Out`, `roster_list_mine.Out`, subjects, consents | `settings(In: muse_read.Out)` + `settings_rosters(In: roster_list_mine.Out)` + `settings_subjects(In: subject_settings_read.Out)`。subjects のみ。consents は削除 |
| `muses/space_row` | `space_list.FreeSpace` | `space_list.Out` を受け、一覧 Block 内で行を描く |
| `muses/space_selector` | `space_list.Out` + `selected: String` | `space_list.Out`, `Arg(selected: Option(String))` |
| `muses/unclaim_confirm` | `roster_list_mine.Out` を含む1欄 record | `roster_list_mine.Out` |
| `muses/widget_form` | `Mode` + `space_list.Out` + `muse_heaven_list.Out` | `widget_form` は new のみ (`muse_heaven_list.Out`); edit は `widget_form_edit(In: widget_read.Out)`; dropdowns は `widget_space(In: space_list.Out)` / `widget_heavens(In: muse_heaven_list.Out)` |
| `muses/widget_list` | `widget_list.Out` + `space_list.Out` + selected | `widget_list(In: widget_list.Out)` + `widget_space(In: space_list.Out)` |
| `muses/widget_row` | `widget_list.Row` | `widget_list.Out` を受け一覧内で行を描く |
| `console/api_key_page` | `www_origin: String` | `Nil`, `Arg(www_origin: String)` |
| `console/consent_page` | `idp_origin: String` | `Nil`, `Arg(idp_origin: String)` |
| `console/console_header` | `idp_origin: String` | `Nil`, `Arg(idp_origin: String)` |
| `console/roster_editor` | `Option(store_roster_list.Row)` + `www_origin` | `store_roster_read.Out`, `Arg(id: String, www_origin: String)` |
| `console/roster_photo_remove_confirm` | `id: String`, `order: String` | `Nil`, `Arg(id: String, order: String)` |
| `console/roster_remove_confirm` | `String` | `Nil`, `Arg(id: String)` |
| `console/roster_row` | `store_roster_list.Row` | `store_roster_list.Out` を受け一覧内で行を描く |
| `console/session_switch` | `has_store: Bool`, `idp_origin: String` | `subject_list.Out`, `Arg(idp_origin: String)`。`has_store` は Out の stores を case 分け |

### `Arg` を持つ Block 全件

snapshot の3面の全 Block file を走査し、`Arg` が必要な34 module。型は `String` / `Option(String)` に限る。

| Block | `Arg` 欄 |
|---|---|
| `console/api_key_page` | `www_origin: String` |
| `console/consent_page` | `idp_origin: String` |
| `console/console_header` | `idp_origin: String` |
| `console/roster_editor` | `id: String`, `www_origin: String` |
| `console/roster_photo_remove_confirm` | `id: String`, `order: String` |
| `console/roster_remove_confirm` | `id: String` |
| `console/session_switch` | `idp_origin: String` |
| `muses/article_edit` | `handle: String`, `id: String` |
| `muses/heaven_list` | `handle: String` |
| `muses/home_metrics` | `from: Option(String)`, `to: Option(String)` |
| `muses/link_list` | `handle: String` |
| `muses/metrics_dashboard` | `from: Option(String)`, `to: Option(String)` |
| `muses/space_list` | `handle: String` |
| `muses/space_selector` | `selected: Option(String)`, `handle: String` |
| `muses/widget_form` | `kind: Option(String)`, `space: Option(String)`, `handle: String` |
| `muses/widget_form_edit` | `handle: String`, `id: String` |
| `muses/widget_heavens` | `handle: String` |
| `muses/widget_list` | `selected: Option(String)`, `handle: String`, `space: Option(String)` |
| `muses/widget_space` | `selected: Option(String)`, `handle: String` |
| `www/cast_schedule` | `handle: String` |
| `www/claim_head` | `code: String` |
| `www/muse_header` | `handle: String` |
| `www/muse_nav` | `handle: String` |
| `www/roster_list` | `handle: String` |
| `www/store_memberships` | `handle: String` |
| `www/store_schedule` | `handle: String` |
| `www/subscription_action` | `handle: String` |
| `www/widget_articles` | `handle: String`, `space: Option(String)` |
| `www/widget_heaven` | `handle: String`, `space: Option(String)` |
| `www/widget_image` | `handle: String`, `space: Option(String)` |
| `www/widget_links` | `handle: String`, `space: Option(String)` |
| `www/widget_text` | `handle: String`, `space: Option(String)` |
| `www/space_title` | `handle: String`, `id: String` |
| `www/space_main` | `handle: String`, `space: String` |

### 0.10 の exit 4 行の事前予測

0.10.0 の本便生成器で F5 前 snapshot を実測した。下表は F5 後の写し `mid` と API `Args` を読んだ予測で、実測との行対応は次の subsection に記録する。Path は `arg_<name>` の route 段を含む全21 Page。route 段に対する未宣言は検査 #2、列挙した必須 Service Args の欠落は #4。前表の30 Block は `In` が単一 `.Out` / `Nil` でないので #6 も出る。

| Page file (`src/pages/...`) | route Path 欄 | Block / Service 欄 | 予測 |
|---|---|---|---|
| `www/claim/arg_code/page.gleam` | `code` | `ClaimHead.code` | #2 |
| `www/experiences/arg_id/page.gleam` | `id` | Page of / Block の必須 Args は無し | #2 |
| `www/fan/arg_handle/page.gleam` | `handle` | Page of / Block の必須 Args は無し | #2 |
| `www/me/chats/arg_id/page.gleam` | `id` | Page of / Block の必須 Args は無し | #2 |
| `www/me/experiences/arg_id/page.gleam` | `id` | Page of / Block の必須 Args は無し | #2 |
| `www/muse/arg_handle/article/arg_id/page.gleam` | `handle`, `id` | `article_read.handle`, `article_read.id` | #2, #4 |
| `www/muse/arg_handle/article/page.gleam` | `handle` | `article_list.handle` | #2, #4 |
| `www/muse/arg_handle/page.gleam` | `handle` | `muse_read.handle`, Widget `widget_list.handle`, `widget_list.space`。slot 由来の `widget` は裁定で消す | #2, #4 |
| `www/muse/arg_handle/reserve/page.gleam` | `handle` | Page of / Block の必須 Args は無し | #2 |
| `www/muse/arg_handle/reviews/page.gleam` | `handle` | Page of / Block の必須 Args は無し | #2 |
| `www/muse/arg_handle/schedule/page.gleam` | `handle` | `schedule_list.handle`; `from` は Query | #2, #4 |
| `www/muse/arg_handle/space/arg_id/page.gleam` | `handle`, `id` | `space_read(handle,id)`; `space_widget_list(handle,space)` | #2, #4 |
| `www/muse/arg_handle/tweets/page.gleam` | `handle` | Page of / Block の必須 Args は無し | #2 |
| `www/store/arg_handle/cast/arg_id/page.gleam` | `handle`, `id` | `roster_read.handle`, `roster_read.id` | #2, #4 |
| `www/store/arg_handle/page.gleam` | `handle` | `store_read.handle`; `roster_list.handle`, `store_schedule.handle` | #2, #4 |
| `muses/articles/arg_id/page.gleam` | `id` | `article_edit.handle`, `article_edit.id` | #2, #4 |
| `muses/page/widget/arg_id/page.gleam` | `id` | `widget_read.handle`, `widget_read.id`; `widget_heavens.handle`, `widget_space.handle` | #2, #4 |
| `muses/settings/unclaim/arg_id/page.gleam` | `id` | `roster_list_mine.id` | #2, #4 |
| `console/rosters/arg_id/page.gleam` | `id` | `store_roster_read.id`; `roster_editor.id` | #2, #4 |
| `console/rosters/arg_id/photos/arg_order/remove/page.gleam` | `id`, `order` | `roster_photo_remove_confirm.id`, `.order` | #2 |
| `console/rosters/arg_id/remove/page.gleam` | `id` | `roster_remove_confirm.id` | #2 |

route segment の無い muses Page で `handle` を実際に要求するものは次のとおり。Page / Block の Service Args は #4 の対象。muses の14 Page すべてに `Session(SubjectHandle)` を置く const 表も照合対象。

| Page file (`src/pages/...`) | 欄 | 予測 |
|---|---|---|
| `muses/heaven/page.gleam` | `muse_read.handle`, `heaven_list.handle` | #4 |
| `muses/links/page.gleam` | `muse_read.handle`, `link_list.handle` | #4 |
| `muses/page/page.gleam` | `muse_read.handle`, `space_list.handle` | #4 |
| `muses/page.gleam` | `muse_read.handle` | #4 |
| `muses/settings/page.gleam` | `muse_read.handle`; `subject_settings_read` は session 出所を Service 内に閉じる | #4 |
| `muses/page/widget/new/page.gleam` | `widget_form.handle`, `widget_heavens.handle`, `widget_space.handle` | #4 |


#### snapshot (i) で追加確認した 0.10 の行

| Page / Layout file | 検査対象 | 予測 |
|---|---|---|
| `console/layout.gleam` | `ConsoleHeader.In = In` | #6 |
| `www/search/page.gleam` | `SearchResults.article_search.q` | #4 |


### snapshot (i) の exit 4 行照合

基線の診断と snapshot (i) の `_diagnostics.txt` を行単位で比較した。基線の exit 4 は22行、(i) は111行。新規89行・消えた行0・同一22行で、新規行は下表で全件照合した。未分類0。詳細な `comm` 出力は `gen/build/y1f-snap-i-compare.txt`。

| 比較項目 | 基線 | snapshot (i) | 差分 |
|---|---:|---:|---:|
| exit 1 | 3 | 3 | 件数同じ。下記3行が差し替わった |
| exit 2 | 0 | 0 | 変化なし |
| exit 3 | 1 | 1 | 診断行も変化なし |
| exit 4 | 22 | 111 | 新規89行、消失0行 |
| warning | 48 | 48 | 診断行も変化なし |
| 生成 file 数 | 1375 | 1372 | -3 |

置き換わった exit 1 行:

- 消えた: `console` の `switch/page.gleam:110` で `session_switch.view(Nil)` が型不一致。追加: `console` の同 `switch/page.gleam:114` に同じ不一致(生成位置が4行後)。
- 消えた: `muses` の `settings/page.gleam:130` で `settings.view(Nil)` が型不一致。追加: `muses` の `settings/unclaim/arg_id/page.gleam:119` で `unclaim_confirm.view(Nil)` が型不一致。
- 消えた: `www` の `space/arg_id/page.gleam:204` で `space_title.view(it.space_list)` に `space_list.Out` を渡す型不一致。追加: 同 `page.gleam:207` で `space_title.view(Nil)` に `Nil` を渡す型不一致。

file 数が減った3 file は、base にのみ存在する `console/src/gen/widgets.gleam`、`muses/src/gen/widgets.gleam`、`www/src/gen/widgets.gleam`。(i) 側で新規 file は0。

1回目と2回目の生成物は、`console/_diagnostics/console-runtime.txt` 内の Gleam `Downloaded 11 packages in 0.02s` / `0.01s` だけが異なった。実測差分を比較ファイルに残し、経過秒表示だけを両方 `<elapsed>` に正規化した後の `diff -r` は空。

#### 新規 exit 4 の1行ごとの対応

下の各行は `comm` で得た新規診断1行と対応表の該当行を1対1で結ぶ。`#2/#4` は route / 必須 Args 欄、`#6/#7` は F6 の Block 分割・Page.of 配置欄に照合。`console/layout` と `www/search` は今回見えた追加ケースとして下記の追加予測行を置いた。

| # | 新規 exit 4 行 | 対応する表の行 |
|---:|---|---|
| 001 | `console/layout.gleam`: [変数 6] Block ConsoleHeader In In は Service.Out / Nil ではない | 追加予測行: `console/layout.gleam` |
| 002 | `console/pages/api_key/page.gleam`: [変数 6] Block ApiKeyPage In In は Service.Out / Nil ではない | 語彙だけ |
| 003 | `console/pages/consent/page.gleam`: [変数 6] Block ConsentPage In In は Service.Out / Nil ではない | 語彙だけ |
| 004 | `console/pages/page.gleam`: [変数 4] Block/Widget Block StoreSettings の Service.store_read Args.handle が Block Arg / Var に無い | 語彙だけ |
| 005 | `console/pages/rosters/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `console/rosters/arg_id/page.gleam` |
| 006 | `console/pages/rosters/arg_id/page.gleam`: [変数 6] Block RosterEditor In In は Service.Out / Nil ではない | back の1行読み |
| 007 | `console/pages/rosters/arg_id/photos/arg_order/remove/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `console/rosters/arg_id/photos/arg_order/remove/page.gleam` |
| 008 | `console/pages/rosters/arg_id/photos/arg_order/remove/page.gleam`: [変数 2] arg_order 段を指す Path Var が無い | 0.10 予測表: `console/rosters/arg_id/photos/arg_order/remove/page.gleam` |
| 009 | `console/pages/rosters/arg_id/photos/arg_order/remove/page.gleam`: [変数 6] Block RosterPhotoRemoveConfirm In In は Service.Out / Nil ではない | 語彙だけ |
| 010 | `console/pages/rosters/arg_id/remove/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `console/rosters/arg_id/remove/page.gleam` |
| 011 | `console/pages/rosters/arg_id/remove/page.gleam`: [変数 6] Block RosterRemoveConfirm In String は Service.Out / Nil ではない | 語彙だけ |
| 012 | `console/pages/schedule/page.gleam`: [変数 4] Block/Widget Block SchedulePage の Service.store_schedule_list Args.handle が Block Arg / Var に無い | 語彙だけ |
| 013 | `console/pages/switch/page.gleam`: [変数 6] Block SessionSwitch In In は Service.Out / Nil ではない | back の1行読み |
| 014 | `muses/pages/articles/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `muses/articles/arg_id/page.gleam` |
| 015 | `muses/pages/articles/arg_id/page.gleam`: [変数 6] Block ArticleForm In In は Service.Out / Nil ではない | back の1行読み |
| 016 | `muses/pages/articles/new/page.gleam`: [変数 6] Block ArticleForm In In は Service.Out / Nil ではない | 語彙だけ |
| 017 | `muses/pages/heaven/page.gleam`: [変数 6] Block HeavenPanel In In は Service.Out / Nil ではない | 0.10 予測表: `muses/heaven/page.gleam` |
| 018 | `muses/pages/heaven/page.gleam`: [変数 7] Page.of Service.MuseRead を描く Block が placements に無い | 0.10 予測表: `muses/heaven/page.gleam` |
| 019 | `muses/pages/links/page.gleam`: [変数 6] Block LinkList In In は Service.Out / Nil ではない | 0.10 予測表: `muses/links/page.gleam` |
| 020 | `muses/pages/links/page.gleam`: [変数 7] Page.of Service.MuseRead を描く Block が placements に無い | 0.10 予測表: `muses/links/page.gleam` |
| muses/src/pages/metrics/page.gleam | handle: Session(SubjectHandle), from/to: Query | metrics_dashboard(from/to: Option(String)) | metrics_dashboard(In: metrics_muse.Out) | metrics_muse.Args(from: Date, to: Date) → both Option(Date), defaults DefaultMetricsFrom/DefaultMetricsTo held by back | back の Args の形を変える |
| 022 | `muses/pages/page/page.gleam`: [変数 4] Block/Widget Block SpaceList の Service.space_list Args.handle が Block Arg / Var に無い | 0.10 予測表: `muses/page/page.gleam` |
| 023 | `muses/pages/page/page.gleam`: [変数 4] Block/Widget Block ThemeForm の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `muses/page/page.gleam` |
| muses/src/pages/page/page.gleam | handle: Session(SubjectHandle), selected: Query(space), space: Query(space) | widget_list(space: Place) | widget_list(In: widget_list.Out) | widget_list.Args(space: Place) → back accepts space: Option(Place), default AllPlaces | back の Args の形を変える |
| muses/src/pages/page/page.gleam | handle: Session(SubjectHandle), selected: Query(space), space: Query(space) | widget_list(space: Place) | widget_list(In: widget_list.Out) | widget_list.Args(space: Place) → back accepts space: Option(Place), default AllPlaces | back の Args の形を変える |
| 026 | `muses/pages/page/widget/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `muses/page/widget/arg_id/page.gleam` |
| 027 | `muses/pages/page/widget/arg_id/page.gleam`: [変数 6] Block WidgetForm In In は Service.Out / Nil ではない | back の1行読み |
| 028 | `muses/pages/page/widget/new/page.gleam`: [変数 6] Block WidgetForm In In は Service.Out / Nil ではない | 語彙だけ |
| 029 | `muses/pages/page.gleam`: [変数 6] Block Home In In は Service.Out / Nil ではない | 0.10 予測表: `muses/page.gleam` |
| 030 | `muses/pages/page.gleam`: [変数 7] Page.of Service.MuseRead を描く Block が placements に無い | 0.10 予測表: `muses/page.gleam` |
| 031 | `muses/pages/settings/page.gleam`: [変数 4] Block/Widget Block ThemeForm の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `muses/settings/page.gleam` |
| 032 | `muses/pages/settings/page.gleam`: [変数 6] Block Settings In In は Service.Out / Nil ではない | back の1行読み |
| 033 | `muses/pages/settings/unclaim/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `muses/settings/unclaim/arg_id/page.gleam` |
| 034 | `muses/pages/settings/unclaim/arg_id/page.gleam`: [変数 6] Block UnclaimConfirm In In は Service.Out / Nil ではない | 0.10 予測表: `muses/settings/unclaim/arg_id/page.gleam` |
| 035 | `muses/pages/settings/unclaim/arg_id/page.gleam`: [変数 7] Page.of Service.RosterListMine を描く Block が placements に無い | 0.10 予測表: `muses/settings/unclaim/arg_id/page.gleam` |
| 036 | `www/pages/claim/arg_code/page.gleam`: [変数 2] arg_code 段を指す Path Var が無い | 0.10 予測表: `www/claim/arg_code/page.gleam` |
| 037 | `www/pages/claim/arg_code/page.gleam`: [変数 6] Block ClaimHead In String は Service.Out / Nil ではない | 語彙だけ |
| 038 | `www/pages/experiences/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `www/experiences/arg_id/page.gleam` |
| 039 | `www/pages/fan/arg_handle/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/fan/arg_handle/page.gleam` |
| 040 | `www/pages/me/chats/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `www/me/chats/arg_id/page.gleam` |
| 041 | `www/pages/me/experiences/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `www/me/experiences/arg_id/page.gleam` |
| 042 | `www/pages/muse/arg_handle/article/arg_id/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/muse/arg_handle/article/arg_id/page.gleam` |
| 043 | `www/pages/muse/arg_handle/article/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `www/muse/arg_handle/article/arg_id/page.gleam` |
| 044 | `www/pages/muse/arg_handle/article/arg_id/page.gleam`: [変数 4] Block/Widget Block ArticleBody の Service.article_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/article/arg_id/page.gleam` |
| 045 | `www/pages/muse/arg_handle/article/arg_id/page.gleam`: [変数 4] Block/Widget Block ArticleBody の Service.article_read Args.id が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/article/arg_id/page.gleam` |
| 046 | `www/pages/muse/arg_handle/article/arg_id/page.gleam`: [変数 4] Block/Widget Block ArticleHead の Service.article_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/article/arg_id/page.gleam` |
| 047 | `www/pages/muse/arg_handle/article/arg_id/page.gleam`: [変数 4] Block/Widget Block ArticleHead の Service.article_read Args.id が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/article/arg_id/page.gleam` |
| 048 | `www/pages/muse/arg_handle/article/arg_id/page.gleam`: [変数 4] Block/Widget Block MuseNav の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/article/arg_id/page.gleam` |
| 049 | `www/pages/muse/arg_handle/article/arg_id/page.gleam`: [変数 4] Block/Widget Block StoreMemberships の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/article/arg_id/page.gleam` |
| 050 | `www/pages/muse/arg_handle/article/arg_id/page.gleam`: [変数 6] Block MuseHeader In In は Service.Out / Nil ではない | 0.10 予測表: `www/muse/arg_handle/article/arg_id/page.gleam` |
| 051 | `www/pages/muse/arg_handle/article/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/muse/arg_handle/article/page.gleam` |
| 052 | `www/pages/muse/arg_handle/article/page.gleam`: [変数 4] Block/Widget Block ArticleList の Service.article_list Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/article/page.gleam` |
| 053 | `www/pages/muse/arg_handle/article/page.gleam`: [変数 4] Block/Widget Block MuseNav の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/article/page.gleam` |
| 054 | `www/pages/muse/arg_handle/article/page.gleam`: [変数 4] Block/Widget Block StoreMemberships の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/article/page.gleam` |
| 055 | `www/pages/muse/arg_handle/article/page.gleam`: [変数 6] Block MuseHeader In In は Service.Out / Nil ではない | 0.10 予測表: `www/muse/arg_handle/article/page.gleam` |
| 056 | `www/pages/muse/arg_handle/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/muse/arg_handle/page.gleam` |
| 057 | `www/pages/muse/arg_handle/page.gleam`: [変数 4] Block/Widget Block MuseNav の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/page.gleam` |
| 058 | `www/pages/muse/arg_handle/page.gleam`: [変数 4] Block/Widget Block StoreMemberships の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/page.gleam` |
| 059 | `www/pages/muse/arg_handle/page.gleam`: [変数 4] Block/Widget Widget の Service.widget_list Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/page.gleam` |
| 060 | `www/pages/muse/arg_handle/page.gleam`: [変数 4] Block/Widget Widget の Service.widget_list Args.space が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/page.gleam` |
| www/src/pages/muse/arg_handle/page.gleam | current F6: handle Path, space Query; 22:30 target: muse=[handle] | widget_list.Args(handle: Handle, space: Place, widget: Option(WidgetKey)) | Widget(of: WidgetList, render: ByKind), slot name removed | proposed muse_widget_list.Args(muse: Handle), back default Top | back の Args の形を変える |
| 062 | `www/pages/muse/arg_handle/reserve/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/muse/arg_handle/reserve/page.gleam` |
| 063 | `www/pages/muse/arg_handle/reviews/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/muse/arg_handle/reviews/page.gleam` |
| 064 | `www/pages/muse/arg_handle/schedule/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/muse/arg_handle/schedule/page.gleam` |
| 065 | `www/pages/muse/arg_handle/schedule/page.gleam`: [変数 4] Block/Widget Block MuseNav の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/schedule/page.gleam` |
| 066 | `www/pages/muse/arg_handle/schedule/page.gleam`: [変数 4] Block/Widget Block ScheduleList の Service.schedule_list Args.from が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/schedule/page.gleam` |
| 067 | `www/pages/muse/arg_handle/schedule/page.gleam`: [変数 4] Block/Widget Block ScheduleList の Service.schedule_list Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/schedule/page.gleam` |
| 068 | `www/pages/muse/arg_handle/schedule/page.gleam`: [変数 4] Block/Widget Block StoreMemberships の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/schedule/page.gleam` |
| 069 | `www/pages/muse/arg_handle/schedule/page.gleam`: [変数 6] Block MuseHeader In In は Service.Out / Nil ではない | 0.10 予測表: `www/muse/arg_handle/schedule/page.gleam` |
| 070 | `www/pages/muse/arg_handle/space/arg_id/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/muse/arg_handle/space/arg_id/page.gleam` |
| 071 | `www/pages/muse/arg_handle/space/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `www/muse/arg_handle/space/arg_id/page.gleam` |
| 072 | `www/pages/muse/arg_handle/space/arg_id/page.gleam`: [変数 4] Block/Widget Block MuseNav の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/space/arg_id/page.gleam` |
| 073 | `www/pages/muse/arg_handle/space/arg_id/page.gleam`: [変数 4] Block/Widget Block StoreMemberships の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/space/arg_id/page.gleam` |
| 074 | `www/pages/muse/arg_handle/space/arg_id/page.gleam`: [変数 4] Block/Widget Widget の Service.widget_list Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/space/arg_id/page.gleam` |
| 075 | `www/pages/muse/arg_handle/space/arg_id/page.gleam`: [変数 4] Block/Widget Widget の Service.widget_list Args.space が Block Arg / Var に無い | 0.10 予測表: `www/muse/arg_handle/space/arg_id/page.gleam` |
| www/src/pages/muse/arg_handle/space/arg_id/page.gleam | handle/id/space: Path | space_title plus ByKind Widget | space_title(In: space_read.Out); Widget(of: SpaceWidgetList, render: ByKind), Blocks In widget_list.Row | space_read(handle,id); space_widget_list(handle,space) | back の1行読み |
| www/src/pages/muse/arg_handle/space/arg_id/page.gleam | handle/id/space: Path | space_title plus ByKind Widget | space_title(In: space_read.Out); Widget(of: SpaceWidgetList, render: ByKind), Blocks In widget_list.Row | space_read(handle,id); space_widget_list(handle,space) | back の1行読み |
| www/src/pages/muse/arg_handle/space/arg_id/page.gleam | handle/id/space: Path | space_title plus ByKind Widget | space_title(In: space_read.Out); Widget(of: SpaceWidgetList, render: ByKind), Blocks In widget_list.Row | space_read(handle,id); space_widget_list(handle,space) | back の1行読み |
| 079 | `www/pages/muse/arg_handle/tweets/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/muse/arg_handle/tweets/page.gleam` |
| 080 | `www/pages/search/page.gleam`: [変数 4] Block/Widget Block SearchResults の Service.article_search Args.q が Block Arg / Var に無い | 追加予測行: `www/search/page.gleam` |
| 081 | `www/pages/store/arg_handle/cast/arg_id/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/store/arg_handle/cast/arg_id/page.gleam` |
| 082 | `www/pages/store/arg_handle/cast/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `www/store/arg_handle/cast/arg_id/page.gleam` |
| 083 | `www/pages/store/arg_handle/cast/arg_id/page.gleam`: [変数 4] Block/Widget Block CastProfile の Service.roster_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/store/arg_handle/cast/arg_id/page.gleam` |
| 084 | `www/pages/store/arg_handle/cast/arg_id/page.gleam`: [変数 4] Block/Widget Block CastProfile の Service.roster_read Args.id が Block Arg / Var に無い | 0.10 予測表: `www/store/arg_handle/cast/arg_id/page.gleam` |
| 085 | `www/pages/store/arg_handle/cast/arg_id/page.gleam`: [変数 6] Block StoreSchedule In In は Service.Out / Nil ではない | 0.10 予測表: `www/store/arg_handle/cast/arg_id/page.gleam` |
| 086 | `www/pages/store/arg_handle/page.gleam`: [変数 2] arg_handle 段を指す Path Var が無い | 0.10 予測表: `www/store/arg_handle/page.gleam` |
| 087 | `www/pages/store/arg_handle/page.gleam`: [変数 4] Block/Widget Block StoreHead の Service.store_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `www/store/arg_handle/page.gleam` |
| 088 | `www/pages/store/arg_handle/page.gleam`: [変数 6] Block RosterList In In は Service.Out / Nil ではない | 0.10 予測表: `www/store/arg_handle/page.gleam` |
| 089 | `www/pages/store/arg_handle/page.gleam`: [変数 6] Block StoreSchedule In In は Service.Out / Nil ではない | 0.10 予測表: `www/store/arg_handle/page.gleam` |

既存 `article_read` は `id` / `handle` が必須で、Draft を返す API 実装を確認済み。残る新規 Service module 6本は F6 表の欄だけでは生成器の exit 4 実測に置き換わらない。

### Page / Layout const の `vars` 全件

`rg -l 'pub const page: Page' <snapshot>/{www,muses,console}/src/pages/**` の各 file と `pub const (www|muses|console): Layout` を数えた。内訳は www 31 / muses 14 / console 11 / Layout 3 = 59 const。下表は各 const に足す `vars:` の 1 行。

| const file | `vars:` |
|---|---|
| `www/src/pages/about/external/page.gleam` | `[]` |
| `www/src/pages/claim/arg_code/page.gleam` | 語彙だけ |
| `www/src/pages/experiences/arg_id/page.gleam` | `[Var("id", Path("id"))]` |
| `www/src/pages/fan/arg_handle/page.gleam` | `[Var("handle", Path("handle"))]` |
| `www/src/pages/for_stores/api/v1/page.gleam` | `[]` |
| `www/src/pages/me/chats/arg_id/page.gleam` | `[Var("id", Path("id"))]` |
| `www/src/pages/me/chats/page.gleam` | `[]` |
| `www/src/pages/me/experiences/arg_id/page.gleam` | `[Var("id", Path("id"))]` |
| `www/src/pages/me/experiences/page.gleam` | `[]` |
| `www/src/pages/me/feed/page.gleam` | `[]` |
| `www/src/pages/me/inbox/page.gleam` | `[Var("after", Query("after"))]` |
| `www/src/pages/me/page.gleam` | `[Var("after", Query("after"))]` |
| `www/src/pages/me/reservations/page.gleam` | `[]` |
| `www/src/pages/me/reviews/new/page.gleam` | `[]` |
| `www/src/pages/me/settings/page.gleam` | `[]` |
| `www/src/pages/me/subscriptions/page.gleam` | `[]` |
| `www/src/pages/muse/arg_handle/article/arg_id/page.gleam` | `[Var("handle", Path("handle")), Var("id", Path("id"))]` |
| `www/src/pages/muse/arg_handle/article/page.gleam` | `[Var("handle", Path("handle")), Var("cursor", Query("cursor"))]` |
| www/src/pages/muse/arg_handle/page.gleam | current F6: handle Path, space Query; 22:30 target: muse=[handle] | widget_list.Args(handle: Handle, space: Place, widget: Option(WidgetKey)) | Widget(of: WidgetList, render: ByKind), slot name removed | proposed muse_widget_list.Args(muse: Handle), back default Top | back の Args の形を変える |
| `www/src/pages/muse/arg_handle/reserve/page.gleam` | `[Var("handle", Path("handle"))]` |
| `www/src/pages/muse/arg_handle/reviews/page.gleam` | `[Var("handle", Path("handle"))]` |
| `www/src/pages/muse/arg_handle/schedule/page.gleam` | `[Var("handle", Path("handle")), Var("from", Query("from"))]` |
| www/src/pages/muse/arg_handle/space/arg_id/page.gleam | handle/id/space: Path | space_title plus ByKind Widget | space_title(In: space_read.Out); Widget(of: SpaceWidgetList, render: ByKind), Blocks In widget_list.Row | space_read(handle,id); space_widget_list(handle,space) | back の1行読み |
| `www/src/pages/muse/arg_handle/tweets/page.gleam` | `[Var("handle", Path("handle"))]` |
| `www/src/pages/onboard/page.gleam` | `[]` |
| `www/src/pages/page.gleam` | `[]` |
| `www/src/pages/search/page.gleam` | `[Var("q", Query("q"))]` |
| `www/src/pages/store/arg_handle/cast/arg_id/page.gleam` | `[Var("handle", Path("handle")), Var("id", Path("id"))]` |
| `www/src/pages/store/arg_handle/page.gleam` | `[Var("handle", Path("handle"))]` |
| `www/src/pages/tl/page.gleam` | `[]` |
| `www/src/pages/w1_preview/page.gleam` | `[]` |
| `muses/src/pages/articles/arg_id/page.gleam` | back の1行読み |
| `muses/src/pages/articles/new/page.gleam` | 語彙だけ |
| `muses/src/pages/articles/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("cursor", Query("cursor"))]` |
| `muses/src/pages/heaven/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| `muses/src/pages/inbox/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("after", Query("after"))]` |
| `muses/src/pages/links/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| muses/src/pages/metrics/page.gleam | handle: Session(SubjectHandle), from/to: Query | metrics_dashboard(from/to: Option(String)) | metrics_dashboard(In: metrics_muse.Out) | metrics_muse.Args(from: Date, to: Date) → both Option(Date), defaults DefaultMetricsFrom/DefaultMetricsTo held by back | back の Args の形を変える |
| `muses/src/pages/onboard/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| muses/src/pages/page/page.gleam | handle: Session(SubjectHandle), selected: Query(space), space: Query(space) | widget_list(space: Place) | widget_list(In: widget_list.Out) | widget_list.Args(space: Place) → back accepts space: Option(Place), default AllPlaces | back の Args の形を変える |
| `muses/src/pages/page/widget/arg_id/page.gleam` | back の1行読み |
| `muses/src/pages/page/widget/new/page.gleam` | 語彙だけ |
| `muses/src/pages/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("from", Query("from")), Var("to", Query("to"))]` |
| `muses/src/pages/settings/page.gleam` | back の1行読み |
| `muses/src/pages/settings/unclaim/arg_id/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("id", Path("id"))]` |
| `console/src/pages/api_key/page.gleam` | 語彙だけ |
| `console/src/pages/consent/page.gleam` | 語彙だけ |
| `console/src/pages/metrics/page.gleam` | 語彙だけ |
| `console/src/pages/page.gleam` | 語彙だけ |
| `console/src/pages/rosters/arg_id/page.gleam` | back の1行読み |
| `console/src/pages/rosters/arg_id/photos/arg_order/remove/page.gleam` | 語彙だけ |
| `console/src/pages/rosters/arg_id/remove/page.gleam` | 語彙だけ |
| `console/src/pages/rosters/new/page.gleam` | 語彙だけ |
| `console/src/pages/rosters/page.gleam` | 語彙だけ |
| `console/src/pages/schedule/page.gleam` | 語彙だけ |
| `console/src/pages/switch/page.gleam` | back の1行読み |
| `www/src/layout.gleam` | `[]` |
| `muses/src/layout.gleam` | `[]` |
| `console/src/layout.gleam` | `[Var("idp_origin", AuthOrigin), Var("www_origin", Origin("www"))]` |

### BRIEF との差と検証結果

- 対象は21 Page fileで一致。分類は語彙だけ15 / back 1行読み6で BRIEF の推定どおり。back の新規 Service module は `store_roster_read`, `subject_list`, `subject_settings_read`, `widget_read`, `space_read`, `space_widget_list` の6本。`article_read` は既存で、Draft を返すことを API 定義から確認した。DDL変更は無し。
- BRIEF 推定の複合 Block 7本は、F6 の Block module 17本に展開される。settings の同意を除いた分を含む。別裁定で追加した `SpaceMain` はこの7本の外に1 Block。`Arg` は推定14 moduleに対し34 module (+20)。共通 Header / Nav、Widget renderer、ページ外の再利用 Block にも値を渡すため。
- 迷って決めたこと: 空間 route の `id` を `space: Path("id")` としても公開し、`space_widget_list(handle, space)` と Widget renderer の同名 Args に流す。枠名は値にせず、トップの `widget_list(handle, space)` と空間専用 `space_widget_list` に分ける。settings の subjects は `subject_settings_read` に残し、同意 Service / 表示 / helper は削除する。
- `patch --dry-run -p1 -d gen/build/y1f-f6/before < gen/scripts/y1f-f5min.patch`: 68 file を確認。F5 を `verify-chain` に適用後の `diff -qr ... verify-chain mid`: exit 0 / 差分0行。
- `patch --dry-run -p1 -d gen/build/y1f-f6/verify-chain < gen/scripts/y1f-f6.patch` と `... -d gen/build/y1f-f6/mid ...`: 各113 fileを確認。順に当たる。`y1f-f5min.patch` の `vars:` / `Var(` / `Arg(` grep は0。
- `gleam format --check <changed files>`: www 52 file / muses 41 / console 20、3面 exit 0 / formatter output 0行。後続の 0.10.0 本便生成器実測では formatter と 3面 build が停止した。詳細は「snapshot (ii) 実測」。copy 内に無い back Service module は上記6本。
- Page の Block Args と Page/Layout Vars の同名照合: 56 Page を対象に不足0。after の145 `view` module は全て `In` を宣言し、`Arg` module は34。`Var` の出所は `Path` / `Query` / `Session` / `Origin` / `AuthOrigin` のみ。`Literal` / default / variant source は0。
- patch header の `src/gen` 該当0。完了条件4に書かれた `^+++ .*/api/` grep は1行になる: `+++ after/www/src/pages/for_stores/api/v1/page.gleam`。これは WWW の frontend Pageで、backend `api/` は含まない。この Page の `vars: []` は Page 59件をそろえるため必須なので、ファイルを除外していない。
- `git diff --check 355a93a..HEAD`: exit 2、194 trailing whitespace findings。対象は patch artifact 内の空白行 (`+ `)。報告書の whitespace は0件。snapshot source patch の空行は整形していない。


### snapshot (ii) の F6 再走

F5 最小 patch と F6 patch を fresh copy に順番に当てた。生成器は gen から、app dir は copy 内 api。生成物を API と各 face に配置して3面を build した。

| 段 | 生成 stop | file | exit 1 | exit 2 | exit 3 | exit 4 | warning |
|---|---:|---:|---:|---:|---:|---:|---:|
| F5 最小 | 4 | 1372 | 3 | 0 | 1 | 111 | 48 |
| F6 | 4 | 1384 | 3 | 0 | 1 | 51 | 78 |

| 段 / face | build exit | error 数 / source file 数 |
|---|---:|---:|---:|
| F5 / www | 1 | 12 / 10 |
| F5 / muses | 1 | 13 / 12 |
| F5 / console | 1 | 18 / 12 |
| F6 / www | 1 | 11 / 3 |
| F6 / muses | 1 | 16 / 4 |
| F6 / console | 1 | 16 / 4 |

語彙だけの12 Page は SHA-256 header 付き12/12。F6 は F5 と比べ exit 4 が13行増え、73行消えた。新規13行は back の1行読み7行と Query Args の形6行で未分類0。3面 build の error は計43件、すべて back の1行読み Service 欠如 file に閉じ、syntax error は0。roster_row の In を store_roster_list.Row に戻し、Widget Row/Out 型不一致も0にした。

#### F6 新規 exit 4 — file / 区分 / 行数

| file | 区分 | 行数 |
|---|---|---:|
| console/pages/rosters/arg_id/page | back の1行読み | 1 |
| console/pages/switch/page | back の1行読み | 1 |
| muses/pages/page/widget/arg_id/page | back の1行読み | 1 |
| muses/pages/settings/page | back の1行読み | 1 |
| www/pages/muse/arg_handle/space/arg_id/page | back の1行読み | 2 |
| www/service | back の1行読み | 1 |
| muses/pages/metrics/page | back の Args の形 | 2 |
| muses/pages/page | back の Args の形 | 2 |
| muses/pages/page/page | back の Args の形 | 1 |
| www/pages/muse/arg_handle/page | back の Args の形 | 1 |

#### F6 3面 build errors — file / 区分 / 行数

| file | 区分 | 行数 |
|---|---|---:|
| www/src/blocks/space_title.gleam | back の1行読み | 5 |
| www/src/gen/skeleton/space_title.gleam | back の1行読み | 4 |
| www/src/pages/muse/arg_handle/space/arg_id/page.gleam | back の1行読み | 2 |
| muses/src/blocks/settings_subjects.gleam | back の1行読み | 4 |
| muses/src/blocks/widget_form_edit.gleam | back の1行読み | 4 |
| muses/src/gen/skeleton/settings_subjects.gleam | back の1行読み | 4 |
| muses/src/gen/skeleton/widget_form_edit.gleam | back の1行読み | 4 |
| console/src/blocks/roster_editor.gleam | back の1行読み | 4 |
| console/src/blocks/session_switch.gleam | back の1行読み | 4 |
| console/src/gen/skeleton/roster_editor.gleam | back の1行読み | 4 |
| console/src/gen/skeleton/session_switch.gleam | back の1行読み | 4 |

F6 の未実装 Service は store_roster_read, subject_list, subject_settings_read, widget_read, space_read, space_widget_list。API Service Args は変更していない。全数値と2表は gen/build/y1f-r20-snap-ii-summary.txt に保存。
## 51 v5 に足す文

tech canon `/home/yumemism/canonical/tech/_drafts/gleam-framework/63-page-variables.v0.md` の「51 v5 で直す節」5項を反映する。

1. **型一覧:** Page / Layout に `vars`、`Var` / `From` / `SessionKey` を足す。Block は `view(In, Arg)` とし、`Arg` は `In` の Service Out と別の入力口にする。
2. **Page route:** `Path` / `Query` の Page 変数から同名 Block `Arg` を経由して Service `Args` へ渡す形にする。URL に無い Args は query string で受ける。exit 4 は検査2に記す。
3. **Page / Layout:** Page が持つ値と `vars:` 例を明記し、設定値の宣言は Layout に置く。
4. **入口と生成器出力:** loader の引数と `shell.mjs` の Path / Query / Session / Origin 解決を記す。手書きの便も `view` を2引数にする。
5. **書けないもの:** Page から Service を名指す `reads`、`In` に Service Out を2本束ねる形、session から計算した値を持ち込む形を禁止事項に置く。

constructor 名は `Track.Auto` と `TrackSize.AutoSize`。Gleam の module namespace が同じ `Auto` の衝突を許さないため、TrackSize 側だけ `AutoSize` とする。tech canon の注意どおり、gen-7 の `reads` 文は51 v5へ写さない。

## 基線と最終値

| 項目 | 基線 | 最終実測 |
|---|---|---|
| root `gleam build` | exit 0 / warning 1 | exit 0 / warning 1。`build/y1f-r19-root-build.txt` |
| `cd gen && gleam test` | 181 passed | 192 passed, no failures。`gen/build/y1f-r19-gen-test.txt` |
| Article fixture | 92 file | fresh output 112 fileを2回、両 exit 0、diff 0行。`gen/build/y1f-r19-fixture-clean-{one,two}.log`、`...-diff.txt` |
| snapshot (i) | exit 1=3 / 2=0 / 3=1 / 4=22 / warning=48 / 1375 file | fresh copy 2回とも stop 4 / exit 1=3 / 2=0 / 3=1 / 4=111 / warning=48 / 1372 file。前 run と exit4 set 同一111、追加0 / 消失0 / 未分類0。生成部分 diff0、diagnostics 込み全出力 diff0。`gen/build/y1f-r19-snap-i-summary.txt` |
| snapshot (ii) F5 最小 | — | fresh copy: stop4、exit 1/2/3/4=3/0/1/111、warning48、1372 file。3面 build exit1、errors 12/13/18。gen/build/y1f-r20-snap-ii-summary.txt |
| snapshot (ii) F6 | — | fresh copy: stop4、exit 1/2/3/4=3/0/1/51、warning78、1384 file。語彙-only SHA header 12/12。3面 build exit1、errors 11/16/16、syntax 0。新規 exit4 13行は2区分、build errors 43件はback 1行読みに閉じる。gen/build/y1f-r20-snap-ii-summary.txt |
| verify | — | SSR / isolate / given / file / overlay は ALL PASS。Block preview public 7 / admin 1 も PASS。`gen/build/y1f-r19-verify-{ssr,isolate,given,file,overlay,blocks}.txt` |
