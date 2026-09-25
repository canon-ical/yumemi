# yumemi-rel-0.10-0.11

branch `rel/0.10-0.11`、基点 main `f69a758`(0.9.1)。3 本の承認済み branch を順に merge した。段ごとに merge commit を 1 本打った(`git-as makabe`)。push・tag・publish はしていない(鷹野)。証跡は `gen/build/rel/`(gitignore、作業木に残す)。

## DDL

無し。3 段とも schema / migration を変えていない。

## 段と commit

| 段 | merge した branch | commit | version | 衝突を畳んだ file |
|---|---|---|---|---|
| 1 | `impl/yumemi-1f` c2519de(Y1f) | `0b24c40` | 0.10.0 | `gleam.toml`、`gen/manifest.toml`、`gen/fixtures/article/public/manifest.toml` |
| 2 | `impl/yumemi-hw-1` 6387d2c | `0cca9a9` | 0.10.0 | 無し |
| 3 | `impl/yumemi-hw-2` 1b5ca05 | `7d1ad58` | 0.11.0 | 無し |

### 段 1 の衝突

- 3 file とも yumemi の version の行だけがぶつかった(main 0.9.1 と Y1f 0.10.0)。Y1f 側がすでに 0.10.0 を書いていたので、3 file とも Y1f 側を取った。
- 生成器 `gen/src/yumemi_gen/emit/front.gleam`、`gen/test/yumemi_gen_test.gleam`、`gen/scripts/front-harness.mjs`、`gen/scripts/front-scratch/worker-entry.mjs`、tracked の生成物(`client.mjs`、`out/widget_list.gleam`)は git が auto-merge した。
- 両方の意図が残っていることは、次の 2 点で確かめた。
  - decode-1: 往復の verify が 29/0 のまま。`codec_tag`・`discriminator_enum`・`missing_row_enum_tag` も生成器に残っている(`emit/front.gleam:6290`、`:6651`、`:7584`)。
  - Y1f: gen test に Y1f の 13 本が加わり、198 = 194 + 185 − 181 で勘定が合う。
- auto-merge した tracked の生成物は、再生成したものと byte で一致した。

### 段 3 の version

version を 0.11.0 にしたのは 4 箇所。`gleam.toml`、`gen/manifest.toml` と、fixture の `public/manifest.toml`・`admin/manifest.toml` の yumemi の行。admin の manifest は Y1f で入った fixture で、段 1 のときから yumemi 0.10.0 の行を持っていた。

## 検収

| 指標 | 段 1 | 段 2 | 段 3 |
|---|---|---|---|
| root `gleam build` | 0 / yumemi の warning 1(`secret.gleam:5`) | 同左 | 同左 |
| `cd gen && gleam test` | **198 passed**, no failures | **223 passed**, no failures | **241 passed**, no failures |
| 本数の勘定 | Y1f 194 + decode-1 185 − 基線 181 | hw-1 219 + decode-1 の 4 | hw-1 + hw-2 の merge-tree 237 + decode-1 の 4 |
| `node gen/scripts/verify-decode-roundtrip.mjs` | exit 0。本便 29 PASS / 0 FAIL、v0.9.0 24 / 5(想定の赤: Has, Held, Multi, enum kind Articles / HeavenDiary) | 同左 | 同左 |
| Article fixture ×2 | 各 exit 0・112 files・`diff -r` 0 行 | 各 exit 0・112 files・0 行 | 各 exit 0・113 files・0 行 |
| tracked の生成物との比較 | 51 file 一致 / 差 0 / 取り残し 0 | 同左 | 同左 |
| fixture public `gleam build` | 0(cold) | 0 | 0(admin も 0) |

証跡は `gen/build/rel/s{1,2,3}-{root-build,gen-test,roundtrip,fx1.log,fx2.log,fx-compare,fixture-public-build}.txt`。tracked との比較は `gen/build/rel/cmp.sh`。生成物の各 file を `gen/fixtures/article/<同じ path>` の tracked と `cmp` で比べ、あわせて tracked の `src/gen`・`priv/static/_yumemi` のうち生成物に無いものを数えた。tracked の写しが無い 61〜62 file(back の `src/gen/**`、`db/queries/**`)は比べていない。

### 段ごとの生成物の差(どれも tracked の外)

- 段 1 → 段 2: 4 file(`gen/build/rel/s1-s2-fx-diff.txt`)。allow 句の SQL 3 本(`article_list/counts.sql`・`items.sql`、`widget_list/items.sql`)と、`src/gen/query.gleam` の `Pick` の構成子と Arrow の注記。hw-1 の report が「fixture の SQL 差は allow 句の 3 本だけ」「`gen/query.gleam` は Pick を使わない入力でも変わる」と名指ししている分と同じ。
- 段 2 → 段 3: `src/gen/allow/article.gleam` が 1 本増え、112 → 113 になった。root 4 本(`article_blob_save` / `article_list` / `article_read` / `widget_list`)の `Actor` は、`allow.Actor` の別名になった(`gen/build/rel/s2-s3-fx-diff.txt`)。hw-2 の report の「113 file(Y1f の 112 + `src/gen/allow/article.gleam`)」と同じ。

## 鷹野宛

- **0.10.0 の tag を打つなら段 1 の `0b24c40` に。**段 2 の `0cca9a9` も `gleam.toml` は 0.10.0 のままだが、中身には hw-1 の framework の変更が入っている。`src/framework/query.gleam` の `Select` に `Pick` を足し、型引数が 9 から 10 に増えた。これは役員 人見の裁定で受けた破壊的変更。
- decode-1 の申し送りにあった「fixture public の cold build が lock の不整合で止まる」は、この branch では起きない。段 1 で lock が 0.10.0 になり、cold build は exit 0 だった。
- 3 本の branch の root `results.md` は auto-merge で 1 file につながっている。中身は各便の作業状態なので、手を入れていない。

## 確かめたこと

- 段ごとに走らせた: root `gleam build`(exit 0、yumemi の warning 1)、`cd gen && gleam test`(198 / 223 / 241 passed、failures 0)、`verify-decode-roundtrip.mjs`(exit 0、29/0、v0.9.0 は想定の 24/5)。
- Article fixture を段ごとに 2 回ずつ生成した(`gleam run -m yumemi_gen -- fixtures/article build/rel/s<n>-fx{1,2}`)。`diff -r` は 0 行で、tracked 51 file と byte 差 0。
- fixture public の `gleam build` が 3 段とも exit 0。段 3 は admin も exit 0。
- 各段の commit の前に `git status --short` を見て、生成と build で木が汚れていないことを確かめた。

## 確かめていないこと

- Y1f の verify 群(SSR / isolate / given / file / overlay / Block preview)と F5 / F6 の snapshot は、merge 後に走らせていない。この brief の検収項目に入っていないため。
- hw-1 / hw-2 の実物の写し(musearch)への適用は、触らない範囲なので見ていない。
- Hex への publish の dry run(`gleam publish` 系)はしていない。
