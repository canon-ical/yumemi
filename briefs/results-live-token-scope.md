# results live-token-scope ── 合図の札を Live の Block の読みだけに付ける(0.14.1 に同梱)

真壁[IM]、2026-10-17。基点 `d6e2348`(`a30ffa5` + BRIEF の commit)。branch `impl/live-token-scope`。証跡は `build/scope-*.txt`(git の外)。push・tag・Hex は触っていない。柏木は起こしていない。DDL 無し。

## 1〜4 の充足

| # | 中身 | 置き場 | 充足 |
|---|---|---|---|
| 1 | 札は、どこかの面の Page(sp の Frame)で `Live` に置かれた Block の読みの Service にだけ付ける。生成器が面を読んだ後に `Live` の Block の Service を集めて `model.Server.live_reads` に入れ(0.12 の `counted` と同じ道)、api の registry の `live` 表の**読みの行をそれだけに絞る**。書きの行は今までどおり root の Entity を持つ書き全部。runtime(`http.mjs` の `liveIssue`)は手を入れていない ── 元から「表に在る読みだけ札」で、表に無ければ `s.liveToken` が立たず header ごと無い | `gen/emit/front.gleam` の `live_reads`・`live_service`・`public_read`、`gen.gleam`、`gen/emit/back.gleam` の `live_text`、`gen/model.gleam`、`gen/reader/server.gleam`。注記だけ `server/http.mjs`・`server/live.mjs` | 済 |
| 2 | `Live` の Block の読みの allow に `Anyone` があれば停止コード 4(止める形にした)。文言は下 | `gen/emit/front.gleam` の `live_block_notes` | 済 |
| 3 | 札の中身・socket の口・合図の撃ち方・`YumemiLive` は変えていない(`live.mjs`・`http.mjs`・`worker.mjs` は注記の字だけ) | ── | 済 |
| 4 | test(下の表)、README の「Where a signal goes」「A read carries a token」「What the generator stops」と `live.key_missing` の 1 句、CHANGELOG の 0.14.1(0.14.0 から振る舞いが変わる点として冒頭と 1 項目目に明記)、fixture の registry 3 本を生成し直し(rule 41)。lock は block-door で 0.14.1 済み | `README.md`、`CHANGELOG.md`、`gen/fixtures/{notes,article,cms}/src/gen/registry.mjs` | 済 |

## 生成器が止める条件と文言

条件:Page の sp の Frame の `Live(.., block: B, ..)` の B が受ける読みの Service が root の Entity を持ち、その Service の `subjects` に `Anyone`(`model.SubjectAnonymous`)があるか、allow の句に `who: "Anyone"` がある。句が 1 つでも `Anyone` なら止める(fixture の `article_read` のように `Only([Published])` で絞った `Anyone` も止まる)。

```
[exit 4 宣言の矛盾] <面> <Page>: Live(block: <Block>) の Block の Service <service> の allow に Anyone がある(公開の読みの札では、ログインしていない人も同じ root の非公開の書きの時刻を聞ける。Live の Block は root の当事者だけが通る読みにする)
```

`live_reads` の側でも公開の読みは表に入れない(止まるので生成物は書かれないが、二重に外す)。

## 採った形と退けた形

- **表は 1 つのまま、読みの行を絞る。**退けた形:`liveReads` の別の表を足して runtime で両方見る(runtime の変更が増え、0.14.0 の札の道を触る)。表の形 `Service -> [Entity, 'id']` は変わらない
- **`live_reads` は `Server` の欄**(`counted` と同じく `src/server.gleam` の宣言でなく生成器が面から足す)。api の実行時に面の宣言は読まない(BRIEF の失敗例)
- 停止は Layout・pc/tablet の `Live` を数えない(それらは既に exit 4)

## test の表と証拠

| # | 何を | 結果 | 証拠 |
|---|---|---|---|
| 1 | `gleam test` | **`521 passed, no failures`**(基点の 518 + 3) | `build/scope-test-4.txt` |
| 2 | 公開の読みの応答に札が付かない(workerd、表に無い `Anyone` の読み `note_open`、session 無し+browser cookie / session 有り) | ok、header ごと無い(`headers.has` が false) | `build/scope-run-yumemi_live_check.txt` の `scope:` 4 件 |
| 3 | `Live` でない読みに札が付かない(workerd、root を持つ当事者の読み `note_peek` を表から外す、party-a で 200) | ok、header ごと無い | 同上 |
| 4 | `Live` の Block の読み(表に在る、party が root の当事者)には付き、その札の socket が同じ root の別の party の書きで `1` を受ける | ok | 同上 |
| 5 | `node test/yumemi_live_check.mjs` 全体 | **ok 93、NG 0**(0.14.0 の 89 + 4) | 同上 |
| 6 | 生成器の表:面の無い notes は読みの行 0(`note_read` が外れる)・書きは残る / `live_reads` に在る読みだけ載る(root の無い `note_list` は名が在っても載らない) | ok | `registry_has_the_live_table_test`・`registry_lists_only_live_reads_test`(#1) |
| 7 | `front_emit.live_reads`:Live 無し → `[]`、非公開の `article_read` の Live → `["article_read"]`、Feed(root 無し)を Live に足しても `["article_read"]`、Fixed のまま → `[]`、公開の読みの Live → `[]` | ok | `live_reads_are_the_live_blocks_reads_test`・`live_on_a_public_read_stops_test`(#1) |
| 8 | 生成器の停止:fixture の公開の `article_read` を Live にすると note は上の 1 行だけ(gleam)。写しで生成器を本当に走らせると停止コード 4・上の文言(shell の検査) | ok | `live_on_a_public_read_stops_test`、`build/scope-run-yumemi_live2_shell_check.txt` 1 行目 |
| 9 | 生成した api の registry(写し、Anyone の句を外した `article_read` を Live に):`live` 表 = fixture の表 + `article_read` の 1 行(他の読みの行は無い) | ok | 同上 4 行目 |
| 10 | `node test/yumemi_live2_check.mjs` / `yumemi_live2_shell_check.mjs` | **ok 48 / ok 24、NG 0**(shell は 22 + 停止 + 表。写しは Anyone の句を外して生成し直す形にした) | `build/scope-run-yumemi_live2_*.txt` |
| 11 | `node test/yumemi_block_door_check.mjs` / `yumemi_block_door_shell_check.mjs` | **ok 17 / ok 18、NG 0** | `build/scope-run-yumemi_block_door_*.txt` |
| 12 | fixture の生成し直し:notes・article・cms を写し(`build/scope-fx`)で生成、rc 0・article は停止コード 0。差は `registry.mjs` の読みの行(notes `note_read`、article `article_read`・`article_title`、cms `article_read`)と注記 1 行だけ。写しの `src/gen/reads/*.gleam` の差は `gleam format` を通すと同じ(live-1 の results にある既知の formatter の差、本便の外)で、書き戻していない | ok | `build/scope-gen-*-1.txt` |
| 13 | mutation:表の絞りを外す(読みは全部載る)+ 公開の判定をいつも False | NG 3 件(`registry_has_the_live_table_test`・`live_on_a_public_read_stops_test`・shell の検査の停止)。戻して build し直した | `build/scope-mut-1.txt` |
| 14 | `gleam format --check`(触った gleam 7 file) | exit 0 | このセッションの実行 |

test の写しの変更:`yumemi_live2_test.gleam` の `emitted` は `article_read` から `Anyone` の句を外した写し(`private_read`)を使う(公開の読みの Live は止まるので)。`faces_without_live_are_unchanged_test` は元の units のまま(fixture と byte で比べるため)。shell の検査の admin の shell・gate の比べは、写しの `article_read` の字で動く 1 行目の入力の hash だけ伏せた。

## 逃げ道の案(作っていない)

★ が意図して公開の頁を Live にしたいとき:root と別に「公開してよい書き」だけが撃つ宛先を持つ形(例:`Live(.., public: True)` を置いた Block の読みの札は、`allow` に `Anyone` を持つ書きの commit だけを聞く宛先 `<entity>:<id>:public` に結ぶ)。書きの側の宛先を 2 つに分けるので合図の撃ち方に触る ── 本便の「しないこと」なので案だけ。

## 確かめていないこと

- **`Party` の句(session があれば誰でも、の読み)は止めていない。**`Live` の Block の読みが `Party` だけで root の当事者を絞っていない形なら、ログインした第三者に同じ穴が開く。BRIEF の範囲(Anyone)に留めた。要るなら同じ所(`public_read`)に足せる
- **0.14.0 の札で張った socket**は札の期限(最長 1 時間)まで同じ root の書きを聞き続ける。deploy の後 1 時間で消える(README・CHANGELOG に書いた)
- **musearch での効き目**は見ていない(後の便)。musearch の面で `chat_read` の Block が `Live` に置かれていれば `chat_read` だけが表に残り、`muse_top` などの読みの行は外れる、という読みは生成器の作りからの推定。公開の読みを Live に置いていれば生成が exit 4 で止まる
- 実の api と面を繋いだ e2e(wrangler dev)・ブラウザでの 2 者の walk は回していない。札の有無は workerd(手で書いた表)と生成器の表で分けて見た
- block-door のゲート 2 の P2 が後から乗った場合の合わせは鷹野の手(BRIEF どおり)

## DDL

無し。

## r2

真壁[IM]、2026-10-17。基点 `7c52679`(`f9cd66b` + BRIEF r2)。親は柏木のゲート 2 の P1-1。証跡は `build/r2-*.txt`(git の外)。push・tag・Hex・柏木の起動はしていない。DDL 無し。

### 1〜6 の充足

| # | 中身 | 置き場 | 充足 |
|---|---|---|---|
| 1 | `Live` の Block の読みの allow に `Party` × `NoOwner` の句(略記 `allow.Party`・小文字の `allow.party`・`Clause(who: Party, at: <どの相でも>, owner: NoOwner)`)があれば停止コード 4。`public_read` を句ごとの判定 `live_reach` に広げ、`Anyone` と同じ所(`live_block_notes`)で止め、`live_reads`(札の表)からも外す | `src/yumemi/gen/emit/front.gleam` の `Reach`・`live_reach`・`clause_reach`・`stops_live`・`reach_note` | 済 |
| 2 | Entity の主体 × `NoOwner`(`Staff`・`AsFan`、`gen/allow` の略記 `allow.staff` も頭を大文字に揃えて同じ)は警告(停止コード 0)で名指し、札の表には載せる | 同上 | 済 |
| 3 | 読めない句(定数の参照・spread・List でない allow、reader の `UnreadClause`)は停止コード 4。Service に allow の句の行が無いときも読めない扱い | 同上 | 済 |
| 4 | musearch の `chat_read` の allow(`~/yumemism_repo/musearch` main `9e80e40fb` の `api/src/service/chat_read.gleam` 75〜82 行)を test に写し、名指し 0・表に載ることを見た。musearch は読むだけ | `live_allow_of_parties_passes_test` | 済 |
| 5 | test(下の表)。既存の検査 5 本は通ったまま | `test/yumemi_live2_test.gleam` | 済 |
| 6 | README の「A read carries a token」に通る条件・止める条件と限界の 1 文、「What the generator stops」に Party × NoOwner と読めない句(停止)、Entity × NoOwner(警告)。CHANGELOG 0.14.1 の 2 項目目に同じ条件と限界、musearch の `chat_read` が通ること | `README.md`、`CHANGELOG.md` | 済 |

判定は句の `owner` だけで見る:`NoOwner` 以外(`Self`・`Via<Entity>Party`)は通す。`NoOwner` の句は `who` で分ける ── `Anyone` 停止(従来)、`Party` 停止、`System` 何もしない(browser から来ない)、それ以外(Entity の主体)警告。`at`(相)は見ない。

### 文言

```
[exit 4 宣言の矛盾] <面> <Page>: Live(block: <B>) の Block の Service <s> の allow の句 Party(owner: NoOwner)は session があれば誰でも root のどの行も通す(ログインした第三者が同じ root の書きの時刻を聞ける。owner を Self か Via<Entity>Party にする)
[exit 4 宣言の矛盾] <面> <Page>: Live(block: <B>) の Block の Service <s> の allow の句が読めない: <reader の名指し>(root の当事者だけが通る読みか判定できない。Live の Block の読みの allow は句を literal で書く)
[exit 0 警告] <面> <Page>: Live(block: <B>) の Block の Service <s> の allow の句 <Who>(owner: NoOwner)は <Who> なら誰でも root のどの行も通す(<Who> が誰でも登録できる役なら、同じ root の書きの時刻を聞ける。当事者に絞るなら owner を Self か Via<Entity>Party にする)
```

`Anyone` の文言は r1 のまま。`<reader の名指し>` は `allow の句 party_only`・`allow の spread(..)`・`allow が List の literal でない` など。

### test の表と証拠

| # | 何を | 結果 | 証拠 |
|---|---|---|---|
| 1 | `gleam test` | **`526 passed, no failures`**(r1 の 521 + 5) | `build/r2-test-4.txt` |
| 2 | 写しの `article_read` の `Anyone` の句を `Party` に替えて reader から通す:停止は Party の 1 行だけ、表は `[]` | ok | `live_on_any_party_read_stops_test` |
| 3 | `Party` × `NoOwner` の 4 形(`allow.Party`・`allow.party`・`Clause(.., Only([Published]), NoOwner)`・当事者の句と並べた `allow.Party`)は停止 1 行・表 `[]`。`allow.anyone` は Anyone の停止 | ok | `live_allow_of_anyone_in_the_session_stops_test` |
| 4 | 読めない句 3 形(定数 `party_only`・spread `..other.clauses`・`allow: other.clauses`)は停止・表 `[]` | ok | `live_allow_unread_stops_test` |
| 5 | Entity × NoOwner(`allow.staff`、`AsFan` × `NoOwner` と `AsMuse` × `ViaMuseParty`)は警告 1 行、停止 0、表に載る | ok | `live_allow_warns_test` |
| 6 | 当事者の句は名指し 0・表に載る:musearch `chat_read` の写し、`Party` × `Self`、`Staff` × `ViaStaffParty`(相付き)、`allow.System` | ok | `live_allow_of_parties_passes_test` |
| 7 | 既存:`live_warnings_test` は写しの `allow.staff` の新しい警告を除いて Block の警告だけを見るようにした(他の主張は変えていない) | ok | #1 |
| 8 | `node test/yumemi_live_check.mjs` / `yumemi_live2_check` / `yumemi_live2_shell_check` / `yumemi_block_door_check` / `yumemi_block_door_shell_check` | **ok 93 / 48 / 25 / 17 / 18、NG 0**、どれも rc=0 | `build/r2-run-*.txt` |
| 9 | mutation:`"Party" -> Some(AnyParty)` を `None` に | 2 件落ちる(#2・#3)。戻して build し直した | `build/r2-mut-1.txt` |
| 10 | `gleam format --check`(触った gleam 2 file) | exit 0 | このセッション |

test #3〜#6 は `allow_notes`:fixture の App の `clauses` の `article_read` の行だけを `reader/clauses.read` で読んだ句に差し替え、`live_notes`・`live_reads` を本物の道で通す(musearch の `AsFan` などの Entity は article に無いため、reader 全体は通さない)。

### しなかったこと

- **P1-2(`registry.mjs` の 1 行目の注記)は直していない。**生成物の header の字を変えると fixture の registry 3 本の生成し直しが要り、注記だけでは収まらないため。直すなら `emit/back.gleam` の header と fixture の生成し直しを 1 便で
- 札の形・socket の口・runtime は触っていない

### 確かめていないこと

- 生成器を写しで本当に走らせての Party の停止(shell の検査)は足していない。gleam の test は `live_notes` と reader を本物で通しているが、`gen.gleam` の停止コードの集計を経た exit 4 は r1 の Anyone の shell 検査(同じ `live_notes` の Conflict)からの推定
- musearch の api・面での生成は回していない。`chat_read` は allow の写しで判定だけ見た
- 実の e2e・ブラウザの walk は回していない
