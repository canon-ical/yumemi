# BRIEF ── Y1b:ordered create の 3 穴(astra 事後レビュー P0-9 / 10 / 11)(2026-09-21、鷹野[PDM] → 贄川[ORC])

便: yumemi-verb-1b

**親ゴール:** tech 00-goal G2 ── 生成 verb SQL が実 PostgreSQL で手書きと同じ意味を持つ。障害:Y1(承認 09:30、main 7680633、Hex 0.5.0)の ordered create が同時実行・値域・親欠落の 3 点で壊れたまま F3 が musearch に採用する。

**前提:** 基点は yumemi main `784ecd9`(Y1 + 柏木 P2 e0229d0)。作業木は `~/yumemism_repo/yumemi-verb-1b`(branch `verb-1b`、贄川が作る)。musearch は読むだけ。**DDL は書かない。**Y1 の型:贄川 = Claude opus(`claude-niekawa`)、柏木 = Codex sol(ゲート 1 / 2 各 1 回)、真壁 = luna(ゲート 2 の P0 を直す巡は sol)。1 巡 = 1 session。

## 現在地

- astra の事後レビュー(run `~/.codex-agents/runs/kashiwagi-20260921-093150-1579354-9519`、`findings.md` と `evidence/ordered-create-repro.mjs` / `order-range-repro.mjs` / `commands.txt`)が実 PG で再現した 3 件。承認・merge・publish の後なので Y1 は閉じたまま、**本便は DAG の別待ち(#79):F3 は本便の承認が前提**
- P0-9 `emit/verb.gleam:925`(単体)/ `:1240`(CreateMany):READ COMMITTED の 2 接続で親を `FOR UPDATE` しても、先行の commit 後に後続が `max+1` を読み直さず同じ `order` を採番する(UNIQUE ありで 23505)
- P0-10 `emit/verb.gleam:932`:開始値が 0 固定。fixture `PhotoOrder = Range(1,10)` で最初の作成が 0 を出す(CHECK ありで 23514、無しで値域外を保存)
- P0-11 `emit/verb.gleam:1184`:親との INNER JOIN で親の無い入力が INSERT 前に消える。CreateMany は部分成功、単体は 0 行、FK では防げない。贄川が Y1 の P1 に挙げた穴と同じ
- 既存の検証:`cd gen && gleam test` 80、`verify-gate2-sql.mjs` 10 PASS、`verify-verb-sql.mjs --self-test` 4。**3 件とも既存の検証では捕まらない**(単一接続・空の親・Range(0,…) の fixture)

## どこまで

1. **P0-9:採番はロック取得後に読む。**親の `FOR UPDATE` の後で `max("order")` を評価する形(CTE の評価順に頼らず、ロック行を経由した副問合せか、`INSERT … SELECT` の中で親行を JOIN してから集計)。実 PG の 2 接続 test で「後続が先行 + 1 を取る」を証明
2. **P0-10:開始値は宣言の順序型から取る。**`Range(lo, hi)` なら `lo`、無宣言なら 0。`hi` 超過は語彙に無いので名指しの残差のまま(推測で埋めない)。fixture の `Range(1,10)` で最初が 1 になる test
3. **P0-11:親が無ければ失敗させる。**`framework.require_rows` で包む(単体は 0 行で失敗名、CreateMany は入力行数と INSERT 行数の不一致で失敗)。FK に頼らない。2 行(有効 + 不在)の test で「全体が失敗し 0 行」を証明
4. 3 件の test は実 PostgreSQL(`verify-gate2-sql.mjs` の使い捨て schema の形)で、既存 10 PASS を緩めない。`gleam test` は 80 以上
5. musearch main `api/` への clean run で **exit 3 = 0 / exit 4 = 9 / 警告 21 / verb 以外の出力は差 0**、仮宣言コピーの段 2 一致 11 と欠落 by-type 1 が動かない(動くなら理由を報告に)
6. 報告は `docs/reports/verb-1b.md`(3 件の前後 SQL、test の名、数字)。`docs/reports/verb-1.md` の P1 一覧から 3 件を消して本便を指す。framework(`src/`)が変わるなら理由を書く ── 変わらなければ Hex publish は無し、変われば 0.5.1 は鷹野

## しないこと

語彙の追加、H 類の上限(free_space 5 / widget 30 / image 10 / link の url 重複)、I 類、advance_* の楽観ロック、`*Created` の 5 本、失敗名 `not_active`、handwritten ヘッダの絞り込み、`'draft'` literal 依存(以上は F3 か gen-6)。musearch への書き込み、DDL、push、`main` への commit。

## 失敗例

- 採番を `SERIALIZABLE` や advisory lock で「直した」と言う(呼び手の分離レベルを生成 SQL が決めない)
- 開始値を 1 に固定し直す(宣言から取らない)
- 親欠落を FK の 23503 に任せる(INNER JOIN で行が消える限り FK は発火しない)
- test を単一接続・空の親だけで書いて「通った」と言う
- 3 件を直すついでに H 類の SQL の形を変えて段 2 一致 11 を動かす

## 検収

3 件の実 PG test の名と結果、`gleam test` の数、`verify-gate2-sql.mjs` の PASS 数(10 以上)、musearch main への clean run の数字(exit 4 = 9 / 警告 21 / verb 外の差 0)、`results.md` の `## DDL`(無し)、report の path。astra の再現スクリプト 2 本を本便の木で再実行して P0 が消えていること。

## 鷹野の裁定 C(2026-09-21 14:45、巡 2 のエスカレーション「負の下端の開始値」への答え)

**create の開始値は `int.max(lo, 0)`。**`Range(-5, 10)` は 0 から始まる。理由:`reader.gleam:2124` の受理条件 `hi >= int.max(lo, 0)` と診断文「値域に確定値の起点が無い」が、確定値の起点を `max(lo, 0)` と既に定めている(gen-3 / gen-5 で承認済みの正典側の定義)。reorder の確定値も同じ `order_span` から出るので、create だけ `lo` に寄せると負の下端で create と reorder が食い違い、新しい穴になる。**「どこまで 2」の括弧書き「`Range(lo, hi)` なら `lo`」はこの裁定で更正**(`lo >= 0` のときは同じ値、P0-10 の「開始値 0 固定が `Range(1,10)` を破る」はこの形でも閉じる)。試験 `T2 negative lower bound starts at 0` はそのまま。現物の宣言は全部 `lo >= 1` なので musearch 側(F3)への影響は 0。負の値域を「手で置く領域」として使う設計は本便の外、要るなら 20 の改訂として鷹野宛。

