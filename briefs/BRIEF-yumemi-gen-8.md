# BRIEF yumemi-gen-8(WGy)── back の `api/src/gen` を生成器が書き切る(宣言 → registry / http_runtime / codec / runtime ほか)、面の入力を手書きの `http_runtime.mjs` から宣言へ付け替え、Route の曖昧を同じ便で消す(草案、2026-09-26、水無瀬[PL] 起草 → 鷹野[PDM] が裁く)

便: yumemi-gen-8(WGy)

**真壁さんへ。本便は 1 session で直に書き、終端で柏木のゲートを 1 回だけ受けます(贄川は通しません)。**基点は yumemi main `b8ee337`(v0.11.0 + report 1 本)、作業木は `~/yumemism_repo/yumemi-gen-8`(branch `impl/yumemi-gen-8`、鷹野が切る)。**門の便 yumemi-gate-1 が同じ基点から並走します**(持ち分は「門との分け方」)。merge の順は本便 → 門、Hex は両方の merge の後に 0.11.1 を 1 回(鷹野)。**musearch へは 1 file も書きません** ── 確かめは musearch `645ec49` の写し(`gen/build/wgy/snap/`、`git archive` で作る)の上だけ。musearch では F6(`impl/yumemi-6`)が走っていて、採用は後の便 WGm(musearch-yumemi-7)です。記録は `results.md` の先頭の節と `docs/reports/yumemi-gen-8.md`(**`## DDL` は「無し」**)、証跡は `gen/build/wgy/`。commit は `git-as makabe`(path 指定)、`main` に触らない、push と publish は鷹野。柏木の P0 があれば、鷹野が真壁を新しい session で 1 回起こして直す(柏木の 2 回目は無い)。

**版(役員 人見 09-26「0.11.x の patch でいい」):**本便と門は 0.11.1 で出す。musearch 3 面の範囲 `>= 0.11.0 and < 0.12.0` は動かさない。**だから 0.11.0 の公開型を壊さない** ── 既存の record の欄を足さない・変えない、既存の直和に構成子を足さない(利用側の `case` が網羅でなくなる)。足してよいのは新しい型・新しい module・新しい関数だけ。宣言の置き場は新しい const(下の「宣言」)に置く。

**親ゴール:** yumemi の生成器が musearch の 3 面と back の両方を書き切り、musearch の `src/gen` と `api/src/gen` に手書きが残らない状態で閉じる(役員 人見 09-26 01:4x「0.11.0 で生成器は閉じる。中途半端にしない」)。本便はそのうち **back の生成器側と Route の曖昧**を持つ。

**障害:**

- **「3 file」で閉じる。**58 v4 の WGy 行は「`registry` / `http_runtime` / `codec` の 3 file」と数えていた。基点の `api/src/gen` は **369 file のうち 0.11.0 の出力と byte で一致するのは 120**、sha256 ヘッダが無いのが **118**(うち生成器が 1 本も吐かないのが 45)、ヘッダは在るが中身がずれているのが 131(下の棚卸し)。3 file を吐いても 245 file が残る
- **向きが逆のまま。**生成器は手書きの `api/src/gen/http_runtime.mjs` の `const attached=[` を**入力として**読む(`gen/src/yumemi_gen.gleam:214-239`、`model.gleam:378`、`emit/front.gleam:1597`)。http_runtime を生成物にしても、生成器がその生成物を読むなら循環する
- **業務のコードを生成物に混ぜる。**Heaven / lit.link の取得(`heaven_ffi.mjs` 286 行 / `litlink_ffi.mjs` 255 行)や `recoverRosterUpsert` は宣言から導けない。生成器に写して「生成物」と名乗らせると、GENERATED を名乗る手書きが形を変えて残る
- **URL を動かす。**`registry.mjs` の (method, path) は公開の REST v1(`/api/v1/store/*`)と 3 面の島が叩いている。生成器の導出規則に寄せて path を変えると、外の利用者と F6 の面が壊れる
- **F6 と同じ file を触る** ── 本便は musearch を触らないので起きないが、写しを musearch の作業木に向けると起きる

## 棚卸し ── musearch `645ec49` の `api/src/gen`(生成器 v0.11.0 の出力と比べた)

**先頭の 17 file(鷹野の 16 本 + `sql.mjs`)。**「吐く」は v0.11.0 の生成器が同じ path を出すか。

| file | 行 | 吐く | 分類 | 中身 | 行き先 |
|---|---:|---|---|---|---|
| `registry.mjs` | 408 | 吐かない | 手書き(宣言から導ける + 上書き) | Service 122 行の method / path / fields と REST v1 の別名 7 行(計 129 行、`target` / `externalId` / `credential`) | **生成**(HTTP の上書きの宣言を足す) |
| `http_runtime.mjs` | 767 | 吐かない。**生成器の入力** | 手書き(混在) | 入口の検査(host / route / origin / browser / 成人 / rate limit)、cookie・session・`_mb` の署名、Args の decode、`attached` 6 行、業務(`widgetKeys` ── F6 が消す、`recoverRosterUpsert`、`pageviewSuppressed`、blob の put / copy) | 検査の芯は **framework**、decode と attached は**生成**、業務は **★ hook** |
| `codec.mjs` | 385 | 吐かない(生成器は decoder を合わせるために読むだけ、`emit/front.gleam:6649`) | 手書き(宣言から導ける) | entity / types / Args の encode・decode | **生成** |
| `runtime.mjs` | 1132 | 吐かない | 手書き(混在) | 取引の再試行・session・API key の HMAC・invoke / context / DO(framework 相当)、root の集合 15 本・draft の import・関係の decoder(宣言から)、店の時刻・`storeApiKeyIssue`・台帳(業務) | 3 つに割る |
| `driver.mjs` | 17 | 吐かない | framework 相当 | Neon HTTP の transport | **framework** |
| `shell.mjs` | 60 | 吐かない | 混在 | Cloudflare の adapter(fetch / queue / scheduled / `AppSystem`)、cron の式 `0 16 * * *` と DO の class 名 `MusearchUserDo` / `MusearchReleaseDo` | adapter は framework、表は**生成**(cron と DO の宣言を足す) |
| `contracts.mjs` | 31 | 吐かない | framework 相当 | `validateWho`、`foldable`(**実行時に Service の source を正規表現で読む**) | framework。`foldable` は生成時に解く(問い 3) |
| `cron_runtime.mjs` | 64 | 吐かない | 手書き(宣言から + 業務) | `releaseDue` / `rollupMetrics` | 表は**生成**(cron の宣言)、回し方は framework |
| `queue_runtime.mjs` | 63 | 吐かない | 手書き(宣言から導ける) | `registeredKinds` 4 本、id の codec、consumer の表、`sweep` / `consume` | 表は**生成**、sweep / consume は framework |
| `source.mjs` | 16 | 吐かない | 手書き(宣言から導ける) | `entity.visit.Source` の直和の encode / decode | **生成**(codec と同じ口) |
| `heaven_ffi.mjs` | 286 | 吐かない | 手書き(業務) | Heaven の頁の取得・照合 | **★ gen の外へ**(connector の実装、WGm) |
| `litlink_ffi.mjs` | 255 | 吐かない | 手書き(業務) | lit.link の取得 | 同上 |
| `operations_ffi.mjs` | 6 | 吐かない | framework 相当(`rootPhotos` の 1 行だけ業務) | ctx の stage / read / call / enqueue | framework、`rootPhotos` は生成 |
| `key.gleam` | 139 | 吐かない | 手書き(宣言から導ける) | entity の `Key` | **生成** |
| `query.gleam` | 394 | **吐く**(`emit/query.gleam`) | 古い生成物 | Select の値。0.11 は `Pick` と `query/field` `query/from` を足した形 | 再生成で揃う(WGm) |
| `subject.gleam` | 8 | 吐かない | 手書き(宣言から導ける) | entity の `.subject` の 4 つ(★ `entry.gleam` が import) | **生成** |
| `sql.mjs` | 992 | 吐かない | 手書き(束ね) | `db/queries/**` の SQL 文字列の表 | **生成**(queries を束ねる) |

**内訳:**吐く 1 / framework 相当 3 / 混在 3 / 宣言から導ける手書き 8 / 業務の手書き 2 = 17。**yumemi に写し元の framework コードは 1 本も無い**(yumemi の `src/framework/` は Gleam だけで、server の JS を持たない)。「framework の固定コードの写し」に当たる file は無く、framework 相当の手書きが 3 本と、混在の 3 本の中に在る。

**17 本の外(ディレクトリ):**

| 在処 | 数 | 状態 | 行き先 |
|---|---:|---|---|
| `allow/` | 22 | 全部 sha 無しの「GENERATED を名乗る手書き」。v0.11.0(hw-2)が同じ path を吐くが本文が違う(`SystemActor` / `Actor` の型が足りない) | 再生成で揃う(WGm) |
| `connector/` | 9 | sha 無し、生成器は吐かない(`connector.* declaration` と名乗る) | **生成**(connector の境界の emitter を足す) |
| `entry/` | 4 | `http.gleam` は吐くが別物(生成器のは Route 表、musearch のは runtime への FFI 宣言)。`auth` / `queue` / `system` は吐かない | framework 相当の 3 本は framework か生成、`http.gleam` は 1 本に揃える |
| `reads/` | sha 無し 31 | 14 は吐くが違う、17 は吐かない(`store_inbox` の「manual SQL」ほか手書きの読み) | 手書きの SQL を宣言した読みも生成する |
| `root/` | sha 無し 35 | 吐くが違う(6 本はヘッダだけ、`reservation_list_mine` は「handwritten Actor alias」と名乗る) | 再生成で揃う |
| sha 付き | 251 | 120 は一致、131 はずれ(61 はヘッダの sha だけ、70 は本文 ── 古い生成器の出力のまま) | 再生成で揃う |
| 生成器だけが吐く | 36 | `query/field` `query/from`、`reads/` 34 本 | WGm が採る |

**`api/db/queries`(280 本):**GENERATED を名乗る 123(sha 付き 117 / 無し 6)、素の SQL 157(`framework/` 16 本 ── session・outbox・API key、`verb/` の手書き、`allow/` 12 ほか)。v0.11.0 の出力と比べて一致 60 / 違う 42 / 生成器が出さない 178。**`owner Self` の 28 本**は hw-1 から exit 4 で SQL を出さない(`store_roster_list/mine`・`link_import_{read,apply}/latest` を含む、musearch が使っている)。

**生成器の診断(基点、v0.11.0):**exit 1 / 2 / 3 / 4 = 3 / 0 / 0 / 147、警告 49。exit 4 のうち **Route の曖昧が 22**(`schedule_*` の対象が曖昧 16、`store_roster_list` の動詞の入れ子 5、`pageview_record` の対象無し 1)、**`owner Self` が 28**、残り 97 は F6 が消す面の変数の行。

## 宣言 ── 足す 4 つ(新しい module に置き、既存の型の欄は変えない)

1. **HTTP の上書き** ── Service ごとの (method, path)、REST v1 の別名(`target` / 外部 id / credential)。**musearch の `registry.mjs` の現行の 129 行(v1 の 7 行を含む)を正として写し、URL を 1 本も動かさない**。導出規則と同じ行は書かなくてよい
2. **attached(Service でない HTTP の口)** ── `browser_adult` / `session_read` / `session_subject` / `blob_copy` / `media_read` / `socket` の 6 行。**生成器はこれを読み、`http_runtime.mjs` を読まない**
3. **cron** ── 式と、呼ぶ Service / 列挙の読み(`article_release` の `due`、metrics の rollup)
4. **Durable Object** ── class 名と adapter(musearch の `user_do.mjs` / `release_do.mjs` は ★ のまま)

**業務の hook。**宣言から導けない行(Heaven / lit.link の取得、`recoverRosterUpsert`、`pageviewSuppressed`、店の時刻、`storeApiKeyIssue` の特例、台帳)は、生成物が**名前を宣言した hook だけを** import し、実装は gen の外の ★ に置く(問い 2)。生成物が ★ を名指しで import するのはこの口だけ。

## どこまで

1. **行単位の棚卸し** ── 上の 17 本と 4 ディレクトリを行の塊ごとに「framework / 生成 / ★ hook」に割り、`docs/reports/yumemi-gen-8.md` の表に。未分類 0
2. **framework** ── framework 相当の行を yumemi の package に固定の JS として置く(`src/framework/server/` ほか、Hex に載る)。Cloudflare と Neon に寄るのは yumemi の基盤の前提どおり
3. **宣言と reader** ── 上の 4 つ。0.11.0 の公開型を壊さない
4. **emitter** ── `registry.mjs` / `http_runtime.mjs`(検査は framework を呼ぶ形)/ `codec.mjs` / `runtime.mjs` の宣言の部分 / `key.gleam` / `subject.gleam` / `source.mjs` / `sql.mjs` / queue と cron の表 / `shell.mjs` / `connector/*.gleam` / `entry/*.gleam`。全部 sha256 ヘッダ付き
5. **向きを逆に** ── `attached_routes` が読むのを宣言に付け替え、`http_runtime.mjs` を入力として読む行を 0 に。面の emitter(`emit/front.gleam` の `app.attached` の読み手)も宣言から
6. **Route の曖昧(3 面の `api.gleam` ▲ 3 と ★ の route 定数 4 本)** ── 本便で消す。理由:面の `api.gleam` の Route と back の registry を**同じ宣言から**出すのが本便の芯で、ずれ(`api_key` の path と method、console の `StoreRosterList`、www / muses の `ScheduleList`)はその副産物で消える。やること 3 つ:(a) Service の対象を名前の前置きでなく root Entity から解く(`schedule_*` 16 行、`store_roster_list` 5 行、`pageview_record` 1 行 ── **改名しない**、2b-7 の裁定 2)、(b) (method, path) は 1 の宣言から、(c) 面の Route を面が呼ぶ Service だけに絞る(www の `Put` 8 本)。**この 3 つで musearch の ▲ 3 と ★ `muses/src/schedule_routes.gleam`・`console/src/store_api_key_{issue,revoke}_route.gleam`・`www/src/schedule_slots_island.gleam` の route の部分が消せる形になる**(消すのは WGm)
7. **`owner Self` の 28 本** ── hw-1 の鷹野宛 1 の案(主体の鍵の穴)で SQL を出す。exit 4 の 28 行を 0 に
8. **写しで確かめる** ── 下の検収

**しないこと:**musearch への書き込み(写しは `gen/build/wgy/snap/` だけ)、門・rewrite・CSP・pageview・route の順(門の便)、面の `shell.mjs` と `load/**`(Y1f の持ち分で閉じている)、0.11.0 の公開型の既存の欄と構成子、URL の変更、DDL、tag と publish と push、`.claude/_core` `~/.codex` `~/.claude`。

## 門との分け方(並走、merge は本便が先)

- **本便の持ち分:**`gen/src/yumemi_gen.gleam` の `attached_routes`、`model.gleam`、`reader.gleam` の宣言の読み、`emit/entry.gleam`、back の新しい emitter、`emit/front.gleam` の **`api_routes`(5607 行前後)と `app.attached` の読み手だけ**、framework の新しい server の module
- **門の持ち分:**`emit/front.gleam` の `shell_*`(4564 行前後から)と route 表の順、面の lifecycle hook、門の宣言の module
- 同じ file(`front.gleam`)は区画で分ける。区画の外を触りたくなったら止めて鷹野宛に書く

## 失敗例

- 17 本のうち 3 本を吐いて閉じる。`allow/` `connector/` `reads/` `root/` と sha のずれ 131 を「WGm が再生成する」で済ませ、生成器が出さない 45 本を残す
- 生成器がまだ `http_runtime.mjs` を読む(grep 1 行でも)、生成した `http_runtime.mjs` を次の生成の入力にする
- 業務の行を生成物に写して GENERATED を名乗らせる、hook を宣言せず ★ を名指しで import する
- URL を導出規則に寄せて変える、`schedule_*` を改名して曖昧を消す
- 0.11.0 の record に欄を足す、直和に構成子を足す
- 写しを musearch の作業木に向ける、stub だけで測る、`owner Self` を exit 4 のまま閉じる

## 検収(真壁さんが自分で回す)

- root `gleam build` 0、`cd gen && gleam test` が基線以上 + 新規、`gleam format --check src test` 0、Article fixture ×2 で diff 0 と tracked の一致(新しい back の生成物も tracked に足す)
- **`grep -n "http_runtime.mjs" gen/src` が入力の読みとして 0**(生成物の名としての出現は可、表で名指し)
- **写し(musearch `645ec49` の `git archive`)で:**生成器 ×2 で diff 空。exit 4 のうち Route の曖昧 22 と `owner Self` 28 が 0(面の 97 は F6 の射程なので残ってよい、数を名指し)。**写しの `api/src/gen` を生成物で丸ごと置き換え、業務の行を ★ hook に移した写しで、api の `npm test` が基点と同じ数で通る**(PG は `MUSEARCH_TEST_PG_PORT=55540 MUSEARCH_TEST_APP_DB=musearchwgy MUSEARCH_TEST_IDP_DB=idpwgy`、柏木は 55541。55496・5552x・55502/55503 を使わない・止めない)。置き換えた後の `api/src/gen` で sha256 ヘッダの無い file が 0、生成物と byte で一致しない file が 0
- **写しの 3 面の `api.gleam` が生成物のまま**で `api/test/route-match.test.mjs` が通り、生成物と registry の (method, path) が全行一致(www に `Put` が無い)。registry の (method, path) が基点と全行一致(URL を動かしていない)
- 0.11.0 の公開型の差分が「足しただけ」であることを `git diff v0.11.0 -- src/framework` の表で示す
- `## 鷹野宛` に、★ hook に移した行の一覧(WGm が musearch に置く ★ の正)

## 見積

**推定(贄川経路の流儀):最短 7:20 / 中央 10:30 / 最長 18:20。**行単位の棚卸し 0:45、framework の切り出し 2:00、宣言 4 つと reader 1:00、emitter 3:30、向きの付け替え 0:20、Route の曖昧 1:15、`owner Self` 1:00、写しでの確かめ(api の test を生成物で通す)0:40。最長は、写しの test が生成物で通らず runtime を割り直す振れ(× 1.75)。

**直書きの壁時計:**yumemi の hw の比(0.09〜0.11)で真壁 0:57〜1:09、musearch の 2b-8 の比(0.36)で 3:47。本便は写しの api の test まで通すので、hw と 2b-8 の間に寄ると読む。**見張りの止め線 4:00。**柏木 0:15、P0 があれば + 0:15。

## 鷹野への問い ── 起動前に裁く

1. **framework の server の JS を yumemi の Hex package に載せるか。**(a) 載せる ── **推奨**。Cloudflare と Neon に寄るが yumemi の基盤の前提どおり、(b) 生成器が毎回 app の `api/src/gen` に写す(framework の固定コードが生成物として写される。ヘッダは付くが、利用側の数だけ同じコードが増える)
2. **業務の行の置き場。**(a) 生成物は宣言した hook だけを import し、実装は gen の外の ★ ── **推奨**、(b) hook を持たず、業務の行は musearch の ★ Service に移す(`recoverRosterUpsert` などは Service の logic に畳む。WGm が重くなる)
3. **`contracts.mjs` の `foldable`(実行時に Service の source を読む)。**(a) 生成時に解いて registry の `folded` に焼く ── **推奨**、(b) framework に写してそのまま
4. **`owner Self` の 28 本を本便に入れるか。**(a) 入れる ── **推奨**(人見「中途半端にしない」、musearch が使う `store_roster_list/mine` を含む)、(b) 名指しの残りにして WGm は hand の SQL を ★ で持つ

## 鷹野の裁定(2026-09-26 02:2x)

版は 0.11.1(patch、役員 人見 09-26)。問いは全部推奨で採る。
1. **(a)** server の JS は yumemi の Hex package に載せる(`src/framework/server/` ほか)
2. **(a)** 業務の行は gen の外の ★ に置き、生成物は宣言した hook だけを import する
3. **(a)** `foldable` は生成時に解く。実行時に Service の source を読む行を 0 に
4. **(a)** `owner Self` の 28 本は本便に入れる
- 門の便(yumemi-gate-1)と並走する。`emit/front.gleam` は区画で持ち分を分け、merge は本便が先。門の区画に触らない
