# yumemi-decode-1 ゲート 2 レビュー(柏木[CM]、2026-09-25)── 承認、P0 無し

**承認。P0 無し。**生成 decoder は関係の型(Has / Held / Multi)と enum の `kind` の綴りで、api の `encode`(F5 `c27f75d` の `api/src/gen/codec.mjs`)と一致した。「読めずに黙って既定値に倒れる形」は無い。報告 `yumemi-decode-1.md` の数字は、柏木の手元で全部再現した。実 API で未達の 3 Page を「decoder の外(Args の検証で 400)」とした切り分けは正しい。ただし検収 (iii) の「3 Page も 200」は字面どおりには満たしていない。代わりの証跡(Args を補う実験)で受けるかは鷹野さんの判断になる(下の §3)。

対象は `git diff e9dca4b 3b40e35`(19 files、+1086 / −309)。コードは直していない(本回の指示)。柏木の出力は `gen/build/kw/`(gitignore、作業木に残す)に置いた。往復のスクリプトは `gen/build/yd1-roundtrip*` などの証跡を上書きするので、走らせる前に `kw/evidence-before.tar` へ退避し、走らせた後で戻した。

## 1. 検収の再走(柏木が打った値)

| 項目 | 結果 | 証跡 |
|---|---|---|
| root `gleam build` | exit 0、warning 1(`Unused private constructor`、基線と同じ) | kw/root-build.txt |
| `cd gen && gleam test` | 185 passed, no failures | kw/gen-test.txt |
| `node gen/scripts/verify-decode-roundtrip.mjs` | 本便 29 PASS / 0 FAIL。v0.9.0 24 PASS / 5 FAIL(Has, Held, Multi, enum kind Articles / HeavenDiary、想定どおり)。exit 0 | kw/roundtrip.txt |
| `node gen/scripts/verify-encode-copy.mjs` | F5 の `codec.mjs` と tag / encode の本文、空白を除いた diff 0、MATCH | kw/encode-copy.txt |
| fixture 生成 2 回(`gleam run -m yumemi_gen -- fixtures/article build/kw/fx{1,2}`) | 各 exit 0 / 92 files。SHA256 の集合の diff 0。tracked の 31 と byte 差 0 | kw/fx-diff.txt |
| 生成物の `gleam format --check` / sha256 header | 変更した .gleam 7 本と fx1 の全 .gleam が exit 0。gen 配下 56 本で header の欠けは 0 | ── |
| front の検証 | SSR / isolate / given / file / overlay は ALL PASS、blocks は PASS(6 blocks)。mock を `makeEncode` に替えた後の状態で打ち直した | kw/front-*.txt、kw/build-blocks.txt |
| F5 snapshot を HEAD の生成器で再生成 | exit 4、1377 files。記録の `yd1-snapshot-current-1` との差は `www/_diagnostics/www-runtime.txt` の 1 行(`Downloaded 11 packages in 0.02s` と `0.01s`)だけ | kw/snap-cur.log |
| v0.9.0 の生成器との差 | 30 files(www 9 / muses 19 / console 2)。差の行は関係の decoder の断片と `kind` の分岐(−12 / +12)だけ | kw/thirty.txt |
| snapshot に当てた 30 files | HEAD の生成器の出力と byte 一致(差 0)。www / muses / console の `gleam build` は exit 0 | kw/snap-build-*.txt |
| 生成物に残る包み | snapshot の全 `src/gen/out` で `decode.field("value"` 0 件、`decode.field("values"` 0 件、PascalCase の分岐 0 件 | ── |
| 守り | `src/framework` の diff 0 行、`src/` の diff 0、`db/` と `gen/fixtures/article/db/` の diff 0、DDL の file 0、`gleam.toml` 0.9.1、root package 10(基線 10)。F5 `c27f75d` status 0。musearch `bdb2ce3` status 0 と yumemi main `6581524` status 0 で、どちらも進んだ分は水無瀬・鷹野・庵野の docs commit だけ | ── |

## 2. decoder と encode の突合(見ること 2)

- **Has / Held:**`er.Has(key: Key(value))` は、encode の「欄が 1 つの `key`」と「欄が 1 つの `value`」の 2 段で素の文字列になる。decoder は `decode.map(decode.string, …)`(`front.gleam:6781-6787`)で、形が合う
- **Multi:**`Multi(keys: List(Key))` は `keys` を欄に持つ object のまま残り、`{"keys": ["…"]}` になる。decoder は `decode.field("keys", decode.list(of: decode.string), …)`(`:6789`)で、形が合う。鷹野さんの裁定 5 のとおり
- **enum の `kind`:**分岐の文字列は `codec_tag`(`:6542-6561`)。規則は JS の `/([a-z0-9])([A-Z])/g` → `toLowerCase` と同じで、2 つ目の文字が大文字なので match は重ならない。`HTTPReady` から `httpready`、`HeavenDiary` から `heaven_diary` になり、往復 test で値まで照合している
- **既定値へ倒れる形は無い。**`kind` が未知のときの fallback は `decode.failure(…, expected: "<型>.kind")`(`:6100-6110`)。関係の型は `decode.string` を必須で読む。diff で `one_of` と既定値は 1 つも増えていない
- **面の `kind` の値が変わる件:**面の型は `Kind = String` のままで、中身は構成子名から snake_case の wire 値に変わる(往復 test も `row.kind === "articles"` を期待している)。F5 の ★ を読んだ(読むだけ)。www の `ByKind(by: "kind", table: [#("Articles", …)])` は、生成の `rows_helper_text`(`:4267-`)が Row の構成子へのパターンマッチで振り分けるので、値の綴りに依らない。muses の `widget_row.kind_label` は `string.lowercase` をかけてから snake_case で当てる。PascalCase の値と比べる手書きは見つからなかった

## 3. 実 API の未達 3 Page の切り分け(見ること 3)── 正しい

- `yd1-r8/api-requests.txt` では、3 Page とも API の Args 検証が 400 `invalid_argument` を返している(`field` は widget / handle / from)。応答の本文が decoder まで届く前に止まっている
- `yd1-api-worker-argfix.mjs` を読んだ。書き換えるのは要求の query だけ(4 本)で、応答には触っていない。この条件で 8 Page とも 200 になり、`argfix-content.txt` に置き場の本文・roster 名・日付が出ている。生成 decoder が実の応答を読めることの証跡になる。`direct-api.tsv` でも、同じ要求に Args を足すだけで 200 になる
- 原因の在処も F5 の木(読むだけ)で確かめた。www の space Page は `name: "space_main"`(`page.gleam:36`)、api の `WidgetKey` は `MuseTopMain` だけ、route は `/api/rosters/:id`(`www/src/gen/api.gleam:272`)。どれも本便の「しないこと」(面から api への Args の encode、Y1f の値の出所、musearch への書き込み)に当たる
- **鷹野さんへ:**検収 (iii) の字面(Args を補わずに 8 Page が 200)は満たしていない。代わりの証跡で受けるかは鷹野さんの判断。僕は受けてよいと見る。decoder の欠陥ではなく、F5 と Y1f の宿題として申し送りに原因ごとに書いてある

## 4. D1 の直し(見ること 4)── 正しい

`missing_row_enum_tag`(`:7475-7522`)から、`"Row", Some("kind")` の名指しが消えた。判別の欄は `discriminator_field` で取り、enum かどうかは `tagged_variant_tag` と同じ `discriminator_enum` で判定する。停止は `stop.Conflict`(exit 4)。`yumemi_gen.gleam:131` で停止の経路に入っている。test は 2 本ある(欄名 `kind` と `tag`)。欄名が `kind` でない union は、`custom_decoder` が tagged の経路へ入れず untagged の `one_of` で読む(`:5982-6002`)。同じ形の構成子があれば `decodable_variant_shapes` が止めるので、黙って最初の構成子に倒れることは無い。

## 5. 射程の外の変更(見ること 5)── 既存の生成物は壊していない

単独 `Cursor` の decoder(`:6520-6524`)、`out_file` の import の置換(`:5731-5748`)、`verify-codec-roundtrip.mjs` の削除、`front-harness.mjs` が `codec-encode.mjs` を写すようにした件。fixture の 92 files は tracked と byte 一致、snapshot の差は上の 30 files の関係と `kind` の行だけで、効果が出ている生成物は 0。単独 `Cursor` はもともと `decode.string` を面の `Cursor` に当てていて、使えば compile しない形だった。変更後の経路は fixture にも snapshot にも現れない(snapshot の `cursor(raw)` 4 files は全部 `Page` の中、`type Cursor, cursor}` は 0 件)。

## P0

無し。

## P1(直さない、サマリに残す)

1. **(据え置き)**musearch の api は Hex yumemi 0.7.0 に固定されている。往復 test は repo の 0.9.x の framework で値を作る(報告の P1-1)
2. **(据え置き)**`tagged_variant_decoder` は位置の欄を `"value"` で読むが、encode は `"0"` を出す(`front.gleam:6149-6153`、報告の P1-2)。snapshot の生成物では 0 件
3. **往復の網羅が 1 つ減った。**`verify-codec-roundtrip.mjs` の削除で、Y1e が直した「位置の欄を持つ構成子と欄の無い構成子が混ざった union」(`Tagged(k) | External | …`、`Named(String) | Skipped | HTTPReady`)の往復が無くなった。新しい 29 本は `Pair`(record)と、欄の無い enum と、欄に名前がある union だけを持つ。生成物は変わっていない(metrics の 2 files は 30 files の外)ので、壊れてはいない。往復の cases に 1 本足せば返せる
4. **単独 `Cursor` の経路は test が 0 本。**`let assert Ok(value) = cursor(raw)` は、`""` を受けると decode の失敗ではなく panic になる(`Page.next` も前から同じ形)。back の `cursor("")` は `Error` なので今は届かない
5. **import の置換が広がった。**置換の対象が `"import framework/page.{type Page}"` から、import の文全体に現れる `"type Page}"` / `"type Cursor}"` に変わった。利用者の module が `Page` / `Cursor` という名の型を import していると、その行にも `Page, cursor` が足される。今の生成物では 0 件
6. **D1 の test は宣言名 `Row` だけ。**`Row` 以外の名の union が、潰れた enum を判別の欄に持つ場合の test は無い(経路は §4 のとおり正しい)。もう 1 つ、`kind` の union の分岐どうしで `codec_tag` が衝突するか(`ABC` と `Abc` がどちらも `abc` になる類)を検査する所が無い。encode の側でも区別できない、理屈の上だけの穴

## P2(記録。直していない ── 本回はコードを直さない指示)

1. **fixture public の lock が上がっていない。**`gen/fixtures/article/public/manifest.toml:20` が `yumemi 0.9.0` のままなので、写した木での cold build は `Incompatible locked version` で exit 1(`yd1-r8-fixture-public-cold.txt`)。v0.9.0 の release(`4f43a9f`)は、この lock も上げていた。直すのは 1 行で、tag `v0.9.1` の前に入れるのを勧める。報告の鷹野宛に書いてある
2. **F5 への申し送りの 606 paths は内訳を書いた方がよい。**`yd1-f5-regen-files.txt` の 606 のうち、本便による差は `src/gen/out` の 30 だけ(30 本とも 606 に入っていた)。残りの 576(`db/queries/verb` 164 ほか api 側、load の page など)は、v0.9.0 の生成器でも同じ形で出る差で、本便とは関係が無い。F5 が「30 files を受ける」ときに 606 を読み違えないよう、1 行足すとよい
3. **snapshot の「2 回 byte 一致」には診断の所要時間が入る。**`_diagnostics/*-runtime.txt` に gleam の `Downloaded … in 0.0Xs` が残るので、生成物の決定性とは関係なく揺れる(柏木の再生成で 1 行違った)。基線から在る。比べるときは `_diagnostics` を除くか、所要時間の行を落とす

## 判定

**承認 ── P0 無し。**鷹野さんには 2 点を上げる。§3 の検収 (iii) を Args を補う実験で受けるか。P2-1 の lock 1 行を merge と tag `v0.9.1` の前に入れるか。

以上、贄川さんを通さず、鷹野さんへ直接返します(本便は直書きの形)。
