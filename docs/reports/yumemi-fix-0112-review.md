# yumemi-fix-0112 ── 柏木[CM] ゲート(2026-09-26)

対象は `git diff 02d6739 6c8cba8`(02d6739 = v0.11.1、squash `6c8cba8`、真壁 r1 H1〜H3 + r2 List / record)。要求は makabe の task 2 本(便 yumemi-fix-0112 の r1・r2)、背景は musearch-yumemi-7 の `docs/yumemi-7/results.md` の H1〜H3。証跡は `gen/build/kashiwagi/`(gitignore の下)。musearch には書いていない。PG は 55541 だけを起こし、終端で止めた。

**判定:P0 無し。**P1 を 4 件、下に残す。P2 は無し(直した commit は無い)。

## 見たこと

### 1. 0.11.1 の公開型

`git diff v0.11.1 6c8cba8 -- src test gleam.toml` は `src/framework/server/http.mjs`(+11 / -1)と `gleam.toml` の版だけ。Gleam の型・構成子・公開関数は 1 行も変わっていない。`gen/src` の差に `pub` の行の増減は無い(`Wire` / `ScalarKind` は private)。生成の live の口(`live.Set(field, String)`・`live.State`・`transport_send` の 6 引数)もそのまま。**patch で出せる。**

`http.mjs` の変更は 2 行の配線と `queryRaw`。`s.queryKeys` は POST / PUT / DELETE のとき null なので、body の読みは 0.11.1 と同じ。GET / HEAD の query の欄だけ、`bool`(と `option(bool)`)の `true` / `false`、`float`(と `option(float)`)の数の綴りを変換する。変換は 0.11.1 で必ず 400 だった綴りを通すだけで、0.11.1 で通っていた request の結果は変わらない(`text` / `scalar` / `int` / `hook` の欄は変換しない)。

### 2. POST / PUT / DELETE の送り方と既存の島

- 写しの 1 手で変わる live は 11 本(H1 の console `course_add` / `course_edit` / `roster_add` / `roster_edit`、H2 の muses `course_list` / `heaven_embed_code` / `heaven_resolve` / `ledger_store_search` / `notification_inbox`、r2 の `link_import_apply` / `muse_set_theme`)。**この 11 本を import する島は写しに 0 本**(`rg "gen/live/<名>"`、`src/gen` の外)。`calls` に載せている島(`course_add`・`course_editor`・`roster_add`・`roster_edit`・`store_courses`・`ledger_search`・`heaven_link`・`heaven_embed_code`・`notification_more`・`theme_save`・`link_import_apply`)は、どれも手書きの FFI(`*_ffi.mjs`・`island_fetch_ffi.mjs`)で送っていて、生成の live の send を通らない。www の生成の live を使う島(`fan_onboard` ほか)の live は生成物が変わっていない
- 手書きの FFI の送る値と新しい規則を突き合わせた。`roster_add_ffi.mjs` は `age` / `order` / `height` を `Number(...)`、空を `null`、`visible` を真偽で送る。生成の live は `age` / `order`(値型 `int`)を文字列、`height`(`Option(Int)`)を `int.parse` の数か `null`、`visible` を真偽で送る。back の `int` は数も数字の文字列も受けるので、載せ替えても同じ結果になる。`theme_save_ffi.mjs` は `theme` を object、`link_import_apply_ffi.mjs` は `links` を配列で送り、back の hook(`http_hooks.mjs:32`・`:43`)は object / 配列でなければ `invalid`。生成の live の `json_text` はこの形を送る
- 0.11.1 の生成の live では Bool / List / record の欄は必ず 400 だった(back の `bool` は真偽、`list` は配列、hook は object を要る)。新しい規則は 400 を 200 に変えるだけで、200 を 400 に変える綴りは無い。Int は 0.11.1 でも back の `integerRaw` が数字の文字列を受けていたが、新しい `int.parse` はその綴りを全部数にするので同じく通る
- 読めない綴りを文字列のまま送る規則は、back が 400 で返すので黙って別の値にはならない。ただし非 Option の Bool の `""` だけは 400 ではなく偽になる(P1-2)

### 3. GET の query

- `query_path_expression` は path の穴の名(`path_holes`)を除いた Args を載せ、back は `key in path` の欄を `queryKeys` から外し、`raw` でも path が上書きする。穴と query の名が衝突しない。写しの GET の live 5 本の path に `?` を含むものは 0、framework に `searchParams` を別の意味で読む所は無い(`raw` に混ぜる 1 箇所だけ)
- `uri.query_to_string` の `+`:写しの面の gleam_stdlib 1.0.5 は `percent_encode` の後に `+` を `%2B` にする(`uri.gleam:555`)ので、`page_url` や cursor の `+` は空白に化けない
- **back の読みを GET と POST で同じ値に当てた**(`probe-http.{mjs,txt}`、build 済みの `http.mjs` の `decode` 段を直に呼んだ)。`flag=true&ratio=1.5&n=7&text=a` の GET と、body `{flag:true,ratio:1.5,n:7,text:"a"}` の POST は同じ `[true,None,1.5,7,"a"]`。`flag=false&maybe=true` も同じ `[false,Some(true),2,0,""]`。`text=true` は GET でも文字列 `"true"` のまま。`maybe=`(空)は GET も POST も 400。POST の query だけ(body 無し)の `flag=true` は 0.11.1 どおり 400 で、POST は query を変換しない
- 食い違うのは live 側の Int / Float の端の綴りだけ(P1-1)。GET の List は query に 1 つの文字列で載って back が 400 を返すが、0.11.1 は GET の Args を全部落としていたので後退ではない(真壁の report の「写しに無い形」1)

### 4. H3 の辿り

- 循環:`reads_reached` は辿った道を `seen` で持ち、兄弟の間でも足していくので止まる。test(`read_aliases_follow_service_imports_test`)が article_read ↔ article_list の循環を見ている。菱形は 2 回辿るが `list.unique` で 1 つになる
- 順:runtime は `[record.name, ...readAliases].find(Boolean) ?? uniqueRead(name)` で先勝ち。写しの別名 12 本で owner の間の読みの名の重なりを数えると、重なりは `shift_target_public/candidate_stores` と `shift_target_list/candidate_stores` の 1 件だけで、自分の名が先に来るので 0.11.1 と同じ解決になる。規則として、直に import した名は前と同じ順で先頭に来る。辿って足した名が引くのは、0.11.1 で `unregistered read` になっていたか、`uniqueRead` で同じ entry に当たっていた名だけ。**0.11.1 で解決していた読みの行き先は変わらない**
- 回避の import 5 行を写しから消して生成し直すと、0.11.1 から変わるのは header の sha と `runtime.mjs` の `widget_read:['muse_heaven_list','link_list','widget_list']`(順だけ)。重なりが無いので順は結果に効かない

### 5. 再走

| 検収 | 結果 | 証跡(`gen/build/kashiwagi/`) |
|---|---|---|
| root `gleam build` | exit 0 | `root-build.txt` |
| `gleam format --check src test gen/src gen/test` | exit 0 | `format.txt` |
| `cd gen && gleam test` | **289 passed, no failures** | `gen-test.txt` |
| fixture ×2(`-- fixtures/article <out>`) | exit 0 / 0、`diff -r` 0 行。出力 127 file のうち tracked の 66 file と `cmp` して不一致 0 | `fx1`・`fx2`・`fx-diff.txt` |
| 写し(musearch `efd93d6e` の `git archive`、4 package の yumemi を作業木への path 依存に)の 1 手 ×2 | exit 0 / 0、4 dir・`db/queries`・3 面の `_yumemi` の `diff -r` 0 行 | `run1`・`run2`・`gen{1,2}.log`・`regen.sh` |
| 写しの commit 済みの生成物との差 | live 11 本と `runtime.mjs` の 1 行(`shift_target_public:['shift_target_list']`)だけ。`db/queries` は差 0 | `base` と `run1` |
| 写しの api `npm test`(PG 55541、`dropdb` からの新しい DB、auth を先に build) | **698 / 698**(回避の import が在るまま) | `api-1.txt` |
| H3 の回避の import 5 行を消して 1 手 → api `npm test` | 差は header の sha と `widget_read` の別名の順だけ。**698 / 698** | `run3`・`gen3.log`・`api-2.txt` |
| 3 面の `gleam build` / `gleam format --check src`(回避を消した後の生成物) | www / muses / console とも build 0・format 0。`src/gen/live` の warning は muses 6・console 4・www 0 で、全部既存の未使用の変数・引数(新しい import の未使用は 0) | `face-build-*.txt`・`face-fmt-*.txt` |
| back の GET / POST の読みの突き合わせ | 上の 3 | `probe-http.{mjs,txt}` |

PG 55541 は本ゲートで起こした(`ms/api/test/build/pgdata-public`、pid 3109274)。終端で `pg_ctl stop` し、pid が消え、`pg_isready -p 55541` が no response になったのを見た。

## P1(技術的負債、サマリに残す)

1. **同じ欄の Int / Float の綴りが、GET と POST で 200 / 400 に分かれる。**POST の live は `int.parse`(`+5`・`007` を数にする)と `float.parse` → `int.parse`(`1e3` は読めず文字列)で送る。GET の live は欄をそのまま query に載せ、back の `integerRaw`(`+5`・`007` は 400)と `queryRaw`(`1e3` を 1000)で読む。正規の綴り(`7`・`1.5`)では一致する。GET の欄を `int.parse` / `float.parse` で正規化して載せれば後の patch で返せる
2. **非 Option の Bool の欄の `""` を偽で送る。**Set していない欄が 400 にならず `false` で書かれる。0.11.1 の生成の live では 400 だった。編集系(`course_edit.popular`)で島が現在値を Set し忘れると、黙って偽に上書きされる。WGm の申し送り 3 に `""` は偽と書いてあるが、載せ替えの島は Bool の欄を必ず現在値で Set する、と WGm に明示してほしい
3. **`record_type` の判定は型の構造で見ていて、back の読み(`shape_type` の特例・hook)とは紐付いていない。**型の別名(`pub type X = mod.Record`)は辿らないので文字列で送る。app の非 opaque な 1 構成子の wrapper(`XId(value: String)` の形)は `JsonWire` になり、数字だけ・`true`・`null` の綴りの値は JSON の値に化ける。写しには該当が 0(`LedgerStoreId` / `LedgerAreaId` は別名で文字列、`PartyId` は framework の opaque、`JsonWire` は `theme` / `links` の 2 欄だけで、どちらも hook が object / 配列を読む)
4. **生成の live は app の gleam_stdlib に依る。**`uri.query_to_string` の `+` の扱いと `decode.recursive` を使う。1.0.5 で正しいのは確かめたが、yumemi の宣言する下限 `gleam_stdlib >= 0.44.0` の古い版での挙動と compile は確かめていない

## 確かめていないこと

- H1・H2 と r2 の実 API への request(真壁の report の wrangler / PG の走り)は再走していない。back の読みは `decode` 段を直に呼んで見た
- 3 面の `npm run build` / `npm test`、Workerd の門の表
- gleam_stdlib の下限の版での生成の live の compile(P1-4)

## 判定

**P0 無し。**P1 4 件(上)、P2 0 件。
