# BRIEF yumemi-1f ── Page は変数だけを持つ(`reads` を消し `vars` と Block の `Arg`、Service は Block の In から導く)、Hex 0.10.0(草案、2026-09-24、水無瀬[PL] 起草 → 鷹野[PDM] が裁いて commit)

便: yumemi-1f

**前提は 3 つ。**(a) **Y1e の承認と Hex 0.9.0 の publish** ── yumemi main `4f43a9f`(tag `v0.9.0`)。`docs/reports/yumemi-1e.md` の `### 値の出所の穴` と `## 追随便への申し送り` が本便の穴の一覧、**型の正は tech `_drafts/gleam-framework/63-page-variables.v0.md`**(役員 人見 09-24 の裁定 2 回と鷹野の裁定 6 点)、(b) **musearch は snapshot で読む** ── **基点の snapshot は musearch main `8eed4d8`**(F5 の基点と同じ木。`b84ee21` との差は BRIEF 1 本で src は同一)。**run_dir に写して読み、走行中に musearch main が動いても追わない**(F5 が並走する ── 裁定待ち 1)。**`~/yumemism_repo/musearch` は一度も書かない**(`git status --short` 0 行を証跡に)、(c) **`~/yumemism_repo/yumemi` の作業木(main)は触らない** ── musearch の便は生成器を `~/yumemism_repo/yumemi/gen` から呼ぶ(`BRIEF-yumemi-5.md:35` ほか)。**基点は yumemi main `<本 BRIEF の commit>`**(`4f43a9f` の上に本 BRIEF の commit だけ)。作業木は `~/yumemism_repo/yumemi-1f`(branch `impl/yumemi-1f`、贄川が作る)。plan は贄川の run_dir、記録は `docs/reports/yumemi-1f.md`(**`## DDL` 必須、本便は「無し」**)、証跡は `gen/build/y1f-*`。commit は `git-as <役>`、`main` に触らない、push と **Hex publish は鷹野**。1 巡 = 1 session、ゲートは 1 も 2 も便に 1 回、ゲート 2 の P0 を直す巡は真壁を sol で。配役は起動前に `harness-route` で引く(tech `61-stage-baton-7.md` の段 9 の行、柏木は経路 C)。**`gleam.toml` は 0.10.0。****見積 5:30(推定** ── 末尾「見積」)。

**親ゴール:** Page は変数だけを持ち画面を描かない形を、生成器と front の型で成立させ、F5 が ▲ 例外で残した「値の出所の穴」21 file(www 3 / muses 7 / console 11)を生成物に戻せる版(Hex 0.10.0)を出す。

**障害:**

- **A 案と変数の語彙が別々に入って二重持ちになる** ── Page が取りに行く Service の口がいま 3 つ在る(`Page.reads` / `Layout.reads`、`Fixed` の Block の `In`、Y1e が足した「Block の `In` の record の必須 `Out` 欄を page の source に」= `add_block_input_sources`)。`vars` を足して `reads` か束ねた `In` を残すと、同じ Service を 2 箇所で宣言できる形が 0.10.0 に残る。**束ねた `In` は人見 16:52 が採らなかった B 案(1 Block に 2 Service)そのもの**
- **人見が認めない出所(Page が書く定数)が混ざる** ── 出所は route / session / 設定値の 3 つ(役員 人見 09-24 19:30)。`Var` の既定値、`Literal` の構成子、Block の variant を Page が構成子の引数で選ぶ形、`Query` の既定値を Page に書く形、のどれか 1 つで裁定が崩れる
- **0.9.0 の面を壊す移行** ── F5(`>= 0.9.0 and < 0.10.0`)と、その後の 2b-7 / 2b-8 は 0.9.0 の上で `reads: […]` を書き、**生成器は `~/yumemism_repo/yumemi/gen`(yumemi main の作業木)から呼ぶ**。本便を main に merge した時点で、0.9.0 の面を 0.10.0 の生成器が読み、`reads` の欄が無いと落ちる(Hex の版の pin は生成器を守らない)
- **session の値を殻が読めない** ── 生成の `shell.mjs` は `/api/session` を 1 度も打たず、`env` も読まない(`emit/front.gleam:5382-5388` の `readFromApp` は path の穴を `matched.params` だけで埋める)。muses の ▲ 殻が全読みの `:handle` に session の handle を差している(musearch `muses/src/gen/shell.mjs:491-497`)のは、生成物に口が無いから
- **front が行を選んでいる** ── console `roster_editor`(`In(row: Option(store_roster_list.Row), …)`)、www `space_title`(`In = space_list.FreeSpace`)、muses `article_form` の `Edit(article_list_mine.Article, …)` / `widget_form` は一覧を 1 本取って id で探す。変数が入っても「1 行を読む Service」が back に無ければ穴は閉じない

## 現在地(数字は yumemi main `4f43a9f` / musearch main `8eed4d8` の実測。**snapshot の基線は巡 1 の頭で測る ── 未測**)

- **Y1e の最終値**(yumemi-1e.md):`gen test` 181、fixture 92 file、snapshot `a109b47` は exit 1 = 3(3 面とも `[exit 1 値の出所]`)/ exit 2 = 0 / exit 3 = 1 / exit 4 = 20 / 警告 43。**`8eed4d8` は 4b / 2b-5 / 2b-6 が乗っているので数は動く**(F5 の BRIEF は exit 4 = 22 / 警告 48 を上限に置いた)
- **framework:**`front.gleam` 163 行、`Layout.reads` は `:11`、`Page.reads` は `:23`。`Placement` は `Fixed(area, block, cell)` / `Widget(area, name, of, render)`(`:140-142`)
- **生成器の Service の導出:**`emit/front.gleam` の `layout_sources`(`:2771`)と `page_sources`(`:2783`)が `read_sources`(`:2856`、`reads` → source)を種に `placement_sources`(`:2898`)を回す。**`add_block_input_sources`(`:2951`、Y1e)は `In` の record の欄のうち型が `Out` のものを全部 source にする** ── www `muse_header.In(page: muse_read.Out, subscription: Option(subscription_read.Out))` と muses `home.In(muse:, inbox:, …)` はこれで通っている。`reader/front.gleam` は `reads` を `:829` / `:850` で読み、`reads_type_notes`(`:598`)で型を見る
- **fixture:**`reads` を書くのは `gen/fixtures/article/public/src/layout.gleam:80`(`reads: []`)と `pages/article/arg_slug/page.gleam:91`(`reads: [service.ArticleRead]`)の 2 箇所。負の fixture の置き方は `front_overlay_negative/` が先例
- **session の出口は back に既に在る** ── 付属入口 `session_read`(`GET /api/session`、musearch `api/src/gen/http_runtime.mjs:440`)が `subject: {kind, id, handle, phase}` を返す(`:692-694`、匿名なら `{anonymous: true}`)。**殻が 1 往復打てば `SubjectHandle` / `SubjectId` は取れる**
- **設定値の置き場:**console の `wrangler.jsonc:26-27,32-33` が `PUBLIC_WWW_ORIGIN` / `PUBLIC_IDP_ORIGIN` を持ち、▲ の殻が `env` から読む(`console/src/gen/shell.mjs:603-604`)。www / muses の wrangler に origin は無い
- **穴 21 file の読み(水無瀬、F5 の BRIEF 鷹野の裁定 09-24「段8」の 3 を 63 の形に当てた。推定):**
  - **語彙だけで戻る(推定 15):**console 9(`console_header` の `idp_origin` だけの 7 本 = `metrics` / `page` / `rosters` / `rosters/new` / `schedule` と、`api_key`(`www_origin`)/ `consent`(`idp_origin`)、`rosters/arg_id/remove`(`id`)/ `rosters/arg_id/photos/arg_order/remove`(`id` / `order`))、muses 4(`metrics` = Query `from` / `to`、`page` = Query `space`(▲ `load/page/page.gleam:83` の `selected_value(query)`)、`articles/new` / `page/widget/new` = Block を `New` 側に割る)、www 2(`claim/arg_code` = Path `code`、`muse/arg_handle` = `muse_header` と購読の Block を割る)
  - **back の 1 行読みが要る(推定 6):**console `rosters/arg_id`(店の在籍 1 件)/ `switch`(名義の列、`has_store` を畳む)、muses `articles/arg_id`(自分の記事 1 件、`article_read` が下書きを返すかは未確認)/ `page/widget/arg_id`(widget 1 件)/ `settings`(名義の列と同意)、www `muse/arg_handle/space/arg_id`(space 1 件)。**63 の「back の Service 2〜3 本」は少なく数えていた** ── 1 行を選ぶ Block を数えていなかった

## どこまで

1. **framework の型(0.10.0)** ── 63「型」節のとおり。`Page` / `Layout` の `reads` を消して `vars: List(Var)` を 1 欄、`Var(name, from)`、`From { Path(String)  Query(String)  Session(SessionKey)  Origin(face: String)  AuthOrigin }`、`SessionKey { SubjectHandle  SubjectId }`。**差分は `front.gleam` だけ**(`live` / `el` / `css` / `track` は 0 行)
2. **Block の `Arg`** ── reader が `view` の 1 引数(`view(it: In)`)と 2 引数(`view(it: In, arg: Arg)`)を受け、`Arg` の欄は `String` / `Option(String)` だけ。`In` は `<service>.Out` か `Nil`
3. **Service の導出を 1 つにする** ── Page が取りに行く Service = Layout と Page の全断点の `Fixed` の Block の `In` の Service ∪ `Widget` の `of`(Service で重複を除く)。**`read_sources` / `reads_type_notes` と、`add_block_input_sources` の「束ねた `In` を source にする」を消す** ── 束ねた `In` は検査 6 で止める側へ回す
4. **Args の解決** ── Service の Args の欄ごとに、Block の `Arg` の同名の欄 → Page / Layout の同名の `Var` → `From`。`widget` 欄は `Widget` の `name:` のまま。`Widget` の `of` の `widget` 以外の欄は Page の変数から同名で直に取る。束ねられていない `Option` の欄は送らない。**名前の付け替えは `Var` 1 箇所だけ**(Block と Service は対応表を持たない)
5. **load と loader** ── Page ごとに `Vars` の record(Page と Layout の変数全部)を生成し、`load` は `Vars` と各 Service の Out を受ける。loader が Block ごとに `Arg` を組んで `view(out, arg)` を呼ぶ
6. **殻(`shell.mjs`)が 4 つの出所を読む** ── Path は route の一致、Query は URL、Session は **`/api/session` を 1 往復**(Session の変数を持つ Page だけ、同じ request の中で 1 回)、Origin / AuthOrigin は `env`(名前は裁定待ち 4)。`readFromApp` は path の穴と query string を **Args から**埋める(`matched.params` を直に使わない)。島の `given` の読みも同じ Args。**必須の Session が取れない(匿名 / 名義未選択)ときの応答は裁定待ち 3**
7. **型検査 7 つ(exit 4、Page の file・Block・欄を名指し)** ── 63「型検査で止めるもの」の 1〜7。**6(1 Block = 1 Service の外)は Y1e の束ねた `In` を含む**。どの Block も使わない `Var` は警告
8. **fixture を 0.10.0 の形に書き直す** ── `reads` の 2 箇所を消し、5 つの `From` を全部 1 回ずつ使う Page、`Arg` を Service の Args に流す Block と view だけが使う欄、`In = Nil` + `Arg` の Block、Page の変数を読む `Widget`、を置く。**負の fixture を検査ごとに 1 本以上**
9. **snapshot `8eed4d8` の写しで 21 file を試す**(musearch は書かない)── (i) 写しをそのまま 0.10.0 の生成器にかけ、**新しく出る exit 4 の行を全部、F6 の表の行に 1 対 1 で当てる**(未分類 0)、(ii) 写しに F6 の最小の書き換え(`vars` / `Arg` / Block の割り)だけを当て、**「語彙だけで戻る」分が sha256 ヘッダ付きの生成物で build 0 に届くこと**を示す。**写しの `api/` に Service を足さない** ── back の 1 行読みが要る分は表に Service の名・Args・Out の形で書く(到達線は裁定待ち 5)
10. **results**(`docs/reports/yumemi-1f.md`)── `## DDL`(無し)、`## 鷹野宛`、`## 追随便への申し送り`(**F6 の表** ── 21 file ごとに Page の `vars`、Block の `Arg`、割る Block、要る back の Service、の 4 列。加えて musearch の Page / Layout の const ごとの `reads` → `vars` の 1 行、割る Block の一覧、`env` の名前)、**51 v5 に足す文**(63「51 v5 で直す節」の 5 項)、基線の表

### 巡 1 の頭で読むもの

tech `63-page-variables.v0.md` 全文(末尾の裁定 3 つが正)、yumemi `docs/reports/yumemi-1e.md` の `## 追随便への申し送り` 全部、musearch snapshot の `BRIEF-yumemi-5.md` 末尾「鷹野の裁定(窓「段8」)」の 3、`BRIEF-2b-7.md` 末尾「役員 人見の裁定(16:52)」、tech `51-front-types.v5.md` の「Page の route」「Block」「書けないもの」。

## しないこと

**musearch への書き込み**(写しの `api/` に Service を足すのも含む)、**Hex publish**、**`~/yumemism_repo/yumemi`(main の作業木)**、**殻の門**(sign-in への redirect、`/switch` / `/consent` への振り分け ── F5 の ★)、**`reads` を非推奨で残す期間**(鷹野の裁定 6)、任意の env を変数にする口、アプリを跨ぐ origin、島の `calls` の Args(Y1d のまま)、Layout の Block に session を渡すこと、per-element given、minify、back の世代揃え、DDL、`main` への commit、push、`.claude/_core` `~/.codex` `~/.claude`。

## 移行 ── 0.10.0 は壊す版、0.9.0 の面は生成器ごと 0.9.0 に留める

**`reads` は非推奨を経ずに消す**(鷹野の裁定 6)。63 v0 の根拠「musearch は `reads` を 1 本も使っていない」は F5 で崩れる ── F5 が 3 面の Layout と Page に `reads: […]` を書き、2b-7 / 2b-8 も当座の 1 行を足す。**それでも消すのは、0.10.0 が壊す版で、F6 が `reads:` の 1 行を `vars:` の 1 行へ機械的に置き換え、`reads` に書いた Service は Block の `In` から導かれるから**(2b-7 は `reads` の行を results に消し先として列挙する)。

**Hex の版の pin は生成器を守らない。**musearch の便は `~/yumemism_repo/yumemi/gen` を呼ぶので、本便を main に merge した瞬間に F5 / 2b-7 / 2b-8 の生成が 0.10.0 の形で走る。**本便の merge の前に、0.9.0 の面の便が呼ぶ生成器を tag `v0.9.0` に固定する**(置き方は裁定待ち 2)。本便は main の作業木を触らないので、走行中は F5 に影響しない。

**本便は 0.9.0 の面の compile を 0.10.0 で保つ互換の層を作らない** ── 作ると障害 1 の二重持ちになる。0.9.0 と 0.10.0 の境は `gleam.toml` の版と生成器の置き場の 2 つで切る。

## 追随便 F6 の線 ── 21 file を生成物に戻す(musearch、本便の後、BRIEF は鷹野)

- **F6(仮名 `musearch-yumemi-6`)の射程:**3 面の `gleam.toml` を `>= 0.10.0 and < 0.11.0`、Page / Layout の `reads:` を全部 `vars:` に(F5 の 59 本前後 + 2b-7 / 2b-8 の行)、`Arg` を足す Block(63 の推定 14 前後)、1 Block = 1 Service に割る Block(`muse_header` / `home` を含む 7 本前後 → 17 本前後)、back の 1 行読み(推定 6、上の「現在地」)、**札 `値の出所 → Y1f` の 21 file を消して生成物に戻す**
- **F6 の検収の線:**21 file が全部 sha256 ヘッダ付き、札 `値の出所 → Y1f` が 0、3 面の `gleam build` 0 で exit 1 = 0、`reads` の grep 0。**本便の results の F6 の表が F6 の BRIEF の材料で、未分類 0 のまま渡す**
- **F6 の置き場は裁定待ち 6。**本便は F6 の置き場で形を変えない

## 失敗例

- **`reads` を非推奨の別名で残す / 束ねた `In` を「F5 が通っているから」と残す** ── 障害 1 の二重持ち。0.10.0 は壊す版で、互換は F6 が書き換えで持つ
- **出所を 4 つ目に増やす** ── `From` に `Literal`、`Var` に既定値、`Arg` の欄に既定値、`Query` の欄の既定値を Page に書く、Block の variant を Page の `Fixed` から構成子で選ぶ。人見 19:30 の裁定 1 に反する。`New` / `Edit` は Block を割る
- **session から計算した値を変数にする / 殻で計算する**(`has_store` を殻で数える)── Service の Out に畳む。殻が読むのは `subject.handle` と `subject.id` だけ
- **生成物か殻で id を比べて行を選ぶ**(▲ の `find_row` / `findRosterRow` を生成器に移す)── back の 1 行読みの Service を F6 の表に書く
- **決まった名前を全 Page に暗黙に置く**(案 C ── `handle` を Session から黙って差す、muses の ▲ 殻の形を生成物に写す)── 値の出所が Page の file に現れない
- **Block か Service に名前の対応表を持たせる** ── 付け替えは `Var` 1 箇所だけ
- **本便の生成器を `~/yumemism_repo/yumemi` の作業木で走らせる / 固定の前に merge を求める** ── F5 の生成が走行中に 0.10.0 に替わる
- **fixture で通して snapshot で試さずに閉じる**(G7 の P0 の轍)、写しで F6 の書き換えを当てずに「語彙はある」で閉じる(裁定待ち 5 の線に届かない)
- 基線を yumemi-1e.md から写す(毎巡 自分で打つ)、musearch を書く、同 persona の同秒起動、`^session_id:` での終了判定、push、Hex publish

## 検収

- root `gleam build` exit 0(既存 warning 1 から悪化しない)、`cd gen && gleam test` が **181 以上**
- fixture 生成が exit 0、再走 diff 空、face build exit 0 / warning 0、**SSR / isolate / given / file / overlay / Block preview が ALL PASS**、sha256 ヘッダの欠け 0、生成物の `gleam format --check` 0
- **変数:**fixture の SSR で、Path / Query / Session / Origin / AuthOrigin の 5 つがそれぞれ Service の request(path の穴か query string)か view の出力に出る(request の列を証跡に)。`/api/session` は Session の変数を持つ Page でだけ、1 request に 1 回。Session の欠けが裁定待ち 3 のとおりの応答
- **検査 7 つ:**負の fixture ごとに exit 4、Page の file・Block・欄の名が出る。どの Block も使わない `Var` は警告
- **消えたもの:**`src/framework` と `gen/src` に `reads` の欄・`read_sources`・`reads_type_notes` が 0、束ねた `In` を source にする分岐が 0(検査 6 の停止だけが残る)
- **snapshot `8eed4d8`(写し)で:**(i) 素の写しは exit 2 = 0、生成器を 2 回走らせて diff 空、**新しい exit 4 の行が F6 の表と 1 対 1**(未分類 0)、exit 1 / 3 / 警告は巡 1 の基線からの増減を行ごとに名指し、(ii) F6 の最小の書き換えを当てた写しで **「語彙だけで戻る」分(推定 15)が sha256 ヘッダ付きで 3 面 build 0**、残り(推定 6)は表の Service が無いことだけが理由
- **framework の差分**は `front.gleam` だけ、依存 package 数は不変、`gleam.toml` は 0.10.0
- musearch は無傷(`git status --short` 0 行、HEAD 不変)、`~/yumemism_repo/yumemi` の HEAD 不変、`## DDL`(無し)と `git diff --stat <基点> -- db/ gen/fixtures/article/db/` が空で一致
- results に F6 の表と 51 v5 に足す文。**終端は承認かエスカレーション**

**巡ごとに贄川が出すもの:**閉じた項(どこまで 1〜10)の数、`gleam test` の本数、fixture の file 数、snapshot の exit 1 / 2 / 3 / 4 / 警告、F6 の表の行数と未分類の数、musearch の `git status --short`(0 行)。**「継続」で裁定を待たない** ── 問いは終端で返す。

## 見積

**最短 4:00 / 中央 5:30 / 最長 8:30(推定)。**内訳は framework の型と reader(`vars` / `Arg` / view の 2 引数)0:40、Service の導出と Args の解決と `Vars` / load / loader 1:10、殻の 4 出所と `readFromApp` と given 1:00、検査 7 つと負の fixture 0:50、fixture の書き直しと verify(session / query / env の mock)0:40、snapshot の写しの 2 走と F6 の表と 51 v5 の文 0:50、ゲート 2 の P0 1 本の余地 0:20。**生成器の便は 2 本続けて見積の 1.5 倍に振れた**(G7 中央 6:00 → 実測 8:55、Y1e 中央 5:00 → 実測 8:00)── 最長 8:30 はその幅。**予算は中央 × 1.25 = 415 分**(61 の引き方、裁定待ち 7)。

## 裁定待ち ── 起動前に鷹野が裁く

1. **走らせる段。****水無瀬の推奨:段 9 で F5 と並走、snapshot は `8eed4d8` に固定。**本便は yumemi だけ、F5 は musearch だけで file が交わらない。中央 5:30 は F5 6:00 の裏に隠れる。21 file の ▲ は `8eed4d8` に既に在る(F5 はそのまま残す)ので穴の一覧は同じ木で読める。対案は F5 の merge 後に段 10 で 2b-7 / 2b-8 と並走(snapshot が F5 の木になって素直だが、段 10 の長柱が 2b-8 の中央 3:30(58 v4 §2)→ 5:30 に伸びる)
2. **0.9.0 の面が呼ぶ生成器の固定。****水無瀬の推奨:本便の merge の前に鷹野が `git worktree add ~/yumemism_repo/yumemi-v0.9 v0.9.0` を置き、F5 / 2b-7 / 2b-8 の BRIEF の生成器の置き場をそこへ差し替える**(F5 は走行中なら次巡から)。対案は本便の merge を F6 の起動まで止める(main が 0.10.0 の生成器を持たない期間が延び、F6 は `impl/yumemi-1f` の枝から生成器を呼ぶ)
3. **必須の Session が取れないときの殻の応答。****水無瀬の推奨:401 を返すだけ**(sign-in への redirect と名義の振り分けは F5 の ★ の門が先に効く ── 門の生成は別の便)。対案は生成器が `admit` から門を吐く(射程が 1 つ増える、+1:00 前後)
4. **設定値の `env` の名前。****水無瀬の推奨:`Origin(face)` → `PUBLIC_<FACE>_ORIGIN`(大文字)、`AuthOrigin` → `PUBLIC_IDP_ORIGIN`** ── console の wrangler の名前のまま、F6 で wrangler を書き換えない。対案は framework の名前(`YUMEMI_ORIGIN_<FACE>` など)で 3 面 × 2 env を改名
5. **snapshot の写しでの到達線。****水無瀬の推奨:「語彙だけで戻る」分(推定 15)は写しで生成物に戻し、back の 1 行読みが要る分(推定 6)は F6 の表に Service の名・Args・Out の形で書くまで。**写しの `api/` に Service を置くと、back の便の仕事を本便が形だけ先取りして F6 で書き直しになる
6. **F6 の置き場。****水無瀬の推奨:2b-7 / 2b-8 の後(段 11)** ── 58 v4 のゴール(2b と生成器)を動かさない。2b-7 / 2b-8 が足す `reads` と ▲ 例外も F6 が吸う。対案は段 10 の頭(2b-7 / 2b-8 が最初から `vars` で書け当座の 1 行が消えるが、2b の 2 便が F6 の中央 4:00 前後(推定)だけ後ろに落ちる)
7. **起動の予算。****推奨:415 分**(中央 5:30 × 1.25)。実測の 1.5 倍に合わせるなら 495 分

## 人見に聞く点(本便は止めない、既定で走る)

1. **Widget の枠の名(`muse_top_main` / `space_main`、Page の `Widget(name:)`)は「Page が書く定数」ではなく area と同じ配置の名として残してよいか** ── 既定:残す(嬢が widget を置く枠の名で、値の出所ではない)
2. **嬢の面の `/settings` の「同意」の表示も、09-24 16:35 の裁定(同意は画面に見えない)で消すか** ── 既定:消す(F6 の back の Service が 1 つ減る。本便の形は変わらない)
3. **報告 1 点:**58 v4 に無い便が 2 本増える ── 本便(中央 5:30、段 9 の F5 の裏なら長柱は伸びない)と F6(中央 4:00 前後、推定。2b-7 / 2b-8 の後なら 58 v4 のゴールの後ろに付く)
