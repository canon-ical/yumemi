# BRIEF yumemi-1e ── ファイル入力・モーダル・badge と、F5 を止める生成器の穴(0.9.0)(草案、2026-09-24、水無瀬[PL] 起草 → 鷹野[PDM] が裁いて commit)

便: yumemi-1e

**前提は 3 つ。**(a) **G7(`yumemi-gen-7`)の承認と Hex 0.8.0 の publish** ── yumemi main `0c0bdb3`(tag `v0.8.0`)。`docs/reports/gen-7.md` の `## 鷹野宛` / `## 追随便への申し送り` と、柏木ゲート 2 の P1 G2-2〜G2-9(贄川 run `niekawa-20260924-044509-82060-7565` の `verdict.md`)が本便の材料、(b) **musearch は snapshot で読む** ── **基点の snapshot は musearch main `a109b47`**(SV と 2b-4 の merge 後。`2ca76cc` との差は BRIEF 3 本だけで src は同一)。**run_dir に写して読み、走行中に musearch main が動いても追わない**(段 8 で 4b / 2b-5 / 2b-6 が並走する)。**`~/yumemism_repo/musearch` は一度も書かない**(`git status --short` 0 行を証跡に)、(c) **`~/yumemism_repo/yumemi-gen-7` は触らない。****基点は yumemi main `<本 BRIEF の commit>`**(`0c0bdb3` の上に本 BRIEF の commit だけ)。作業木は `~/yumemism_repo/yumemi-1e`(branch `impl/yumemi-1e`、贄川が作る)。plan は贄川の run_dir、記録は `docs/reports/yumemi-1e.md`(**`## DDL` 必須、本便は「無し」**)、証跡は `gen/build/y1e-*`。commit は `git-as <役>`、`main` に触らない、push と **Hex publish は鷹野**。1 巡 = 1 session、ゲートは 1 も 2 も便に 1 回、ゲート 2 の P0 を直す巡は真壁を sol で。配役は tech `61-stage-baton-7.md` の段 8(贄川 K3、柏木 経路 C = Opus 5.5 xhigh、真壁 luna max)。**`gleam.toml` は 0.9.0。****見積 5:00(推定** ── 58 v4 の 3:00 に F5 を止める穴 4 束 +1:30 と、ファイル入力の生成器側 +0:30。末尾「見積」)。

**親ゴール:** tech `58-task-dag.v4.md` の辺 `Y1e → F5` ── **Hex 0.9.0 を出し、F5(`musearch-yumemi-5`、`>= 0.9.0 and < 0.10.0`)が 3 面の ▲ を生成物へ差し替え切れる状態を作る。**同じ版に役員 人見 09-23 の 2 つ(モーダル `pin: Overlay`、`el.badge`)を載せる。

**障害:**

- **ファイル入力の ★ 手書き例外 3 本**(muses `components/blob_copy.gleam` / `components/article_blob_copy.gleam`、console `blob_copy.gleam` + `blob_copy_ffi.mjs`、3 Component / 5 画面)は `live.Set(file, "")` に Dynamic を流す型の流用と、島の外への手(`blob_copy_ffi.mjs` の `document` 引き、`yumemi-blob-done` の emit、console は `POST /api/blobs` → `PUT …/photos/:order` を FFI で連投)で通している。**生成物に載せる形が無い**
- **`live.Event` に構成子を足すと、musearch の ★ 島 43 本(muses 30 / console 13、`case msg` が `live.Send` / `live.Done` を網羅)が 0.9.0 で compile しなくなる**(musearch main `2ca76cc` の実測)── 58 v4 の「`Set` に Binary の枝」を字どおりに型で足すと、F5 が版を上げた瞬間に面が落ちる
- **G7 の snapshot 再走で exit 1 が 5 本残った**(decoder 2 + client 3)── F5 は `api/` に 1 行も書けず、生成物を手で直せない。**生成器側の穴が 1 本でも残ると F5 は build 0 に届かない**
- **Gleam SSR の `<head>` に viewport meta が無い**(柏木 SV P1-6)── 実機の SP で描画幅 980px 前後、断点 900px を越えて PC の配置で出る。Playwright の viewport 試験では見えない
- G7 の P1 を全部入れると段 8 の長柱が伸びる(58 v4 では Y1e 3:00 が段 7b の長柱)

## 現在地(数字は yumemi main `0c0bdb3` / musearch main `2ca76cc` / staging の実測。**snapshot の基線は巡 1 の頭で測る ── 未測**)

- **G7 の最終値**(gen-7.md、`9c2b0bd` 上):`gen test` 159、fixture 88 file、snapshot は exit 2 = 0 / exit 3 = 1(www の `shell.gleam` 不在、F5 が置く)/ exit 4 = 20 行 / exit 1 = 5 / 警告 29。**`a109b47` は SV の Page 17 本と ▲ 20 本、2b-4 の Service が乗っているので数は動く**
- **framework の front は 6 file**(`front.gleam` 163 / `front/css` 79 / `el` 33 / `live` 22 / `track` 33 / `sketch_css` 149 行)。`css.Pin` は `Top | Bottom | NoPin`、`el` は `text` / `img` / `each` / `island` の 4 つ
- **ファイル入力の受け口は back に既に在る** ── 付属入口 `blob_copy`(`POST /api/blobs`、`http_runtime.mjs` の付属入口表)、Args に `Blob` を持つ Service は `roster_photo_put.blob` / `muse_edit_profile.icon` / `widget_add.image` / `widget_edit.image` ほか。**Blob 欄を持つ Service の島なら、送る前に runtime が `blob_copy` へ上げて key を差し込めば島またぎは消える**
- **viewport:**生成器の殻は `emit/front.gleam:2043-2050` で `charset` と `title` だけ。staging `https://app.yumemism.dev/` の `<head>` は `meta charset` + `title` + script で viewport 0 件(本日実測、`/muse/<handle>` は鷹野の実測)。SvelteKit の `app.html` は `width=device-width, initial-scale=1, viewport-fit=cover` ── **`viewport-fit=cover` が無いと `pin: Bottom` の `env(safe-area-inset-*)` が 0 になる**(51 v5「貼り付け」)
- **G7 の exit 1 の読み(水無瀬、根は未確定):**(i) www の `gen/live/roster_claim` が Error を `Invalid | Failed` に畳み、Service の `CodeInvalid | CodeExpired | PersonaAlreadyOnStore` を失う ── ★ `claim_button.gleam:57` が落ちる = **生成器側(確認済み)**、(ii) `metrics_muse` / `metrics_store` の `entity/visit.Source`(`Tagged(SourceKey) | External | Internal | Direct`)が判別不能 ── 型は `api/` に在り F5 は触れない = **生成器側**、(iii) muses `unclaim_confirm.view(Nil)`(`In(rosters: roster_list_mine.Out)`)= **推定 生成器側**、(iv) console `session_switch.view(Nil)`(`In(has_store: Bool, idp_origin: String)`、Page は `of: None`)= **推定 面側**(51 の「1 Block = 1 Service の Out」の外)、(v) www の `front.Target` 不在 = **面側**(snapshot の面が 0.7.0 に依る、F5 の版上げで消える)。www の ★ component 5 本(view のみ)の esbuild import 検査は未到達
- **G7 の P1 の行き先(水無瀬の選別。線は「F5 の前に閉じないと F5 が詰まるか」):**
  - **入れる:**G2-4 `--bg-image` が生の key(▲ は `/media/<encode 済み key>?v=w1600`、差し替えると背景画像が出ない = 画面の後退で F5 は手で直せない)/ G2-5 `doc/api_v1.gleam` が Markdown 原文 1 本(▲ 278 行の見出し・表・code、差し替えると API 文書の画面が崩れる)/ G2-8 一時 package が manifest を消す(F5 の「2 回走らせて byte 一致」が成り立たず、Hex の rate limit で止まる ── G7 の巡 8 と柏木で実際に当たった)/ exit 1 の生成器側(上の i〜iii)
  - **外す:**G2-2 grid 欄の名前付き const(F5 はリテラルで書く ── G7 P1-G1-1)/ G2-3 既定値の 2 箇所(省略時の CSS は旧 runtime と同じで F5 の見た目は動かない)/ G2-6 付属入口表の源の欠け(musearch には在る、源は back の世代揃えで動く)/ G2-7 末尾 `/`(鳴って止まる、CLI の不便)/ G2-9 `At` の重なり(F5 は `Flow` だけ)/ P1-E-1 registry 監査の固定値(F5 の検収に無い)/ minify・per-element given・gen-6 P1-4 / 9 / 11(既存の申し送りの列)

## どこまで

1. **ファイル入力 ── Blob 欄を持つ島を生成物で書けるようにする**(58 v4 の Y1e)。**`live.Event` の構成子は増やさず、`Set(field, String)` の形も変えない**(裁定待ち 1)── 選んだファイルは生成 runtime が持ち、島の状態には runtime の札(String)だけが入る。`Send` のとき runtime が Blob 欄の札を `blob_copy` へ上げて key に差し替えてから Service を叩く。**付属入口 `blob_copy` そのものを叩く島**(記事の本文画像 = 上げて URL を見せる)は `Target.Entry` で同じ口に乗せる。**musearch の 3 本がこの 2 形のどちらで書けるかの対応表**(file / 画面 / Service か Entry / 消える島またぎ)を results に
2. **モーダル = `css.Pin` に `Overlay`**(役員 人見 09-23)── 生成器が `<div popover>` + `::backdrop` を吐く。**top layer なので `z-index` / `position` は ★ に出ない**。開閉は `el.opener` / `el.closer`(`popovertarget` / `popovertargetaction`、**JS ゼロ・島の状態を使わない**)、中身は普通の Block、島は置ける。**`Overlay` の area は grid の `template` に載らない**(既定の template 計算からも外す)。`el.opener` が同じ Page / Layout に無い area か `Overlay` でない area を名指ししたら生成器が止める。**行ごとのモーダルの形は裁定待ち 4**
3. **通知 badge = `el.badge(count: Option(Int), child:)`**(役員 人見 09-23)── 位置の CSS と、`None` / `0` を隠すのは生成器。値は同じ Block の Out。**★ に比較を書かせない**(51「書けないもの」の値の比較)
4. **殻の `<head>` に viewport meta**(柏木 SV P1-6)── `width=device-width, initial-scale=1, viewport-fit=cover`。`shell.gleam` の const は増やさない(生成器の定数)
5. **F5 を止める穴 4 束**(G7 の P1 から選別、根拠は上の「行き先」)── (i) **G2-4** `--bg-image` を ▲ と同じ media の URL に(組み立てを ★ `media` に委ねるか生成器が持つかは plan、理由を results に)、(ii) **G2-5** `doc/api_v1.gleam` を `docs/api-v1.md`(84 行)の見出し・表・inline code・段落・一覧から要素で組む、(iii) **G2-8** 一時 package が面の `manifest.toml` を保つ(2 回目の build で版を解き直さない)、(iv) **exit 1 の切り分け** ── 5 本を「生成器側 / 面側」に分け、**生成器側は閉じる**(Service の Error の variant を生成 live の Error に通す、`visit.Source` の形の decoder を back の codec と同じ表現で、Out を包む `In` の構築)。**面側は file と最小の直しを名指しで `## 追随便への申し送り` に**(F5 の BRIEF に鷹野が足す)
6. **results**(`docs/reports/yumemi-1e.md`)── `## DDL`(無し)、`## 鷹野宛`、`## 追随便への申し送り`(F5 宛:★ 3 本の差し替え方、exit 1 の面側、`a109b47` の exit 4 で本便が足した / 消した行)、**51 v5 に足す文**(`Pin.Overlay`、`el.opener` / `closer` / `badge`、ファイル入力の形、殻の viewport、**「書けないもの」の重ねの行の更新** ── 残るのはドロワー / tooltip / 浮くボタン。鷹野が tech に写す)、**閉じた穴と残した穴の表**(G7 の P1 全件の行き先、未分類 0)、基線の表

### 巡 1 の頭で読むもの

`docs/reports/gen-7.md` 全文、柏木ゲート 2 の P1(上の run_dir の `verdict.md` と `kashiwagi-20260924-124720-567496-826/last-message.md`)、tech `_drafts/plan/60-stage7-shape.v0.md` 末尾の追記 2 本(grid と Y 便の射程)、tech `51-front-types.v5.md` の「貼り付け」「Component の状態」「書けないもの」、musearch snapshot の `docs/console-1a/results.md` の ★ 手書き例外(申し送り 7 / 鷹野宛 5)と `docs/store-1/results.md` の BlobCopy。

## しないこと

**musearch への書き込み**、**Hex publish**、**Page を view 関数にする形**(役員 人見 09-23 に不採用 ── Page の仕事は配置表まで)、**Block ⊃ Block / Area ⊃ Area**(モーダルの中身は Area に置いた Block)、ドロワー / tooltip / 浮くボタン、**G7 の P1 のうち上で「外す」としたもの**、per-element given、minify、back の世代揃え、`live.Event` の構成子の追加と `Set` の形の変更(裁定待ち 1 で覆らない限り)、DDL、`main` への commit、push、`~/yumemism_repo/yumemi-gen-7`、`.claude/_core` `~/.codex` `~/.claude`。

## 失敗例

- **`live.Event` に `SetFile` の類を足す** ── ★ 島 43 本の `case` が網羅でなくなり、F5 が 0.9.0 に上げた瞬間に muses / console が compile しない。F5 は ★ の作り替えを射程に持たない
- **島またぎを runtime の汎用の口にする**(島が別の島の属性を書く、`yumemi-blob-done` の類の合図を framework に上げる)── 島は葉、が崩れる。消すのは Blob 欄の Service に畳む形で
- **モーダルの開閉に島の状態や JS を使う**、`z-index` / `position` を ★ の Style に出す
- **badge の「0 なら隠す」を ★ の `case` に書かせる**
- **G7 の P1 を全部閉じて長柱を伸ばす** ── 「外す」の 9 件は F5 を止めない。巡が余っても手を出さない(追随便の列)
- **exit 1 を「面側」に寄せて本便を軽くする** ── 面側と書くなら、F5 が `api/` を触らず・生成物を直さずに消せる直しであることを file 名で示す
- **fixture で通して snapshot で試さずに閉じる**(G7 の P0 は入力側の古い `src/gen` を bundle して PASS を出した)
- 基線を gen-7.md から写す(毎巡 自分で打つ)、musearch を書く、同 persona の同秒起動、`^session_id:` での終了判定、push、Hex publish

## 検収

- root `gleam build` exit 0(既存 warning 1 から悪化しない)、`cd gen && gleam test` が **159 以上**
- fixture 生成が exit 0 / 88 file 以上、再走 diff 空、face build exit 0 / warning 0、**SSR / isolate / given / Block preview が ALL PASS**、sha256 ヘッダの欠け 0、生成物の `gleam format --check` 0
- **ファイル入力:**fixture に Blob 欄の Service を持つ島を 1 本置き、選ぶ → 送るで `blob_copy` → Service の 2 request が出て Service の body に key が入る(request の列を証跡に)。musearch の 3 本の形で書いた見本が snapshot の写しの上で build 0
- **Overlay:**fixture の Page に 1 つ、SSR の HTML に `popover` と `popovertarget` が出て、**client script を切っても開閉する**(NO-JS)。`Overlay` の area が `grid-template-areas` に出ない。名指し違いの opener で生成器が止まる
- **badge:**`None` / `Some(0)` / `Some(3)` の 3 つで、表示と非表示が CSS だけで分かれる
- **viewport:**fixture の SSR 出力の `<head>` に上の 1 行
- **snapshot `a109b47`(写し)で:**exit 2 = 0、**exit 1 は面側の名指しだけ**、exit 3 と exit 4 と警告は巡 1 の基線から悪化しない(増減は行ごとに名指し)、**生成器を 2 回走らせて `client.mjs` を含め diff が空**、2 回目の build が Hex で版を解き直さない、`--bg-image` の値と `doc/api_v1` の要素数(見出し / 表 / 行 / code)が ▲ と一致
- **framework の差分**は `front/css.gleam`(`Pin` の 1 構成子)・`front/el.gleam`(3 関数、裁定待ち 4 を入れるなら 4)と、ファイル入力に要る最小だけ。**`live.gleam` は 0 行**(裁定待ち 1 が (a) のとき)、依存 package 数は不変、`gleam.toml` は 0.9.0
- musearch は無傷(`git status --short` 0 行、HEAD 不変)、`## DDL`(無し)と `git diff --stat <基点> -- db/ gen/fixtures/article/db/` が空で一致
- results に上の表と 51 v5 に足す文。**終端は承認かエスカレーション**

**巡ごとに贄川が出すもの:**閉じた束の数、`gleam test` の本数、snapshot の exit 1(生成器側 / 面側の内訳)/ exit 2 / exit 3 / exit 4 / 警告 / file 数、musearch の `git status --short`(0 行)。**「継続」で裁定を待たない** ── 問いは終端で返す。

## 裁定待ち ── 起動前に鷹野が裁く

1. **ファイル入力の形。**(a) runtime がファイルを持ち、島の状態には札の String だけ(`live.Event` / `Set` 不変)、(b) `live.Event` に構成子を 1 つ(★ 島 43 本の `case` が落ちる ── F5 に 43 file の追随が乗る)、(c) `Set` の値を和型に(`live.Set(field, next)` を書く ★ 43 本が落ちる)。**水無瀬の推奨:(a)** ── 0.9.0 を 0.8 系の ★ に対して足すだけの版にでき、Blob 欄の Service に畳めば島またぎも消える。58 v4 の「`Set` に Binary の枝」は射程の名で、型の形は人見の裁定ではない(How)
2. **G7 の P1 の選別。****水無瀬の推奨:上の「入れる」4 束だけ。**G2-5 は ★ に戻す択もあるが、gen-6 裁定 7(14 種目は生成物、源を手書きにしない)の逆転になるので採らない
3. **snapshot の基点。****水無瀬の推奨:`a109b47` に固定して追わない**(G7 の型)。F5 が受ける木に近い(SV の ▲ 20 本と 2b-4 の Service が乗っている)。段 8 の 3 便の merge 後を待つと起動が 4b の後ろに落ちる
4. **行ごとのモーダル。**60 の追記は「`each` の中に popover を吐き、島の Args は属性」。**Area は配置表の欄で行を知らないので、`Overlay` の area だけでは行ごとは書けない** ── popover の容れ物を `el` にもう 1 つ要る(id は生成器が行から振り、★ は id を書かない)。**水無瀬の推奨:本便に入れる**(人見が形を名指ししている、+0:15 前後)。**入れないなら 2b-7 / 2b-8 の前に次の Y 便**
5. **F5 の BRIEF に足す行**(musearch、鷹野が書く。本便は musearch を書かない)── (i) ★ 手書き例外 3 本を本便の形へ戻す(札は `yumemi-front-1e` と書いてある = 本便)、(ii) 本便が名指しした exit 1 の面側、(iii) grid の新しい欄はリテラルで書く(G2-2 が外れたため)。**推奨:本便の承認時に当てる**
6. **起動の予算。**tech 61 の Y1e 225 分は 3:00 の値。**推奨:375 分**(中央 5:00 × 1.25)

## 人見の卓(本便は裁かない)

- **裁定は要らない。**射程は 58 v4 の Y1e と役員 人見 09-23 の 2 つ、足したのは F5 を止める穴と、SvelteKit が持っていた viewport を戻すことだけで、新しい要件は無い
- **報告 1 点:**人見が見積もった Y 便 3:00 は **5:00 に動く**(段 7b の長柱、58 v4 の合計 19:40 → **21:40**)。理由は G7 が 0.8.0 を出した後に見えた穴で、**本便に入れずに F5 の前に Y 便をもう 1 本挟むと、同じリポ・同じ Hex の直列なので段が 1 つ増える**(中央 +2:30 前後、推定)

## 見積

**最短 3:30 / 中央 5:00 / 最長 7:30(推定)。**内訳は 58 v4 の 3:00(ファイル入力 1:33 + モーダル 1:00 + badge 0:30 ── 役員 人見 09-23)に、(i) **ファイル入力の生成器側 +0:30**(1:33 は Y1c の framework だけの便の実測で、G7 から島の live は生成物になった ── runtime の上げ直しと Blob 欄の Field が乗る)、(ii) **F5 を止める穴 +1:30**(viewport 0:05 / G2-4 0:20 / G2-5 0:25 / G2-8 0:15 / exit 1 の切り分けと生成器側 0:25〜0:45)。**行ごとのモーダルを入れると +0:15。****G7 は中央 6:00 に対し実測 8:55**(起動 04:45 → 承認 13:40、巡 9、ゲート 2 の P0 1)── 生成器の便は見積を 1.5 倍に振れた実績があり、最長 7:30 はその幅。

## 鷹野の裁定(2026-09-24 14:10、窓「段7」)── 裁定待ち 6 項を全部裁いた

1. **ファイル入力は `Event` と `Set` を変えない形**(推奨どおり)。生成 runtime がファイルを持ち、`Send` の時に `blob_copy` へ上げて key を Blob 欄に入れる。musearch の ★ 島は `live.Event` を網羅の `case` で持つ(鷹野の実測で muses 30 / console 12)── 構成子を足すと F5 の版上げで全部 compile が落ちる
2. **G7 の P1 の選別は「入れた項」の 4 束だけ**(G2-4 / G2-5 / G2-8 / 生成器側の exit 1)。外した項は追随便の列に残す
3. **snapshot は musearch `a109b47` に固定**、走行中の main を追わない
4. **行ごとのモーダルは本便に入れる**(+0:15、人見 09-23 が形を名指し)
5. **F5 の BRIEF に足す行(★ 3 本を本便の形に戻す、exit 1 の面側の直し、grid の欄はリテラル)は本便の承認時に鷹野が当てる**(段 8 の鷹野)
6. **`--budget` は 375 分**(61 の表の 225 を差し替える)。見積 中央 5:00(58 v4 の 3:00 から +2:00、理由は「見積」)は人見に報告する
