## DDL

無し。`git diff --stat 355a93a -- db/ gen/fixtures/article/db/` は空。

## 鷹野宛

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

Y1e の「値の出所の穴」27 行を Page file でまとめると 21 file。BRIEF の www 3 / muses 7 / console 11 と一致した。Page の `vars` は Page 自身の値。console の共通設定は Layout の `Var("idp_origin", AuthOrigin)` と `Var("www_origin", Origin("www"))` から Block の同名 `Arg` に流す。設定 env は `Origin(face)` → `PUBLIC_<FACE>_ORIGIN`、`AuthOrigin` → `PUBLIC_IDP_ORIGIN`。生成器 source の `gen/src/yumemi_gen/emit/front.gleam` と shell check を確認した。

| Page file | Page `vars` | Block `Arg` | 割る Block | 要る back の Service | 区分 |
|---|---|---|---|---|---|
| `console/src/pages/rosters/arg_id/page.gleam` | `handle: Session(SubjectHandle)`, `id: Path("id")` | `roster_editor(id: String, www_origin: String)`; `console_header(idp_origin: String)` | `roster_editor(In: Option(store_roster_list.Row))` → `In = store_roster_read.Out` | `store_roster_read(id) → Out(roster: roster.Owned, phase: roster.Phase, photos: List(roster_photo.RosterPhoto))` | back の 1 行読み |
| `console/src/pages/rosters/arg_id/remove/page.gleam` | `id: Path("id")` | `roster_remove_confirm(id: String)`; header は `idp_origin` | `roster_remove_confirm(In: String)` → `In = Nil` | 無し | 語彙だけ |
| `console/src/pages/rosters/arg_id/photos/arg_order/remove/page.gleam` | `id: Path("id")`, `order: Path("order")` | `roster_photo_remove_confirm(id: String, order: String)`; header は `idp_origin` | `roster_photo_remove_confirm(In: {id, order})` → `In = Nil` | 無し | 語彙だけ |
| `console/src/pages/api_key/page.gleam` | `[]` | `console_header(idp_origin: String)`, `api_key_page(www_origin: String)` | 無し | 無し | 語彙だけ |
| `console/src/pages/consent/page.gleam` | `[]` | `console_header(idp_origin: String)`, `consent_page(idp_origin: String)` | 無し | 無し | 語彙だけ |
| `console/src/pages/metrics/page.gleam` | `handle: Session(SubjectHandle)`, `from: Query("from")`, `to: Query("to")` | header は `idp_origin` | `metrics_page(In: metrics_store.Out)` はそのまま | 無し | 語彙だけ |
| `console/src/pages/page.gleam` | `handle: Session(SubjectHandle)` | header は `idp_origin` | 無し | 無し | 語彙だけ |
| `console/src/pages/rosters/new/page.gleam` | `[]` | header は `idp_origin` | 無し | 無し | 語彙だけ |
| `console/src/pages/rosters/page.gleam` | `handle: Session(SubjectHandle)` | `roster_list(handle: String)`; header は `idp_origin` | 無し | 無し | 語彙だけ |
| `console/src/pages/schedule/page.gleam` | `handle: Session(SubjectHandle)` | header は `idp_origin` | 無し | 無し | 語彙だけ |
| `console/src/pages/switch/page.gleam` | `[]` | `session_switch(idp_origin: String)`; header は `idp_origin` | `session_switch(In: {has_store: Bool, idp_origin: String})` → `In = subject_list.Out`; 空判定は `stores` の空/非空 | `subject_list() → Out(stores: List(Store))` | back の 1 行読み |
| `muses/src/pages/articles/arg_id/page.gleam` | `handle: Session(SubjectHandle)`, `id: Path("id")` | `article_edit(handle: String, id: String)` | `article_form(Edit(...))` → `article_edit(In: article_read.Out)`、新規は `article_new(In: Nil)`。共通フォームは Component | 既存 `article_read(id, handle) → Out(article, phase, muse)`。`api/src/service/article_read.gleam` の AsMuse / AnyPhase により Draft も読める | back の 1 行読み |
| `muses/src/pages/page/widget/arg_id/page.gleam` | `handle: Session(SubjectHandle)`, `id: Path("id")`, `selected: Query("space")` | `widget_form_edit(handle: String, id: String)` | `widget_form(Mode.Edit(...))` → `widget_form_edit(In: widget_read.Out)`; 新規フォームと編集フォームを分け、共通フォームは Component | `widget_read(handle, id) → Out(row: widget_list.Row)` | back の 1 行読み |
| `muses/src/pages/articles/new/page.gleam` | `handle: Session(SubjectHandle)` | `article_new` は引数なしの view | `article_form(New)` → `article_new(In: Nil)`、共通フォームは Component | 無し | 語彙だけ |
| `muses/src/pages/page/widget/new/page.gleam` | `handle: Session(SubjectHandle)`, `kind: Query("kind")`, `space: Query("space")`, `selected: Query("space")` | `widget_form(handle: String, kind: Option(String), space: Option(String))` | `widget_form` は new、`widget_form_edit` は edit。共通フォームは Component | 無し | 語彙だけ |
| `muses/src/pages/page/page.gleam` | `handle: Session(SubjectHandle)`, `selected: Query("space")`, `space: Query("space")` | `space_selector(selected: Option(String))`; `widget_list(selected: Option(String))`; 他は無し | `widget_list(In: {widgets, spaces, selected})` → `widget_list(In: widget_list.Out)` + `widget_space(In: space_list.Out)` | 無し | 語彙だけ |
| `muses/src/pages/settings/page.gleam` | `handle: Session(SubjectHandle)` | 設定の分割 Block は back Out を直接読む | `settings(In: {muse, rosters, subjects, consents})` → `settings_profile(In: muse_read.Out)`, `settings_rosters(In: roster_list_mine.Out)`, `settings_subjects(In: subject_settings_read.Out)`。同意表示と同意用 Block / Service は削除 | `subject_settings_read() → Out(subjects: List(#(String, String, Bool)))`。consents は含めない | back の 1 行読み |
| `muses/src/pages/metrics/page.gleam` | `handle: Session(SubjectHandle)`, `from: Query("from")`, `to: Query("to")` | `metrics_dashboard(from: Option(String), to: Option(String))` | `metrics_dashboard(In: {metrics, from, to})` → `In = metrics_muse.Out` | 無し | 語彙だけ |
| `www/src/pages/claim/arg_code/page.gleam` | `code: Path("code")` | `claim_head(code: String)` | `claim_head(In: String)` → `In = Nil` | 無し | 語彙だけ |
| `www/src/pages/muse/arg_handle/space/arg_id/page.gleam` | `handle: Path("handle")`, `id: Path("id")`, `space: Path("id")` | `space_title(handle: String, id: String)`; `SpaceMain` は `handle` / `space` を受ける | `space_title(In: space_list.FreeSpace)` → `In = space_read.Out`; `Widget(name: "space_main")` → `Fixed(SpaceMain)`, `In = space_widget_list.Out` | `space_read(handle, id) → Out(space: free_space.FreeSpace)`; `space_widget_list(handle, space) → Out(widgets: List(widget_list.Row))` | back の 1 行読み |
| `www/src/pages/muse/arg_handle/page.gleam` | `handle: Path("handle")`, `space: Query("space")` | `muse_header(handle: String)`, `subscription_action(handle: String)`, widget renderer Blocks は `handle` / `space` | `muse_header(In: {page: muse_read.Out, subscription: Option(subscription_read.Out)})` → `muse_header(In: muse_read.Out)` + `subscription_action(In: subscription_read.Out)` | Widget は `Widget(area, of: widget_list, render)`。`widget_list(handle, space) → Out(widgets: List(Row))` は同名 Page Vars から取る。枠名由来の Service Arg は無い | 語彙だけ |

記事編集 Page は保存済み Article を1件読む必要があるため「back の1行読み」に分類した。snapshot API の `api/src/service/article_read.gleam:22-54` には既存の `article_read(id, handle)` があり、Out は `article, phase, muse`。AsMuse + AnyPhase と owner handle check により所有者は Draft を読める。新しい Service module は要らない。表の back Service のうち、`store_roster_read` / `subject_list` / `subject_settings_read` / `widget_read` / `space_read` / `space_widget_list` は F6 が必要形を申し送る新規 Service。API はこの便で変更しない。

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
| 002 | `console/pages/api_key/page.gleam`: [変数 6] Block ApiKeyPage In In は Service.Out / Nil ではない | F6 表: `console/src/pages/api_key/page.gleam` |
| 003 | `console/pages/consent/page.gleam`: [変数 6] Block ConsentPage In In は Service.Out / Nil ではない | F6 表: `console/src/pages/consent/page.gleam` |
| 004 | `console/pages/page.gleam`: [変数 4] Block/Widget Block StoreSettings の Service.store_read Args.handle が Block Arg / Var に無い | F6 表: `console/src/pages/page.gleam` |
| 005 | `console/pages/rosters/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `console/rosters/arg_id/page.gleam` |
| 006 | `console/pages/rosters/arg_id/page.gleam`: [変数 6] Block RosterEditor In In は Service.Out / Nil ではない | F6 表: `console/src/pages/rosters/arg_id/page.gleam` |
| 007 | `console/pages/rosters/arg_id/photos/arg_order/remove/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `console/rosters/arg_id/photos/arg_order/remove/page.gleam` |
| 008 | `console/pages/rosters/arg_id/photos/arg_order/remove/page.gleam`: [変数 2] arg_order 段を指す Path Var が無い | 0.10 予測表: `console/rosters/arg_id/photos/arg_order/remove/page.gleam` |
| 009 | `console/pages/rosters/arg_id/photos/arg_order/remove/page.gleam`: [変数 6] Block RosterPhotoRemoveConfirm In In は Service.Out / Nil ではない | F6 表: `console/src/pages/rosters/arg_id/photos/arg_order/remove/page.gleam` |
| 010 | `console/pages/rosters/arg_id/remove/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `console/rosters/arg_id/remove/page.gleam` |
| 011 | `console/pages/rosters/arg_id/remove/page.gleam`: [変数 6] Block RosterRemoveConfirm In String は Service.Out / Nil ではない | F6 表: `console/src/pages/rosters/arg_id/remove/page.gleam` |
| 012 | `console/pages/schedule/page.gleam`: [変数 4] Block/Widget Block SchedulePage の Service.store_schedule_list Args.handle が Block Arg / Var に無い | F6 表: `console/src/pages/schedule/page.gleam` |
| 013 | `console/pages/switch/page.gleam`: [変数 6] Block SessionSwitch In In は Service.Out / Nil ではない | F6 表: `console/src/pages/switch/page.gleam` |
| 014 | `muses/pages/articles/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `muses/articles/arg_id/page.gleam` |
| 015 | `muses/pages/articles/arg_id/page.gleam`: [変数 6] Block ArticleForm In In は Service.Out / Nil ではない | F6 表: `muses/src/pages/articles/arg_id/page.gleam` |
| 016 | `muses/pages/articles/new/page.gleam`: [変数 6] Block ArticleForm In In は Service.Out / Nil ではない | F6 表: `muses/src/pages/articles/new/page.gleam` |
| 017 | `muses/pages/heaven/page.gleam`: [変数 6] Block HeavenPanel In In は Service.Out / Nil ではない | 0.10 予測表: `muses/heaven/page.gleam` |
| 018 | `muses/pages/heaven/page.gleam`: [変数 7] Page.of Service.MuseRead を描く Block が placements に無い | 0.10 予測表: `muses/heaven/page.gleam` |
| 019 | `muses/pages/links/page.gleam`: [変数 6] Block LinkList In In は Service.Out / Nil ではない | 0.10 予測表: `muses/links/page.gleam` |
| 020 | `muses/pages/links/page.gleam`: [変数 7] Page.of Service.MuseRead を描く Block が placements に無い | 0.10 予測表: `muses/links/page.gleam` |
| 021 | `muses/pages/metrics/page.gleam`: [変数 6] Block MetricsDashboard In In は Service.Out / Nil ではない | F6 表: `muses/src/pages/metrics/page.gleam` |
| 022 | `muses/pages/page/page.gleam`: [変数 4] Block/Widget Block SpaceList の Service.space_list Args.handle が Block Arg / Var に無い | 0.10 予測表: `muses/page/page.gleam` |
| 023 | `muses/pages/page/page.gleam`: [変数 4] Block/Widget Block ThemeForm の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `muses/page/page.gleam` |
| 024 | `muses/pages/page/page.gleam`: [変数 6] Block SpaceSelector In In は Service.Out / Nil ではない | F6 表: `muses/src/pages/page/page.gleam` |
| 025 | `muses/pages/page/page.gleam`: [変数 6] Block WidgetList In In は Service.Out / Nil ではない | F6 表: `muses/src/pages/page/page.gleam` |
| 026 | `muses/pages/page/widget/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `muses/page/widget/arg_id/page.gleam` |
| 027 | `muses/pages/page/widget/arg_id/page.gleam`: [変数 6] Block WidgetForm In In は Service.Out / Nil ではない | F6 表: `muses/src/pages/page/widget/arg_id/page.gleam` |
| 028 | `muses/pages/page/widget/new/page.gleam`: [変数 6] Block WidgetForm In In は Service.Out / Nil ではない | F6 表: `muses/src/pages/page/widget/new/page.gleam` |
| 029 | `muses/pages/page.gleam`: [変数 6] Block Home In In は Service.Out / Nil ではない | 0.10 予測表: `muses/page.gleam` |
| 030 | `muses/pages/page.gleam`: [変数 7] Page.of Service.MuseRead を描く Block が placements に無い | 0.10 予測表: `muses/page.gleam` |
| 031 | `muses/pages/settings/page.gleam`: [変数 4] Block/Widget Block ThemeForm の Service.muse_read Args.handle が Block Arg / Var に無い | 0.10 予測表: `muses/settings/page.gleam` |
| 032 | `muses/pages/settings/page.gleam`: [変数 6] Block Settings In In は Service.Out / Nil ではない | F6 表: `muses/src/pages/settings/page.gleam` |
| 033 | `muses/pages/settings/unclaim/arg_id/page.gleam`: [変数 2] arg_id 段を指す Path Var が無い | 0.10 予測表: `muses/settings/unclaim/arg_id/page.gleam` |
| 034 | `muses/pages/settings/unclaim/arg_id/page.gleam`: [変数 6] Block UnclaimConfirm In In は Service.Out / Nil ではない | 0.10 予測表: `muses/settings/unclaim/arg_id/page.gleam` |
| 035 | `muses/pages/settings/unclaim/arg_id/page.gleam`: [変数 7] Page.of Service.RosterListMine を描く Block が placements に無い | 0.10 予測表: `muses/settings/unclaim/arg_id/page.gleam` |
| 036 | `www/pages/claim/arg_code/page.gleam`: [変数 2] arg_code 段を指す Path Var が無い | 0.10 予測表: `www/claim/arg_code/page.gleam` |
| 037 | `www/pages/claim/arg_code/page.gleam`: [変数 6] Block ClaimHead In String は Service.Out / Nil ではない | F6 表: `www/src/pages/claim/arg_code/page.gleam` |
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
| 061 | `www/pages/muse/arg_handle/page.gleam`: [変数 6] Block MuseHeader In In は Service.Out / Nil ではない | F6 表: `www/src/pages/muse/arg_handle/page.gleam` |
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
| 076 | `www/pages/muse/arg_handle/space/arg_id/page.gleam`: [変数 6] Block MuseHeader In In は Service.Out / Nil ではない | F6 表: `www/src/pages/muse/arg_handle/space/arg_id/page.gleam` |
| 077 | `www/pages/muse/arg_handle/space/arg_id/page.gleam`: [変数 6] Block SpaceTitle In FreeSpace は Service.Out / Nil ではない | F6 表: `www/src/pages/muse/arg_handle/space/arg_id/page.gleam` |
| 078 | `www/pages/muse/arg_handle/space/arg_id/page.gleam`: [変数 7] Page.of Service.SpaceList を描く Block が placements に無い | F6 表: `www/src/pages/muse/arg_handle/space/arg_id/page.gleam` |
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
| `www/src/pages/claim/arg_code/page.gleam` | `[Var("code", Path("code"))]` |
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
| `www/src/pages/muse/arg_handle/page.gleam` | `[Var("handle", Path("handle")), Var("space", Query("space"))]` |
| `www/src/pages/muse/arg_handle/reserve/page.gleam` | `[Var("handle", Path("handle"))]` |
| `www/src/pages/muse/arg_handle/reviews/page.gleam` | `[Var("handle", Path("handle"))]` |
| `www/src/pages/muse/arg_handle/schedule/page.gleam` | `[Var("handle", Path("handle")), Var("from", Query("from"))]` |
| `www/src/pages/muse/arg_handle/space/arg_id/page.gleam` | `[Var("handle", Path("handle")), Var("id", Path("id")), Var("space", Path("id"))]` |
| `www/src/pages/muse/arg_handle/tweets/page.gleam` | `[Var("handle", Path("handle"))]` |
| `www/src/pages/onboard/page.gleam` | `[]` |
| `www/src/pages/page.gleam` | `[]` |
| `www/src/pages/search/page.gleam` | `[Var("q", Query("q"))]` |
| `www/src/pages/store/arg_handle/cast/arg_id/page.gleam` | `[Var("handle", Path("handle")), Var("id", Path("id"))]` |
| `www/src/pages/store/arg_handle/page.gleam` | `[Var("handle", Path("handle"))]` |
| `www/src/pages/tl/page.gleam` | `[]` |
| `www/src/pages/w1_preview/page.gleam` | `[]` |
| `muses/src/pages/articles/arg_id/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("id", Path("id"))]` |
| `muses/src/pages/articles/new/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| `muses/src/pages/articles/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("cursor", Query("cursor"))]` |
| `muses/src/pages/heaven/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| `muses/src/pages/inbox/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("after", Query("after"))]` |
| `muses/src/pages/links/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| `muses/src/pages/metrics/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("from", Query("from")), Var("to", Query("to"))]` |
| `muses/src/pages/onboard/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| `muses/src/pages/page/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("selected", Query("space")), Var("space", Query("space"))]` |
| `muses/src/pages/page/widget/arg_id/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("id", Path("id")), Var("selected", Query("space"))]` |
| `muses/src/pages/page/widget/new/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("kind", Query("kind")), Var("space", Query("space")), Var("selected", Query("space"))]` |
| `muses/src/pages/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("from", Query("from")), Var("to", Query("to"))]` |
| `muses/src/pages/settings/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| `muses/src/pages/settings/unclaim/arg_id/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("id", Path("id"))]` |
| `console/src/pages/api_key/page.gleam` | `[]` |
| `console/src/pages/consent/page.gleam` | `[]` |
| `console/src/pages/metrics/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("from", Query("from")), Var("to", Query("to"))]` |
| `console/src/pages/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| `console/src/pages/rosters/arg_id/page.gleam` | `[Var("handle", Session(SubjectHandle)), Var("id", Path("id"))]` |
| `console/src/pages/rosters/arg_id/photos/arg_order/remove/page.gleam` | `[Var("id", Path("id")), Var("order", Path("order"))]` |
| `console/src/pages/rosters/arg_id/remove/page.gleam` | `[Var("id", Path("id"))]` |
| `console/src/pages/rosters/new/page.gleam` | `[]` |
| `console/src/pages/rosters/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| `console/src/pages/schedule/page.gleam` | `[Var("handle", Session(SubjectHandle))]` |
| `console/src/pages/switch/page.gleam` | `[]` |
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


### snapshot (ii) の生成・3面 build 実測

| 段 | 生成 stop | 生成 file | exit 1 | exit 2 | exit 3 | exit 4 | warning |
|---|---:|---:|---:|---:|---:|---:|---:|
| F5 最小 patch | 4 | 1372 | 3 | 0 | 1 | 111 | 48 |
| F6 patch | 1 | 1380 | 0 | 0 | 1 | 222 | 115 |

| 段 / face | `gleam build` stop | error 数 / file 数 | 内訳 |
|---|---:|---:|---|
| F5 最小 / www | 1 | 12 / 10 | Type mismatch 11、Unknown label 1 |
| F5 最小 / muses | 1 | 13 / 12 | Type mismatch 12、Unknown label 1 |
| F5 最小 / console | 1 | 18 / 12 | Type mismatch 17、Unknown label 1 |
| F6 / www | 1 | 1 / 1 | Syntax error: `www/src/gen/load/search/page.gleam` |
| F6 / muses | 1 | 1 / 1 | Syntax error: `muses/src/gen/load/page.gleam` |
| F6 / console | 1 | 1 / 1 | Syntax error: `console/src/gen/load/page.gleam` |

F5 最小 patch の全 error file 名と件数、F6 の3面ログは `gen/build/y1f-snap-ii-summary.txt` と `gen/build/y1f-snap-ii-{f5min,f6}-{www,muses,console}-build.log`。生成ログは `gen/build/y1f-snap-ii-{f5min,f6}-generation.log`。F5 patch は68 file、F6 patch は113 file に適用した。両写しの `api/` は元 snapshot と diff 0。新規 Service は足していない。

F6 表の「語彙だけ」15 Page はすべて `src/gen/load/...` の SHA-256 header 付き生成物として出た(15/15)。ただし生成器が書いた `Vars` の field が `vars[0]: String` のようになり、Gleam の constructor field 構文として不正。`console/src/gen/load/page.gleam:21` で実物を確認し、F6 の3面 build も上表の syntax error で止まった。生成器の `gleam format` 自体も `vars[0]` の `[` を constructor field 名として読めず stop 1。F6 の内部 diagnostics は exit 4 が222行で、6つの未実装 back Service だけには限られない。よって到達線は未達。F6 patch の追加修正では解消できない生成器側の穴として記録し、生成器/framework/API は変更しなかった。6本の Service module の有無は `api/src/service` で確認: `store_roster_read`, `subject_list`, `subject_settings_read`, `widget_read`, `space_read`, `space_widget_list` はいずれも無し。今回の build は先に formatter 構文で停止したため、それらだけの build 結果とは判定できない。

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
| root `gleam build` | exit 0 / warning 1 | exit 0 / warning 1。`build/y1f-r13-root-build.txt` |
| `cd gen && gleam test` | 181 passed | 189 passed。`gen/build/y1f-r13-gen-test.txt` |
| Article fixture | 92 file | 112 fileを2回、両 exit 0、`diff -r` 0行。`gen/build/y1f-r13-fixture-{one,two}.log`、`...-diff.txt` |
| snapshot (i) | exit 1=3 / 2=0 / 3=1 / 4=22 / warning=48 / 1375 file | 2回とも stop 4 / exit 1=3 / 2=0 / 3=1 / 4=111 / warning=48 / 1372 file。新規 exit 4 は89行、消失0、未分類0。elapsed 表示をそろえた後 `diff -r` 空。`gen/build/y1f-snap-i-compare.txt` |
| snapshot (ii) F5 最小 | — | generator stop4、exit 1/2/3/4=3/0/1/111、warning48、1372 file。3面 build は stop1、error 12/13/18。file別一覧は `gen/build/y1f-snap-ii-summary.txt` |
| snapshot (ii) F6 | — | generator stop1、exit 1/2/3/4=0/0/1/222、warning115、1380 file。語彙だけ15 fileは SHA-256 header 15/15。3面 build は各 stop1、`vars[0]` に起因する syntax error 各1。到達線は未達。`gen/build/y1f-snap-ii-summary.txt` |
| verify | — | SSR / isolate / given / file / overlay は ALL PASS。Block preview は public 7 / admin 1 とも PASS。Hex API rate limit 時は前回の `build/packages` をseedして同じ script を再実行。`gen/build/y1f-r13-verify-*.txt` |
