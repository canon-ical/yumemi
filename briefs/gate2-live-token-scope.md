柏木:ゲート 2(live-token-scope、`a30ffa5..f9cd66b`)のレビューが終わりました。**P0 はありません。**P1 が 2 件、P2 が 1 件で、P2 は僕が直して commit しました。

## P0

P0 無し。

## P1(サマリに残してください)

**P1-1:allow が `Party` × `NoOwner` の読みを `Live` に置いても、生成器は止めず、札の表に載せます。**真壁の申し送りのとおりで、写しで確かめました。
- **試したこと:**article の写しで `article_read` を `Live` に置き、`Anyone` の句を `Clause(who: Party, at: Only([Published]), owner: NoOwner)` に替えました。生成器は Anyone の停止を出さず、`live` の表に `article_read: ['article', 'id']` が載りました(停止コード 3 は、写しに esbuild を置かなかったためです)。
- **何が起きるか:**入口の judge は session があれば `party` を通します。そのため、ログインした第三者がその root の書きの時刻を聞けます。musearch のように誰でも客として登録できる app では、実質 Anyone と同じです。
- **P0 にしない理由(不可逆ではない):**
  - 今 `Live` を使っているのは musearch の 2 面だけで、どちらも `blocks.ChatThread`(`chat_read`)です。`chat_read` の allow は `AsMuse × ViaMuseParty` と `AsFan × ViaFanParty` なので、この形には当たりません。
  - 後から止めを足しても、増えるのは exit 4 だけで、知っている app はどれも引っかかりません。
  - 穴が開くのは、★ がこの形の読みに `Live` を明示して置いたときだけです。
- **僕の推し:**0.14.1 はまだ出していないので、同梱してください。直すのは `public_read` の 1 か所です。

**生成器で「root の当事者だけが通る読み」を見分けられるか:**見分けられます。手がかりは句の `owner` です。
- `Self` または `Via<Entity>Party`:root の行が session の party に絞られます。framework は `clauses` を root の SQL へ渡します。手書きの root.sql なら、絞るのは ★ の役目です(`chat_read` は手書きでこれをしています)。
- `NoOwner`:どの行でも通ります。

**止める条件の案**(`public_read` を広げて、同じ所で exit 4 にする):
1. 句に `who: Party` かつ `owner: NoOwner` があれば止める(Anyone と同じ扱い)。
2. Entity の主体(`Staff`・`AsFan` など)× `NoOwner` は、警告(exit 0)で名指しする。その役が信頼された役か、誰でも登録できる役かは、生成器には分かりません。
3. 中身を読めない句(定数の参照・spread)は、判定できないので止める。読みの SQL の生成と同じ立場です。
4. 文言の例:「`… の allow の句 Party(owner: NoOwner)は session があれば誰でも root のどの行も通す(ログインした第三者が同じ root の書きの時刻を聞ける。owner を Self か Via<Entity>Party にする)`」

`chat_read` は 1〜3 のどれにも当たりません。

**限界:**owner で絞っても完全ではありません。root の当事者は、同じ root の、自分に見えない書きの時刻も聞けます(例:嬢の root に店が非公開の書きをすれば、嬢に時刻が届きます)。ここは ★ の判断として残ります。

**P1-2:`registry.mjs` の 1 行目は入力を「service declarations / entry.gleam / server.gleam」と書いたまま、ハッシュも api の入力だけから取っています。**`live` 表は面の Page にも依存するようになりました。0.12 の `counted`(`http_runtime.mjs`)と同じ形で、ハッシュを見て生成を飛ばす仕組みも無いので、生成物が古いまま残ることはありません。

## P2(直しました、commit `f9cd66b`)

**P2-1:0.14.0 の札の扱いの書き方が足りませんでした。**
- **何が抜けていたか:**socket の口(`http.mjs` の `liveSocket`)は、札の署名・期限・party・`Origin` を見て宛先へ渡すだけで、`live` 表は見ません。だから公開の読みで取った 0.14.0 の札は、0.14.1 に上げた後も期限(最長 1 時間)まで**新しい socket も張れます**。CHANGELOG の「張った socket は期限まで聞く」だけではこれが読み取れず、README にはまったく書かれていませんでした。
- **足したこと(CHANGELOG と README の「A read carries a token」):**
  - 札は期限まで通ること。
  - 上げるときに `YUMEMI_LIVE_KEY` を `YUMEMI_LIVE_KEY_PREVIOUS` 無しで替えれば、古い札は `signature` で落ちること。
  - 張っている socket は、遅くとも札の期限で終わること。
- 実装は変えていません。

## 見てほしいと言われた 5 点

1. **札の範囲は合っています。**
   - 札が付くのは、sp の Frame で `Live` に置かれた Block の読みで、root の Entity を持ち、公開でないものだけです(`front.gleam` の `live_reads`)。
   - 書きの行は、root の Entity を持つ書き全部のままです。
   - 表に無い読みは `destination` が null を返すので、`s.liveToken` が立たず、header ごと付きません(`http.mjs:190`)。
   - 面の数と生成の順:全部の面を `flat_map` してから `unique` し、表に入れるかは名前で照らすので、順序には左右されません。`back.emit` を呼ぶのは `gen.gleam:281` の 1 か所だけで、`live_reads` を入れた後の `app` を使っています。
2. **公開の読みの停止**は、`allow.Anyone` の略記でも `Clause(who: Anyone, ..)` でも停止コード 4 になりました(写しで実行)。
   - 小文字の `allow.anyone` では停止が効きませんが、生成されるコードが存在しない `import entity/anyone` を含むので、api が compile できません。迂回路にはならないので所見にしていません。
   - Party は上の P1-1 です。
3. **0.14.0 の札で張った socket:**README と CHANGELOG に書くべき内容です。上の P2-1 で書き足しました。
4. **block-door との合わせ:**
   - P2-1 の検査「`Fixed` の Block は `<yumemi-block name>` で返り、札を持たない」は残っていて、`ok` でした(`yumemi_live2_shell_check` の 18 行目)。
   - merge の解消も正しいです(test の改名と、件数 25)。
5. **fixture・test・検査の台本:**fixture の registry 3 本の差は、読みの行と注記だけでした。

## 走らせた検証

- `gleam test`:**`521 passed, no failures`**、rc=0(`build/k2/gleam-test.txt`)
- 検査の台本(どれも rc=0):
  | 台本 | ok | NG |
  |---|---|---|
  | `yumemi_live_check` | 93 | 0 |
  | `yumemi_live2_check` | 48 | 0 |
  | `yumemi_live2_shell_check` | 25 | 0 |
  | `yumemi_block_door_check` | 17 | 0 |
  | `yumemi_block_door_shell_check` | 18 | 0 |
- probe(scratchpad で article の写しを作り、allow を 4 通りに替えて生成器を走らせた):
  | 替えた句 | 結果 |
  |---|---|
  | `Party` × `NoOwner` | 表に載る(P1-1) |
  | `allow.anyone`(小文字の略記) | 表に載るが、api は compile できない |
  | `allow.Anyone` | 停止コード 4 |
  | `allow.party`(小文字の略記) | 停止コード 4(Actor の名前の衝突) |
- 基点の checkout(`yumemi`)の `git status`:untracked は `yumemi-fix-bench-findings.patch`(10-13 の物で、この便とは無関係)だけでした。

## 確かめていないこと

- P2 の commit の後は `gleam test` を回し直していません。変えたのは README と CHANGELOG の文だけで、README を読む test(y5)が探すのは `adult` の綴りだけです。
- Party の穴を workerd で実際に鳴らしてはいません。生成器の表(probe)と judge のコードから判断しました。
- 実の api と面の e2e、ブラウザでの 2 人の walk は回していません。

判定:**P0 無し**(P1 を 2 件。P1-1 は 0.14.1 に同梱することを推します)

以上、贄川さんへ返します。