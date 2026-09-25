# BRIEF yumemi-hw-1 ── 生成器の back の宿題 6 件(逆向き矢印・無診断・allow 句・札の素通り・`'draft'` 依存・列の選択)、Hex 0.11.0 は hw-2 と合わせて 1 回(2026-09-25、水無瀬[PL] 起草 → 鷹野[PDM] が裁いた)

便: yumemi-hw-1

**真壁さんへ。本便は 1 session で直に書き、終端で柏木のゲートを 1 回だけ受けます(贄川は通しません)。**基点は `impl/yumemi-1f` の `c2519de`(Y1f、承認済み・未 merge)。merge の順は decode-1 → Y1f → 本便 → hw-2。**hw-2(Actor の統一)が同じ基点から並走します** ── `emit/root.gleam`・`emit/allow.gleam`・`reader/allow.gleam` は hw-2 の持ち分で、本便は触りません。front(`emit/front.gleam` / `reader/front.gleam` / `src/framework/front*`)も触りません。

**親ゴール:** 生成器が back の読みで黙って落としている穴を塞ぎ、musearch が手書き ▲ で逃がしている読みを「生成物で置ける」形にする。あわせて、読みが使わない列まで返す形を β の前に止める ── Dleam の顧客は使わない列の分まで 4KB 単位で払う(keiei `_sessions/2026-09-25_02.md:100`、役員 人見「このあと塞ぐ」)。musearch の ▲ を外すのは後の追随便。

**障害:**
- **層ごとに判定が割れている** ── `with:` の逆向きは SQL 層では生成されて musearch も採用済みだが、型の層(`gen/query.gleam` の `Arrow`・reads の戻りの組)には出ない。片方だけ直すと、割れが別の場所へ動くだけ
- **認可と列が黙って漏れる** ── root を持たない Service の名前付き読みに allow 句が入らないまま exit 0 で通る。読みはほぼ全部 `SELECT x.*` で、選ぶ口が無い

## 現在地(`c2519de` × musearch main `728adfa` の写し、水無瀬 09-25 実測。musearch は書かない)

- `cd gen && gleam test` **194**。写しの `api/` に 2 回当てると、back の出力 **725 file**、2 回の diff 空。exit 4 = **back 22 行**(`schedule_*` 曖昧 16 / `store_roster_list` 5 / `pageview_record` 1)+ 面 89 行、exit 1 = 3(面の値の出所 ── F6 待ち)、exit 3 = 1(`www/src/shell.gleam` 無し ── F5 待ち)、警告 **48 = 札の素通り 24 + module 名 24**
- **逆向き矢印:**`reader.gleam:1256-1273` の `arrows` は子→親だけ。`emit/typing.gleam:133` の `row` は `select.with` を見ない。SQL 層は `emit/sql.gleam:716-803` が Held の逆向きを出す(`roster_list/listed.sql` は photos 付きで ▲ と本文一致)。▲ の形は reads 5 本(`roster_list` / `roster_read` / `store_roster_list` / `link_import_apply` / `link_import_read`)、例 `List(#(Roster, Phase, List(RosterPhoto)))` / `Option(#(LinkImport, List(LinkImportCandidate)))`
- **無診断:**`reader.gleam:1913-1916` の `arrow_names` が、構成子でない項を `filter_map` で捨てる。型の層は `with` を見ないまま exit 0
- **allow 句:**`emit/sql.gleam` に allow を注入する処理が無い。model の Service は allow について `subjects` しか持たない(`model.gleam:384-397`)。▲ は musearch `api/db/queries/article_search/nearest.sql`(`EXISTS(… jsonb_array_elements($2::jsonb) …)` で phase と `via_muse_party`)
- **札:**`emit/verb.gleam:102-119` ── `handwritten_verbs` の名が生成候補に無いと、警告 1 行で素通りする。musearch は 9 entity に 24 名(8 → 24、2b-4 / 2b-6 で増えた)
- **`'draft'`:**`gen/test/yumemi_gen_test.gleam:1615-1627` が `,'draft'` の文字列分割で placeholder を数える(`:1302` から 5 fixture)
- **列の選択:**`Select` に返す列の欄が無い(`src/framework/query.gleam:82-95`、生成 `gen/query.gleam` の `Select` も同形)。写しの読み SQL 157 本のうち **153 本が `SELECT x.*`**(`chunk` の embedding も返る)。musearch の ★ は `q.Select(` の literal **72 本 / 45 file**、fixture 12 本

## どこまで

1. **逆向き矢印** ── `with:` に書いた Held の逆向きを型の層に出す。`gen/query.gleam` の `Arrow` に `RosterToPhotos` / `LinkImportToCandidates` が出て、reads の戻りの組の末尾に子の `List` が載る(上の ▲ の形)。名の規則は `emit/sql.gleam:775` の `with_name_matches` と 1 箇所にまとめる
2. **無診断** ── `join:` / `with:` の項が矢印として読めない、または SQL 層と型の層のどちらか一方でしか出せないときは、exit 4 で service・const・項を名指しして止める。片方だけ出る形を無くす
3. **allow 句** ── root を持たない Service(`Root(at, seed)`)の名前付き読みで、allow が phase / owner を絞るなら、生成 SQL の WHERE に allow 句を入れる(`nearest.sql` の形)。入れられない形は exit 4。clauses の jsonb と party の引数の番号を results に契約として書く。owner の名から party への道(`ViaMuseParty` = muse の party)の規則は hw-2 の `party_of` と同じ規則にし、results に 1 行で書く
4. **札の素通り** ── 生成候補を持たない手書き verb を宣言する語を足す(既定名 `manual_verbs`)。載せた名は警告を出さず、ヘッダの `handwritten:` の扱いは今の札と同じ。`handwritten_verbs` が候補と一致しないときの警告は残し、文言で新しい語を名指しする。新しい語の名が生成候補と一致したら exit 4
5. **`'draft'` 依存** ── `:1615` の数えを、phase の綴りに依らない形にする
6. **列の選択** ── `Select` に返す列を選ぶ口を**非破壊で**足す(既存の literal 72 本と fixture は 1 字も直さず、出力も変わらない)。選んだ Select は、SQL が選んだ列だけを返し、reads の戻りは Entity 型でなく選んだ列の record になる。from / join に無い列、空の選択、keyset / order / with が要る列を落とす選択は exit 4。行の JSON の欄名と record の欄名の対応を results に書く(musearch の runtime が読む契約)

**しないこと:**Actor と `gen/allow`(hw-2)、root の `version`・`sql_manifest.json` の旧綴り(musearch の F6 の後の追随便)、`root.sql` と allow SQL の生成、`runtime.mjs` / `registry.mjs`、front の生成器、musearch と `~/yumemism_repo/yumemi-decode-1` の木への書き込み、`gleam.toml` の version、publish、push、`main` への commit。

## 失敗例

- SQL 層だけ、または型の層だけを直す。allow 句を「読み手が絞る」として落としたまま exit 0 で通す
- 列の選択を `Select` の必須欄にして ★ 72 本を壊す。新しい札の語で、名の打ち間違いが黙って通る
- hw-2 の持ち分(`emit/root.gleam` ほか)に手を入れる。`yumemi_gen_test.gleam` の既存の test を書き換える(追記だけにする ── hw-2 との merge を追記の衝突だけにするため)
- fixture でだけ通して写しで試さない(G7 の P0 の轍)。musearch の ▲ と「同じ形になった」と、本文の対照無しに書く

## 検収(真壁さんが自分で回す)

- root `gleam build` 0、`cd gen && gleam test` **194 以上**(6 項それぞれに正と負の test)、fixture を 2 回生成して diff 空・tracked と一致
- 写し `728adfa`(run の外に置き、musearch は書かない)に 2 回当てて diff 空。**exit 4 の back 22 行と警告の module 名 24 は動かさない**。札 24 は、写しの ★ の 24 名を新しい語へ移した写しで 0。増えた行は全部名指しする
- 写しで、reads 5 本と `nearest.sql` の生成物と musearch の ▲ の本文の対照表を作る(差は行ごとに理由)。列の選択は、写しの Select 1 本(例 `roster_list.listed`)に選択を足した写しで、SQL の列と reads の record が一致すること。`gen/query.gleam` は ★ の requalify 前なので被せない(From / Field を submodule に割るため `q.Article` が解決しない ── 写しで 268 error、keiei `canon/open.md` の yumemi の行)
- `docs/reports/yumemi-hw-1.md` に `## DDL`(無し)・`## 鷹野宛`・`## 追随便への申し送り`(musearch の ▲ のうち生成物で置ける file の一覧)。終端は承認かエスカレーション

## 鷹野の裁定(09-25)

- **2 本に割る。**壁時計が一番足りない予算(役員 人見)なので、並走できる割り方を優先する。本便 = 1・2・3・6・8・9、hw-2 = 4 Actor の統一。交わりは `yumemi_gen_test.gleam` への追記と、emit の登録の数行だけ。merge は本便 → hw-2 で、衝突は鷹野が畳む
- **Hex は 0.11.0**。本便と hw-2 の両方を merge してから、1 回で出す
- **5(root の version)と 7(manifest の旧綴り)は本便の外。**★ の entity に `version: Int` を宣言する形と manifest の綴りは、どちらも musearch の F6 の後の追随便へ
- **宿題 9 件の外の 3 つ**(query の requalify / `root.sql` と allow SQL / 今すぐ採れる root 4 本)は本便に入れず、keiei `canon/open.md` の yumemi の行に立てた
- **見積(推定):**最短 4:25 / 中央 5:55 / 最長 9:30、予算 445 分(中央 × 1.25)。うち列の選択が中央 2:15

## 役員 人見の裁定(09-25 18:5x)── framework の `Select` に列の選択を足す

**破壊的変更で構わない。yumemi にはまだ利用者がいないので、今のうちに直す(役員 人見「いまなら間に合う」)。**真壁の鷹野宛 3(`Pick` を生成の `gen/query.gleam` にだけ足し、framework `src/framework/query.gleam` の `Select` には足さなかった)を覆す。framework の `Select` に返す列の欄を足し、生成 SQL の `SELECT x.*` が選んだ列に変わるところまでを本便に入れる。型引数が増えるのは受ける。Hex は予定どおり 0.11.0(hw-2 と合わせて 1 回)。柏木のゲートの後、P0 と一緒に真壁を新しい session で 1 回起こして直させる。
