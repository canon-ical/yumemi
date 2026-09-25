# yumemi-hw-1 ── 生成器の back の宿題 6 件(真壁 r1、2026-09-25)

基点は `impl/yumemi-1f` の `c2519de`。写しは musearch `728adfa` の `api/ www/ muses/ console/ docs/` を `git archive` で `gen/build/hw1/snap/` に置いた(musearch には書いていない)。証拠は全部 `gen/build/hw1/`(git 管理外)。

## 結論

- 6 項とも実装した。`cd gen && gleam test` は **212 passed**(194 + 18。18 本のうち 17 本は新しい `gen/test/yumemi_gen_hw1_test.gleam`、1 本は `yumemi_gen_test.gleam` の末尾に足した)
- 写しに 2 回当てると、どちらも exit 4 で、差は www の runtime build の記録に出る時間の 1 行だけ。**back の exit 4 は 22 → 50 行**。22 行はそのまま残り、増えた 28 行は全部 **allow 句の owner `Self`**(下の表)。警告の module 名 24 行は変わらない
- **鷹野さんに裁いてほしい点が 1 つあります**: `Self` は party の穴で表せないので、brief どおり exit 4 にした。これで、今まで出ていた読みの SQL が 28 本出なくなる。この 28 本には、musearch が採用済みの `store_roster_list/mine`・`link_import_read/latest`・`link_import_apply/latest` も入る(「鷹野宛」)

## DDL

無し。migration / schema / database には触れていない。

## 6 項の中身

| # | 何をしたか | 置き場 |
|---|---|---|
| 1 逆向き矢印 | `with:` に書かれた Held の逆向きを `App.reverse_arrows` に持ち、`gen/query.gleam` の `Arrow` の末尾に出す。reads の組の末尾には子の `List` が付く(並びは SQL の SELECT 句と同じで、from・join・with・along の順)。名の規則(`<親>To<子の短い名の複数形>`)は `relation.gleam` の 1 箇所にまとめた。SQL 層・型の層・`Arrow` の 3 つが同じ関数で解く。**旧来の「候補が 1 本なら名を見ずに通す」逃げ道は消した** | `relation.gleam`、`emit/typing.gleam`、`emit/query.gleam`、`reader.gleam` |
| 2 無診断 | `join:` / `with:` の項が構成子でない場合(関数呼び出し・小文字の変数)、捨てずに `Select.unread` に残し、exit 4 で名指しする(例:`SQL を出さなかった <service>/<const>: 矢印として読めない項: join の 1 番目`)。次の 2 つも exit 4 にした:join に逆向きの矢印を書く、join に Multi の矢印を書く(Multi は今まで壊れた `JOIN … ON x.id=o.tags_id` を黙って出していた)。forward の with はこれまでどおり exit 1 | `reader.gleam`、`relation.gleam`、`emit/sql.gleam` |
| 3 allow 句 | root を持たない Service の名前付き読みで、allow が相(`Only`)か owner(`NoOwner` 以外)を絞るときは WHERE に `EXISTS(… jsonb_array_elements($N::jsonb) cl …)` を入れる。allow の Entity が from / join に居なければ、順向きの矢印 1 本で入れ子の EXISTS にして辿る(▲ `article_read/root` と同じ形)。入れられない形は exit 4:`Self`、相の無い Entity を `Only` で絞る、party の列が無い、辿れない、辿る道が複数、句が読めない | `reader/clauses.gleam`(hw-2 の `reader/allow.gleam` とは別の口)、`emit/sql.gleam` |
| 4 札の素通り | 新しい語 `pub const manual_verbs: List(String)` を足した(Entity と ER の外の module)。warning は出さず、ヘッダの `handwritten:` に載る。`handwritten_verbs` が候補と合わないときの警告は残し、文言に「(生成候補の無い手書き verb は manual_verbs へ)」を足した。`manual_verbs` の名が生成候補と一致したら exit 4 | `reader.gleam`、`emit/verb.gleam` |
| 5 `'draft'` | `create_sql_input_placeholder_count` は、最初の文字列 literal(初期の相)より前の `$` を数える形に変えた。関数本体の 4 行だけを直し、test は書き換えていない | `gen/test/yumemi_gen_test.gleam` |
| 6 列の選択 | `gen/query.gleam` の `Select(p)` に 2 つ目の構成子 `Pick(columns: List(Field), select: Select(p))` を足した。既存の `q.Select(...)` literal は 1 字も直さずに通る。Pick した読みの SQL は選んだ列だけを返し、reads の戻りは `<Pascal(const)>Row` の record になる。exit 4 にする形:空の選択、重複、from / join に無い列、欄の名の衝突、order / keyset / with が要る列を落とす、group / agg との併用、`select:` に `q.Select` を直に書かない | `reader.gleam`、`emit/typing.gleam`、`emit/sql.gleam`、`emit/reads.gleam`、`emit/query.gleam` |

hw-2 の持ち分(`emit/root.gleam`・`emit/allow.gleam`・`reader/allow.gleam`)と front は触っていない。`emit/root.root_for` は呼ぶだけ。`yumemi_gen_test.gleam` への変更は、5 の helper 本体 4 行と末尾への追記 1 本だけ。

### 契約 ── allow 句(musearch の runtime が読む)

- **穴の番号は SQL の 2 行目に書く**:`-- allow: clauses=$N party=$M`。owner の句が無いときは `-- allow: clauses=$N` だけで、party の穴は無い。`N` は読みの穴(where / Paged の size / keyset / having / Nearest の `$1`)の最大の番号 + 1、`M = N + 1`
- `$N` は、actor に合った句を `[{"phases": null | ["published", …], "owner": "no_owner" | "via_muse_party" | …}]` の jsonb で渡す。http_runtime の `s.clauses` と同じ形(相と owner は構成子名の snake)
- `$M` は actor の party(text)
- owner の名から party への道:**`Via<Entity>Party` = その Entity の `party` 列**(`ViaMuseParty` = muse の party、`ViaStoreParty` = store の party)。hw-2 の `party_of` と同じ規則
- 相は allow の Entity の Phase 列(`cl->'phases' ? a.phase`)で照らす
- root を持つ Service の読みには入れない(root の 1 文の持ち分で、本便の外)

### 契約 ── 列の選択(行の JSON の欄名 = record の欄名)

- SQL の SELECT 句は `<別名>.<列> AS <欄の名>` を `columns` の順に並べ、その後ろに with の子(`AS <with の名>`、子の行の jsonb 配列)、along の値(`AS distance`)が続く。record `<Pascal(const)>Row` も欄の名・並びが同じ
- 欄の名の規則:from の列は Property の名(`RosterName` → `name`。関係の列 `store_id` は `store` で、型は `Key(Store)`)。join した Entity の列は `<Entity の snake>_<Property>`(`AlbumTitle` → `album_title`)
- SQL の予約語は AS 側を `"order"` のように引用する。JSON の欄名は `order` のまま
- 写しでの実測:`roster_list.listed` を `q.Pick(columns: [q.RosterId, q.RosterName, q.RosterCatch, q.RosterOrder, q.RosterPhase, q.RosterMuse], select: …)` に変えた写し(`gen/build/hw1/snap-pick`)で、SQL は `SELECT r.id AS id,r.name AS name,r.catch AS catch,r."order" AS "order",r.phase AS phase,r.muse_id AS muse,COALESCE(…) AS photos`、record は `ListedRow(id: RosterId, name: Name, catch: Catch, order: Order, phase: roster.Phase, muse: Option(Key(muse.Muse)), photos: List(roster_photo.RosterPhoto))` で、7 欄が名と並びで一致した。この reads を写しの api に重ね、★ の `row` を `reads.ListedRow` を分解する形に変えて `gleam build` すると exit 0(`gen/build/hw1/pick-overlay-build.txt`)。診断は Pick の無い写しと 1 行も変わらない
- 非破壊:Pick を使わない読みの SQL と reads は 1 字も変わらない(fixture の SQL 差は allow 句の 3 本だけ。下の検収)

## 検収

| 項目 | 結果 | 証拠 |
|---|---|---|
| root `gleam build` | exit 0、warning 1(既存の `src/framework/secret.gleam`) | `gen/build/hw1/root-build-final.txt` |
| `cd gen && gleam test` | **212 passed, no failures**(基線 194)。`gleam format --check src test` は 0 | `gen/build/hw1/test-3.txt` |
| Article fixture ×2 | 2 回とも exit 0 で 112 file、diff は 0 行。tracked の生成物 51 file(`public` / `admin` の `src/gen` と `priv`)は全部一致(`api/src/gen/http_runtime.mjs` は入力なので比べない)。基線からの差は 4 file:allow 句が入った `article_list/{items,counts}.sql`・`widget_list/items.sql` の 3 本(`Only([Published])` の相だけ)と、`gen/query.gleam`(`Pick` の構成子と Arrow の注記) | `gen/build/hw1/fx-{a,b}`、`fx-base` |
| 写し ×2 | 2 回とも exit 4。基線は 1372 file / back 725 で、今回は **1344 / 697**(allow の `Self` で SQL 28 本が出なくなった分)。`diff -r` の差は `www/_diagnostics/www-runtime.txt` の「Downloaded 11 packages in 0.01s / 0.02s」1 行だけ(runtime build の記録で、生成器の出力ではない)。face 3 面の生成物は基線と同一 | `gen/build/hw1/out-{a,b}`、`snap-ab-diff.txt` |
| 写しの診断 | exit 1=3、exit 3=1 は基線と同じ。**exit 4 は 111 → 139**:back は 22 → 50(22 行はそのまま、+28 は下の表)、face の 89 行は同一。警告は 48 のまま(module 名 24 は同一、札 24 は文言に manual_verbs を名指しする句が付いた) | `gen/build/hw1/snap-summary.txt` |
| 札を移した写し | 24 名を 9 file で `manual_verbs` へ移した写し(`snap-manual`)では、**札の警告が 0**、警告は module 名の 24 だけ、exit 4 は同一。生成物の差は sha256 ヘッダと `verb.gleam` のヘッダ `handwritten:` の並びだけ(名の集合は 51 名で同じ) | `gen/build/hw1/out-manual`、`manual-vs-a.txt` |
| reads の型を ★ に当てる | 生成した reads 4 本(`roster_list` / `store_roster_list` / `link_import_read` / `link_import_apply`)を写しの api に重ねて `gleam build` すると exit 0。★ の logic が組の末尾の `List` をそのまま型として受ける | `gen/build/hw1/overlay-build.txt` |

### 増えた exit 4(28 行、全部 allow 句の owner `Self`)

`SQL を出さなかった <service>/<const>: allow 句の owner Self は party の穴で表せない(主体の鍵が要る)`:

heaven_link/by_shop, heaven_link/top_order, link_import/current_identity, link_import_apply/existing, link_import_apply/latest, link_import_apply/top_tail, link_import_candidate_add/proposal, link_import_candidate_edit/candidate, link_import_candidate_toggle/candidate, link_import_read/latest, link_move/mine, link_reorder/mine, roster_add/same_name, roster_claim/by_code, roster_list_mine/mine, roster_reorder/place, roster_upsert/by_external, roster_upsert/same_name, space_add/count, space_add/last_order, space_reorder/mine, store_roster_list/mine, widget_add/counts, widget_add/heaven_linked, widget_add/heaven_used, widget_add/last_order, widget_add/space_owned, widget_reorder/place

どれも root を持たない Service で、allow が `AsMuse` か `AsStore` の `Self`(多くは `Only([Onboarded])` 付き)。

### 対照表 ── reads 5 本と `nearest.sql`(生成物 × musearch の ▲)

| ▲ | 生成物との差(行ごと) | 理由 |
|---|---|---|
| `src/gen/reads/roster_list.gleam` | 1 行目のヘッダ(▲ は `/ RosterToPhotos`、生成は sha256)。`import entity/store` → `store.{type Store}` と `Key(store.Store)` → `Key(Store)`。`import gen/root/roster_list.{type Root}` を足した。戻りの型の改行 | ヘッダと import の綴りは生成器の既存の流儀(Key の中身は非修飾)。**戻りの型は同じ** `List(#(roster.Roster, roster.Phase, List(roster_photo.RosterPhoto)))` |
| `src/gen/reads/store_roster_list.gleam` | 同上 | 同上。ただし SQL `mine` は `Self` で exit 4(表の外) |
| `src/gen/reads/link_import_read.gleam` | ヘッダ、`gen/root` の import、改行 | 戻りの型は同じ `Option(#(link_import.LinkImport, List(link_import_candidate.LinkImportCandidate)))`。SQL `latest` は `Self` で exit 4 |
| `src/gen/reads/link_import_apply.gleam` | ヘッダ(▲ は `.latest / LinkImportToCandidates`、生成は Service 単位)、`step.read(…)` の折り返し | 戻りの型は同じ。SQL `latest` / `existing` / `top_tail` は `Self` で exit 4 |
| `src/gen/reads/roster_read.gleam` | ▲ の `photos(it) -> List(RosterPhoto)` と `rootPhotos` の FFI が生成物に無い。`to_store` / `to_muse` は ▲ が「Root の値を渡すだけ」で、生成は `io.relation_*` の読み | `photos` は root の 1 文に畳む逆向きで、★ の `with:` ではない。root.sql の生成は本便の外(`canon/open.md` の行)。`to_*` の差は gen-3b からの既存の差 |
| `db/queries/roster_list/listed.sql` | 本文は同一。差は sha256 だけ | ── |
| `db/queries/article_search/nearest.sql` | (1) 生成は `SELECT c.*,to_jsonb(a) …`、▲ は `c.*` を返さない。(2) 生成は `ORDER BY … ,c.article_id ASC` と key を足す。▲ には無い。(3) allow 句:生成は相だけ `(cl->'phases'='null'::jsonb OR cl->'phases' ? a.phase)` で、穴は `$2` だけ。▲ は owner の句 `(cl->>'owner'='no_owner' OR (cl->>'owner'='via_muse_party' AND m.party=$3))` と `$3` も持つ。(4) 2 行目の `-- allow: clauses=$2`。(5) FROM / JOIN / WHERE の改行 | (1) ▲ は chunk の列を返さず、`Near(article, muse, distance)` の record で受ける。Pick は列を選ぶ口なので、join した Entity を丸ごと返す形は Pick でも書けない(embedding を落とすだけなら Pick で書けるが、そのときは記事と嬢も列で選ぶことになる)。(2) 生成器の既存の規則(安定順の key)。(3) `article_search` の allow は `Anyone / Only([Published]) / NoOwner` の 1 句だけなので、owner の句を出さない。▲ は allow/article の一般形を写している。**▲ の runtime は `[v, clauses, party]` の 3 つを渡すので、生成 SQL(穴 2 つ)にすると bind の数が合わない ── runtime が `-- allow:` の行に従う必要がある** |

## 鷹野宛

1. **allow 句の owner `Self` をどう入れるか(裁定が要る)。** brief の契約(句の jsonb + party)では `Self` を表せない。muse は同じ party に複数居てよいので、`m.party=$party` にすると Self より広くなる。そのため 28 本を exit 4 にし、SQL は出していない。この 28 本には musearch が採用済みの `store_roster_list/mine` と `link_import_{read,apply}/latest` が入るので、追随便はこの 3 本の SQL を ▲ から外せない。案:3 つ目の穴 `subject=$K` を足し、`(cl->>'owner'='self' AND <allow の Entity>.<key>=$K)` にする。▲ の root SQL が既にこの形(`m.id=$3::uuid`、`$3` = subject_id)。ただし store の ▲ は `s.party=$3` で、root 側の Self も揃っていない。裁定があれば 1 関数(`emit/sql.gleam` の `party_of`)を直すだけで済む
2. **with の名の規則を厳しくした。** 旧来は「その親を指す子が 1 本だけなら、名を見ずに解く」逃げ道があったが、消した。写しと fixture の with 3 種(`RosterToPhotos` / `LinkImportToCandidates` / `AlbumToPhotos`)は規則どおりの名なので、影響は 0
3. **`framework/query.gleam` の `Select` には `Pick` を足していない。** framework の `Select` は型引数が 9 個で、Field にあたる引数を持たない。足すと型引数が増え、Hex の利用者に破壊的変更になる。生成の `gen/query.gleam` だけに足した。0.11.0 で framework 側も揃えるなら、別に 1 行の裁定が要る
4. `gen/query.gleam` の出力は Pick を使わない入力でも変わる(`Pick` の構成子と、Arrow の上の 2 行の注記)。fixture の tracked 物には `gen/query.gleam` が無いので、tracked の差は 0

## 追随便への申し送り

**生成物で置ける ▲**(musearch の F6 の後の追随便で外す):

- `api/src/gen/reads/roster_list.gleam` ── 生成物をそのまま置ける(型は ★ に当てて build 0)。SQL `db/queries/roster_list/listed.sql` も本文は同一
- `api/src/gen/reads/store_roster_list.gleam`・`link_import_read.gleam`・`link_import_apply.gleam` ── reads の .gleam は置ける(build 0)。ただし同じ Service の SQL(`store_roster_list/mine`、`link_import_read/latest`、`link_import_apply/{latest,existing,top_tail}`)は、鷹野宛 1 の裁定まで ▲ のまま
- ★ 9 file の札 24 名(`entity/{chunk,muse_schedule,notice,prep,reservation,roster,store}.gleam`、`ledger_store.gleam`、`metrics.gleam`)── `handwritten_verbs` から `manual_verbs` へ移せば、警告 24 が消える(写しで実測、移した一覧は `gen/build/hw1/manual-names.txt`)
- 列の選択 ── ★ 72 本は直さずに通る。`SELECT x.*` を絞りたい読みは `q.Pick(columns: [...], select: q.Select(...))` で包み、logic は `reads.<Const>Row` を受ける形にする。runtime は上の「契約 ── 列の選択」に従って、行の JSON を欄の名のまま record に写す

**まだ置けない ▲**:

- `api/src/gen/query.gleam` ── ★ の requalify の前なので被せない(brief どおり)。`RosterToPhotos` / `LinkImportToCandidates` は生成側の `Arrow` にも出るようになった
- `api/db/queries/article_search/nearest.sql` と `reads/article_search.gleam`(`Near` の record)── 対照表の (1)(3) の差。runtime が `-- allow:` の穴の数に従うまでは置けない
- `api/src/gen/reads/roster_read.gleam` の `photos` ── root.sql(本便の外)

## 確かめたこと / 確かめていないこと

- 確かめたこと:上の検収表の全部。加えて、生成した reads 4 本と Pick の reads を写しの api に重ねた `gleam build` が 0 であること
- 確かめていないこと:生成した SQL を Postgres で走らせていない(allow 句の EXISTS、Pick の SELECT)。musearch の runtime(`runtime.mjs` / `sql.mjs`)は `-- allow:` の行を読まない ── 契約を書いただけで、runtime 側は追随便の仕事。新しい test が直す前の生成器で落ちることは、model の欄が増えて旧コードでは compile しないため、走らせて確かめてはいない(`'draft'` の test は、旧 helper なら `'pending'` の行を 3 と数えて落ちる、と式から確認した)
