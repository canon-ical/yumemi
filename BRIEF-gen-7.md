# BRIEF gen-7 ── musearch の面を生成物で差し替えるために閉じる生成器の穴(草案、2026-09-22、水無瀬[PL] 起草 → 鷹野[PDM] が裁いて commit)

便: yumemi-gen-7

**前提は 3 つ。**(a) **Y2(`yumemi-gen-6`)の承認** ── yumemi main `bd8f3fb`、Hex 0.7.0 のまま。`docs/reports/gen-6.md` の `## P1`(13 件)と `## 束 1: 15 file の差分分類`が本便の材料、(b) **musearch を snapshot に固定して読む** ── **基点の snapshot は musearch main `<段 6 merge sha>`**(穴のまま。段 6 の 2 便が `console/` の面 package を足した後)。**`~/yumemism_repo/musearch` は一度も書かない**(gen-6 の型 ── `git status --short` 0 行を証跡に)、(c) **F4 / F4B の URL の裁定は本便に要らない** ── 本便は route 表の中身ではなく生成器の口を触る。**基点は yumemi main `bd8f3fb`**。作業木は `~/yumemism_repo/yumemi-gen-7`(branch `impl/gen-7`、基点から、贄川が作る)。plan は贄川の run_dir、記録は `docs/reports/gen-7.md`(**`## DDL` 必須、本便は「無し」**)、証跡は `gen/build/gen7-*`。commit は `git-as <役>`、`main` に触らない、push と **Hex publish は鷹野**(`.hex-token` は `~/canonical/tech/`)。1 巡 = 1 session、ゲートは 1 も 2 も便に 1 回、ゲート 2 の P0 を直す巡は真壁を sol で。柏木は**実行経路 C**(`claude-kashiwagi`、Opus xhigh)、真壁は luna。**見積 4:30(推定** ── gen-6 の 10:01 / 巡 12 より小さく、gen-3b / Y1d より大きい。**裁定待ち 1 で Hex が動くなら +1:30**)。

**親ゴール:** tech `_drafts/gleam-framework/00-goal.md` の G2 ── **`musearch-yumemi-5` が musearch の 3 面の ▲ を生成物へ差し替えられる状態を作る。**本便のゴールは生成器の完成ではなく、**差し替えを止めている穴だけを閉じること。**

**障害:**

- **`custom_decoder` の複数 variant の先頭固定**(gen-6 P1-1)── **これが閉じていない生成器で面を差し替えると、musearch の `widget_list` の 6 variant のうち `Text` だけが構築され、嬢の console の widget が全部テキストで描かれる。**落ちないので誰も気づかない
- **reader が Gleam の受ける構文で止まる** ── spread の後の末尾カンマ(`[a, ..rest,]`)を glance が `UnexpectedToken(Comma)` で読めず **exit 2**。gen-6 の検収で P4 の `api_doc.gleam:26` が実際に踏み、鷹野が musearch 側で末尾カンマを外して回避した(main `c99c107`)。**「壊れた 1 本で exit 2」は生成器の口の問題**
- 穴を「全部閉じてから」にすると便が終わらない(gen-6 の P1 は 13 件、そのうち framework が動くものが 3 件)
- **`fallbackClient` が exit 0 + 警告 1 本で素の entry を書く** ── 警告 31 本の中に紛れ、**差し替え便が本物でない bundle を採用する**
- **生成物が `gleam format` に掛かっていない** ── 77 file の差分が人に読めず、`musearch-yumemi-5` の棚卸しが成立しない
- musearch を書く(snapshot 固定の破り)

## 現在地(数字は yumemi main `bd8f3fb` / musearch `c99c107` の実測)

- **gen-6 の基線:**root `gleam build` exit 0(既存 warning 1)、`cd gen && gleam test` **128 passed**、fixture **86 file**(再走 diff 空)、front SSR / isolate / given / Block preview **ALL PASS**、sha256 ヘッダ **808 file / 欠け 0**。**musearch `c99c107` での実測:exit 4 = 21 行 / 警告 31 / exit 2 = 0 / 903 file = back 611 + www 159 + muses 133、back の採用済み 290 一致 / 差 0**
- **`gen/src` は 25 file / 16777 行。**`custom_decoder` の根は **`gen/src/yumemi_gen/emit/front.gleam:3956-3963`**(gen-6 の名指し)── **fields を持つ複数 variant の型なら型名を問わず先頭 variant だけを `decode.success` する**(`Row` 固有ではない)。**踏む対象は musearch の生成 `out/` 98 本のうち 1 本、fixture の 6 本のうち 1 本 = 計 2 本**で、fixture 側は `public/src/gen/shell.mjs:33,35` の `decodeWidgetList` が SSR の source として実際に通す
- **gen-6 の P1 13 件の分類(水無瀬):**
  - **差し替えを止めているもの(本便の必須):**1(`custom_decoder`)、**reader の末尾カンマ**(番号無し、鷹野の追記)
  - **差し替えの読みを妨げるもの:**8(生成物が `gleam format` に掛かっていない)、12(**`fallbackClient` で黙って劣化** ── `repositoryRoot()` が cwd の basename で決まり、temp build か `npx --yes esbuild` が落ちると素の entry を書いて **exit 0 + 警告 1 本**に落ちる。柏木ゲート 2。**追随便の再現性に直接効く**)
  - **生成物の穴(差し替え後に musearch で見える):**2(Block preview の Layout 欠落)、3(opaque decoder の placeholder assert 4 箇所)、5(`--bg-image` が `url("…")` に包まれない)、7(`validate` の失敗の文言が全部 `"invalid"`)、10(`widget_list` の `Summary` が logic から構成されない)
  - **framework が動く = Hex の版が上がるもの(裁定待ち 1):**13(同じ tag の各 island へ given を client 初期化時に配る ── lustre の `register` が tag 単位)、**`Fixed(of:)` か `Page.reads`**(Page が Block 用の 2 本目の読みを宣言できない ── front-3 の P1-9 / 鷹野宛 2)、**`Target` を framework 所有に上げる**(front-4 の申し送り ── 島の `calls` が `List(service.Service)` と `List(api.Target)` の 2 形に割れた)
  - **その他:**4(面 package の direct dependency `sketch` / `sketch_lustre` の notice 56〜57 件)、6(`client.mjs` が 181,827 B / 6,224 行)、9(`framework/page` を import する写しが 3 file)、11(穴を持たない名前付きクエリの `P` enum)
- **gen-6 裁定 7 で送られた「生成物 14 種目」(静的資料の写し)の源は front-4 の results で確定している** ── `api/src/external_hosts.mjs`(`.mjs`、6 件)/ `docs/api-v1.md`(84 行、`api/priv/` に写しは無い)/ `api/src/gen/http_runtime.mjs` の付属入口表。**`source.load` は `.gleam` しか読まない**(gen-6 のエスカレーションの理由)ので、`.mjs` と `.md` を読む口が要る
- **gen-6 裁定 10 の `src/shell.gleam` は口だけ在って実体が無い** ── 51 v5:121 が 3 const(`lang` / `title` / `theme`)を定め、**生成器は読むだけ**。musearch の 3 面には**まだ 1 本も置かれていない**(`musearch-yumemi-5` が置く)。**本便は「無ければ既定に落ちる」ではなく「無ければ診断」にするかを決める**
- **`registry.mjs` の生成物化は Y 候補のまま**(F4 裁定 2)。**gen-6 の報告が「registry.mjs は musearch が今動かしている古い世代の back 生成物で、この生成器は `registry.mjs` を出さない」「追随便は面だけを差し替えず、back の生成物も同じ世代に揃える」と書いた** ── 本便に入れるかは裁定待ち 2
- **front-1 の `## Y2(gen-6)への申し送り` の「▲ の道と名前の表」が、生成器が再現すべき出力の仕様書**(module の道 / const 名 / 型名 / 関数名が 10 区分で並ぶ)── 本便で口を足すときはこの表の名前を動かさない
- **枠:**10:42 の rates は **codex weekly 4 = 減りすぎ**、claude weekly 25 無印。**柏木は経路 C(claude opus xhigh)で codex を食わない** ── codex を食うのは**ゲート 2 の P0 を直す真壁 sol の巡だけ**。尽きたら P0 の直しは庵野 + 柏木ゲートの形へ(鷹野の How)
- **並走:**musearch の便(F4B / svelte-out-1)と同じ段でよい ── **リポが違うので衝突 0**。gen-6 も段 5 で musearch 4 便と並走して事故なし

## どこまで

1. **`custom_decoder` の複数 variant**(P1-1、**必須**)── fields を持つ全 variant を出し分ける decoder を吐く。**fixture の `Row { ArticleRow Summary }` と musearch の `out/widget_list.gleam` の 6 variant の両方で、variant 固有欄(`articles` / `links` / `heaven_public`)が落ちないこと**を試験で
2. **reader が spread の後の末尾カンマを受ける**(**必須**)── glance の版を上げるか前処理で。**「Gleam の compiler が通す構文で生成器が止まる」を無くす**のが線。ほかに同型の構文が在れば results に一覧
3. **生成物に `gleam format` を掛ける**(P1-8)── 差し替え後の diff が人に読めるようになる
4. **`fallbackClient` の黙った劣化を止める**(P1-12、柏木ゲート 2)── **exit 0 + 警告 1 本で素の entry を書く形をやめ、停止コードで鳴らす**。`repositoryRoot()` が cwd の basename に依存する形も直す
5. **生成物 14 種目(静的資料の写し)**(gen-6 裁定 7)── 源の口は上の 3 つ。**`.mjs` と `.md` を読む口**を 1 本。**台帳が動いたら公表文も動くことを試験で**
6. **面の ★ `src/shell.gleam` を読む**(gen-6 裁定 10、51 v5:121)── 3 const を読み、`shell.mjs` の殻に出す。**無いときの挙動を決める**(診断か既定か ── 決めた理由を results に)
7. **P1 の 2 / 3 / 5 / 7 / 10 のうち、巡が余った分だけ**(**余らなければ全部申し送り** ── 本便は差し替えを止めている穴が先)
8. **results**(`docs/reports/gen-7.md`)── `## DDL`(無し)、`## 鷹野宛`、`## 追随便への申し送り`、**閉じた穴と残した穴の表**(gen-6 の P1 13 件 + 追加分に対する行き先)、**基線の表**、**musearch snapshot での再走の数字**

### 巡 1 の頭で読むもの

`docs/reports/gen-6.md` 全文(到達表 13 種 / 15 file の分類 / P1 13 件 / 基線)、musearch snapshot の `docs/front-{1,2,3,4}/results.md` と `docs/console-1b/results.md` の `## Y2(gen-6)への申し送り`(**front-1 の「▲ の道と名前の表」が生成器の出力の仕様書**)、tech `51-front-types.v5.md` の `## Layout` / `## 生成器が吐くもの` / `## テスト`。

## しないこと

**musearch への書き込み**(snapshot は read-only、`git status --short` 0 行を証跡に)、**Hex publish**(鷹野)、**framework の型を動かすこと**(裁定待ち 1 で入らない限り ── `Fixed(of:)` / `Page.reads` / `Target` / per-element given)、**`registry.mjs` の生成物化**(裁定待ち 2)、**back の生成物の世代揃え**(musearch 側の便)、**URL / route 表の中身**(F4 / F4B)、**生成器の再設計**、**DDL と migration**、`main` への commit、push、`.claude/_core` `~/.codex` `~/.claude`。

## 失敗例

- **`custom_decoder` を `Row` 固有の直しで閉じる** ── 根は「fields を持つ複数 variant の型なら型名を問わず」(gen-6 の名指し)。**musearch の 98 本のうち今日 1 本しか踏んでいないだけ**で、Service が増えれば増える
- **末尾カンマを musearch 側で避け続ける**(鷹野が `c99c107` でやった回避は一度きりの応急)── **生成器が Gleam の構文を読めないまま**では、次に誰かが書いた瞬間に exit 2 で全便が止まる
- **`gleam format` を掛けずに差し替え便へ渡す** ── 77 file の差分が読めず、**消えた分岐の棚卸し**(`musearch-yumemi-5` の「どこまで」3)が成立しない
- **`fallbackClient` を「警告が出ているから見れば分かる」で残す** ── 警告 31 本の中に紛れる。**exit 0 で劣化する形は残さない**
- **P1 13 件を全部閉じようとして巡を使い切る**(gen-6 は巡 12 = 枠いっぱいだった)── **1 / 2 が閉じていれば差し替えは始められる**
- **musearch を書く**(gen-6 は 3,490 file 無傷で通した)
- **`shell.gleam` が無いときに「既定色を生成器がべた書き」で埋める** ── gen-6 裁定 10 が禁じた「手書きが先・生成器が後」の逆転そのもの。**無いなら診断で鳴らす**のが筋(決めた形を results に)
- **14 種目の源を `api/priv/` に新設する** ── 現物は `api/src/external_hosts.mjs` と `docs/api-v1.md` で、**源を作ると「手書きが先」がまた逆転する**(gen-6 のエスカレーションの理由そのもの)
- **fixture を直して musearch で試さずに閉じる** ── `custom_decoder` も末尾カンマも、**musearch snapshot での再走で確かめる**(fixture の 6 本と musearch の 98 本は形が違う)
- **基線の数字を「前の便がそう書いていたから」で写す** ── gen-6 は基線の訂正を 2 回やっている(`gleam test` 89、生成 604 file)。**毎巡 自分で打つ**
- 同 persona の同秒起動、`^session_id:` での終了判定、push、Hex publish

## 検収

- root `gleam build` exit 0(既存 warning 1 から悪化しない)、**`cd gen && gleam test` が 128 以上**
- **fixture 生成が exit 0 / 86 file 以上、再走 diff が空**、fixture face build exit 0 / error 0 / warning 0
- **front SSR / isolate / given / Block preview が ALL PASS**、sha256 ヘッダの欠け 0
- **musearch snapshot `<段 6 merge sha>` で:exit 2 = 0、exit 3 = 0、exit 4 と警告が基線から悪化しない**、file 数を results に。**再走 diff が空**
- **`custom_decoder`:**fixture の `Row { ArticleRow Summary }` と musearch の `out/widget_list.gleam` で**全 variant が構築され、variant 固有欄が落ちない**ことを試験 2 本以上で
- **末尾カンマ:**`[a, ..rest,]` を含む file を fixture に 1 本置き、**exit 2 が出ない**
- **`fallbackClient`:**esbuild を落とした状態で走らせ、**exit 0 で通らない**(停止コードと診断が出る)
- **14 種目:**源(`.mjs` / `.md`)を 1 字動かすと生成物も動くことを試験 1 本で
- **`shell.gleam`:**fixture に 1 本置いて 3 const が殻に出ること、無いときの挙動が決めたとおりであること
- **`gleam format --check`** が生成物に対して 0
- **musearch は無傷** ── `git status --short` 0 行、HEAD 不変、file 数不変
- **gen-6 の P1 13 件 + 追加分が、全部「閉じた」か「残した(行き先つき)」のどちらかに落ちている**(未分類 0)
- `## DDL`(無し)と `git diff --stat <基点> -- db/ gen/fixtures/article/db/` が空で一致
- results に `## 鷹野宛`、`## 追随便への申し送り`、上の表 2 枚

**巡ごとに贄川が出すもの:**閉じた穴の件数、`gleam test` の本数、musearch snapshot の exit 2 / exit 3 / exit 4 / 警告 / file 数、musearch の `git status --short`(0 行)。**「継続」で裁定を待たない** ── 問いは終端で返す(58 v3 §7-15)。**529 で落ちたら孤児の pid の消滅を待ってから起こし直す**(§7-12)。

## 裁定待ち ── 起動前に鷹野が裁く

1. **framework が動く 3 件を本便に入れるか**(= Hex 0.8.0 を出すか)── (i) `Fixed(of:)` か `Page.reads`(Page が Block 用の 2 本目の読みを宣言できない ── いま musearch の `shell.mjs` が直に引いている)、(ii) `Target` を framework 所有に上げる(島の `calls` が 2 形に割れている)、(iii) per-element given(lustre の `register` が tag 単位 ── **lustre 側の変更が要るので本便では閉じない見込み**)。**水無瀬の推奨:(i) と (ii) は入れる、(iii) は申し送り。**(i) を入れないと `musearch-yumemi-5` の棚卸しで `shell.mjs` の直引きが「生成器が吐くべき」の山に積み上がり、面が生成物だけで建たない。**入れるなら Hex 0.8.0 と、musearch 3 面の `gleam.toml` の版の上げが `yumemi-5` に乗る**(+1:30 前後)
2. **`registry.mjs` の生成物化(back の世代揃え)を本便に入れるか。**gen-6 が「追随便は面だけを差し替えず、back の生成物も同じ世代に揃える」と書いた件。**水無瀬の推奨:入れない** ── F4 が registry を手で作り直した直後で、生成器が同じ file を吐き始めると F4 の一致試験の意味が変わる。**F4B の後に「back の世代揃え」1 便(yumemi + musearch の 2 本)を立てるのが筋**。入れるなら本便は +3:00 前後で、`yumemi-5` の前提が 1 本増える
3. **P1 の 2 / 3 / 5 / 7 / 10 をどこまで入れるか。****水無瀬の推奨:巡が余った分だけ**(gen-6 は巡 12 で枠いっぱいだった)── 優先は 3(placeholder assert = invalid 入力で panic)> 5 > 10 > 2 > 7
4. **snapshot の基点。**段 6 の merge 後(`console/` の面 package を含む)か、F4 / F4B の merge 後(URL が動いた後)か。**水無瀬の推奨:段 6 の merge 後** ── 本便は route 表の中身を見ないので URL が動く前で足り、段 7 の中で F4B と並走できる

## 人見の卓(本便は裁かない)

- **無し。**裁定待ち 1 は Hex の版が上がる話で、`yumemi` の版は 0.x の間は鷹野の裁きで動いてきた(0.5.0 / 0.6.0 / 0.7.0)。**人見の卓に上げるとすれば「front の型に欄を足すことの是非」だが、51 v5 の裁定(2026-09-21、役員 人見)がすでに `Fixed` の形を定めており、`of:` を足すのはその追認の範囲**。異論が在れば鷹野が上げる


## 鷹野の裁定(2026-09-22 15:35、段用予備の窓、稼働中のバトン 1 条)

1. **framework が動く (i) `Fixed(of:)` / `Page.reads` と (ii) `Target` の framework 所有化は入れる ── Hex 0.8.0**(裁定待ち 1、水無瀬の推奨)。(iii) per-element given は lustre 待ちで申し送り。publish は鷹野(承認後、`yumemi-5` の前)。**Y1e(ファイル入力の `Set` に Binary の枝)を 0.8.0 に同居させるかは人見の卓** ── 同居なら本便に束 1 つ(+1:33)、既定は入れない
2. **`registry.mjs` の生成物化は入れない**(裁定待ち 2)── F4B の後の「back の世代揃え」1 便(yumemi + musearch)
3. **P1 の 2 / 3 / 5 / 7 / 10 は巡が余った分だけ、優先は 3 > 5 > 10 > 2 > 7**(裁定待ち 3)。bundle の minify(P1-6)も同じ列の最後尾
4. **snapshot の基点は musearch の段 6 の merge 後**(裁定待ち 4)── 段 7 の頭で F4B と並走
5. **D1 が代案(動詞 → method の対応表)で裁かれたら、その対応表は本便に同居**(musearch 4b の裁定 3)── 起動時点で届いていれば「どこまで」に 1 項足す、届いていなければ入れない
