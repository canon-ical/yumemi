# yumemi-fix-0112 ── 生成器の穴 H1〜H3、版 0.11.2(真壁[IM]、2026-09-26)

基点は yumemi main `02d6739`(v0.11.1)、branch は `impl/yumemi-fix-0112`。穴は WGm(musearch-yumemi-7 `efd93d6e`)の `docs/yumemi-7/results.md` にある「生成器の穴」H1〜H3。musearch には書いていない。検収は `git archive efd93d6e` の写し(`gen/build/fix0112/ms/`)でやった。証跡は `gen/build/fix0112/` に置いた(gitignore の下なので commit には入っていない)。

## 直したもの

| # | 穴 | 直し | 場所・test |
|---|---|---|---|
| H1 | 生成の live は Bool の Args を JSON の文字列で送っていた。back が `invalid_argument` 400 を返す | live の body を Args の型で encode する。`Bool` は `json.bool` で、`"true"` / `"True"` / `"on"` を真、`"false"` / `"False"` / `""` を偽にする。`Int` は `int.parse` を通して `json.int`。`Float` は `float.parse` を通して `json.float`(整数の綴りも受ける)。読めない綴りは文字列のまま送るので、back が 400 で返す。`Option(X)` は空なら `null`、空でなければ中身を同じ規則で送る。値型(`gen/types/*`)は文字列のまま(back の `int` / `scalar` は文字列を受ける) | `emit/front.gleam` の `body_value_expression` / `json_value_expression` / `send_imports`、`yumemi_fix_0112_test.live_body_encodes_args_by_type_test` |
| H2 | GET のとき生成の transport が body を捨て、Args を query にも載せていなかった | GET では path の穴に入らない Args を `with_query(path, pairs)` で query に載せる(`uri.query_to_string` で percent-encode する)。`Option` が空なら載せない。Bool の綴りは `true` / `false` に揃える。GET の body は `json.object([])`。`transport_ffi.mjs` は変えていない(GET は今までどおり body を送らない)。back 側は framework `server/http.mjs` の decode を直した。GET / HEAD の query から来た欄だけ、`bool` を `true` / `false` の綴りで、`float` を数の綴りで読む。POST / PUT / DELETE は今までどおり body の JSON の型で読む。query の読み(`searchParams` を raw に混ぜる所)自体は元から在った | `emit/front.gleam` の `query_path_expression` / `query_pair_expression`、`framework/server/http.mjs` の `queryRaw` と `s.queryKeys`、`live_get_puts_args_in_query_test`・`transport_keeps_get_without_body_test` |
| H3 | 読みの別名が `import service/*` の先を辿らなかった | `read_aliases` を `reads_reached` にした。Service の module の `import gen/reads/<Z>` に加えて、`import service/<Y>` の先の module の `gen/reads/<Z>` も推移で辿る(辿った道は持ち回り、循環は止める)。順は直に import した名が先、辿った名が後で、重なったら先の 1 つを残す。自分の名は入れない。import の名は行頭の `import` から `[a-z0-9_/]` の範囲で取る。これで `import gen/reads/x.{..}` や alias 無しの行でも名が崩れない | `emit/runtime.gleam`、`read_aliases_follow_service_imports_test`(推移と循環) |
| 版 | ── | `gleam.toml` を 0.11.2 に、`gen/manifest.toml` の path 依存も 0.11.2 に。README の framework/server の節に 1 段落足した | ── |

公開型は変えていない。`live.Set(field, String)`・`live.State`・`transport_send` の 6 引数はそのまま。`git diff v0.11.0 -- src/framework` は 11 file とも `A` で、+1349 / 削除 0。

## 確かめたこと

| 検収 | 結果 | 証跡(`gen/build/fix0112/`) |
|---|---|---|
| root `gleam build` | exit 0 | `root-build.txt` |
| `cd gen && gleam test` | **287 passed, 0 failures**(基点 283 + 本便の 4) | `test-3.txt` |
| `gleam format --check src test gen/src gen/test` | exit 0 | ── |
| Article fixture ×2(`-- fixtures/article <out>`) | 2 回とも exit 0、`diff -r` 0 行。tracked の 66 file と `cmp` で不一致 0。fixture には GET の Args も Bool の Args も `import service/*` も無いので、生成物は変わらない | `fx-one`・`fx-two`・`fx-*.log` |
| `git diff v0.11.0 -- src/framework` | `A` 11、+1349 / -0。`src test gleam.toml` は `A` 11・`M` 1(`gleam.toml`) | ── |
| 写し(`efd93d6e` の `git archive`、4 package の yumemi を作業木への path 依存に)の 1 手 ×2(`rm -rf` 4 dir → `gleam run -m yumemi_gen -- <写し>/api <写し>`) | 2 回とも停止コード 0。4 dir・`db/queries`・3 面の `priv/static/_yumemi`・`_diagnostics.txt` の `diff -r` は 0 行。警告は 33 で、WGm の `gen7.log` と行の集合が一致 | `run1`・`run2`・`gen1.log`・`gen2.log`・`regen.sh` |
| 写しの commit 済みの生成物との差 | 変わったのは live 9 本と `runtime.mjs` の別名 1 行だけ。live は H1 の console `course_add` / `course_edit` / `roster_add` / `roster_edit`(roster の `visible` は Bool、`height` は Option(Int))と、H2 の muses `course_list` / `ledger_store_search` / `heaven_resolve` / `notification_inbox` / `heaven_embed_code`。別名は H3 で `shift_target_public:['shift_target_list']` が増えた。registry・SQL・その他は差 0 | `base-*` と `run1` の `diff -rq` |
| 写しの api `npm test`(PG 55540、`dropdb` からの新しい DB、auth を先に build) | 回避の import が在るまま:**698 / 698**(`api-1`)。回避の import を消して生成し直した後:**698 / 698 を 2 回**(`api-2`・`api-4`)。間の `api-3` は 696 / 698 で、落ちた 2 本(`compile_fail: mixed_system` / `subject_type`)はどちらも `Hex API failure: rate limit exceeded`。環境の要因で、次の回は通った | `api-{1,2,3,4}.txt` |
| 3 面の `gleam build` / `gleam format --check src`(回避を消した後の生成物、yumemi 0.11.2 の path 依存) | www / muses / console とも build 0・format 0。`src/gen/live/` に出る warning は WGm の `now-build-*` と同じ既存の未使用 Var(muses 6・console 4)で、本便で増えたものは無い | `final-build-*.txt`・`final-fmt-*.txt` |
| **H1・H2 を実 API に当てる**(写しの API を wrangler 8841 で起こし、bridge 8840 → PG 55540)。生成の live(compile した `gen/live/*.mjs`)の `init` → `Set` → `Send` の effect を lustre の `perform` で node から走らせた。fetch は wrangler に向け、cookie と host を付けた | H1 前(0.11.1 の形、`popular:"true"`)は **400** `invalid_argument` / `popular`。H1 後の live `course_add` は **200**(DB で `popular=true`、`minutes=60`)。live `course_edit` は **200**(`popular=false`、`minutes=90`)。H2 前の `GET /api/courses`(id 無し)は 200 で `ledger_store:null` と空。H2 後の live `course_list` は **200**、`/api/courses?id=<台帳>` で台帳が返り、足したコースを含む。H2 前の `ledger_stores/search`(q 無し)は **400** `invalid_argument` / `q`。H2 後の live `ledger_store_search` は **200**、`?q=fix0112%20%E5%8F%B0%E5%B8%B3%20…`(空白と日本語を percent-encode)で台帳に当たった | `ms/real/live-run.{mjs,tsv}`・`live-requests.tsv`・`launch.sh` |
| **H3 の回避を消しても通る** | 写しの `service/widget_list_mine.gleam` と `widget_read.gleam` から捨て名の import 5 行(`_link_reads` / `_heaven_reads` / `_widget_reads`)を消して生成し直した。`widget_list_mine` の別名は前後とも `['link_list','muse_heaven_list','widget_list']`。`widget_read` は `['muse_heaven_list','link_list','widget_list']` で、順だけ変わった(直に import して使っている `heaven_reads` が先に来る)。生成は ×2 で差 0。api は 698 / 698 ×2 で、`widget_list_mine` / `widget_read` / `widget_choices` / `space_read` の N2 の test も含めて通り、`unregistered read` は 0 件 | `gen3.log`〜`gen5.log`・`run3`・`api-2.txt`・`api-4.txt` |

PG 55540 は本便で起こした(`ms/api/test/build/pgdata-public`、pid 3088717)。終端で `kill 3088717` し、pid が消えて `pg_isready -p 55540` が no response になったのを見た。wrangler(8841、inspector 9641)と bridge(8840)は `ms/real/pids.txt` の pid で止め、port が空いたのを見た。

## 確かめていないこと

- back の query の `bool` / `float` の読み(`queryRaw`)を実 request で通していない。musearch には GET で Bool / Float の Args を持つ Service が無い(Bool の Args を持つのは `course_add` / `course_edit` / `roster_add` / `roster_edit` / `roster_upsert` / `store_verify` で、どれも Write)。コードを読んだのと `node --check` だけ
- `schedule_availability.course`(Option、path の穴 `id` の後ろ)は、写しに呼ぶ live が無い(`calls` に並べた島が無い)ので、生成物で確かめていない。規則は `article_list.cursor`(Option の GET)と同じで、そちらは test で見た
- 3 面の `npm run build` / `npm test`、Workerd の門の表、台本の selector は回していない
- Hex への publish、tag、push はしていない(しないことの指示どおり)
- H1・H2 の穴の外で見つけたもの(直していない):**List の Args は live でまだ `json.string` で送る**(`link_reorder` / `roster_reorder` / `space_reorder` / `widget_reorder` の `ids`)。live で呼ぶ島が出ると 400 になる。(**r2 で塞いだ**)path の穴の値(`"/api/x/" <> args.id`)は元から percent-encode していない

## WGm への申し送り

1. **0.11.2 を採ったら、H3 の捨て名の import を消してよい。**`api/src/service/widget_list_mine.gleam` の `_link_reads` / `_heaven_reads` / `_widget_reads` と、`widget_read.gleam` の `_link_reads` / `_widget_reads` の計 5 行。消すと `runtime.mjs` の `widget_read` の別名の順が `['muse_heaven_list','link_list','widget_list']` になる。api の test はこの順で 698 / 698
2. **1 手で変わるのは live 9 本と `runtime.mjs` の別名 1 行**(`shift_target_public:['shift_target_list']` が増える。`shift_target_public` が `import service/shift_target_list` を持つため)。registry は変わらない。H2 の 5 本のうち `heaven_resolve`(`page_url`)・`heaven_embed_code`(`kind` / `design` / `num` / `color` / `fontsize`)・`notification_inbox`(`after`)は、島を載せ替えていなくても、今まで GET で落としていた Args を送るようになる
3. **島が live に渡す Bool の値は `"true"` / `"false"`**(`live.Set(Popular, "true")`)。`bool.to_string` の `"True"` / `"False"` と、checkbox の既定の値 `"on"` も受ける。`""` は偽。それ以外の綴りは文字列のまま送られて 400 になる
4. **GET の島**(`store_courses` の `course_list`、`ledger_search` の `ledger_store_search`、`schedule_slot` の `schedule_availability`)は Args を `Set` すれば query に載る。`Option` の欄は `""` のとき載らない(`course_list.id` を空にすると、店の主体は自分の台帳を読む)。`Option` でない欄は空でも `q=` として載る
5. 載せ替えの残りの島で List の Args を live で送るものが出たら、上の「確かめていないこと」の List の穴に当たる。その場合は止めて鷹野宛に(**r2 で塞いだ**。下の r2 節)

## r2 ── List の Args と、同じ系統の残り(鷹野[PDM] 2026-09-26 06:2x の便)

r1 が穴の外で見つけた List の Args を塞いだ。あわせて、live が Args の型どおりに送らない形を生成器のコードで数え、写しの Service の Args にある形は全部直した。

### 直したもの

| 形 | 直し | 場所・test |
|---|---|---|
| `List(X)`(X はスカラ。値型・Id・列挙・日付・Bool / Int / Float) | live の欄は **JSON の文字列の配列**(`["a","b"]`、空の欄は `[]`)を持つ。send は `list_items` で読み、要素を H1 と同じ規則で JSON の配列にする(`List(Int)` なら数、`List(Bool)` なら真偽、それ以外は文字列)。配列として読めない綴り(`a,b,c` など)は文字列のまま送り、back が `invalid_argument` 400 で返す。`Option(List(X))` は空なら `null` | `emit/front.gleam` の `Wire`・`arg_wire`・`wire_value_expression`・`wire_helpers_text`、`live_body_encodes_list_and_record_args_test` |
| record(構成子が 1 つで欄が全部名付き、opaque でない)・組・`Dict`・スカラでない要素の `List` | back はこれらを ★ の decoder(hook)で読み、JSON の形は app が決める。live の欄は **JSON の本文**を持ち、send は `json_text` で読んで JSON の値としてそのまま送る(`decode.recursive` で `json.Json` に組み直す。FFI は足していない)。読めない綴りは文字列のまま送る | 同上 |
| 文字列のまま送るもの | 構成子が複数の sum(`Place` の `'top'` / `'all'` / id は back の hook が綴りで読む)、値型(`gen/types/*`)と framework の opaque な型(`LinkId(value: String)` の形。record の判定から外す)、列挙、日付、Cursor、Key、Blob の token | `live_body_encodes_list_and_record_args_test` の `place` / `token`、`live_without_list_has_no_wire_helpers_test` |
| fixture | `fixtures/article` の `article_create.tags: List(Key(Tag))` が該当した。島の `pick_tag` は select の値を素で Set していて、0.11.1 でも back の `list` が配列を要るので 400 だった。`tags([value])`(JSON の配列の文字列)で Set する形に直し、tracked の生成物 `public/src/gen/live/article_create.gleam` と `public/priv/static/_yumemi/client.mjs` を生成し直した | ── |
| README | framework/server の節の r1 の段落の後に、List の欄の綴りと JSON の本文の欄を 1 段落 | ── |

公開型は変えていない(`live.Set(field, String)`・`live.State`・`transport_send` の 6 引数)。`git diff v0.11.0 -- src/framework` は r1 と同じ 11 file とも `A`(+1349 / -0)で、r2 は framework を触っていない。

### 同じ系統の残りを数えた(生成器のコード)

live の Args の送り方は `arg_wire` の 4 つ(`ScalarWire` / `OptionWire` / `ListWire` / `JsonWire`)で全部。back の decode の語彙(`emit/http.gleam` の `shape_type`、`framework/server/http.mjs` の `decodeArg`)と突き合わせた。

| back の語彙 | live の送り方 | 写しの件数(Args 286 欄、130 Service) |
|---|---|---|
| `bool` / `integer` / `float` / その `option` | H1(真偽・数、空なら null) | bool 6、integer 1、option(integer) 4、float 0 |
| `list`(要素がスカラ) | r2 の `ListWire` | 4(`link_reorder` / `roster_reorder` / `space_reorder` / `widget_reorder` の `ids`) |
| `hook` で record・組の List を読む | r2 の `JsonWire` | 2(`muse_set_theme.theme: muse.PageTheme`、`link_import_apply.links: List(#(Label, PageUrl))`) |
| `hook` で文字列を読む | 文字列 | 4(`widget_list(_mine).space: Option(Place)`、`notification_notify.recipient`、`ledger_store_add.area`) |
| `scalar` / `int`(値型。`int` は数字の文字列も受ける)/ `enum` / `date` / `datetime` / `time` / `cursor` / `key` / `blob` / `text` と、その `option` | 文字列(元から合っている) | 残り全部 |

**写しに無い形(名指し。直していない):**

1. **GET の List / record / Dict の Args。**query には欄の文字列(`["a","b"]` や `{…}`)がそのまま 1 つの値として載り、back の `list` は配列を要るので 400 になる。写しの GET の Args はスカラ・列挙・`Option`・文字列を読む hook だけで、該当 0。query の形(同じ名を繰り返すか、JSON を 1 つ載せるか)は、出たときに back の query の読み(`searchParams` を raw に混ぜる所)と一緒に決める
2. **`Dict` の Args** は `JsonWire` で送るが、back の語彙に `dict` が無いので hook が要る。写しに 0
3. **文字列でない JSON を読む hook で、型が record でないもの**(構成子が複数の sum を object で読む hook など)。live は文字列で送るので hook が 400 を返す。写しに 0(`Place` の hook は文字列を読む)
4. **`Option(Bool)` / `Option(Float)`** は H1 の規則で送る(test は `Option(Int)` と `Option(List(Bool))` で見た)。写しに 0

### 確かめたこと

| 検収 | 結果 | 証跡(`gen/build/fix0112/`) |
|---|---|---|
| root `gleam build` | exit 0 | `r2-root-build.txt` |
| `cd gen && gleam test` | **289 passed, 0 failures**(r1 の 287 + r2 の 2)。fixture の client の build と esbuild も PASS | `r2-test-4.txt` |
| `gleam format --check src test gen/src gen/test` | exit 0 | ── |
| Article fixture ×2 | 2 回とも exit 0、`diff -r` 0 行。r1 の `fx-one` との差は `article_create` の live と `client.mjs` の 2 file だけ(`tags` が `list_items` を通る)。tracked 66 file は生成し直した 2 file を入れて `cmp` 不一致 0。record の判定を締めた後(`fx-r2c`)も差 0 | `fx-r2a`・`fx-r2b`・`fx-r2c` |
| `git diff v0.11.0 -- src/framework` | `A` 11、+1349 / -0 | ── |
| 写しの 1 手 ×2 | 2 回とも停止コード 0、4 dir・`db/queries`・3 面の static・`_diagnostics.txt` の `diff -r` 0 行、警告 33(r1 と同じ行の集合)。r1 の最終(`run3`)との差は `muses/src/gen/live/muse_set_theme.gleam` と `link_import_apply.gleam` の 2 本だけ(`theme` / `links` が `json_text` を通る、`import gleam/dict`)。record の判定を締めた後(`run7`)も `run6` と差 0 | `run4`・`run5`・`run6`・`run7`・`gen6.log`〜`gen10.log` |
| 写しの api `npm test`(PG 55540、`dropdb` からの新しい DB、auth を先に build) | **698 / 698** | `api-5.txt` |
| 3 面の `gleam build` / `gleam format --check src` | www / muses / console とも build 0・format 0。muses の warning 8・console 6 は r1 の `final-build-*` と同数 | `r2-build-*.txt`・`r2-fmt-*.txt` |
| **reorder を実 API で 1 本**(写しの API を wrangler 8841、bridge 8840 → PG 55540)。reorder を呼ぶ島が写しに無いので、console に `calls = [service.RosterReorder]` だけの probe の島(`r2_probe.gleam`、写しの中だけ)を置いて live を生成し、node で `init` → `Set(Ids, JSON の配列の文字列)` → `Send` の effect を走らせた | 前(r1 までの形、`ids` を文字列で)は **400** `invalid_argument` / `ids`。後の live `roster_reorder` は **200**、body は `{"ids":["…","…","…"]}`、DB の順が 0,1,2 → 指示どおり 2,0,1。配列でない綴り(`a,b,c`)は **400** `invalid_argument` / `ids`。probe を消して生成し直し、`run5` と差 0 に戻した | `ms/real/r2-run.{mjs,out,tsv}`・`r2-requests.tsv` |
| **record を実 API で 1 本**(同じ stack、`support.mjs` の `onboard` の muse) | 前(`theme` を JSON の文字列で)は **400** `invalid_argument` / `theme`。後の live `muse_set_theme`(`Set(Theme, "{\"background\":\"#112233\",\"accent\":\"#445566\"}")`)は **200**、DB の `app.muse.theme` に `background` / `accent` が入った | 同上 |

roster_reorder は `requires [Use]` なので、店の identity に利用の同意(`/api/consents/give`)を先に通した(1 回目は同意が無く 403 `consent_missing` で、body の配列は decode を通っていた)。PG 55540 は本便で起こした(pid 3100031)、wrangler(3101585)と bridge(3101584)は `ms/real/pids.txt` の pid で止め、終端で `kill` して 4 port(55540 / 8840 / 8841 / 9641)が空き、`pg_isready -p 55540` が no response になったのを見た。

### 確かめていないこと

- `link_import_apply.links`(`List(#(Label, PageUrl))`、hook は `[{label,url}]` を読む)は実 request で通していない。生成物が `json_text(args.links)` になったのと、同じ `JsonWire` の theme が 200 になったところまで
- `link_reorder` / `space_reorder` / `widget_reorder` の live は写しでは生成されない(呼ぶ島が無い)。規則は同じ `ListWire` で、roster_reorder を実 API で見た
- GET の List / record(写しに無い、上の 1)、back の query の bool / float(r1 から変わらず)
- 3 面の `npm run build` / `npm test`、Hex への publish、tag、push はしていない

### WGm への申し送り(r2)

1. **List の Args の島は、欄を JSON の文字列の配列で Set する。**`live.Set(Ids, json.array(ids, json.string) |> json.to_string)`。空の配列は `"[]"` か `""`。`a,b,c` のような綴りは 400
2. **record・組の List の Args の島は、欄を back の hook が読む JSON の本文で Set する。**`muse_set_theme` は `{"background":…,"background_image":…,"text":…,"accent":…}`(無い欄は省くか null)、`link_import_apply` は `[{"label":…,"url":…}, …]`
3. 0.11.2 で 1 手をかけると、r1 の 9 本と別名 1 行に加えて `muse_set_theme` / `link_import_apply` の live 2 本が変わる(島を載せ替えていなければ、今の手書きの島には影響しない)
