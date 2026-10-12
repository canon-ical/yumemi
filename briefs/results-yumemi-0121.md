# results ── yumemi-0121(0.12.1、生成の form・同じ名の読み・閉じた dialog・Failed と Refused・要件の符号、真壁 r1)

基点 `d09832b`(tag `v0.12.0`)、BRIEF の commit `6791261` の上。branch `impl/yumemi-0121`。証跡は `build/0121-*`・`build/test-*.txt`(git の外)。版の行・tag・publish は触っていない。

## 矛盾(贄川さんに確認が必要)

**musearch の写しで muses 4 本・console 2 本の test が落ちる。BRIEF の「生成し直すだけで通ること」と、BRIEF の 1・4 は両立しない。**★ は 1 行も変えずに生成器は exit 0 で通り、build も通る。落ちる 6 本は、0.12.0 の生成物の字か意味をそのまま縛っている test。

| 面 | test | 縛っているもの | 原因の項 |
|---|---|---|---|
| muses | `li-1-link-import.test.mjs:67` | `/<form><fieldset>…/` | 1(form が `<form method="dialog">` になる) |
| muses | `guard-2-islands.test.mjs:107` | `html.indexOf("<form>")` | 1 |
| console | `cn-3-ssr.test.mjs:59` | `/…data-yumemi-island[^>]*><form>…/` | 1 |
| console | `live-islands.test.mjs:146` | `/…data-yumemi-island><form><fieldset>…/` | 1 |
| muses | `3-2m-retire.test.mjs:102`(onboard_wizard K12) | 403 `forbidden`(Refused の枝あり)で `when(Failed)` の「登録できませんでした。」も出ること | 4 |
| muses | `3-8c-phone.test.mjs:70` | 403 `phone_unverified` で同じ「登録できませんでした。」が出ること | 4 |

- 1 の 4 本は test の字だけの話。直すなら `<form>` を `<form method="dialog">` に読み替える。form に属性を足さずに済ませる形も考えた。送りのボタンに `formmethod="dialog"` を付ける形で、この 4 本は通る。ただ、★ が `type` を書かない `<button>` を Component の中に置くと、JS の無い click や Enter で GET の送りになり、本文が URL に載る。BRIEF の失敗例も form の method を足す形を前提にしているので、form の側を取った
- 4 の 2 本は BRIEF の 4 そのもの。`onboard_wizard.gleam:163-167` は、0.12.0 の runtime が拒みのときも `failed` を立てることを前提に、`when(Failed)` を共通の 1 行として書いている。0.12.1 では、Refused の枝のある断りで Failed は出ない(下の 4)。今の見た目を保つなら、★ がその 1 行を Refused の枝に写すことになる(★ の書き換え)。見た目の変化を受け入れるなら、test の期待を直すだけで済む
- どちらを取るかは musearch の側の判断。yumemi の側で変えられるのは、1 を button の側に寄せる案だけ(上の欠けがある)

## やったこと

1. **生成の form**(`front/live.gleam` の `component`):interactive Component の form を `<form method="dialog">` にした。runtime が submit を取らない送り(JS が無い・読み込みの途中・JS の失敗)は、dialog の外では何もしない。dialog の中では dialog が閉じるだけで、本文はどこへも出ない。runtime は submit の頭で `preventDefault` するので、JS がある間は今までどおり。★ の `html.form` / `html.form_` は書いた method のまま(GET の頁送りは GET)。生成器の側に form を描く所は無い(`rg '"form'`)
2. **同じ名の読み**:生成の `gen/reads/<service>.gleam` の口を `read_of(ctx, owner, name, input)` にした(`operations.mjs` に足し、生成の `operations_ffi.mjs` が export)。名は今までどおり運び、持ち主の Service は 3 つ目の引数で添える。runtime の `ctx.read(name, input, owner)` は `spec.reads["<owner>/<name>"]` を直に引く。添えの無い口と表に無い名は、今までどおり自分の表 → `readAliases` → 1 本だけの名の順に引く。畳み(`fold:`)は root の Service 自身の読みにだけ掛ける。手書きの読み(`server.reads`)も同じ口にした
   - 最初は名を `<service>/<name>` に修飾した。musearch api の test が 96 本落ちたので、この形はやめた。musearch の ★ の Durable Object の ctx と test の偽の ctx が、`ctx.read(name)` を名だけで引いていた(`unregistered USER DO read: notification_inbox/inbox` ほか)。名を変えない今の形なら、名だけで引く ctx は 3 つ目を見ないだけで済む
3. **閉じた dialog**(`emit/front.gleam` の `closed_dialog_css`、style.css と SSR の頁の `<style>` の両方):`dialog:not([open]) { display: none !important; }` と、同じ規則を `@layer yumemi-closed-dialog { … }` の中にも置いた。層の中の `!important` は層の外の `!important` より強い。`@layer` を知らない browser には層の外の 1 行が効く。作り手の Style は sketch の class で、層の外にある
4. **Failed と Refused**:
   - runtime(`interactive.mjs` の `yumemiDone`):失敗で `error` は今までどおり立てる。断り(表の `refused` か `requires` の符号)には `refused-<code>`。`failed` は、その断りの `when` の枝(`[data-yumemi-when~="<svc>.refused-<code>"]`)が Component の中に無いときだけ立てる。`refused` / `requires` の外の符号と、読めない本文も `failed`
   - 生成の CSS:`when(Failed)` の枝は `failed` と `sent-<svc>` で出す(今までは `error`)
   - 枝の無い断りは、今までどおり Failed で出る。断りの枝を書かず `when(Failed)` だけで受けている Component(musearch の 0.11 で字を分けていなかった面)が黙ることは無い。`css.State(css.Failed)` は今までどおり `error`(断りも含む)
5. **要件の符号**(`emit/front.gleam` の `requirement_codes` / `attached_requirement_codes`):
   - Service の `requires` の `Declared` があれば `DeclarationMissing`、`Consented` / `ConsentedFor` があれば `ConsentMissing` を、live module の `Error` の後ろに足す(状態は `refused-declaration-missing` / `refused-consent-missing`、CSS の行も)。attached の口に `NeedsDeclared` の役があれば `DeclarationMissing` を足す(口の名は model が `BlobCopy`、役の表が `blob_copy` なので snake で突き合わせる)
   - ★ が Service の `Error` に同じ名の構成子を書いていればそれを使い、重ねない
   - client の表は `refused`(Service の `Error` の符号)のまま、要件の符号は別の欄 `requires` に置く。musearch の test 7 本が `refused` を「api の構成子」と突き合わせている。1 本の欄に混ぜた版ではその 7 本が落ちたので分けた
   - ★ の Component は `when(Refused(ConsentMissing), ..)` を書ける。宣言に足す欄は無い
6. README:form の `method="dialog"` と JS の無い送り、`When` の `Failed` の意味と要件の構成子、状態の `failed`、閉じた dialog の CSS
7. fixture `gen/fixtures/article`・`cms` を生成し直した(reads 4 本・operations_ffi 2 本・style.css 4 本・shell.mjs 4 本・client.mjs 2 本)

## 確かめ

- **root**:`npm ci` exit 0(`build/npm-ci.txt`、esbuild の allow-scripts の警告だけ)。`gleam test` は before `441 passed, 1 failures` → after **`451 passed, no failures`**(`build/test-final.txt`)。before の 1 本は、基点の上で 2 の最初の形を書いた直後に回した `yumemi_gen_wgy_test.manual_read_writes_the_typed_port_test` で、読みの口の字の期待。基点そのものの本数は 442。`gleam format --check src test` 0
- **書き換えた期待**:`yumemi_gen_wgy_test.manual_read_writes_the_typed_port_test` ── 手書きの読みの口の字(`fn query(ctx: Context, owner: String, name: String, ..)` と `query(ctx, "article_create", "counts", ..)`)
- **新しい test**(`test/yumemi_0121_test.gleam` 9 本、`yumemi_0121_test_ffi.mjs`、子の node の `yumemi_0121_read_check.mjs` 7 項・`yumemi_0121_state_check.mjs` 7 項)
  - 1:`component_form_sends_nothing_without_the_runtime_test`(`<form method="dialog"><fieldset>`)、`star_get_form_keeps_its_method_test`(★ の `method="get"` の form は get のまま、dialog も post も無い)
  - 2:`generated_reads_carry_the_owner_test`(fixture article の生成の reads の口が全部 `read_of` で、呼びが `query(ctx, "<自分の service>", "<名>"`)、`runtime_reads_the_qualified_query_test`。後者は、timeline が feed_b・feed_a の順に `rows` を import した表で、`read_of` が持ち主の `rows` を引くことを見る。添えの無い `read` の 2 通りと、名だけで引く ctx に名がそのまま届くことも見る
  - 3:`closed_dialog_stays_hidden_test`(生成の style.css と shell.mjs に 2 行、停止コード 0)
  - 4:`failed_branch_is_not_shown_on_a_refusal_test`。生成の CSS の failed の行が `:state(failed)` と `[data-yumemi-state~="failed"]` で、`:state(error)` の行は無い。runtime は次の 7 項:枝のある断り → `refused-*` だけ、枝の無い断り → `failed` も、`requires` の符号 2 通り、外の符号、読めない本文、成功
  - 5:`requirement_codes_ride_on_refused_test`(写しの article_publish に `Consented("use"), Consented("handling")`、停止コード 0、`Error` の末尾に `ConsentMissing` が 1 つ、`requires: ["consent_missing"]`、`refused` は 2 つのまま、CSS の行、要件の無い article_create には足さない)、`declared_and_a_star_constructor_of_the_same_name_test`、`needs_declared_attached_route_test`
- **fixture**:article・cms を生成して停止コード 0(article の警告は数えの 1 行だけ)。`git add` の後にもう 1 回、停止コード 0・未 stage の差 0 行(`build/0121-gen-{article,cms}-{5,6}.txt`)。面の node_modules は root の node_modules への symlink を一時に置いて回し、消した
- **musearch の写し**:main `afe6279f5` を `git archive` で `.scratch/musearch` に置いた。5 package の yumemi を本作業木への path 依存にし、各 package で `gleam deps download`(exit 0、`Added yumemi v0.12.0`)。node_modules は手元の musearch への symlink。runbook の手で brand・fonts・legal を作り、`src/gen` を消して api から `gleam run -m yumemi/gen -- . ..` を回した
  - 生成器:**停止コード 0**、`[exit 1` 以上の行 0、2 回目も停止コード 0・差 0(`build/0121-ms-gen-{5,6}.txt`)。Hex の rate limit には当たっていない
  - 生成物の差(基点の生成物から):`gen/live/*` に要件の構成子(`ConsentMissing` 107 本、`DeclarationMissing` 1 本 ── www の `schedule_slots`)、`api/src/gen/reads/*` が `read_of`、4 面の style.css・shell.mjs・client.mjs
  - **www `npm run build` 0・`npm test` 446/446**、admin 21/21(`build/0121-ms-{www,admin}-test3.txt`)
  - **muses 508/512、console 88/90**(落ちる 6 本は上の「矛盾」、`build/0121-ms-{muses,console}-test3.txt`)。build は 4 面とも exit 0
  - **api `npm test` 1756/1756**(新しい PG、port 55921、写しの `build/pgdata-55921`。回した後に止めた、`build/0121-ms-api-test4.txt`)。同じ PG を使い回した 3 回目は `sql-coverage` の `staff_screen_rejects/given_up` が 1 本落ちた。前の回の chat が 200 行を超えて `LIMIT 200` の外に出るためで、新しい PG では通る。auth の build が無いと `2a-6`・`3-1b-idp` が import で落ちるので、写しの auth も build した
  - 2 の最初の形(名を `<service>/<name>` に修飾)では api が 96 本落ちた(`build/0121-ms-api-test.txt`)。今の形で 0

## 51 v6 に足す行

- interactive Component の form は `method="dialog"`。runtime が取らない submit は外へ何も送らない(JS の無い送りを持たないことの実装)。★ の `html.form` は書いた method のまま
- `When.Failed` は「その Component に、同じ Service の Failed の枝の外の Refused の枝が無い失敗」。兄弟に並べた Refused の枝が出る断りでは Failed を出さない。Failed の枝の中に入れ子にした Refused の枝は数えない(Failed と一緒に隠れるので、入れ子の形は 0.12.0 のとおり汎用の字と断りの字の両方が出る)。状態は `error` に加えて `refused-<code>` か `failed`。`css.State(Failed)` は `error` のまま(r2)
- live module の `Error` は、Service の `Error` に要件の構成子(`DeclarationMissing` / `ConsentMissing`、attached の `NeedsDeclared` は `DeclarationMissing`)を足したもの。client の表は `refused`(Service の `Error`)と `requires`(要件)の 2 欄
- 生成の読みは `read_of(ctx, owner, name, input)`。ctx の `read(name, input, owner?)` の 3 つ目は省いてよく、名だけで引く ctx を壊さない。持ち主を添えた読みが表(`<owner>/<name>`)に無ければ `unregistered read` で止め、名だけの道(`readAliases`・1 本だけの名)に落とさない(r2)
- 生成の CSS は閉じた dialog を `!important` と `@layer` で隠す
- 第 44 条:★ の `html.form` / `form_` の中に interactive Component を置かない(exit 4)。HTML の parser が form の中の form を捨て、Component の欄が ★ の form の method で送られる。直に・pipe・変数・Component に届く関数(他の module の関数も)を通す形を辿る(r2)

## 次の版へ(触っていない)

- BRIEF の「しないこと」の宿題(attached の `Entry`、`out` の record、Out の別名、消えた生成物、逃げ道の数え、`isList`、動的な dialog の key、Page の Var `date`、decoder の import)は触っていない
- `When.Failed` と `css.State(css.Failed)` が指すものがずれた(前者は `failed`、後者は `error`)。合わせるかは次の版で決める
- After の `error` を符号ごとに分ける口(musearch の `muse_retire` の 409)は無いまま
- 名だけで引く `ctx.read` の取り違え(`readAliases` の先の同じ名)は、添えの無い口では今も起きる。生成の読みはもう通らない道で、手書きの FFI だけが通る

## DDL

無し。

## r2(真壁、BRIEF `BRIEF-yumemi-0121-r2.md`、基点 `fd6cbf6`)

### ゲート 2 の所見(柏木、写し)

- **P0-1 入れ子の Refused の枝を持つ断りで、何も出なくなる**(`interactive.mjs:364`)。runtime は断りの枝が Component の**どこかに**あれば `failed` を立てない。`when(Failed, [p("取り込めませんでした。", when(Refused(NothingExtracted), ..), "…")])` の形では、外の Failed の枝と一緒に中の Refused の枝も隠れ、0.12.1 で何も出ない。musearch の muses に 14 か所(`heaven_refresh:46`・`schedule_timeline:441/470/500/519/582/652`・`roster_unclaim:40`・`heaven_link:219/238`・`schedule_add:119`・`claim_button:43`・`link_import:62`・`setting_edit:66`)、断りの符号で約 45 本。直し方の方向:数える断りの枝を同じ Service の `failed` の枝の外のものだけにする。state_check に入れ子を足し、README 133・137 行と「51 v6 に足す行」を合わせ、写しで muses・console を回し直す
- **P1-1 ★ の `html.form` の中に Component を置くと本文が外へ出る**(0.12.0 からの穴)。HTML の parser が Component の `<form method="dialog">` を捨て、control は ★ の form に属する。runtime は `:scope > form` を見つけられず、★ の form の method(GET なら URL)で送られる。生成器は止めない。生成器の条で止めるのがよい(この入れ子はもともと動いていない)
- **P1-2 `runtime.mjs:368-369`:`owner` を付けた読みが表に無いと名だけの道に落ちる。**`storage.in_object_named` で表から外した読みで、`readAliases` の先の同じ名をまた引く余地。`owner` があるときは `unregistered read` にする方が合う。test は無い
- **P1-3 `When.Failed`(`failed`)と `css.State(Failed)`(`error`)のずれ。**黙る害は無い(README の注記は柏木が `fd6cbf6` で足した)
- **P1-4 要件の符号が載らない形:**`requires` が literal の list でない(別の定数・連結)、Service が `service/` の下の階層にある。どちらも Failed に落ちるので黙りはしない
- **P1-5 `declared_and_a_star_constructor_of_the_same_name_test` が見ていないもの:**停止コードと、client の表で `refused` に `consent_missing` が入り `requires` に入らないこと

### やったこと

1. **P0-1**(`front/interactive.mjs` の `refusalShown`):断り `code` の枝を `querySelectorAll` で拾い、`branch.parentElement?.closest('[data-yumemi-when~="<svc>.failed"]')` の無い枝が 1 つでもあれば `failed` を立てない。兄弟に並べた形(BRIEF 4、onboard_wizard)は断りの字だけ、入れ子の形は 0.12.0 のとおり両方の字。README の live module の `Failed` と状態の `failed` の 2 か所を合わせた。fixture の `client.mjs` 2 本が変わる(生成し直した)
2. **P1-1 第 44 条**(`gen/reader/front.gleam` の `component_in_form_notes`、`surface_notes` に足す):★ の `html.form` / `form_` の呼び出し・capture・pipe の中に、`gen/interactive.<名>`(と `gen/islands`)、それを束ねた変数、それに届く関数が現れれば exit 4。Component に届く関数は module をまたいで不動点まで辿る(`<module の道>.<関数名>`)。第 21 条の `out_in_control` の中身を `placed_inside` / `reaching_functions` / `reaches` に分けて両方で使う(第 21 条の判定は変えていない)。README の「Placing it.」に 1 文
3. **P1-2**(`server/runtime.mjs` の `read`):`owner` があれば `spec.reads["<owner>/<name>"]` だけを引き、無ければ `unregistered read: <owner>/<name>`。添えの無い口は今までどおり
4. **P1-5**:同じ名の構成子の test が停止コード 0 と client の表 `"refused": [..., "consent_missing"], "requires": ["declaration_missing"]` を見る。停止コード 0 にするため、写しの `server.gleam` に `consents` と `browser`(`Declaration(kind: "adult")`)を足した(足さないと第 32・40 条で exit 4 だった)

### 確かめ

- **root**:`npm ci` exit 0(`build/r2-npm-ci.txt`、esbuild の allow-scripts の警告だけ)。`gleam test` は **`454 passed, no failures`**(`build/test-r2-final.txt`、r1 の 451 + 第 44 条の 3 本)。`gleam format --check src test` 0
- **新しい test・検査**
  - state_check 9 項(r1 の 7 + `a refusal branch nested in Failed also shows Failed`・`a nested refusal branch and a sibling one: refused only`)。偽の DOM は `querySelectorAll` と枝の `parentElement.closest` を持つ形にした
  - read_check 9 項(r1 の 7 + `an owner without the name does not fall back to readAliases`・`… to the only read of that name`)
  - `component_inside_a_star_form_stops_test`(直に・pipe と同じ module の関数で、exit 4 と `public/blocks/summary: ★ の html.form` の行)、`component_through_another_module_inside_a_form_stops_test`(article が summary の `pub fn liked` を form に入れる)、`component_beside_a_star_form_passes_test`(form の隣の Component と Component の無い form は 0)
  - 他の module を辿る分の効き:`Some(#(path, name)) -> list.contains(reaching, ..)` を `False` にすると `component_through_another_module_inside_a_form_stops_test` だけが落ちる(`build/test-r2-mut.txt`、453 passed 1 failures)。戻してある
- **fixture**:article・cms を生成して停止コード 0、差は `public/priv/static/_yumemi/client.mjs` 2 本(`refusalShown`)。`git add` の後にもう 1 回、停止コード 0・未 stage の差 0 行(`build/r2-gen-{article,cms}-{1,2}.txt`)。面の node_modules の symlink は消した
- **musearch の写し**(`.scratch/musearch`、r1 と同じ path 依存):
  - 生成器:**停止コード 0**、2 回目も 0(`build/r2-ms-gen-{1,2}.txt`)。第 44 条は当たらない。r1 の生成物からの差は 4 面の `client.mjs` だけ
  - **muses 508/512、console 88/90**(`build/r2-ms-{muses,console}-test.txt`)。build は exit 0。落ちるのは **r1 の 6 本と同じ 6 本で、新しく落ちたものは無い**
    - form の 4 本(`li-1-link-import:67`・`guard-2-islands:107`・`cn-3-ssr:59`・`live-islands:146`):`<form>` の字を縛る test。残る
    - onboard_wizard の 2 本(`3-2m-retire:102`・`3-8c-phone:70`):兄弟に並べた形で、断りの字だけが出る(BRIEF 4 と裁きのとおり)。test 自身が状態の並びを置いて SSR の枝を見ている。残る
  - 入れ子の実例:muses の `link_import` を harness で描き、枝の入れ子を辿った。`link_import.refused-nothing-extracted` は `link_import.failed` の中にだけあり、直した数えでは `nothing_extracted` で `failed` が立つ(両方の字が出る)。scratch の script で見た(git の外)
  - **api 1756/1756**(新しい PG、port 55922。回した後に止めた、`build/r2-ms-api-test.txt`)。P1-2 で読みの道を変えたので回した。**www 446/446・admin 21/21**(`build/r2-ms-{www,admin}-test.txt`)

### 次の版へ(r2 で触っていない)

- P1-3:`When.Failed`(`failed`)と `css.State(css.Failed)`(`error`)のずれ。合わせるかは次の版
- P1-4:`requires` が literal の list でない形(別の定数の参照・連結)と、`service/` の下の階層の Service では要件の構成子が足されない(Failed に落ちるので黙りはしない)
- 第 44 条は、form を描く関数が children を引数で受け、呼ぶ側が Component を渡す形(`wrapper.box([interactive.x(..)])` で `box` の中が `html.form_([], children)`)は辿らない。引数の流れを追う検査は無い
- 同じ Service の Failed の枝の外でも、他の Service の Failed の枝の中にある断りの枝は「外」と数える(その Service が失敗していなければ隠れたまま)。そう書いた ★ は musearch に無い
