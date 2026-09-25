# BRIEF yumemi-decode-1 ── 生成 decoder を api の codec の encode に合わせる(関係の型の素の値、`kind` の綴り)、Hex 0.9.1(草案、2026-09-25、水無瀬[PL] 起草 → 鷹野[PDM] が裁く)

便: yumemi-decode-1

**前提は 3 つ。**(a) **F5(`musearch-yumemi-5`)は止まっている** ── 贄川の終端(エスカレーション 09-25 15:58、run_dir `niekawa-20260925-154646-1948622-18133`)に鷹野が (C) を裁いた。F5 の木 `~/yumemism_repo/musearch-yumemi-5`(HEAD `c27f75d`)は **run_dir に写して読み、一度も書かない**(`git status --short` 0 行と HEAD 不変を証跡に)、(b) **`~/yumemism_repo/yumemi`(main の作業木)は触らない** ── F5 は生成器をそこから呼ぶ(musearch `BRIEF-yumemi-5.md:35`)ので、本便の merge で F5 の次の生成がそのまま直る、(c) **Y1f(`impl/yumemi-1f`、0.10.0、承認済み・未 merge)は触らない**。**基点は yumemi main `<本 BRIEF の commit>`**(tag `v0.9.0` = `4f43a9f` の上に BRIEF の commit だけ、`src/` と `gen/` は `4f43a9f` と同一)。作業木は `~/yumemism_repo/yumemi-decode-1`(branch `impl/yumemi-decode-1`、贄川が作る)。plan は贄川の run_dir、記録は `docs/reports/yumemi-decode-1.md`(**`## DDL` 必須、本便は「無し」**)、証跡は `gen/build/yd1-*`。commit は `git-as <役>`、`main` に触らない、push と **Hex publish は鷹野**。1 巡 = 1 session、ゲートは 1 も 2 も便に 1 回、ゲート 2 の P0 を直す巡は真壁を sol で。配役は起動前に `harness-route` で引く(柏木は経路 C)。**`gleam.toml` は 0.9.1**(F5 の `>= 0.9.0 and < 0.10.0` に入る patch)。**見積 中央 2:30(推定)。**

**親ゴール:** F5 が生成物だけで、データのある実 API の Page を 200 で描ける ── 生成器が面の decoder を api の codec の `encode`(musearch `api/src/gen/codec.mjs:135-146`)の規則どおりに作る版(Hex 0.9.1)を出す。

**障害:**

- **関係の型を encode と違う形で読む** ── `encode` は欄が 1 つの object を素の値に展開するので `Held(key: Key(value: "m1"))` は `"m1"` で届くが、生成 decoder は `{"value": …}` を待つ。F5 の木で www 9 / muses 19 / console 2 の計 30 file・54 箇所、全部 `Held`。www の公開 Page(記事一覧・記事・space・roster・schedule)と muses の Widget の Page が 500
- **`kind` で判別する union の分岐が構成子名のまま** ── `encode` は enum を `tag()` で snake_case(`articles`)にするが、`widget_list` の decoder は `"Articles"` を待つ。**muses だけでなく www の `widget_list`(`/muse/:handle` と space の Widget、例外にせず生成物のまま)も同じ**(水無瀬の実測、F5 の終端には無い)
- **stub が同じ誤りを持ち、test が緑になる** ── fixture の mock `gen/scripts/front-scratch/worker-entry.mjs:12` は `category: { value: "news" }` を返す。stub の上の test と DOM の数えでは見えない
- **直し方次第で api の JSON か面の型が動く** ── 前者は外部 API(`docs/api-v1.md`)と ★ の手書き decoder を、後者は 0.9.x の ★ の compile を巻き込む

## 現在地(yumemi `4f43a9f` と F5 の木 `c27f75d` の実測、水無瀬。基線は巡 1 の頭で打ち直す)

- **encode の規則の正は musearch の手書き** ── `codec.mjs` は header に GENERATED とあるが生成器は見当たらず(musearch / yumemi を grep)、musearch の commit で 8 回直されている。yumemi が持つのは Y1e の写し `gen/scripts/verify-codec-roundtrip.mjs:112-123` だけ
- **(1) の在処:**`gen/src/yumemi_gen/emit/front.gleam` の `relation_decoder`(`:6458`)が `has_decoder` / `held_decoder` / `multi_decoder`(`:6710-6720`)を呼び、`decode.field("value", …)` / `decode.field("values", …)` を吐く。面の型は `opaque_text`(`:7680-7684`)が `Held(value: String)` などに写す。**Y1e の P0 直し(`36156df`)は利用者定義の `{value}` / `{key}` を `variant_decoder`(`:6270`)で直したが、`framework/er` は `:5804` / `:6563` で別経路に分かれるので届いていない。**`Multi` は `{"keys": […]}` で届くのに `values` を待つ(musearch の使い手は今 0、穴は同じ)
- **(2) の在処 ── 漏れた経路:**`row_enum_aliases`(`:7432`)が Row の構成子名と重なる enum(`widget.Kind`)を `String` の alias に潰す(F5 の P1 `widget_list.Kind = String` はこれ)。潰れた型は `custom_decoder`(`:5956`)で `decode.string` になり、**Y1e が snake_case にした `enum_decoder`(`:6382`)を通らない**。`discriminator_field`(`:6156`)が `kind` を拾い、`tagged_union_decoder`(`:6061`)の分岐は `string.inspect(variant.name)`(`:6074`)で構成子名のまま。fixture の `widget_list` は `kind: String` に back が `"Article"` を書く形(`gen/fixtures/article/src/service/widget_list.gleam:28-29,67-69`)で、こちらは構成子名で正しい
- `gen test` 181、fixture 92 file。判別できない union は `decodable_variant_shapes`(`:7389`)→ `decoder_notes`(`:7357`)が止める。F5 の実 API の道具は F5 の木の `docs/evidence/yumemi-5-a6-*`(api worker / PG bridge / fixtures / Page の status)

## どこまで

1. **関係の型の decoder を encode どおりに** ── `Has` / `Held` は素の文字列から、`Multi` は `keys` の文字列の列から。`Key` / `Link` は今のまま。**面の型(`Held(value: String)` ほか)は変えない**(★ と `blocks_preview` の構築 `relation_default`、`:1257` は無傷)
2. **`kind` の分岐の綴り** ── 判別の欄の型が enum(`enum_aliases` に在る)なら分岐の文字列は `codec_tag`、`String` なら今のまま構成子名。enum に同名の構成子が無い Row の構成子は生成器が止める(exit 4、file と構成子を名指し)。`Kind = String` の alias は残す(裁定待ち 2)
3. **往復の test(stub 頼みでない)** ── back の実の型の値(`src/framework` の `er` / `blob` / `time` / `party` / `page` と、probe に置く Service の型)を作り、**`codec.mjs` の `encode` と同じ本文**で JSON にし、生成 decoder で読んで期待の面の値と一致させる。型ごとに 1 本以上:素の型、`Option` / `List`、`gen/types` の値、framework の opaque と `Page` / `Cursor`、`Key` / `Link` / `Has` / `Held` / `Multi`、`{value}` / `{key}` の record、位置の欄、欄の無い enum、潰れた enum を `kind` に持つ union、`String` の `kind` の union、欄で判別する union。`encode` の写しは 1 箇所にまとめる
4. **fixture の mock を encode の形に** ── `worker-entry.mjs` の応答は手で JSON を書かず、写しの `encode` を通す
5. **results** ── `## DDL`(無し)、`## 鷹野宛`、`## 追随便への申し送り`(F5 宛:再生成で変わる file の一覧、生成物に戻せる例外、実 API の Page の表)、基線の表

**しないこと:****api の外から見える JSON を変える**(`codec.mjs` の規則、registry の応答 ── 要ると判断したら止めてエスカレーション)、**musearch への書き込み**(F5 の木と `~/yumemism_repo/musearch` の両方)、**面の生成型の形を変える**(`Held(value:)`、`Kind = String` を含む)、**Y1f の射程**(値の出所、`reads` / `vars`)と `impl/yumemi-1f` への取り込み、面 → api の向きの Args の encode(見つけたら申し送り)、`~/yumemism_repo/yumemi`(main の作業木)、`main` への commit、push、Hex publish、DDL、`.claude/_core` `~/.codex` `~/.claude`。

## 失敗例

- **encode 側を直す**(`codec.mjs` で包みを残す / PascalCase で出す)── musearch の file で本便の外。外部 API と ★ の手書き decoder が動く
- **decoder が両方の形を受ける**(`decode.one_of` で `{value}` と素の値)── mock の誤りが緑のまま残り、次の食い違いも見えなくなる
- **`widget_list` や `Held` を名指しで直す**(Y1e が `visit.Source` の特例を消した轍)── 規則は型の形で決める
- **fixture の mock を手で合わせて閉じる / `gen test` の文字列一致だけで閉じる**(往復していない)。基線を F5 の results から写す(毎巡 自分で打つ)、同 persona の同秒起動、`^session_id:` での終了判定

## 検収

- root `gleam build` 0(warning 1 から悪化しない)、`cd gen && gleam test` が 181 以上、**往復の test が型ごとに PASS**(本数を書く)。**`v0.9.0` の生成器では関係の型と enum の `kind` の往復が赤**になる証跡を 1 度。`encode` の写しと `codec.mjs:135-146` の本文が一致(空白を除いた diff 0)
- fixture 生成 exit 0、**2 回走らせて byte 一致**、face build 0 / warning 0、SSR / isolate / given / file / overlay / Block preview が ALL PASS、sha256 ヘッダの欠け 0、生成物の `gleam format --check` 0。fixture の差分は関係の decoder と mock だけ
- **snapshot(F5 の木 `c27f75d` の写し)で測る:**(i) `v0.9.0` と本便の生成器でそれぞれ木の外に 2 回ずつ生成し、各 2 回は byte 一致、**2 つの生成器の差は 30 file の decoder の行だけ**(型の宣言と他の file は 0 行)、30 file の `decode.field("value"` が 0、www / muses の `widget_list` の分岐が snake_case、(ii) 写しの `src/gen` に本便の生成物を当て、muses `widget_list` の ▲ 例外を生成物に戻して 3 面 `gleam build` 0、(iii) **実 API**(a6 の道具、DB は F5 の `musearchyumemi5` / `idpyumemi5` と別名)で、データのある状態の www の記事一覧・記事・space・roster・schedule・`/muse/:handle`、muses の `/page`・`/page/widget/:id` が 200。同じ道具で `v0.9.0` の生成物が 500 になることも 1 度打つ。Page ごとの status の表を証跡に
- musearch は無傷(F5 の木と `~/yumemism_repo/musearch` の `git status --short` 0 行・HEAD 不変)、`~/yumemism_repo/yumemi` の HEAD 不変、`src/framework` の差分 0 行、`gleam.toml` は 0.9.1、依存 package 数は不変。`## DDL`(無し)と `git diff --stat <基点> -- db/ gen/fixtures/article/db/` が空で一致。**終端は承認かエスカレーション**
- **巡ごとに贄川が出すもの:**往復の test の本数と赤 / 緑、snapshot の 2 生成器の差の file 数、実 API の Page の status、musearch の `git status --short`(0 行)。**「継続」で裁定を待たない** ── 問いは終端で返す

## 見積と追随

**最短 1:30 / 中央 2:30 / 最長 4:00(推定)。**内訳は関係の decoder と `kind` の綴りと停止 0:30、往復の test と `encode` の写しの一本化 0:40、fixture と mock 0:15、snapshot の 2 生成器の比較 0:20、実 API の立ち上げと Page の表 0:35(a6 の道具を使い回す)、ゲート 2 の P0 の余地 0:10。生成器の便は 2 本続けて見積の 1.5 倍に振れた(G7・Y1e)ので、**予算は中央 × 1.5 = 225 分**(Y1f の裁定 7 の引き方)。

- **F5:**本便の merge 後に `~/yumemism_repo/yumemi/gen` で再生成し、30 file を生成物のまま受け、muses `widget_list` の ▲ 例外を消す(例外 24 → 23)。続きの指示は鷹野が F5 の箱に書く
- **Y1f:**`impl/yumemi-1f` は本便の merge 後に main を取り込み(`emit/front.gleam` が重なる)、本便の往復の test を通してから段 10 の後の merge に進む

## 裁定待ち ── 起動前に鷹野が裁く

1. **予算。**推奨:225 分(中央 × 1.5)。対案は 190 分(× 1.25)
2. **`Kind = String` の alias は本便で残す。**面の型を enum に戻すと 0.9.x の ★ が compile しなくなる。typed の Kind は Y の列へ
3. **encode の規則の正の置き場。**`codec.mjs` は GENERATED の header を持つ手書きで、yumemi の写しと食い違うと本便の test は緑のまま実 API で割れる。推奨:本便は写しと本文の一致を検収で確かめるまで。正をどちらが持つか(生成器が codec を吐くか)は back の世代揃えの射程として `keiei/canon/open.md` に立てる
4. **Hex 0.9.1 は `src/framework` 0 行の publish になる**(F5 は生成器を main の作業木から呼ぶので、publish が無くても直る)。推奨:裁定どおり publish して tag と版を揃える
