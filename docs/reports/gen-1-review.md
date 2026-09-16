# gen-1 レビュー(柏木[CM]、2026-09-16)── 条件付き承認、critical 0

**条件付き承認。**禁則 5 つ(musearch 非汚染 / 名前の非焼付け / glance 固定 / 入力は Gleam のみ / 4 束の外へ出さない)は全部守られ、報告 `gen-1.md` の数字 4 表は柏木の手元で 1 桁も違わず再現した。条件は取りこぼし 3 点 + 2 点(P2)だけ。

## 禁則の検算

| 見た点 | 結果 |
|---|---|
| musearch のワークツリー | 生成・format・probe-compile の後も `git status --porcelain` は空(3 回)。probe は `/tmp` の複製で走る |
| diff に musearch のパス | 無い。変更は `gen/**`(30)・`docs/reports/gen-1.md`・`.gitignore`・`src/framework/query.gleam` のみ |
| 生成器に musearch の名前 | `gen/src` の該当 16 件は全部 doc comment の例示。分岐・出力文字列には無い。例外 1 つは P2-3 |
| glance | `gen/gleam.toml:11` `glance = "7.0.0"` 完全固定 |
| 入力 | `gen/src/yumemi_gen/source.gleam:29` で `gen/` を除いた `src/**/*.gleam` だけ。YAML / JSON / TOML を開く経路は無い(★ 84 ファイル) |
| 4 束の外 | 出力 124 ファイルは 4 種のみ。root.sql / verb / entry / migration の emitter はソースにも無い |
| commit | 4 本とも author=committer=真壁、`github/gen-1` に push 済み |

## 数字の再現(柏木が出した値)

`gleam test` 18 passed。束 1:61 / 完全一致 57 / 不一致 4、生成だけの行 0。束 2:生成 400 行 / 手書き 277 行、手書きだけの行 0。束 3:22 / 7 / 9 / 6 / 1 / 2。束 4:29 / 0 / 14 / 15 / 9 / 2。probe-compile:0 → 5 → 17(16 箇所)。fixture は 20 本文の写しとして byte 一致、test は文字列で実際に当てている。

## 残差の分類 ── 6 件を実物で検算、全部正しい

D3(`Max(Order)` の戻りは 20:771 どおり `Option(Order)`、手書きの `Option(Int)` が逸脱)、D4(生値が規則どおり、★ の logic が `key.free_space` を通すのが不整合 ── ただし札は未決側へ)、D10(★ は `join: []`、手書き SQL だけが JOIN を足した)、D12 / D13(★ の `Asc(Handle)` を手書きが落とした、`NULLS LAST` は生成側だけ)、G1(★ から導けるのに組めない ── 真の不足)、G4(`ConsentVersion` の衝突は probe で `Duplicate definition` として実際に出た)。

## runtime へ触った箇所 ── 全部

`src/framework/query.gleam` の 4 行だけ(`Cond` に `IsTrue(field)` と `EqOrNull(field, operand)`)。`Cond` を `case` で網羅する箇所は framework に無く、`gleam build` は通る。20:664「語彙が足りないときはフレームワーク側に足す」の経路どおり。critical にしない ── 追加のみ、手書き `gen/query.gleam` が自前で足していた形を所有者側へ戻しただけ、否決されても影響は ★ の綴り 2 箇所。**人見の裁定は要る。**

## 条件(次便で直す、P2)

1. 束 4 の「生成器だけ 9 本」と束 3 の `reads/article_release` が残差表に無い(手書き側の欠落 ── D 側へ 10 件足す)
2. 出力が不整合でも exit 0。G1 で SQL を落としたのに `reads/article_list.gleam` は出る。20 の exit code 規定に合わせて非 0 に
3. スキーマ名 `app` が生成器に焼かれている(`gen/src/yumemi_gen/emit/sql.gleam:234`)。★ にも 20 にも出所が無い唯一の文字列。framework の定数か 20 の規定から取る
4. 未決 6 に 2 つ足りない ── `order: []` + `NoLimit` に `ORDER BY <key> ASC` を足す規則、Option 列の `NULLS LAST` 規則。D4 は「手書きの逸脱」でなく未決側へ
5. 20 規約①の入力ハッシュが header に無い(`app gen --check` の便で要る)

人見へ上げるのは未決 3(語彙の追加)・未決 1(key 列と比べる穴の型)・未決 7(From と Field の名前空間)の 3 つ。残り 5 つは 20 本文の訂正として鷹野側で処理できる。
