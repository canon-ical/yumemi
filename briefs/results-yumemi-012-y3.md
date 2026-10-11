# results ── yumemi-012-y3(0.12 段 C、interactive Component を form と custom state に移して lustre を外す、名前付きの逃げ道、lock の照合、段 B の継ぎ目と柏木の P1、真壁 r1)

基点 `e57bcf2`(段 B の merge 後の main)。branch `impl/012-y3`。証跡は `build/012-y3-*`(git の外)。版の行(`0.12.0-dev`)は触っていない。

## やったこと

1. **宣言と view**(`src/yumemi/front/live.gleam`)。`After(ok, error)`・`Then`(`Stay`・`ReloadPage(notice)`・`GoTo(route, notice)`)・`Reloads(read, on)`。State・Event・given は消した。生成物だけが呼ぶ `@internal` の口(`bind`・`bind_check`・`bind_choice`・`bind_file`・`when`・`out`・`send`・`component`・`json_string`・`json_object`・`Constraint`)を同じ module に置き、★ が呼べば第 3 条で止まる(`reader/front.gleam` の `is_internal_reference` に足した)
2. **生成物**(`emit/front.gleam` の interactive Component の群を書き直し、旧い `live_targets`〜`spec_*`・`transport_text`・`client_components`・`component_has_app`・`client_notes`・`client_registration` を消した)
   - Service ごと(と attached の `Entry` ごと)の live module:`Args`(欄は全部 String)・`Field`・`Error`・`When`(`Idle`・`Waiting`・`Succeeded`・`Failed`・`Refused(Error)`)・`Slot`(Out の List でない欄、構成子は `Out<欄>`)と `bind`・`bind_check`・`bind_choice`・`bind_file`・`when`・`out`・`send`、`@internal args_json`。lustre・gleam_json・transport_ffi を使わない
   - `src/gen/interactive.gleam`(`gen/islands` を改名、SSR の印 `data-yumemi-island` は残す)。Component ごとに `calls` の順の Args と、view が受けるなら `with` を取り、タグの中に `<form><fieldset>` と view を描く。`data-yumemi-args` は Service の名を鍵にした初期値の JSON
   - `src/gen/route.gleam` に Page の閉じた enum `Route`(`Root`・`ArticleArgSlug` の形)と `PageRoute(route, path)`
   - `src/gen/escapes.gleam`(`src/escapes/*.mjs` ごとに `<yumemi-escape name>` を出す関数)
   - `src/gen/media.gleam` に `src(blob, variant) -> el.Src`
   - 送りのボタンは `<button type="submit" formnovalidate data-yumemi-send="<service>">`。`formaction` は出さない
   - `when` の枝を隠す規則(Service ごとに idle / waiting / succeeded / failed / refused-<code>)を `@supports selector(:state(x))` の中(`:state()`)と `@supports not ..` の中(`[data-yumemi-state~=..]`)の 2 通りで、`_yumemi/style.css` と殻の頁の `<style>` に出す。fieldset の枠を消す 1 行と `[data-yumemi-when] { display: contents }` も
3. **SSR と runtime**(新しい `src/yumemi/front/interactive.mjs`、460 行)。`client.mjs` は runtime を import して Component の表(タグ → Service ごとの method・path・Args の型・`refused` の code・Slot の道・After、`reloads`)と逃げ道の `mount` を渡し、navigate の `go` / `reload` を渡す。タグごとに共通の class を継ぐ空の subclass を define。submit(submitter の Service・その Service の control だけの制約検証・暗黙の送信で focus の control の Service と違えば捨てる・送りの間は fieldset と `aria-busy`)、Args の組み立て(初期値に control の値を重ね、0.11.2 の送り方で JSON、GET は穴の外を query)、Blob の欄は選んだ file を `/api/blobs` に上げて key を入れる、Done(`ok` / `error` / `refused-<code>`・`sent-<service>`、out の textContent)、After(`ReloadPage` / `GoTo` は navigate を通り、文言は sessionStorage の 1 鍵から `el.notice` へ 1 回)、`reloads`(単一の値は前の読みを中断して out に、一覧は query を替えて replace・scroll と focus を保つ)、`:state()` の無い browser は `data-yumemi-state`、invoker commands の無い browser の dialog の代わり、`yumemi-escape` の mount / unmount。lustre は client に入らない(生成した `client.mjs` に `lustre` の字 0)
4. **名前付きの逃げ道**。`src/escapes/<name>.mjs` → `gen/escapes` と `yumemi-escape`。interactive Component の中にも置ける。数えは面ごとに 1 行:`[exit 0 警告] <面>: 逃げ道 ── escape <種> 種 <か所> か所(うち interactive Component の中 <n>)、生の CSS <n> file <n> 規則、数える口の送り先 ToService <n>`(`_diagnostics.txt` にも同じ行)。`reader/cms.gleam` の `ToService` の警告の Note は消してこの行に移した(条文の Note は触っていない)
5. **生成器が止めるもの**(51 v6 の停止コードどおり)── 第 4 条(★ の `@external`、4)・第 5 条(`src/escapes/` の外の `.mjs`、4)・第 6 条(名の形 4、`mount` が無い 3)・第 9〜22 条(下の「条文の止まり方」)・第 26 条(Shell の色が literal でないとき 3 → 4)・第 28〜31 条(抜け道を閉じた、下)・第 41 条(lock)・第 43 条(`el.static_src` の literal 4 と file 3)。第 18 条は Component のタグ名と `Route` の variant 名の重なりも
6. **lock の照合(第 41 条)**(`gen.gleam` の `lock_notes`、`gen_ffi.mjs` の `locked_yumemi`・`running_yumemi`)。走っている版は、yumemi の root で走るなら root の `gleam.toml`、依存として走るなら起こした package の `manifest.toml` の yumemi の行。照合するのは app の dir と、生成器が見つけた面の package だけ(`manifest.toml` の無い package は見ない)。auth のような生成器の触らない package は渡さないので照合の外
7. **段 B の継ぎ目 6 つ**:1(`el.Src`・`el.static_src`・`gen/media.src`、`el.img(class, src, alt, attrs)`、属性の列の `attr.src` は Src に負ける)、2(地の画像の URL は `gen/media` の `media.url(value, media.theme_background)`。fixture article の public の app の `media.gleam` は外し、back の `server.gleam` に media を宣言)、4(数えの 1 行)、5(navigate の `boot` の呼び出しと given の差し替えの条件を外した)、6(lustre・sketch_lustre を依存から外し、`is_legacy_component`・例外の数の行・`el.legacy_island`・`sketch_css.class`・shadow root・`island_style.mjs` を消した。class 名は sketch の Style を CSS の字にし、その字(class 名を伏せたもの)の FNV-1a の hash で作る ── 構成子の名に依らない)、7(`el.dialog` の 3 つ、`el.notice`)。3(route の照合の共有)は BRIEF どおり入れていない
8. **段 A からの申し送り**。`gen/scripts` の 3 file は消した(`y1e-prepare-f5.mjs`:段 A の前の Y1e の F5 の一度きりの道具で旧 ffi の名を import、`verify-decode-roundtrip.mjs`:v0.9.0 の `gen/` package と比べる道具で比べる先が今は無い、`verify-route-table.sh`:`yumemi/gen` で起こす形に直して回したが、写しの scratch が生成物の `entry` の import を解けず基点の前から壊れていた。route 表は root の `article_http_route_table_has_twelve_rows_test` が同じことを見るので `route-table-scratch.gleam.toml` と一緒に消した)。queue の consumer の基は、積む Service の root の Entity が食い違えば止める(`emit/back.gleam` の `consumer_roots_conflict`、exit 4、★ の宣言は増やしていない)
9. **上げ口と file の control**。`calls` は `Target`(`Of`・`Entry`)のまま、`pub const target` は読まない(`calls` に畳む)。Blob の欄は `bind_file`。上げ口 `BlobCopy` の live は `Args(file, from)`:file を選んでいれば本文に file、無ければ `{from}`(0.11.4 の `copy_from`)、戻りの key は `OutKey`。attached の口は Service でないので `after_send` の組を持てない(戻りの後は Stay)
10. **fixture と README**。article の public の Component を新しい形に(`like_button`・`pick_tag`(`with`・`ReloadPage` の文言)・`blob_save`(`bind_file`)・`article_blob_copy`(`Entry`))、足したもの:`article_manage`(送り 2 つ、dialog の中の送り、`GoTo` の文言、Component の中の逃げ道)・`title_lookup`(`reloads` の単一の値。読みの Service `article_title` を back に足した)・`tag_filter`(`reloads` の一覧、Layout の Feed に置く `widget_list`)・`src/escapes/clock.mjs`。site_header に `el.notice`、status の頁に `Var("widget", Query("widget"))`。cms も生成し直した。README に「Interactive Components (0.12)」「Named escapes (0.12)」と lock の段を足し、要素・生の CSS・Shell・遷移・Style の節と 0.11.4 の注を現物に直した
11. **遷移の柏木の P1 2 つ**(`navigate.mjs`、下の「鷹野に返す点」4)
12. **逃げ道の数えの抜け道**:pipe(`"a.css" |> el.static_sheet` は literal として読み数える、変数の pipe と関数参照は第 31 条)、実行時の柵(`//`・`\`・`:`・`..` の段を含む path は何も指さない `/`)、第 29 条(CSS の escape を解き、括弧の中の空白を詰め、at-rule の前置きも見る、`[class…css…]`)、同じ file を 2 か所で読んでも 1 file
13. **★ の検査の外と停止コード**:`source.load` は `src/gen/` の file のうち 1 行目が `//// GENERATED` のものだけを外す(手で置いた file は ★ として第 1 条ほかに掛かる)。第 26 条の literal でない色は 4

## 検収

### test(before / after)

| | before(`e57bcf2`) | after |
|---|---|---|
| root `gleam test` | 388 本 | **417 本、失敗 0**(`build/012-y3-test13.txt`) |
| `gleam format --check src test` | 0 | 0 |

足した test は `test/yumemi_012_y3_test.gleam` の 29 本。1 本を差し替えた(`legacy_island_drops_bad_tags_and_arguments_test` → `static_sheet_refuses_outside_paths_test`、`el.legacy_island` が消えたため。本数は同じ)。

期待値を書き換えた test と理由(本文の注にも書いた):

| test | 理由 |
|---|---|
| gate `client_registers_every_app_component_and_flags_missing_app_test` | lustre の登録が無くなり、`pub fn app` は第 9 条・0.11 の view は第 11 条で止まる(0.11.15 の「app() が無ければ exit 3」は逆) |
| gate `attached_entry_live_sends_blob_fields_test` | transport_ffi が無くなり、attached の live は Service と同じ形 |
| y2 `unsafe_url_schemes_are_not_rendered_test` | `el.img` の引数が `(class, src, alt, attrs)` に |
| y2 `article_1_..`・`article_2_..` | 第 1・2 条の例外が無くなった |
| y2 `fixture_surface_counts_rules_once_per_face_test`(と helper が逃げ道の JS を写す) | 数えの 1 行 |
| y4 `navigation_goes_through_navigation_api_test`(start_check) | `boot` を外し、止まった取りの 2 通りを足して 18 → 19 行 |
| y5 `to_service_is_counted_as_escape_with_warning_test` | ToService の数は数えの 1 行に |
| fix_0112 の 4 本 | Args の送り方は runtime の表の型(wire)に移った。runtime の振る舞いは y3 `runtime_wire_encodes_args_by_type_test` |
| fix_0113 の 2 本 | 202 は runtime が成功として読み、表に `"accepted"` |
| fix_0114 の 9 本(H5・H6・H8・H9・r2) | live の update / request・`copy_from`・島の `styled`・`boot`・`yumemi-done` が無くなった。H8 は class 名が構成子の名に依らないことを見る 8 件に替えた |
| gen の数の 6 本(route 表 12 → 13、Service 7 → 8、out 7 → 8、unit 16 → 17、root の矢印 +2、reads +1) | fixture に読みの Service `article_title` を足した |
| gen の front の 17 本(`front_emit_*`・`front_model_*`・`front_calls_*`・`direct_attribute_*`・`lustre_internal_*`・`nested_island_*`・`service_variant_*`・`front_emit_blob_theme_*`) | live module・client・route・地の画像の URL の形が替わった。`components/` の module は第 10・11 条にも掛かるので第 1 条の 1 つを選んで見る |
| gen `a_clean_app_has_no_notes_test`(helper `without_stage_b_counts`) | 数えの 1 行を外して見る |
| look の 3 本(yumemi_test) | 島の shadow の `<style>` が無くなり、Component の Style は頁の `<style>` |

### fixture の生成

- article:`gleam run -m yumemi/gen -- gen/fixtures/article gen/fixtures/article` 停止コード 0、警告は数えの 1 行だけ。`git add` の後にもう 1 回で停止コード 0・差 0(`build/012-y3-gen10.txt`・`-gen11.txt`)
- cms:停止コード 0、2 回目 0・差 0(`build/012-y3-gen-cms{1,2}.txt`)
- 途中で 1 回 Hex の rate limit(`client Out decoder 用 Gleam build に失敗`、exit 1)、間を置いて回し直した(`build/012-y3-gen3.txt`)

### 条文の止まり方(`test/yumemi_012_y3_test.gleam`)

1 条ずつ、止まる形と停止コード:第 4(`@external`、4)・第 5(`src/helper.mjs`、4)・第 6(`Bad-Name.mjs` 4、`mount` 無し 3)・第 9(4)・第 10(重なり・空、4)・第 11(順の違う Args・`with` の名、4)・第 12(書きの組が無い 3、読みの組 4)・第 13(1 要素に bind 2 つ・Field が変数、4)・第 14(4)・第 15(Out に穴の欄が無い 4、ある形は止まらない)・第 16(Layout に `el.notice` が無い、3)・第 17(read が calls に無い・書き・on が空、一覧の読みで Page に Query の Var が無い、4)・第 18(タグ名、4)・第 19(4)・第 20(書きに send 無し 3、一覧の読みに send 4)・第 21(4)・第 22(`el.Element`・live の型の List、4)・第 26(定数を参照した色、4)・第 29(7 つの書き方)・第 31(変数の pipe・関数参照、4。literal の pipe は数え、止まらない)・第 41(4、照合の外は止めない)・第 43(literal でない 4、file が無い 3)。正しい形の Component と fixture の 7 本は止まらない。手で置いた `src/gen/hand.gleam` の lustre の import は第 1 条で止まり、`//// GENERATED` の file は外れる

### Chromium(fixture の public の頁、`build/012-y3-chromium*.txt`、台 `build/012-y3-interactive-checks.mjs`)

SSR の頁(`build/012-y3-render-pages.mjs` で sample を描いた文書)に `_yumemi/style.css` と束ねた `client.mjs` を足し、台の server が API を模す。Chromium 153。

- **既定 37/37・`:state()` の無い browser 37/37・`commandForElement` の無い browser 38/38・client を minify 37/37**
- 送りの成功(out に Out の欄、成功の枝)・失敗(500)・Refused(409 `already_published` で `refused-already-published` の枝と失敗の枝)、送りの間の `aria-busy` と fieldset、POST は 1 回で Args は `data-yumemi-args` の初期値
- 送り 2 つ:押していない送りの `required` で止まらない、押した送りの `required` では止まる、別の送りの control で Enter しても最初の送りは走らない、自分の control の Enter は送る、別の送りの失敗の枝は出ない
- dialog の開け閉めと中の送り(`article_create` を 1 回)
- `reloads` の単一の値:読みの間 fieldset を止めない、後の読みの戻りが入り、遅い前の読みは捨てる。一覧:`?widget=other` へ移り、履歴の数が同じ、scroll が同じ、focus が同じ name の control
- `ReloadPage` の文言が `el.notice` に出て、読み込み直すと出ない。`GoTo` は Out の `slug` で `/article/moved` へ移り文言が出る
- 逃げ道が 2 つとも mount、client の遷移で前の頁の分が unmount し来た頁で mount。移った先の Component が起き、送りは 1 回
- shadow root 0、JS の `<style>` 0(SSR の 1 本)、Component の中の class が全部文書の規則に当たる。console の error 0(台が返す 4xx / 5xx の読み込みの error は除く)
- `:state()` の無い browser は、init script で `ElementInternals.states` を消し、CSS の `@supports selector(:state(x))` を偽にする写し(Chromium の CSS は `:state()` を持つので選択子の名を替えた)で、属性の側の規則だけで同じ結果
- `commandForElement` の無い browser では、runtime の代わりが JS の `showModal` / `close` を 1 回ずつ呼んだ(Chromium の invoker commands は JS の口を通らないので、呼ばれた数で代わりを見た)

### 遷移の 2 つ

- **取得の最中の競合**(Y4 柏木の台を写した `build/012-y3-k-harness-race.mjs`、結果 `build/012-y3-k-race-after.json`):`#s` を押す・`replaceState` の 2 通りとも、終わりの URL `/slow#s`・`/slow?tab=2` で中身 `SLOW`。基点は Y4 の `012-y4-k-race-before.json`(どちらも中身 `A` のまま)
- **pushState の後に戻る**(`build/012-y3-k-harness-push.mjs`、`build/012-y3-k-push-{after,before}.json`):同じ path に pushState して戻ると、after は取り直し 0・input の状態 `typed` が残る・送り手の POST 3 件(初期・`/b`・`/a` へ戻る)。before(基点の navigate.mjs)は `/a` を取り直し・状態が消え・POST 4 件(余分な `spa` 1)。別の頁へ client の遷移で行って戻るのは両方とも取り直す

### class 名

- 同じ article の頁を node(gleam の build)・esbuild の bundle・minify の bundle で描き、文書の md5 が 3 つとも同じ(`build/012-y3-ssr-{node,bundle,bundle--minify}.html`)。Y2 は同じ形で 4 通りの名を測った
- runtime の test(fix_0114 の H8)で、構成子の JS の名を替えても同じ class 名

### Hex の tarball

`gleam export hex-tarball` の `metadata.config` の requirements は argv・gleam_stdlib・glexer・glance・sketch・simplifile の 6 つ。lustre・sketch_lustre は無い(`build/012-y3-hex.txt`)。root の `manifest.toml` の `lustre` 0 件。

### musearch の写しで数えた件数(`build/012-y3-ms-gen1.txt`・`-ms-count.txt`)

origin/main `80e3102d0`(BRIEF の書かれた後に進んでいた)を `git archive` で `.scratch/musearch` に、Y1 の名前の置き換え(2266 file)、Y5 の宣言の書き換え(`yumemi-012-y5/build/012-y5-ms-star.diff` を `patch -p2`、fuzz 1 が 1 hunk、失敗 0)、5 package の yumemi を本作業木への path 依存、面の node_modules は手元の musearch への symlink。api から `gleam run -m yumemi/gen -- . ..`:停止コード 4(期待どおり)、`[exit` の行 2047(4:1715・3:286・0:44・1:2)。写しは捨てた。

| 条 | 件数(admin / console / muses / www) |
|---|---|
| 第 1 条(lustre の import) | 1111(110 / 141 / 524 / 336) |
| 第 2 条 | 4(各面 1) |
| 第 4 条(`@external`) | 149(— / 8 / 83 / 58)── 77 の 149 と同じ |
| 第 5 条(逃げ道に移る FFI の `.mjs`) | **47 file**(— / 8 / 23 / 16)── 77 の 47 file と同じ |
| 第 9 条(`pub fn app`) | 129(13 / 17 / 67 / 32) |
| 第 10 条 | 28(2 / 2 / 12 / 12)── `calls = []` ほか |
| 第 11 条 | 102(11 / 15 / 55 / 21) |
| 第 12 条 | 245(24 / 35 / 141 / 45) |
| 第 19 条 | 7(1 / — / 5 / 1) |
| 第 20 条 | 151(12 / 18 / 95 / 26) |
| 第 27 条 | 7(www) |
| 第 28 条 | 7(— / 3 / 3 / 1) |
| 第 29 条 | 8(www) |
| 第 41 条 | 4(各面 1)── 面の `manifest.toml` が 0.11.15 を lock したまま(api は `gleam run` で lock が替わった)。段 D で各面 `gleam update yumemi` |

逃げ道の 1 行:www `escape 0 種 0 か所、生の CSS 4 file 34 規則、ToService 1`、muses・console `生の CSS 3 file 0 規則`(file が無い第 28 条の分)。exit 1 の 2 行は muses・www の client の build が path 依存の yumemi の `simplifile` を解けない(面の manifest が古いまま)ため。面の `@external` を持つ `.gleam` は 67 file(段 D の逃げ道への移しの量の目安)。

## BRIEF・51 v6 との食い違いと選んだこと

- **Slot の構成子は `Out<欄>`**(51 v6 の例は `Slot { Id Opened }`)。Field と Out に同じ名の欄(`slug`)があると同じ module の構成子が重なり compile しない。重なるときだけ前置きすると、Args に欄を足しただけで ★ の Slot の名が替わるので、常に `Out` を前置きした
- **`when` は `<div data-yumemi-when>` で包み、`display: contents`**。枝を隠す規則は隠す側で書くので ★ の class の `display` と当たらない
- **`bind_file` を live module に足した**(51 v6 の一覧に無い)。Blob の欄の file の control の口
- **attached の `Entry` は `after_send` の組を持てない**(`after_send` の型が `List(#(service.Service, ..))` で `api.Attached` を入れられない)。戻りの後は Stay として第 12 条の外
- **`Error` の variant が無い Service の live は `pub type Error`(構成子 0)**。`Refused(Error)` は作れない
- **第 17 条の一覧の形**:Component を置く Block は `gen/interactive.<名>(..)` を呼ぶ Block。Layout の Block は全 Page に載るとし、Page の Var と Layout の Var を合わせて見る。合わせて、Page の Var の「未使用」の警告(`[変数 0]`)が Layout の置き場の使う Var も数えるようにした(Layout の Widget は Page の Var を受けるのに、警告は Page の置き場だけを見ていた)
- **第 22 条**は同じ module の import で型を解き、別の module の record の中までは辿らない(51 v6 確認できなかったこと 16 のまま)
- **第 29 条の `[class…]`**は値に `css` を含めば止める(`[class*="csstuff"]` も止まる、狭めていない)
- **数えの「種」**は面の `src/escapes/*.mjs` の数(名の形の正しいもの)、「か所」は ★ の module の中の `gen/escapes` の関数の参照の数(呼ばない参照も 1 か所)
- **runtime の移動**:`navigate.mjs` に `go(href, {replace, keep})` を足し、印(`info.yumemi = "go"`)の付いた navigate を利用者の push と同じく取る。`reloads` の一覧は `history: "replace"`・`scroll: "manual"`・`focusReset: "manual"` で、差し替えの後に同じタグの同じ name の control へ focus
- **given の殻の表**:`shell_runtime_text` は Y6 の持ち場なので触らず、`shell_given_rows` を空にした(殻の runtime の givens の回る所は空の表を回すだけ。Y6 の merge の後に消せる)
- **地の画像の URL**:back に media の宣言が無い app は key のまま(URL を組めない)。fixture article に media を宣言した
- **`css.class([])`(空)は class を出さない**(sketch の時と同じ。hash の名にしない)
- `PageRoute` は `PageRoute(route, path)` に替えた(51 v6 の形。生成物を読む ★ は今 0)

## 鷹野に返す点

1. **上げ口と file の control**:51 v6 に足す行の案 ── 「live module は `bind_file(field)` を持ち、Blob の欄は file の control。runtime が送る前に `/api/blobs` へ上げて key を Args に入れる」「attached の `Entry` は `calls` に並べられるが `after_send` の組を持たない(戻りの後は Stay)」「`BlobCopy` の live は `Args(file, from)`」
2. **止め線**:止め線の前に閉じた(残りは下の「確かめていないこと」)
3. **継ぎ目 3(route の照合の共有)**は入れていない
4. **interactive Component の pushState の決め方**:**口を持たない。** runtime は history を積まない(After の `GoTo` は push、`reloads` の一覧は replace で、どちらも navigate の `go` を通る client の遷移)。逃げ道の JS が `history.pushState` した entry へ戻る / 進むのは、navigate.mjs が entry の key ごとに「どの差し替えの中身か」を覚え、今の中身と同じなら取らずに browser に任せる ── 頁を取り直さず、Component の状態が残り、送り手は `navigation.transition` が null なので数えない(Y5 の送り手の振る舞いはそのまま)。README の遷移の節に書いた
5. **queue の consumer の基**:積む Service の root の Entity が揃っていれば名前順の先頭の root の 1 文を借りる。Entity が同じで root の 1 文の引数が違う Service が 2 本あると、名前順で選んだ方の 1 文で読む(m012-api の形は Entity が違ったので止まる)。そこまで縛るなら consumer に root の 1 文を持たせる宣言が要る

## 確かめていないこと

- workerd の上の SSR。node・esbuild の bundle・minify の bundle で文書が同じことは見た(class 名は CSS の字の hash なので bundler に依らない、という構造からの推測を含む)
- 実機の iOS(`:state()` の無い Safari、invoker commands の無い Safari)。Chromium で JS の口と CSS の `@supports` を消した写しだけ
- 暗黙の送信の `submitter` が Chromium 以外で form の最初の送りのボタンになること(51 v6 確認できなかったこと 15)
- 閉じた `dialog` の中の送りのボタンが暗黙の送信の `submitter` になるときの振る舞い
- 一覧の `reloads` で、Navigation API の無い browser の頁の読み込みの後に focus が戻ること(戻らない、頁の読み込み)
- musearch の写しの compile と test(段 D)。止まる件数だけ
- `bind` の `pattern` は JS の正規表現の `v` の旗で読まれる。Spec の正規表現が `v` で無効なら browser は検査しない(server の `invalid_argument` に任せる)。musearch の Spec を全部当ててはいない
- 第 17 条の一覧の形で、Component を置く Block が `gen/interactive` を別名で import する形(`import gen/interactive as x`)は見ている、関数を値として渡す形は見ていない

## DDL

無し(fixture article に足した `db/queries/article_title/root.sql` は読みの 1 文で、表は変えない)

## r2(柏木の P1 5 件と P2 2 件、真壁 Opus 直書き)

基点 `b52fdcd`(r1 `483b5a4` の上に柏木の直し 4 件)。branch `impl/012-y3`。main は merge していない。証跡は `build/012-y3-r2-*`(git の外)。

### やったこと

1. **P1-1 第 21 条の連鎖の抜け**(両方で閉じた)
   - runtime(`interactive.mjs` の `yumemiDone`):`out` の span が `option`・`select`・`textarea`・`datalist` の中(`closest`)なら書かない。生成器の検査の書き方に依らない柵
   - 生成器(`reader/front.gleam` の `out_in_control`):`html.option`・`select`・`textarea`(と `_` 付き)の呼び出し・capture(`[o] |> html.option_([], _)`)・pipe の中に、live の `out` の参照(pipe の `publish.OutSlug |> publish.out` も)、`out` を含む値を束ねた変数(関数ごとに `let`・`use`・`case` の束ねを不動点まで、入れ子の Block と fn も)、`out` に届く同じ module の関数(呼び合いも不動点まで)が現れたら止める(4)
2. **P1-2 第 22 条の 3 形**(`forbidden_with_type` を module を持って解く形に):unqualified の型の import(`el.{type Element}`・`{type Element as Node}`)、同じ module の custom type の欄(`List(Item)` と `Item(icon: el.Element)`、循環は 1 度だけ)、型の別名(`pub type Icon = el.Element`・`pub type Next = List(create.Args)`)。読みは Component の読みの時に `with_forbidden` として畳む(`aliases` を引く `component_import` は消した)
3. **P1-3 Args の初期値は型付き**(下の「P1-3 の型の形」)
4. **P1-4 error 側の `GoTo`**(`emit/front.gleam` の第 15 条):`after_send` の `error:` が穴のある route の `GoTo` なら止める(4)。runtime も失敗の時は穴を埋めない(`follow` に Out を渡さない)
5. **P1-5 一覧の `reloads` は数えない**:runtime は一覧の取り直しで `go(href, {replace: true, keep, count: false})`。`navigate.go` は `count: false` を navigate の `info` に載せ(`{yumemi: "go", keep, count: false}`)、送り手(`pageview.mjs`)は navigate の `info.count === false` を数えない。頁の読み込みに落ちたとき(route 表に無い・取れない・Navigation API が無い)のために、`go` は sessionStorage の `yumemi:uncounted` に `{href, at}` を置き、送り手は頁の読み込みで今の URL と 10 秒の内なら 1 回だけ数えず印を消す(client 遷移の成功でも消す)。README の遷移の節に 1 項
6. **P2**:(a) `live.when` の包みを `<span>`(CSS の `[data-yumemi-when] { display: contents }` は r1 のまま、`:state()` の隠す規則は属性の選択子なので要素名に依らない)。(b) 第 18 条で `yumemi-` で始まるタグを止める(4)
7. fixture article:`blocks/article.gleam` の `tags: "[\"fixture\"]"` → `tags: ["fixture"]`・`tags: "[]"` → `tags: []`・`existing: "stored-optional-key"` → `existing: Some("stored-optional-key")`、`blocks/feed.gleam` の `widget_list_live.Args(widget: "", slug: "")` → `(widget: None, slug: None)`。README の Interactive Components の節(Args は型付き・第 22 条の 3 形・error 側の GoTo・第 21 条の辿り・`yumemi-` のタグ・when の span)と遷移の節

### P1-3 の型の形(鷹野に返す点)

live module の `Args` の欄の型は、その Service の Args の欄の wire の形の Gleam の型:`Bool`・`Int`・`Float` はそのまま、`Option(x)`・`List(x)` もそのまま(`gleam/option` を import)、それ以外のスカラ(値型・Id・列挙・日付)は `String`(back が文字列で読む、`gen/out` の値型が `String` の別名なのと同じ)。字への写しは生成物の `args_json` が `live.json_bool`・`json_int`・`json_float`・`json_string`・`json_option(value, encode)`・`json_list(values, encode)`(どれも `@internal`、★ が呼べば第 3 条)で持つ。runtime の表の型(wire)は r1 のままで、型付きの JSON の値もそのまま送る(`wireValue` は配列・真偽・数・null を受ける)。

★ の 1 例(fixture の Block):

```gleam
interactive.pick_tag(
  article_create.Args(slug: "article", title: "本日の記事", body: "..", category: "news", tags: ["fixture"]),
  pick_tag.With(choices: ["fixture", "gleam", "cloudflare"], selected: "fixture"),
)
interactive.blob_save(article_blob_save.Args(slug: it.article.slug, blob: "stored-image-key", existing: Some("stored-optional-key")))
```

生成物(`gen/live/article_create.gleam`):`Args(slug: String, title: String, body: String, category: String, tags: List(String))`、`#("tags", live.json_list(args.tags, live.json_string))`。SSR の `data-yumemi-args` は `"tags":["fixture"]`・`"existing":"stored-optional-key"`・`"widget":null`。

**record・組・Dict・スカラでない要素の List の欄**(wire が `json`)は型で書く形が無いので、その Service を `calls` に置くと止める(4、第 11 条)。後で record の写しと encoder を足せば緩められる(★ の書き方は変わらない向き)。fixture と musearch の写しで当たる数は数えていない(fixture は 0)。

**51 v6 に足す行**(「interactive Component の生成物」):

- 「live module の `Args` の欄は Service の Args の欄の型 ── `Bool`・`Int`・`Float`・`Option`・`List` はそのまま、他のスカラは `String`。Block は初期値を型で書き(`tags: ["news"]`、`note: None`)、`data-yumemi-args` の JSON の字は生成物の `args_json` が `live.json_*` で写す」
- 「Args の欄が record・組・Dict・スカラでない要素の List の Service は interactive Component の `calls` に置けない(4、第 11 条)」
- 「生成器が止めるもの」第 15 条に「`after_send` の `error:` の `GoTo` は穴の無い route に限る(4)」、第 18 条に「`yumemi-` で始まるタグ(4)」、第 21 条に「pipe・変数・同じ module の関数を辿る。runtime も control の中の `out` に書かない」、第 22 条に「unqualified の import・同じ module の record の欄・型の別名を辿る」
- 「`when` の包みは `<span>`(`display: contents`)」、「`reloads` の一覧の取り直しは pageview に数えない(navigate の info の `count: false`、頁の読み込みに落ちたら `yumemi:uncounted` の印で 1 回)」

### 検収

| | before(`b52fdcd`) | after |
|---|---|---|
| root `gleam test` | 421 本(`build/012-y3-r2-test0.txt`) | **428 本、失敗 0**(`build/012-y3-r2-test3.txt`) |
| `gleam format --check src test` | 0 | 0(`build/012-y3-r2-fmt.txt`) |

足した test は `test/yumemi_012_y3_test.gleam` の 7 本(`article_21_out_through_pipe_variable_and_function_test`(4 形 + 止まらない形)・`article_22_unqualified_record_and_alias_test`(4 形 + 止まらない形)・`article_15_error_goto_needs_a_route_without_holes_test`・`article_18_yumemi_prefixed_tag_stops_test`・`live_args_are_typed_and_blocks_write_values_test`・`when_wraps_with_a_span_test`・`runtime_r2_closes_the_kashiwagi_p1_test`(偽の DOM の 9 件、`test/yumemi_012_y3_r2_check.mjs`))。基点のコード(`b52fdcd` の src に live.gleam の json 口だけ足した写し)で回すと、この 7 本が全部落ち、他の 421 本は通った。

期待値を書き換えた test:`yumemi_fix_0112_test.live_body_encodes_args_by_type_test` ── live module の Args が `Args(slug: String, pinned: String, rank: String, weight: String, note: String)` から `Args(slug: String, pinned: Bool, rank: Int, weight: Float, note: Option(Int))` に替わった(P1-3)。`live.json_bool`・`json_int`・`json_float`・`json_option` の写しも見るようにした。

**柏木の直し 4 件(`b52fdcd`)**:それぞれの test(`runtime_uploads_a_chosen_file_once_test`・`textarea_bind_renders_the_value_as_content_test`・`bind_pattern_keeps_the_spec_regex_escapes_test`・`article_3_aliased_unqualified_import_stops_test`)は 428 本の中で通る。柏木の台 `build/012-y3-kashiwagi/double-upload.mjs` を今の runtime で回して `POST の数: 1`。

**fixture の生成**:article 停止コード 0(警告は数えの 1 行だけ)、`git add` の後にもう 1 回で 0・差 0(`build/012-y3-r2-gen-article{1,2}.txt`)。cms 停止コード 0、2 回目 0・差 0(`build/012-y3-r2-gen-cms{1,2}.txt`、差は runtime の入った `client.mjs` だけ)。article の public と admin は `gleam build --target javascript` が通る(Block の型の値で compile、`build/012-y3-r2-public-build.txt`)。

**Chromium 153**(SSR を描き直した `build/012-y3-r2-pages`、台は r1 の `build/012-y3-interactive-checks.mjs`):既定 37/37・`:state()` 無し 37/37・`commandForElement` 無し 38/38・minify 37/37(`build/012-y3-r2-chromium-{default,nostates,nocommand,minify}.txt`、r1 と同じ数)。足した台 `build/012-y3-r2-chromium-probe.mjs`(fixture の client.mjs に送り手の start を足した束、頁に門の印)8/8(`build/012-y3-r2-chromium-probe.txt`):頁の読み込みで initial 1 件 → 一覧の `reloads` で `?widget=other` に移って pageview 0 件 → link の client 遷移で `spa` 1 件・option の中の out に書かず select の値は `""`(外の out には入る)・`<p>` の中の span の when は p に残り div は外へ出る・頁の when は span で `display: contents`。

### 選んだこと・食い違い

- **when の span は `<p>` の件だけを直す。**table の直下(`<table>`・`<tr>` の中で `<td>` の外)は span も div と同じく parser が table の外へ出す(foster parenting。Chromium 153 の DOMParser で `<table><span data-yumemi-when>` の span が table の外、`<td>` の中の span は td の中に残ることを見た)。table の直下に `when` を置く形を止めるかは決めていない(止めていない)
- **第 21 条の同じ module の関数**は「本体のどこかで `out` に届く関数」を全部数える(戻り値に入るかは見ない)ので、option の中で呼ぶ関数がどこかで `out` を描くだけでも止まる。変数は名で見て、同じ関数の中の同じ名の束ね直し(shadowing)は区別しない(止まる側に倒れる)
- **第 22 条**は別の module の record の中までは辿らない(r1 のまま、51 v6 確認できなかったこと 16)
- **`yumemi:uncounted` の印**は 10 秒で効かなくなる。頁の読み込みに落ちた後、印の URL と同じ URL を 10 秒の内に利用者が開き直すと 1 回数えない
- runtime の柵(control の中の out)は `datalist` も入れた

### 確かめていないこと

- Navigation API の無い browser で、一覧の `reloads` の頁の読み込み(`location.replace`)が数えられないこと(偽の DOM では見た、Chromium の写しは作っていない)
- record・組・Dict の Args を持つ Service の Component が musearch の写しに何本あるか(第 11 条の新しい止まりの件数)
- Safari・Firefox

### DDL

無し
