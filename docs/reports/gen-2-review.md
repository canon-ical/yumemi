# gen-2 レビュー(柏木[CM]、2026-09-16)── 条件付き承認、critical 0

**条件付き承認。**禁則 5 つは全部守られ、報告の数字は束ごと・段ごとに柏木の手元で 1 桁も違わず再現した。**★ の綴りの逸脱は真壁の非ではなく BRIEF の誤り** ── Gleam に構成子の再輸出が無いことを 4 通りで実測した。

## ★ の綴り ── BRIEF が不可能を指示していた(gleam 1.18.1、javascript target)

| 試した形 | 結果 |
|---|---|
| `pub type From = from.From` を置いて `q.Article` | error: Unknown module value ── 型別名は構成子を運ばない |
| `pub const Article = from.Article` | Syntax error ── 構成子名の const は書けない |
| `import q/from.{type From, Article}` で再輸出 | error ── 無資格輸入は再輸出されない |
| `import gen/query/from as From` | Syntax error ── 別名は小文字のみ |
| `import … as qfrom` / `as qfield`(真壁の形) | Compiled |
| `from.Article` / `field.ArticleSlug`(素の module 名) | Compiled ── record label `from:` と module 名が同綴りでも通る |

裁定 4「From と Field は別 module」を採る限り ★ の 1 度の書き換えは必然で、真壁の判断は正しい。逸脱として数えない。無資格輸入で裸の `Article` にする案は From 23 + Field 197 が ★ の名前空間へ降りて Entity 型と衝突するので採らない。

## P2 5 件 ── 全部 ✓

| # | 条件 | 検算 |
|---|---|---|
| 1 | 残差表に手書き側の欠落 10 件 | D16(1)+ D17(9)、`compare.py` の「生成器だけ」束 3 で 1・束 4 で 9 と一致 |
| 2 | 不整合なら非 0 | 手元で `EXIT=1`、`_diagnostics.txt` と stderr が同文、`stop.gleam` の表は 20 の 6 分類と一致 |
| 3 | スキーマ名を生成器から抜く | `gen/src` に `"app"` は 0 件、出所は `src/framework/schema.gleam:6` の 1 箇所、出力の `FROM app.widget w` は不変 |
| 4 | 決め 2 つを外す / D4 を未決へ | 20 の規定として fixture が当てている(`test/yumemi_gen_test.gleam:303, 309`)、D4 は未決へ |
| 5 | header に入力ハッシュ | 4 束すべて `[sha256:12桁]`、`digest_ffi.mjs` は本物の sha256 |

## 数字の再現(柏木の値、全部一致)

`gleam test` 33 passed。束 1:61 / 0 / 57 / 4 / 0・0。束 2:生成 414(184 + 28 + 202)/ 手書き 277、生成だけ 133。束 3:22 / 0 / 16 / 6 / 1 / 2。束 4:29 / 0 / 14 / 15 / 9 / 2。probe-compile 0 → 162 → 22 → 17(16 箇所、gen-1 と同じ顔ぶれ)。出力 126 ファイルは 4 束 + `_diagnostics.txt` の外へ 1 本も出ていない。musearch は無傷(2 回)、`requalify.py` は `/tmp` の複製にだけ当たる。commit 4 本とも真壁。

## runtime へ触った箇所 ── 全部

`src/framework/schema.gleam` の新規 9 行だけ(`pub const app` / `pub const framework`)。gen-1 の `query.gleam` 4 行と合わせて計 2 箇所、既存の値も出力も動いていない。

## 未決 3(生成器 → framework の path 依存)── P2

循環は無く(runtime は生成器を知らない)、剥がすなら `gen/gleam.toml` 1 行と `emit/sql.gleam:4` の import 1 行。代替案(★ に `pub const schema`)の方が全アプリの ★ を巻き込む。

## 指摘(P2、次便)

1. exit 1 の分類名が 20 と違う(`stop.gleam:50`「生成器の不足」/ 20「内部エラー」)── 20 側を「内部エラーと未実装」に広げる(鷹野、同日に反映)
2. 不整合でも 126 ファイルを書いてから止まる ── `--check` の便で「書かずに止まる」か「部分出力に印」かを決める
3. `schema.framework` は誰も読んでいない、doc の「生成器も runtime もここだけを読む」と `db/schema.sql` の参照が現状に合わない
4. 入力ハッシュが生の source text の sha256 ── `gleam format` で動く。`--check` の偽陽性になるので正規形で取るか決める(後の便)
