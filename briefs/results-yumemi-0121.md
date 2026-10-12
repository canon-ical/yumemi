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
- `When.Failed` は「その Component に Refused の枝の無い失敗」。Refused の枝が出る断りでは Failed を出さない。状態は `error` に加えて `refused-<code>` か `failed`。`css.State(Failed)` は `error` のまま
- live module の `Error` は、Service の `Error` に要件の構成子(`DeclarationMissing` / `ConsentMissing`、attached の `NeedsDeclared` は `DeclarationMissing`)を足したもの。client の表は `refused`(Service の `Error`)と `requires`(要件)の 2 欄
- 生成の読みは `read_of(ctx, owner, name, input)`。ctx の `read(name, input, owner?)` の 3 つ目は省いてよく、名だけで引く ctx を壊さない
- 生成の CSS は閉じた dialog を `!important` と `@layer` で隠す

## 次の版へ(触っていない)

- BRIEF の「しないこと」の宿題(attached の `Entry`、`out` の record、Out の別名、消えた生成物、逃げ道の数え、`isList`、動的な dialog の key、Page の Var `date`、decoder の import)は触っていない
- `When.Failed` と `css.State(css.Failed)` が指すものがずれた(前者は `failed`、後者は `error`)。合わせるかは次の版で決める
- After の `error` を符号ごとに分ける口(musearch の `muse_retire` の 409)は無いまま
- 名だけで引く `ctx.read` の取り違え(`readAliases` の先の同じ名)は、添えの無い口では今も起きる。生成の読みはもう通らない道で、手書きの FFI だけが通る

## DDL

無し。
