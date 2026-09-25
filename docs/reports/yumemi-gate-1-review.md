# yumemi-gate-1 柏木ゲート（2026-09-26）

対象は `3209703..ce84b70`、BRIEF 末尾の鷹野の裁定および今回の追加裁定。判定は **承認**。**P0 無し**。本便でコードは変更していない。

## P0

無し。新規 `src/framework/gate.gleam` 以外の `src/framework`、既存の `Page` / `Layout` / `Entry`、`gen/src/yumemi_gen/model.gleam` に差分は無く、0.11.0 の既存公開型は変わっていない。`emit/front.gleam` の差分は route 表、shell、client、門の接続で、報告された WGy の `api_routes` / `app.attached` 読み手、`model.gleam`、`emit/entry.gleam`、back emitter には触れていない。

門は `gen/src/yumemi_gen/emit/gate.gleam:399-428` で route に合った Page にだけ session を読み、`rules` の `pages` / `except` と `checks` を宣言順に評価してから redirect と shell に進む。console の写しの `Every` と `/switch`・`/consent` の除外、www の `/me` 前方一致、muses の `Authenticated` + `Muse` からの既定 `Admitted` を生成物と突合した。`gen/build/gate/workerd/table-{before,after}-https.tsv` は各 98 行で、比較器の実行結果は status・Location・CSP・pageview・描画 Page・APP 読み回数の差 0。cookie を消す処理は新しい `gate.mjs` に無く、session 読みの例外は 502 を返す。

route 表の重なりは現行 3 面で `/articles/new`、`/page/widget/new`、`/rosters/new` と各 `:id` の 3 対だけ。`route_order` は各 literal を param より前に置き、Workerd 表の 6 行も前後同一。`-` / `_` の別 route 同士の衝突は 0。`/api-key` と `/for-stores/api/v1` の生成物への対応も表で前後同一。

client entry は `app()` を持つ component を module で一意化して登録する。証跡の bundle 定義数は muses 37/37、console 14/15（差は名指しの残り `blob-copy`）で、登録 tag の重複は 0。www の 7 本は `app()` が無く生成器が exit 3 で診断する。既存の登録が二重になる形や、宣言済み `app()` を落とす形は確認されなかった。

## P1

1. **www の client entry を実面へ採用する前提**。www の島 7 本に `pub fn app()` が無く、生成物の登録は 0 本。生成器は欠落を診断して止まるため、黙って島を落とす欠陥ではない。WGm で component 宣言と手書き島の移設を終えた後、bundle の登録数と重複を再検査する。`docs/reports/yumemi-gate-1.md` の WGm 申し送りと `gen/build/gate/client/compare.py` に対象がある。

## P2

1. **空白だけの検索 query**。`gen/src/yumemi_gen/emit/front.gleam:5612-5614` は `""` だけを `None` にし、`?q=%20` を `Some(" ")` にする。前の www `gates.mjs:191-201` は trim 後に空なら空結果で短絡した。鷹野の追加裁定どおり空白だけを `None` に直す必要がある。今回は「コードは直さない」の指示に従って記録のみ。修正 commit は無し。現在の写しの `/search` Page は `q` Var 未宣言なので、この差は Workerd 98 行では検出できない。F6 の `q` 宣言が入る前に修正・検証すること。

## 再走した検証と限界

- root `gleam build`: compile 成功。既存 `framework/secret.gleam:5` の unused private constructor warning 1 件。
- `cd gen && gleam test`: **252 passed, no failures**。
- root と gen の `gleam format --check src test`: 両方とも差分要求 0。
- `cd gen && gleam run -m yumemi_gen -- fixtures/article build/gate/review-fx-{one,two}` を各 1 回: ともに 115 file を出力し、二つの出力の `diff -r` は 0 行。fixture の既存生成物 public 31 file、admin 19 file とも byte 不一致 0。
- `python3 gen/build/gate/workerd/compare.py ...table-before-https.tsv ...table-after-https.tsv`: 98 行、上記 6 列の差 0。200 の body 差は `/search?r=mail` の pageview script 1 行。ほかの body hash 差 15 行は 500 応答に含まれる path の差。
- `git diff --check 3209703 ce84b70`: 指摘 0。

写しの `src/gen` 全体を載せた面の build は、基線から Page 宣言が 0.11 に追随しておらず通らない。実 API / PG での門も未実行。今回の Workerd は F5 の stub を使用し、11 種の読みは decoder と合わず門を通った後に前後とも 500 になる。空の検索の短絡撤去は F6 の `q` Var と `article_search.q: Option` が揃うまで検収できない。これらは本便の生成器と門の判定を止める P0 ではなく、WGm / F6 の実面採用時に検証する。

## verdict

**承認。P0 無し。** P1 は www client の採用前提 1 件。P2 は `?q=%20` の追従漏れ 1 件で、0.11.1 の実面採用前に修正する。
