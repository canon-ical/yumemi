# yumemi-hw-1 レビュー(柏木[CM]、2026-09-25、ゲート 1 回)── 差し戻し、P0 1 件

**差し戻し。**検収の数字は柏木の手元で全部再現した(212 passed、fixture 2 回 diff 0・tracked 51 file 一致、写し 2 回の差は runtime build の時間 1 行だけ、back exit 4 は 22 → 50 で +28 は全部 `Self`、警告 48 のうち module 名 24 は同一)。生成 `nearest.sql` の句は ▲ と意味が一致し、緩む向きの差は無い。

P0 は 1 件。allow 句の読み手(`reader/clauses.gleam`)が、**句を定数に包む書き方と list の spread を「絞らない句」と読み違える。**このとき読みの SQL から allow 句が消え、exit 0・診断 0 件で通る。Gleam 1.18.1 で compile が通る普通の書き方で、BRIEF の失敗例「allow 句を落としたまま exit 0 で通す」そのものにあたる。直す範囲は狭い(下の P0-1)。

基点 `c2519de`、先端 `d732b58`。柏木の証拠は全部 `gen/build/kw/`(git 管理外)。musearch は `git archive 728adfa` で写しただけで、終了時の `git -C ~/yumemism_repo/musearch status --porcelain` は 0 行。

## 検収の再走(柏木が出した値)

| 項目 | 結果 | 証拠 |
|---|---|---|
| root `gleam build` | exit 0、warning 1(既存の `src/framework/secret.gleam:5`) | `kw/root-build.txt` |
| `cd gen && gleam test` | **212 passed, no failures**。基点を `git archive c2519de` で別の木に出して走らせると 194 | `kw/test.txt`、`kw/base-test.txt` |
| `gleam format --check src test` | exit 0 | `kw/format.txt` |
| fixture article ×2 | 2 回とも exit 0 で 112 file、`diff -r` は 0 行。tracked の 51 file(`{public,admin}/src/gen`・`priv`)は `cmp` で全部一致。基点との差は `article_list/{items,counts}.sql`・`widget_list/items.sql`・`src/gen/query.gleam` の 4 file | `kw/fx-{a,b}`、`kw/base-fx` |
| 写し ×2 | 2 回とも exit 4、1344 file(基点 1372)。`diff -r` の差は `www/_diagnostics/www-runtime.txt` の `Downloaded 11 packages in 0.01s / 0.02s` 1 行だけ | `kw/out-{a,b}`、`kw/base-out` |
| 写しの診断 | 基点 → 先端:exit 0 警告 48 → 48、exit 1 3 → 3、exit 3 1 → 1、**exit 4 111 → 139**。基点の exit 4 は 1 行も消えず、増えた 28 行は全部 `allow 句の owner Self は party の穴で表せない`。module 名の警告 24 は同一。札 24 は基点の行の末尾に `(生成候補の無い手書き verb は manual_verbs へ)` が付いただけ | `kw/*/_diagnostics.txt` |
| 札を移した写し | 真壁の `snap-manual` を写し直して走らせた(`728adfa` との差は entity 7 と ER の外 2 の計 9 file の `manual_verbs` だけ)。札の警告は 0、exit 4 は `out-a` と同一。生成物の差は sha256 のヘッダ(`diff -r` の両側で 1642 行)と `handwritten:` の並びだけ | `kw/out-manual` |
| Pick を足した写し | `roster_list.listed` を `q.Pick(...)` にした写しで、SQL は `SELECT r.id AS id,r.name AS name,r.catch AS catch,r."order" AS "order",r.phase AS phase,r.muse_id AS muse,COALESCE(…) AS photos`。record `ListedRow` は 7 欄で、名も並びも SQL と同じ | `kw/out-pick` |
| reads 4 本と ▲ の対照 | 真壁の対照表のとおり。戻りの型は 4 本とも ▲ と字面で同じ。差はヘッダ・import の綴り・改行だけ(P2-2 に誤記が 1 つ) | `diff snap/api/src/gen/reads/*.gleam out-a/src/gen/reads/*.gleam` |

## P0

### P0-1 allow 句を定数に包むか spread で書くと、句が黙って落ちる

- 該当:`gen/src/yumemi_gen/reader/clauses.gleam:54`(`Some(name) -> model.Clause(who: name, at: AnyPhaseAt, owner: "NoOwner")`)、同 `:27`(`glance.List(elements: elements, ..)` が spread の後ろを捨てる)
- 仕組み:`g.ctor_name` は `Variable` と `FieldAccess` なら大文字・小文字を問わず `Some(名)` を返す。そのため `allow: [published_only]` の `published_only`(module に置いた `const`)は「who だけの略記」と読まれ、AnyPhase / NoOwner として扱われる。`emit/sql.allow_clause` は、どの句も絞らないと見て allow 句を入れない。spread(`[allow.staff, ..public_clauses]`)は後ろの句をそもそも読まない
- 実測:fixture article の写しで `article_list` の allow を次の 2 通りに書き換え、生成器を走らせた
  - `const published_only = allow.Clause(who: allow.Anyone, at: allow.Only([article.Published]), owner: allow.NoOwner)` + `allow: [published_only]` → **exit 0、診断 0 件、`article_list/items.sql` に `-- allow:` も `EXISTS(… jsonb_array_elements …)` も無い**(`kw/fxc/article` → `kw/out-const`)
  - `allow: [allow.staff, ..public_clauses]` → 同じ(`kw/fxs/article` → `kw/out-spread`)
  - どちらの書き方も Gleam 1.18.1 で compile が通る(`kw/constcheck`、`const` の中の record と list の spread)
  - 再現の注意:fixture の `gleam.toml` の path 依存は `../../../..` なので、写しは `gen/build/article` に、`fixtures/docs` は `gen/build/docs` に置いて走らせた(走らせた後に消した)
- なぜ P0 か:認可が緩む向きに働き、しかも黙って通る。runtime は `-- allow:` の行が無い読みに句を渡さないので、公開前の相の行がそのまま返る。本便が約束した「入れられない形は exit 4」(report の 3 に「句が読めない」とある、`clauses.gleam` の module doc にも「読めない句は捨てずに UnreadClause」とある)が、この 2 つの形で守られていない。Hex 0.11.0 で外の利用者に出す生成器なので、句を定数に括り出す(musearch の `allow.Clause` 140 個には同じ形が多いので、起きやすい整理)だけで漏れる
- 基点との関係:基点は allow 句をどの読みにも入れていなかったので、戻り(regression)ではない。ただし BRIEF 3 の「どこまで」を満たしていない形で、BRIEF の失敗例そのもの
- 同じ便の中で扱いが割れている:矢印の読み(`reader.gleam` の `arrow_names`)は、小文字の `Variable` / `FieldAccess` と `Call` を「読めない項」として exit 4 に回している。allow の読みにはそれが無い
- 直し方の方向(範囲は `reader/clauses.gleam` だけ):
  1. `Clause` でない項を who の略記と読むのは、大文字で始まる構成子(`Anyone` / `Staff` / `As*` など)と、fixture の流儀の `allow.<小文字>`(allow の import の別名への FieldAccess)だけにする。修飾の無い小文字の `Variable`、allow 以外の module への小文字の FieldAccess、`Call` は `UnreadClause`
  2. `glance.List` の `rest` が `Some(_)` なら `UnreadClause`
  3. hw1 の test に負の test を 2 本足す(定数に包んだ句、spread)。どちらも exit 4 で名指しされ、SQL が出ないこと
  - 定数を辿って中身の Clause を読む直し方でもよい。どちらを採っても、`allow.staff` を使う fixture の出力(tracked 51 file と SQL 3 本)は変わらないはず

## 見ること 1〜6

### 1. BRIEF の「どこまで」と「検収」

- 1 逆向き矢印・2 無診断・4 札・5 `'draft'`・6 列の選択は、「どこまで」を満たす(下の P1 は満たした上での残り)
- 3 allow 句は P0-1 の 2 つの形で満たしていない。それ以外の形(`Self`、相の無い Entity、party の列が無い、辿れない、辿る道が複数、at が読めない)は exit 4 で名指しされ、SQL を出さないことを test と写しで確かめた
- 検収は上の表のとおり全部再現した。「写しで 2 回、diff 空」は、runtime build の記録の時間 1 行を除けば成り立つ(生成物ではない。真壁の報告どおり)

### 2. allow 句が認可を緩める向きの差 ── `nearest.sql` との意味の比較

緩む向きの差は無い。

| 点 | 生成(`out-a/db/queries/article_search/nearest.sql`) | ▲ | 判定 |
|---|---|---|---|
| 相 | `(cl->'phases'='null'::jsonb OR cl->'phases' ? a.phase)` | 同じ | 同じ。`a` は chunk → article の join で、▲ と同じ行 |
| owner | 出さない | `(cl->>'owner'='no_owner' OR (cl->>'owner'='via_muse_party' AND m.party=$3))` | `article_search` の allow は `Anyone / Only([Published]) / NoOwner` の 1 句だけなので、runtime が「actor に合った句」を渡す限り、owner は常に `no_owner`。▲ の owner 部は恒真。緩まない |
| 句の結び | 1 つの `cl` の中で相と owner を AND、句どうしは EXISTS で OR | 同じ | 同じ |
| 穴 | `$2` だけ。runtime が 3 つ bind すると Postgres が数の不一致でエラー | `$2`・`$3` | 閉じる向き(エラー)に倒れる。漏れない |

fail-closed を確かめた点:`phases` の key が無い句は `NULL` なので拒否、`Only([])` は拒否、Option / Link の矢印を辿る入れ子の EXISTS は FK が NULL なら拒否、知らない owner(`Via*Party` の形でない、Entity が無い)は exit 4、`Self` も exit 4。穴の番号は読みの穴の後ろで、Paged(`$4`)と Nearest(`$2`)はどちらも正しい。

残りは P0-1 と P1-1・P1-2(道の選び方)。

### 3. 鷹野宛 1 ── owner `Self` と 28 本の exit 4 ── **推奨 (c)。本便の merge 時点では (b) のまま**

**実物で分かったこと:**28 本(19 Service)は全部、allow の module が主体の Entity そのもの(`gen/allow/muse` × `AsMuse` が 15 Service、`gen/allow/store` × `AsStore` が 4 Service)で、owner は `Self`、多くは `Only([Onboarded])` 付き。root を持たない Service でこの句が絞っているのは、**行ではなく主体**(主体が onboarded の muse か store であること)。行の範囲は logic が主体の鍵を where の穴に渡して決めている(例:`store_roster_list` の `reads.mine(store: key.store(by.id))`)。▲ の SQL 3 本(`store_roster_list/mine`・`link_import_{read,apply}/latest`)の本文は基点の生成物と同じで、allow 句は持っていない。

| 案 | 中身 | 認可 | 壊れるもの |
|---|---|---|---|
| (a) 契約に主体の鍵 `$K` を足し、行から allow の Entity へ辿って `E.key=$K` で照らす | 真壁の案 | 緩まない | **行の範囲が変わって壊れる読みがある。**`roster_claim/by_code` は未 claim の roster(`muse: Link(Muse)` が NULL)を code で引く読みで、`r.muse_id` から muse へ辿ると 0 行になり、claim ができなくなる。`heaven_link/by_shop` は他の muse の行も見て `GirlTaken` を判定する(`service/heaven_link.gleam:113-115`)。自分の行だけに絞ると、この検査が素通りになり、同じ嬢を 2 人の muse が取れる。加えて E ≠ 主体の形(`gen/allow/roster` × `AsStore` の Self = `r.store_id`)に広げるには、句の jsonb に `who` が要る |
| (b) exit 4 のまま、28 本は musearch の ▲ に残す | 今の実装 | 緩まない | 追随便で ▲ の 3 本を外せない。musearch の生成は既存の 22 行で既に exit 4 なので、門の状態は変わらない |
| **(c) 主体の門として分類する** | root を持たない Service で `who: As<E>` × `owner: Self`(E は allow の Entity)の句は、行の SQL に入れない。主体の相と主体そのものの確かめは、主体を解く門(hw-2 の Actor の統一)が主体自身の行で照らす。生成器は契約の 1 行(例 `-- allow: actor`)を出すか、何も出さないで exit 0。主体の門と行の絞り(`Anyone × Only`)が同じ allow に混ざる形は、jsonb に `who` が載るまで exit 4 | 緩まない(この句は元から行を絞っていない。相は主体に対して照らす) | 無い。28 本とも今の ▲ と同じ本文の SQL が生成物で置ける |

**推奨は (c)。**実装は hw-2 に入れる(主体の門は hw-2 の持ち分なので)。hw-2 が「root を持たない Service で主体の相を照らす」ことを確かめてから、28 本を exit 0 に戻す。**それまでは (b) が正しい状態で、本便の merge はこのままでよい。**(a) は、上の 2 本で行の意味を変えてしまうので採らない。

併せて見つけたこと(本便の外、musearch 側):▲ の root SQL は、muse では `Self` を `m.id=$3::uuid` で照らすが、store(`store_read/root.sql`・`store_schedule_list/root.sql`)では `s.party=$3` で照らす。`api/db/schema.sql:66` の `store.party` には UNIQUE が無い。1 つの party が複数の store を持てるなら、この照らし方は Self より広い。仕様として意図したものか、musearch で確かめてほしい。

### 4. 鷹野宛 3 ── Pick を `gen/query.gleam` にだけ足した件 ── **親ゴールは達成する。推奨:framework には足さず、「1 対 1」の注記を直す**

- 生成 SQL の `SELECT r.*` は、選んだ列の指定に変わる(上の表の Pick の行。柏木が写しで走らせた)。P0 ではない
- framework の `Select` を使う利用者は 0。musearch の ★ の 72 本も fixture も `import gen/query as q` で書いている。生成の `gen/query.gleam` は `framework/query` を import しておらず、生成器が読むのはソースの構文木。だから framework に `Pick` が無くても、利用者は選ぶ口を使える。musearch の ★ で、`Select` の値を literal 以外に使う箇所(欄の参照・pattern)も 0 件で、構成子を足しても壊れない
- **推奨:0.11.0 では framework の `Select` に足さない**(型引数が増えて Hex の利用者に破壊的変更になるのに、使う人が居ない)。代わりに、今は嘘になった「構成子は framework/query.gleam と 1 対 1」の注記(`model.gleam:250`、`emit/query.gleam:7`)を「`Pick` は生成側だけ」と直す(P2-1)。`framework/query` を参照の形として残すかは、別に 1 行の裁定でよい
- 親ゴールに対して残るもの(P1-3):with の子は `to_jsonb(p)` で全列を返す。Pick を使わない join は `to_jsonb(x)` で全列を返す。★ の `x.*` 153 本が細くなるのは、追随便で ★ に Pick を書いてから

### 5. 鷹野宛 2 ── with の名の規則を厳しくした件 ── 黙っては壊さない

- 名の規則の本文は、基点の `emit/sql.gleam` の `with_name_matches` / `plural` と字面で同じ。消えたのは「親を指す子が 1 本なら名を見ない」逃げ道だけ
- 規則に合わない名は exit 4(`with の逆向きが無い: <名>(名は <親>To<子の短い名の複数形>)`)で service / const ごとに名指しされる。型の層は同じ `relation.with_arrow` で解くので、層ごとに判定が割れない。黙っては壊さない
- 既存の入力はどれも規則どおり:写しの `with:` は `RosterToPhotos` ×4 と `LinkImportToCandidates` ×2、fixture は `AlbumToPhotos`(`ArticleToCategory` は順向きで、今までどおり exit 1)。写しの back の exit 4 22 行も変わらない
- 残り(P2-4、基点から):`plural` は母音 + y も `ies` にする(`Day` → `Daies`)。不規則な複数形も書けない。どちらも exit 4 で表に出るので、黙っては壊さない

### 6. hw-2 の持ち分と既存 test

- `emit/root.gleam` は diff に無い。`emit/allow.gleam` と `reader/allow.gleam` は基点にも先端にも無い。front の 3 つも diff に無い。`emit/sql.gleam` が `emit/root.root_for` を import して呼ぶだけ
- `yumemi_gen_test.gleam` の 23 行は、helper `create_sql_input_placeholder_count` の 1 行の置き換えとその注記 1 行、それと末尾への test 1 本の追記。BRIEF 5 が名指ししている `:1615` はこの helper の本体なので、ここを直すのは必然。既存の test 関数の本文は 1 行も変わっていない。hw-2 と衝突しうるのは末尾への追記だけ(report の「helper 本体 4 行」は実際には 2 行。P2-3)

## P1(記録。直さない)

- **P1-1 allow の Entity と owner の Entity を辿る道が、allow の Entity から出ていなくてよい。**`emit/sql.gleam:1023` の `reach` は、読みの中に既に居る別名があれば、どの道で join されたかを問わずその別名を使う。居なければ、from / join のどれかから出る矢印 1 本で辿る。hw1 の test `allow_clause_filters_phase_and_party_test` は、allow が `article` で owner が `ViaStaffParty` の形を、memo の `staff` で照らすことを正としている(Article には Staff への矢印が無い)。report の契約は「hw-2 の `party_of` と同じ規則」だが、owner を allow の Entity から見るなら、この形は exit 4 になるはず。hw-2 の実物がまだ無いので確かめられない。緩む向きに働く形(owner の Entity が allow の Entity と別の道で join されている)は、写しには 0 本(allow 句が入る読みは `nearest.sql` の 1 本だけ)。P0-1 と同じ回で、「allow の Entity から出る矢印で辿れなければ exit 4」に揃えることを勧める
- **P1-2 root を持たない Service の `As<E>` × `Only`(E は allow の Entity)を、行の絞りに変えてしまう。**鷹野宛 1 と同じ根で、これは主体の相を照らす句。今の実装は、行から E へ辿って行の相として照らす。写しでは 0 本(同じ形はどれも `Self` なので exit 4 になっている)。(c) を入れるときに、owner が `Self` でないものも同じ分類に入れる
- **P1-3 Pick が with の子と Pick を使わない join に届かない。**4 の最後に書いたとおり。親ゴールを最後まで満たすには、子の列の選択も要る
- **P1-4 `join:` / `with:` が list literal でないとき(定数の参照、spread)は、両方の層で黙って捨てる。**`labelled_list` → `g.list_elements` が `[]` を返す。両方の層が同じように捨てるので、層ごとに割れはしない。ただし診断が出ない。基点からある `where:` も同じで、where を定数に括り出すと絞りが消え、返る行が増える。6 項の外で基点からある穴なので、P0 にはしない。P0-1 と同じ直し方(literal でない、または `rest` がある list は `Unsupported`)を勧める

## P2(記録。鷹野の指示どおりコードは直していない)

- P2-1 「構成子は framework/query.gleam と 1 対 1」の注記(`gen/src/yumemi_gen/model.gleam:250`、`gen/src/yumemi_gen/emit/query.gleam:7`)が、`Pick` を足したことで事実と合わない
- P2-2 report の対照表で、`link_import_read.gleam` の差に「`gen/root` の import」とあるが、実際の diff はヘッダと改行だけ(`gen/root` の import が増えたのは `roster_list` と `store_roster_list`)
- P2-3 report の「`yumemi_gen_test.gleam` への変更は、5 の helper 本体 4 行」は、実際には置き換え 1 行と注記 1 行
- P2-4 `relation.plural` の母音 + y(基点から)
- P2-5 どの句も owner を絞らないとき、生成 SQL には owner の照らしが無い。runtime がこの Service の句だけを渡すことを前提にしている。念のため `AND cl->>'owner'='no_owner'` を足せば、前提が崩れても閉じる向きに倒れる
- P2-6 `manual_verbs` は、名の打ち間違いが生成候補と 1 字違いでも黙って通る(設計どおり)。1 字違いに警告を出すと、BRIEF の失敗例「名の打ち間違いが黙って通る」を もう 1 段防げる

## 走らせたもの

- `cd gen && gleam test`(先端 212 passed、基点 194 passed)、`gleam format --check src test`(0)、root `gleam build`(0、warning 1)
- `gleam run -m yumemi_gen -- fixtures/article build/kw/fx-{a,b}`(0 / 0)、基点の木でも同じ入力で(0)
- `gleam run -m yumemi_gen -- build/kw/snap/api build/kw/out-{a,b}`(4 / 4)、基点の木で `base-out`(4)。最初は写しの根を渡してしまい exit 3(`src/types.gleam が無い`)になったので、`snap/api` に直して走らせ直した
- `snap-manual`・`snap-pick` を写し直して生成(どちらも 4、差は上の表のとおり)
- P0-1 の 2 つの形(`kw/fxc`、`kw/fxs`)の生成(どちらも 0)と、`kw/constcheck` の `gleam build`(0)
- 走らせていないもの:生成 SQL を Postgres で走らせること(真壁と同じく未実行)。hw-2 の `party_of` との突き合わせ(実物が無い)

## 判定

**差し戻し。**

| # | 要旨 | 該当 |
|---|---|---|
| P0-1 | allow の句を定数に包むか spread で書くと、句を「絞らない」と読み、読みの SQL から allow 句が消えて exit 0 で通る | `gen/src/yumemi_gen/reader/clauses.gleam:27`・`:54` |

P0-1 を直す回で、P1-1(辿る道を allow の Entity からに揃える)と P1-4(literal でない list)も一緒に閉じることを勧める。鷹野宛 1 は (c) を hw-2 で入れ、本便の merge 時点は (b) のまま。鷹野宛 3 は framework に足さず、注記を直す。
