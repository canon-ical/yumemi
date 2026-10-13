# BRIEF yumemi-0131 ── 0.13.1:実行時の Markdown の Component と、文書サイトを本番に出す前の 6 つの穴

便: yumemi-0131
基点: yumemi main `1eb718c`(tag `v0.13.0`)
起案: 鷹野[PDM]、2026-10-13
親: `~/canonical/tech/_drafts/gleam-site/20-yumemi-poc.v0.md`(PoC の結果と「足りないもの 15 件」)、`~/canonical/tech/_drafts/gleam-framework/51-front-types.v6.md`(型の正本案)

親ゴール: Markdown の本文を DB に持つ文書サイトを、面に手書きの md パーサも事業の機能も置かずに、yumemi だけで書いて本番に出せる。
- 障害: 同じ md の読みを app ごとに書き直す(文書サイトの PoC で 700 行、別の事業の記事と規約で 2 種 3 写し)
- 障害: 一般化で、既に Markdown を描いている app の出力が 1 byte でも変わり、その app の面の書き直しが要る
- 障害: 文書サイトの形の app が、生成の停止・整数の列の 503・log の無い 503 で黙って壊れる

## 現在地

- 0.13.0 は Hex に出ている(冪等キー、`DLEAM_SQL_ENDPOINT`)。0.14 は別の便(専用の DB ドライバ)が取る。**この便は足すだけの 0.13.1**
- 面は yumemi にしか依存できない。`el` は生の HTML を受けない。だから Markdown は木に読んで `html` の要素で組むしかない
- 今ある md の読みは 4 つ。どれも yumemi の外か、用途が違う:
  - (a) 事業 app の記事の読み `~/yumemism_repo/musearch/www/src/article_markdown.gleam`(303 行、`muse_editor/src/` に同じ写し)。7 種だけ読む(見出し・段落と改行・太字・箇条書き・番号・リンク・`---`)。それ以外は字のまま。空行は畳まず数で返す、`#`・`##` は 2、段落の中の改行は `br`、`plain`(抜粋)と `rule` も公開している。描くのは app の Block(`www/src/blocks/article_detail.gleam`)
  - (b) 同じ app の規約の読み `www/src/legal_doc.gleam`(194 行)。前書きの `status:`、h1〜h3、箇条書き・番号、段落の中の改行は詰める、行の中の記法は読まない
  - (c) 文書サイトの PoC `~/yumemism_repo/gleam-site-yumemi-poc`(branch `poc` `400a4ed`)の `www/src/md.gleam`(597 行)+ `md_view.gleam`(95 行)。見出し・段落・コードブロック(言語名)・表・引用・入れ子の箇条書きと番号・区切り線、行の中はコード・太字・斜体・リンク・`<code>`・自動リンク
  - (d) yumemi 本体の生成時の読み `src/yumemi/gen/markdown.gleam`(`docs/api-v1.md` を静的な要素に)
- (a)(b) の振る舞いは事業 app の test が縛っている(`www/test/ed-2-rule-ssr.test.mjs`・`article-list-ssr.test.mjs`・`3-5a-legal.test.mjs`、`muse_editor/test/ed-1-article-format.test.mjs`・`ed-2-editor.test.mjs`)
- PoC の 21 頁の原稿は `~/yumemism_repo/yumemi-site/docs/gleam-ja`(読む頁の表は PoC の `dev/ingest.mjs` 18〜23 行)
- 6 つの穴(20 の番号):
  - 2 面を置くと `src/external_hosts.mjs` と `docs/api-v1.md` が無いと exit 3(`src/yumemi/gen/static_source.gleam:44〜51`)、`gen/doc/api_v1.gleam` が面の style を名指しする
  - 3 Paged の一覧を整数の列で並べると 503。`src/yumemi/gen/emit/sql.gleam` の `cast_of` が integer 等を持たない(隣の `keyset_cast` は持つ)
  - 6 一意制約の違反が log の無い 503。内部の例外は全部 503 に畳まれる
  - 9 `html` に `em` `i` `h5` `h6` `kbd` `del` `sup` `caption` が無い
  - 10 Style に文書の語彙が無い ── 中央寄せ、`overflow-x`、`white-space`、辺ごとの線、`font-style`
  - 11 実行時の Markdown の描画が無い(上の 4 つ)

## どこまで

1. **実行時の Markdown を読んで描く Component が yumemi にある。**語彙は Page / Block / Component の Component(interactive でなくてよい、view の関数でよい)。置き場・型・名前は真壁が決める。読みの木も公開する(app が自分の Block で描けるように)
2. **読む記法の範囲と読み方は、使う側が選べる。**(c) の範囲(表・コードブロックの言語名・入れ子のリスト・引用・見出し h1〜h6・行の中の記法)を全部読める。(a) と (b) の読み方(読まない記法は字のまま、空行を数で返す、見出しの段の写し方、段落の中の改行を `br` にするか詰めるか、前書き、`plain`・`rule` に当たるもの)も、選び方 1 つで再現できる
3. **(a)(b) の互換を test で縛る。**(a)(b) の test の入出力の表を、事業名の無い一般の題材に書き直して yumemi の test に持つ。(a)(b) の読みと yumemi の読みが同じ入力で同じ木を返す(木の形が違うなら、同じ HTML を描けることを示す)
4. **(c) の 21 頁で突き合わせる。**PoC の `md.gleam`+`md_view.gleam` と、新しい Component の出力 HTML を 21 頁で比べ、差を results に全部挙げて理由を添える(PoC の誤りを直した差はよい)。原稿は yumemi の木に写さない(`.scratch/` で回す)
5. **穴 2・3・6・9・10 を閉じる。**2 は 2 つの file が無い app でも生成が通り、ある app の生成物は byte 同じ。3 は integer・bigint・boolean・double precision の列で Paged が通る。6 は一意制約の違反の log に制約の名が出る。応答の status を 503 から替えるなら(409 など)、外から見える契約の差として results に書く。9・10 は足すだけ
6. **既存の fixture と、事業 app の写しが変わらない。**fixture の各面で生成器 2 回 exit 0・差 0。事業 app(`~/yumemism_repo/musearch` main を `.scratch/` に写し、path 依存で)の各面の生成物の差を results に全部挙げる(差 0 が目標)、www・muse_editor の test が通る

## しないこと

- 版を替えない・tag を打たない・publish しない(鷹野がする)
- 事業 app の写しの src を書き換えない(乗り換えは別の便)。文書サイトの PoC も書き換えない
- `yumemi new`、穴 1・4・5・7・8・12〜15 は外。見つけた直しは results に「次の版へ」
- 構文の色付けはしない(言語名を class か data 属性で残すだけ)
- 事業名・役員の名・事業 app の path を src・README・test・fixture・commit message に書かない(Hex に載る)

## 失敗例

- 一般化のついでに (a) の空行の数・`#` の段・字のまま返す記法の振る舞いを変える(事業 app の記事の見た目が変わる)
- 生 HTML を通す口を開ける(`el` が生の HTML を受けないのは柵。md の中の HTML の直書きは字のまま escape)
- リンクの `href` を素通しにする(`javascript:` 等。(a) は http(s) だけ、(c) は相対も通す ── どちらの柵か選べる形に)
- `gleam test | grep passed` の終了コードで合否を読む(字で見る)。root で `npm ci` を忘れて bundle の test が 2 本落ちる

## 返すもの

`briefs/results-yumemi-0131.md`(1〜6 の充足、Component の公開の形と使い方の例、21 頁の差の表、事業 app の写しの生成物の差、外から見える契約の差、次の版へ)。README の該当節。commit は `git-as 真壁`。
