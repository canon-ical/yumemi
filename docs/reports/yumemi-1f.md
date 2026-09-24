## 追随便への申し送り

### F6 対象表

Y1e の「値の出所の穴」27 行を Page file でまとめると 21 file。BRIEF の www 3 / muses 7 / console 11 と一致した。Page の `vars` は Page 自身の値。console の共通設定は Layout の `Var("idp_origin", AuthOrigin)` と `Var("www_origin", Origin("www"))` から Block の同名 `Arg` に流す。

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

`article_read` は snapshot API の `api/src/service/article_read.gleam:22-44` で Args が `id, handle`、Out が `article, phase, muse`、AsMuse は AnyPhase のため下書きを返すことを確認した。表の back Service のうち、`store_roster_read` / `subject_list` / `subject_settings_read` / `widget_read` / `space_read` / `space_widget_list` は F6 が必要形を申し送る新規 Service。API はこの便で変更しない。

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

生成器がこの木で 0.10.0 ではないため実測は未実行。下表は F5 後の写し `mid` と API `Args` を読んだ予測。Path は `arg_<name>` の route 段を含む全21 Page。route 段に対する未宣言は検査 #2、列挙した必須 Service Args の欠落は #4。前表の30 Block は `In` が単一 `.Out` / `Nil` でないので #6 も出る。

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
- `gleam format --check <changed files>`: www 52 file / muses 41 / console 20、3面 exit 0 / formatter output 0行。0.10.0 型生成器の build / typecheck は未実行。copy 内にまだ無い Out module は上記6本。
- Page の Block Args と Page/Layout Vars の同名照合: 56 Page を対象に不足0。after の145 `view` module は全て `In` を宣言し、`Arg` module は34。`Var` の出所は `Path` / `Query` / `Session` / `Origin` / `AuthOrigin` のみ。`Literal` / default / variant source は0。
- patch header の `src/gen` 該当0。完了条件4に書かれた `^+++ .*/api/` grep は1行になる: `+++ after/www/src/pages/for_stores/api/v1/page.gleam`。これは WWW の frontend Pageで、backend `api/` は含まない。この Page の `vars: []` は Page 59件をそろえるため必須なので、ファイルを除外していない。
- `git diff --check 355a93a..HEAD`: exit 2、194 trailing whitespace findings。対象は patch artifact 内の空白行 (`+ `)。報告書の whitespace は0件。snapshot source patch の空行は整形していない。
