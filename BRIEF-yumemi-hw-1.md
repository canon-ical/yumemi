# BRIEF yumemi-hw-1 ── 生成器の back の宿題 7 件(逆向き矢印・無診断・allow 句・Actor の統一・札の素通り・`'draft'` 依存・列の選択)、Hex 0.10.1(草案、2026-09-25、水無瀬[PL] 起草 → 鷹野[PDM] が裁く)

便: yumemi-hw-1

**真壁さんへ。本便は 1 session で直に書き、終端で柏木のゲートを 1 回だけ受けます(贄川は通しません)。**基点は `impl/yumemi-1f` の `c2519de`(Y1f、承認済み・未 merge)。merge の順は decode-1 → Y1f → 本便で、decode-1 と Y1f が触ったのは front(`emit/front.gleam` / `reader/front.gleam` / `src/framework/front*`)だけ ── 本便はそこを触りません。

**親ゴール:** 生成器が back で黙って落としている 7 つの穴を塞ぎ、musearch が手書き ▲ で逃がしている読み・root・allow を「生成物で置ける」形にする版を出す(musearch の ▲ を外すのは後の追随便)。

**障害:**
- **層ごとに判定が割れている** ── `with:` の逆向きは SQL 層では生成され musearch も採用済みなのに、型の層(`gen/query.gleam` の `Arrow`・reads の戻りの組)には出ない。片方だけ直すと割れが別の場所へ動くだけ
- **生成物が生成されない module を指す** ── 生成 root は `import gen/allow/<entity> as allow` を吐くが、生成器は `gen/allow` を 1 本も吐かず、root の `Actor` の variant 名(`Anonymous` / `AsStaff` …)は musearch の ▲ `allow.Actor`(`StoreActor` / `AnyActor` …)と衝突する
- **認可が黙って落ちる** ── root を持たない Service の名前付き読みに allow 句が入らず、exit 0 で通る

## 現在地(`c2519de` × musearch main `728adfa` の写し、水無瀬 09-25 実測。musearch は書かない)

- `cd gen && gleam test` **194**。写しの `api/` に 2 回当てて back の出力 **725 file**・2 回の diff 空。停止は exit 4 = **back 22 行**(`schedule_*` 曖昧 16 / `store_roster_list` 5 / `pageview_record` 1)+ 面 89 行、exit 1 = 3(面の値の出所 ── F6 待ち)、exit 3 = 1(`www/src/shell.gleam` 無し ── F5 待ち)、警告 **48 = 札の素通り 24 + module 名 24**
- **逆向き矢印:**`reader.gleam:1256-1273` の `arrows` は子→親だけ、`emit/typing.gleam:133` の `row` は `select.with` を見ない。SQL 層は `emit/sql.gleam:716-803` が Held の逆向きを出す(`roster_list/listed.sql` は photos 付きで ▲ と本文一致)。▲ の形は reads 5 本(`roster_list` / `roster_read` / `store_roster_list` / `link_import_apply` / `link_import_read`)、例 `List(#(Roster, Phase, List(RosterPhoto)))` / `Option(#(LinkImport, List(LinkImportCandidate)))`
- **無診断:**`reader.gleam:1913-1916` の `arrow_names` が構成子でない項を `filter_map` で捨てる。型の層は `with` を見ずに exit 0
- **allow 句:**`emit/sql.gleam` に allow の注入が無い。▲ は musearch `api/db/queries/article_search/nearest.sql`(`EXISTS(… jsonb_array_elements($2::jsonb) …)` で phase と `via_muse_party`)
- **Actor:**`emit/root.gleam:93-171` が root ごとに独自の `Actor` を吐く。musearch の root ▲ 15 本がこれだけで生成物を採れず、`gen/allow` ▲ は 22 本 839 行(`Actor` を持つのは 11 本)、★ の `allow.*` 参照は 140 行 + 判定 `is_self` 10 / `is_staff` 5 / `party_of` 1
- **札:**`emit/verb.gleam:102-119` ── `handwritten_verbs` の名が生成候補に無いと警告 1 行で素通り。musearch は 9 entity に 24 名(8 → 24、2b-4 / 2b-6 で増えた)
- **`'draft'`:**`gen/test/yumemi_gen_test.gleam:1615-1627` が `,'draft'` の文字列分割で placeholder を数える(`:1302` から 5 fixture)
- **列の選択:**`Select` に返す列の欄が無い(`src/framework/query.gleam:82-95`、生成 `gen/query.gleam` の `Select` も同形)。写しの読み SQL 157 本のうち **153 本が `SELECT x.*`**。musearch の ★ は `q.Select(` の literal **72 本 / 45 file**、fixture 12 本

## どこまで

1. **逆向き矢印** ── `with:` に書いた Held の逆向きを型の層に出す。`gen/query.gleam` の `Arrow` に `RosterToPhotos` / `LinkImportToCandidates` が出て、reads の戻りの組の末尾に子の `List` が載る(上の ▲ の形)。名の規則は `emit/sql.gleam:775` の `with_name_matches` と 1 箇所にまとめる
2. **無診断** ── `join:` / `with:` の項が矢印として読めない、または SQL 層と型の層のどちらかでしか出せないときは exit 4 で service・const・項を名指しして止める。片方だけ出る形を無くす
3. **allow 句** ── root を持たない Service(`Root(at, seed)`)の名前付き読みで、allow が phase / owner を絞るなら生成 SQL の WHERE に allow 句を入れる(`nearest.sql` の形)。入れられない形は exit 4。clauses の jsonb と party の引数の番号を results に契約として書く
4. **Actor の統一** ── `src/gen/allow/<entity>.gleam` を生成物にする(`Who` / `At` / `Owner` / `Clause` / `PartyActor` / `SystemActor` / `Actor` と ★ が呼ぶ判定)。生成 root の `Actor` は `allow.Actor` を指し、root 独自の variant を出さない。**名の規則は musearch の ▲ 22 本に合わせる** ── ★ の 140 行を 1 字も動かさないため
5. **札の素通り** ── 生成候補を持たない手書き verb を宣言する語を足す(既定名 `manual_verbs`)。載せた名は警告を出さず、ヘッダの `handwritten:` の扱いは今の札と同じ。`handwritten_verbs` の不一致の警告は残し、文言で新しい語を名指しする(0.10 系の互換)。新しい語の名が生成候補と一致したら exit 4
6. **`'draft'` 依存** ── `:1615` の数えを phase の綴りに依らない形にする
7. **列の選択** ── `Select` に返す列を選ぶ口を**非破壊で**足す(既存の literal 72 本と fixture は 1 字も直さず出力も不変)。選んだ Select は SQL が選んだ列だけを返し、reads の戻りは Entity 型でなく選んだ列の record になる。from / join に無い列・空の選択・keyset / order / with が要る列を落とす選択は exit 4。行の JSON の欄名と record の欄名の対応を results に書く(musearch の runtime が読む契約)

**しないこと:**root の `version`(★ の宣言と musearch の runtime の穴、鷹野の問い)、`sql_manifest.json` の旧綴り(musearch の台帳)、`root.sql` と allow SQL の生成、`runtime.mjs` / `registry.mjs`、front の生成器、musearch と `~/yumemism_repo/yumemi-decode-1` の木への書き込み、`gleam.toml` の version、publish、push、`main` への commit。

## 失敗例

- SQL 層だけ、または型の層だけを直す。root を `allow.Actor` の別名にして `gen/allow` を生成しない(musearch の 11 本は `Actor` を持たず compile が落ちる)
- allow 句を「読み手が絞る」として落としたまま exit 0、列の選択を `Select` の必須欄にして ★ 72 本を壊す、新しい札の語で名の打ち間違いが黙って通る
- fixture でだけ通して写しで試さない(G7 の P0 の轍)、musearch の ▲ と「同じ形になった」を本文の対照無しに書く

## 検収(真壁さんが自分で回す)

- root `gleam build` 0、`cd gen && gleam test` **194 以上**(7 項それぞれに正と負の test)、fixture を 2 回生成して diff 空・tracked と一致
- 写し `728adfa`(run の外に置き、musearch は書かない)に 2 回当てて diff 空。**exit 4 の back 22 行と警告の module 名 24 は動かさない**、札 24 は写しの ★ の 24 名を新しい語へ移した写しで 0、増えた行は全部名指し
- **写しの `api/` に生成 `gen/allow` と生成 root を被せて `cd api && gleam build` 0**(★ は 1 字も直さない)。被せられない allow module は名と理由を名指し ── 3 本を超えたら止めて終端で返す
- 写しで、reads 5 本・`nearest.sql`・root 15 本の生成物と musearch の ▲ の本文の対照表(差は行ごとに理由)。`gen/query.gleam` は ★ の requalify 前なので被せない(生成は `From` / `Field` を submodule に割り、★ の `q.Article` が解決しない ── 写しで 268 error、本便の外)
- `docs/reports/yumemi-hw-1.md` に `## DDL`(無し)・`## 鷹野宛`・`## 追随便への申し送り`(musearch の ▲ のうち生成物で置ける file の一覧)。終端は承認かエスカレーション
