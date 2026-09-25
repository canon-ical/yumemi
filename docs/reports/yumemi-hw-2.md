# yumemi-hw-2 ── Actor の統一(`gen/allow` を生成物にし、Sum の root の `Actor` を `allow.Actor` の別名にする)

基点 `c2519de`(Y1f)。hw-1 の持ち分(`reader.gleam` / `model.gleam` / `emit/{typing,reads,query,sql,verb}.gleam`)と front は触っていない。

## DDL

無し。migration / schema / database は変更していない。

## 何を足したか

| file | 中身 |
|---|---|
| `gen/src/yumemi_gen/reader/allow.gleam`(新) | ★ の Service のうち `gen/allow/<m>` を `allow` の名で import するものから、allow module ごとに `who` / `owner` の構成子、`Only([...])` の要素の module、小文字の略記(`allow.staff`)、`allow.<name>(` の呼び出し(コメントは token の段で除く)を集める。`owner_entity`(`Via<Entity>Party` → Entity 名)もここに置いた |
| `gen/src/yumemi_gen/emit/allow.gleam`(新) | `src/gen/allow/<m>.gleam` を sha256 ヘッダ付きで出す。対象は、全 root が import する allow の道と、★ が import する allow の道の和。入力ハッシュ(その allow を使う Service、`types`、`entity/*` 全部)もここで取る |
| `gen/src/yumemi_gen/emit/root.gleam` | `Sum` の形は `pub type Actor =\n  allow.Actor` になり、root 独自の variant と entity の import を出さない。`Direct` は変更なし。`actor_is_sum` / `allow_path` を公開した |
| `gen/src/yumemi_gen.gleam` | 登録は emit と notes の 2 か所と import 2 行(+12 −2 行)。notes の置き場所は `root.notes` の直後 |
| `gen/test/allow_emit_test.gleam`(新) | 18 本(正 13・負 5) |
| `gen/test/yumemi_gen_test.gleam` | **既存の 3 行を差し替えた**(下の「鷹野宛」1) |

### 規則

- **owner から party への道:** `Via<X>Party` は Entity `X`(型名)の `party` 欄を指す(`ViaMuseParty` なら `muse.party`、`ViaStoreParty` なら `store.party`)。`X` の Entity が無いか、Entity に `party` 欄が無ければ exit 4。`NoOwner` / `Self` / `Via<X>Party` のどれでもない名は exit 5。hw-1 の SQL 側と同じ規則にするため、`reader/allow.owner_entity` を公開した
- `Who`:★ の句に書かれた構成子。並びは `Anyone`、`Party`、句に出た順の主体、`System`。`Owner`:常に `NoOwner` を置き、`Self` と `Via*` は句に書かれたときだけ足す
- `At`:`AnyPhase` を置く。phase は ★ の `Only([...])` の要素の module(複数の Entity に跨れば exit 4)で決め、`Only` が無ければ allow module と同名の Entity の phase を使う。どちらも無ければ `AnyPhase` だけ
- `Actor`:この allow を使う root のうち、Actor が Sum の形のもの全部の主体の和。Entity の主体は `<Type>Actor(<entity>.<Type>)`、`Party` は `AuthenticatedActor(party: PartyId)`、`System` は `SystemCaller`(`SystemActor` は型の構成子と名が衝突するため別の名にした)。最後に必ず `AnyActor` を置き、`pub type AnyActor = Actor` の別名も出す。`PartyActor` / `SystemActor` の型は、allow module ごとに常に出す
- 判定は ★ が呼ぶものだけを出す。
  - `is_self(by, it: <m>.<M>)`:主体が同じ Entity なら key の欄の `==`。`Held(<主体>)` の欄を持つなら `er.to_string(er.of_held(it.<欄>)) == <key>.to_string(value.<key>)`。それ以外は `False`
  - `is_<entity>`:その主体の variant なら `True`。variant が無ければ常に `False`
  - `party_of`:Entity の `party` 欄 / `AuthenticatedActor` の party / それ以外は `None`
- 小文字の略記の句(fixture の `allow.staff`)は `pub const staff: Clause = Clause(who: Staff, at: AnyPhase, owner: NoOwner)` にする

## 検証

| 項目 | 結果 | 証拠 |
|---|---|---|
| root `gleam build` | exit 0、警告 1(既存の `src/framework/secret.gleam`) | `gen/build/hw2-root-build.txt` |
| `cd gen && gleam test` | **212 passed, no failures**(基点 194 + 18) | `gen/build/hw2-test-2.txt`(基点は `hw2-test-base.txt`) |
| Article fixture を 2 回生成 | 2 回とも exit 0 で 113 file(Y1f の 112 + **`src/gen/allow/article.gleam`**)。`diff -r` は 0 行。tracked の生成物 51 本(`public` / `admin` の `src/gen` と `priv/static/_yumemi`)は byte 一致。`api/src/gen/http_runtime.mjs` は入力なので出力に無い | `gen/build/hw2-fx-{one,two}.log`、`hw2-fx-diff.txt` |
| 写し `728adfa` に 2 回当てる(`/tmp/hw2/ms`、musearch は `git archive` で読んだだけ) | 2 回とも exit 4 で 1394 file(基線 1372 + `src/gen/allow` 22 本)。`diff -r` は 0 行。**`_diagnostics.txt` は基線(本便の前の生成器)と同一**:164 行、exit 4 は 111 行(うち back 22)、警告 48 | `gen/build/hw2-snap-{a,b}.txt`、`hw2-snap-diff.txt` |
| 基線から変わった生成 root | Sum の 21 本だけ。Actor が理由の ▲ 15 本と、生成と一致していた 6 本(`article_list` / `article_read` / `link_list` / `muse_heaven_list` / `schedule_list` / `schedule_availability`) | 同上 |
| 写しの `api/` に被せて `gleam build` | **exit 0**。被せたのは生成 allow 21 本と生成 root 103 本。▲ に残したのは allow 1 本(`page_view`)と root 19 本(`schedule_availability`、Root の欄が違う 18 本)。★ は 1 字も直していない。警告は 138 → 120 で、生成した allow / root に警告は 0 | `gen/build/hw2-overlay-build.txt`(基線は `hw2-overlay-base-build.txt`)、分類は `hw2-roots-class.txt` |
| 生成物の `gleam format --check` と sha256 ヘッダ | 写しと fixture のどちらも format 0、`src/gen/allow` のヘッダ欠けは 0 | ― |

### 被せられないもの(名指し。allow は 1 本で、上限 3 本の内)

- **allow `page_view`**:★ `pageview_record.gleam:558-585` は `allow.AuthenticatedActor(_, Some(subject.Muse))` のように 2 欄の構成子で割る。2 欄目の `subject: Option(subject.Subject)` は句(`Anyone` だけ)から導けない。生成物の Actor は `AnyActor` だけになる
- **root `schedule_availability`**:★ `schedule_availability.gleam:13` は root から構成子 `Anonymous` を import し、`:79` で `Anonymous, Some(_) ->` と割る。Sum を `allow.Actor` の別名にすると、root から `Anonymous` が消える。allow `muse_schedule` は生成物で通る
- **Root の欄が違う root 18 本**(本便の外。Actor の宣言と `logic` の型は ▲ と一致):`article_pin` `fan_onboard` `heaven_unlink` `link_import_apply` `metrics_muse` `muse_edit_profile` `muse_onboard` `pageview_record` `roster_edit` `roster_issue_code` `roster_photo_delete` `roster_photo_put` `roster_read` `roster_remove` `roster_unclaim` `store_onboard` `store_request_handle` `store_request_notify`

## 対照表 ── 写しの生成物と musearch の ▲

▲ は `gleam format` で書式を揃えてから、1 行目(ヘッダ)を除いて比べた。行ごとの diff は `gen/build/hw2-contrast/{allow,root}-<m>.diff`(820 行)にある。

### root 15 本

| root | 差 | 理由 |
|---|---|---|
| `course_add` `course_edit` `course_retire` `reservation_list_mine` `roster_list` `space_list` `store_read` `store_schedule_list` `subscription_add` `subscription_read` `widget_list` | 無し | ― |
| `muse_read` | ▲ に `import entity/article` の 1 行が多い | ▲ の未使用 import |
| `article_search` | 生成:`pub type Actor = allow.Actor`、`logic: fn(Actor, …)`/▲:Actor 無し、`logic: fn(allow.AnyActor, …)` | 生成の別名 `AnyActor = Actor` で同じ型になる。★ `_by: allow.AnyActor` のまま compile する |
| `pageview_record` | Root:生成 `Root(page_view: page_view.PageView, …)`/▲ `Root(browser: BrowserId, …)` | Root の欄(本便の外)。Actor の宣言は一致 |
| `roster_read` | Root:▲ に `store: store.Store` と `muse: Option(muse.Muse)` がある | 同上 |

### allow 22 本

凡例:**W** = ▲ にあるが ★ の句が使わない Who / Owner の構成子(生成物は出さない)。**T** = 生成物が常に出す `PartyActor` / `SystemActor` / `Actor` / `AnyActor` の型(▲ は module ごとにまちまち)。

| allow | 生成物に無い ▲ の行 | 生成物にだけある行 | 理由 |
|---|---|---|---|
| `article` | `Party` `Self`、`AuthenticatedActor(party)`、`import gen/types/muse_id` | `MuseActor(muse.Muse)`、`import entity/muse` | W。Actor は Sum の root の主体の和で、`article_read`(Anyone+AsMuse)と `article_search`(Anyone)から `MuseActor` と `AnyActor` になる。Party の Sum が無いので `AuthenticatedActor` は出ない(▲ の muse_id は未使用 import) |
| `consent` | `Anyone` `AsMuse` `System` `Self` `ViaMuseParty`、`Only(List(muse.Phase))`、`AuthenticatedActor`、import 2 行 | `AnyActor` の別名 | W。★ に `Only` は無く、consent Entity に phase が無いので `AnyPhase` だけ。Sum の root が無いので Actor は `AnyActor` だけ |
| `course` | `Anyone` `Party` `System` `Self`、`is_staff` | 別名 | W。`is_staff` は course の ★ が呼ばないので出さない |
| `fan` | ― | `SystemActor` / `Actor` / 別名 | T |
| `free_space` `link` `muse_heaven` `widget` | `Anyone` `Party` `System` `Self`、`AuthenticatedActor` | 別名 | W。Sum の root が無い |
| `ledger` | `StaffActor` の型 | `SystemActor` / `Actor` / 別名 | T。`ledger.StaffActor` を ★ は使わない(`ledger_store_add` の root は `staff.Staff` を直に取る) |
| `metric_rollup` `notification` `prep` `subscription` | 使われない Who / Owner | `Actor` / 別名 | W・T |
| `muse` | `System` `ViaMuseParty`、`import gen/types/muse_id`、`is_self` の本体(`muse_id.to_string` で比べる)、`party_of` の並び | `is_self` の本体は `value.id == it.id` と `_ -> False`、別名 | W。同じ型の `==` は構造の比較なので、文字列を経由しない。`party_of` の本体は一致(置き場所が `is_self` の後になっただけ) |
| `muse_schedule` | `Party` `System` `Self`、`Only(List(muse.Phase))` | `Only(List(muse_schedule.Phase))`、`Actor { MuseActor, FanActor, AnyActor }`、import | ★ の句に `Only` は無いので、同名の Entity の phase を使った。Actor は `schedule_availability`(Sum)の主体 |
| `page_view` | `Party` `AsMuse` `System` `Self` `ViaMuseParty`、`AuthenticatedActor(party, subject)` | 別名 | **被せられない 1 本**(上記) |
| `reservation` `shift_target` | 使われない Who、`Only(List(muse.Phase))` | `Only(List(reservation.Phase))`(reservation だけ)、`Actor` / 別名 | ★ に `Only` は無い。reservation は Entity の phase、shift_target は phase が無いので `AnyPhase` だけ |
| `roster` | `Party` `System` `Self`、`MuseActor`、`is_self` の比較の左右 | `Who` の並び(`AsMuse` が `Staff` の後)、別名、`er.to_string(er.of_held(it.store)) == store_id.to_string(value.id)` | W。roster の Sum の root は `roster_read`(Anyone+AsStore+Staff)だけなので `MuseActor` は出ない。is_self の比べる中身は同じ |
| `store` | `Party` `System` `ViaStoreParty`、`import gen/types/store_id`、`is_self` の本体 | `StoreActor(value) -> value.id == it.id`、別名 | W。`muse` と同じ |
| `store_request` | `StaffActor` の型 | `Only(List(store_request.Phase))`、`SystemActor` / `Actor` / 別名 | T。phase は同名の Entity から |
| `store_request_notify` | ― | `PartyActor` / `Actor` / 別名 | T(Entity の外の module なので `AnyPhase` だけ) |

## 鷹野宛

1. **矛盾:既存の test を 3 行書き換えた。**`yumemi_gen_test.gleam:727-729`(`root_bundle_uses_allow_and_args_key_test`)は、fixture の `article_read`(Anyone + Staff の Sum)が `pub type Actor {` / `Anonymous` / `AsStaff(staff.Staff)` を持つことを固定していた。指示書の 3「Sum の形なら `pub type Actor = allow.Actor`」と両立しないので、同じ 3 行を「別名が在る / `Anonymous` が無い / `AsStaff(staff.Staff)` が無い」に置き換えた(行数も関数も変えていない)。hw-1 はこの関数を触らない見込みなので、merge の衝突は起きないと見ている。新しい test は別 file(`test/allow_emit_test.gleam`)に置き、`yumemi_gen_test.gleam` への追記は 0 行
2. **Sum を一律に別名にすると、★ 1 本が compile しない**(`schedule_availability` が root の `Anonymous` を import している)。今回は root を ▲ に残して build した。直し方は 2 つ:(a) 追随便で ★ の 1 行を `allow.AnyActor` にする、(b) 生成器で「★ が root から構成子を import する Service は旧形を保つ」という例外を作る。どちらにするかは鷹野さんの判断が要る
3. **compile で拾えない差:runtime.mjs(本便の外)は `allowArticle.AuthenticatedActor` を組む**(`runtime.mjs:233` の既定の枝。`article_read` など、どの名指しの枝にも当たらない Service が通る)。生成した `allow/article` には `AuthenticatedActor` が無い(Party の Sum が無いため)。生成した article allow を musearch に入れるなら、runtime のこの枝も同時に直す必要がある。`allowPageView.AuthenticatedActor`(`:176`)は page_view を ▲ に残す限り問題ない
4. 名の決定:Sum の中の `System` は `SystemCaller` にした(`SystemActor` は型の構成子と衝突する)。musearch には該当が無い
5. `reader/allow.gleam` は、source.gleam と同じく glexer を直に import している(transitive dependency の警告が 2 件増える。前例は `source.gleam:9-10`)

## 追随便への申し送り

musearch の ▲ のうち、生成物で置ける file(`728adfa` の写しで、置いた状態の `cd api && gleam build` が 0 を返した組):

- **allow 21 本**:`article`(※ runtime.mjs:233 を同時に直す。鷹野宛 3)、`consent` `course` `fan` `free_space` `ledger` `link` `metric_rollup` `muse` `muse_heaven` `muse_schedule` `notification` `prep` `reservation` `roster` `shift_target` `store` `store_request` `store_request_notify` `subscription` `widget`。置けないのは `page_view`
- **Actor が理由の root 13 本**:`article_search` `course_add` `course_edit` `course_retire` `muse_read` `reservation_list_mine` `roster_list` `space_list` `store_read` `store_schedule_list` `subscription_add` `subscription_read` `widget_list`。Root の欄も違う `pageview_record` / `roster_read` は、Root の欄の便の後になる
- **いま生成と一致している root のうち、本便で形が変わる 6 本**:`article_list` `article_read` `link_list` `muse_heaven_list` `schedule_list` は置き直しても ★ は compile する(どれも `_by` を使わない)。runtime.mjs は、これらに `allowMuse.MuseActor` / `allowArticle.*` を渡している(JS なので型は見ない)。`schedule_availability` は鷹野宛 2 の判断を待つ。この root だけは、runtime.mjs:217-219 が `record.root.AsMuse` / `AsFan` / `Anonymous` を組んでいる
- runtime.mjs が組む allow の構成子のうち、生成物に無いのは `article.AuthenticatedActor` と `page_view.AuthenticatedActor` の 2 つ(他の 19 個は在る)

## 確かめていないこと

- runtime.mjs で実際に動かすこと(JS の実行)。構成子の有無を照合しただけで、HTTP を通していない
- 他の fixture(`flag` など)は、tracked の生成物が無いので、2 回生成の比較をしていない。どれも test の中で生成し、test はすべて通っている
