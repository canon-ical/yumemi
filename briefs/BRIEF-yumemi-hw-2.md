# BRIEF yumemi-hw-2 ── Actor の統一(`gen/allow` を生成物にし、生成 root の `Actor` を `allow.Actor` に寄せる)、Hex 0.11.0 は hw-1 と合わせて 1 回(2026-09-25、水無瀬[PL] 起草 → 鷹野[PDM] が裁いた)

便: yumemi-hw-2

**真壁さんへ。本便は 1 session で直に書き、終端で柏木のゲートを 1 回だけ受けます(贄川は通しません)。**基点は `impl/yumemi-1f` の `c2519de`(Y1f、承認済み・未 merge)。**hw-1(読みの宿題 6 件)が同じ基点から並走します** ── `reader.gleam` / `model.gleam` / `emit/{typing,reads,query,sql,verb}.gleam` は hw-1 の持ち分で、本便は触りません。merge の順は decode-1 → Y1f → hw-1 → 本便。front も触りません。

**親ゴール:** 生成 root が import している `gen/allow` を生成物にし、root の `Actor` と allow の `Actor` を 1 つの名に揃える。これで musearch の root ▲ 15 本と allow ▲ 22 本を「生成物で置ける」形にする(musearch の ▲ を外すのは後の追随便)。

**障害:**
- **生成物が、生成されない module を指す** ── 生成 root は `import gen/allow/<m> as allow` を吐くが、生成器は `gen/allow` を 1 本も吐かない。musearch の ▲ 22 本の半分(11 本)は `Actor` を持たない
- **名が 2 系統ある** ── 生成 root は `Anonymous` / `AsStaff` / `AsStore` / `AsMuse` / `AsFan`、musearch の ▲ は `StoreActor` / `StaffActor` / `MuseActor` / `FanActor` / `AuthenticatedActor` / `AnyActor`。★ は後者で書かれているので、生成器の名に寄せると ★ が壊れる

## 現在地(`c2519de` × musearch main `728adfa` の写し、水無瀬 09-25 実測。musearch は書かない)

- `emit/root.gleam:93-171`(`actor_plan` / `actor_declaration`)が、root ごとに独自の `Actor` を吐く。単節は主体の型をそのまま使い(`Direct`)、複数節と `Anyone` だけの形は独自の sum(`Sum`)になる。写しの出力に `gen/allow` は 0 本
- model の Service は allow について `allow_module` と `subjects` しか持たない(`model.gleam:384-397`)── owner / at の句は読まれていない。**読む口は reader の外に置けます**:front は `reader/front.gleam` と `front_emit.emit(app, units, …)`(`yumemi_gen.gleam:188`)で、units を直に読む先例
- musearch の allow ▲ は 22 本・839 行(`Who` / `At` / `Owner` / `Clause` / `PartyActor` / `SystemActor` / `Actor` と判定)。`Actor` を持たないのは fan / prep / reservation / notification / subscription / ledger / store_request / metric_rollup / shift_target / muse_schedule / store_request_notify。`ledger` と `store_request_notify` は Entity でなく、ER 外 module と Service 単位の allow
- ★ の参照(`api/src/service`):`allow.Clause` 140 行、`AnyPhase` 86 / `AsMuse` 64 / `Only` 54 / `NoOwner` 54 / `Self` 44 / `ViaMuseParty` 29 / `AsStore` 26 / `Anyone` 16 / `Staff` 14 / `ViaStoreParty` 13、Actor の variant は `PartyActor` 9 / `SystemActor` 7 / `AuthenticatedActor` 7 / `AnyActor` 7 / `MuseActor` 2 / `FanActor` 2 / `StoreActor` 1 / `StaffActor` 1、判定は `is_self` 10 / `is_staff` 5 / `party_of` 1
- root ▲ のうち Actor が理由のもの 15 本:Actor だけ 13(`article_search` / `course_add` / `course_edit` / `course_retire` / `muse_read` / `reservation_list_mine` / `roster_list` / `space_list` / `store_read` / `store_schedule_list` / `subscription_add` / `subscription_read` / `widget_list`)+ Root の欄も違う 2(`pageview_record` / `roster_read`、Root の欄は本便の外)。`article_search` だけは `fn(allow.AnyActor, …)` と書く

## どこまで

1. **allow の句を読む口を `reader/allow.gleam`(新)に閉じる** ── ★ の `allow.*` の用法(`Who` / `At` / `Owner` / `Clause` の構成子と、判定の呼び出し)を units から allow module ごとに集める。`reader.gleam` / `model.gleam` / `typing.gleam` は触らない。触らずに済まないと分かったら、書く前に止めて終端で返す(鷹野は 1 本に戻す)
2. **`src/gen/allow/<module>.gleam` を生成物にする**(sha256 ヘッダ付き)── `Who` / `At` / `Owner` / `Clause` / `PartyActor` / `SystemActor` / `Actor`(と `AnyActor` の別名)と、★ が呼ぶ判定 `is_self` / `is_staff` / `party_of`。**名は musearch の ▲ 22 本に合わせる。**owner の名から party への道(`Via<Entity>Party` = その Entity の party)の規則は、hw-1 の allow 句と同じ規則にし、results に 1 行で書く
3. **生成 root の `Actor` は、`Sum` の形なら `pub type Actor = allow.Actor`** にし、root 独自の variant を出さない。`Direct` の形は今のまま
4. **登録は `yumemi_gen.gleam` の emit と notes に数行。**input hash は `emit/hash.gleam` の既存の口で取る(新しい口が要るなら `emit/allow.gleam` の中に置く)

**しないこと:**allow SQL と `root.sql` の生成、`runtime.mjs`、root の `Root` の欄(version・onboard の形・`Root(at, seed)` への潰れ)、hw-1 の file、front、musearch と `~/yumemism_repo/yumemi-decode-1` の木への書き込み、`gleam.toml` の version、publish、push、`main` への commit。

## 失敗例

- root を `allow.Actor` の別名にして、allow を生成しない(Actor の無い 11 本で compile が落ちる)
- ★ の名を生成器の名に寄せ、★ 140 行を動かす前提にする。`reader.gleam` に手を入れる
- `yumemi_gen_test.gleam` の既存の test を書き換える(追記だけにする ── hw-1 との merge を追記の衝突だけにするため)
- fixture でだけ通して、写しで build しない(G7 の P0 の轍)

## 検収(真壁さんが自分で回す)

- root `gleam build` 0、`cd gen && gleam test` **194 以上**(正と負:owner が複数 / `Only` の phase / `Party` / `System` / 判定が要る句 / Entity でない allow module)。fixture を 2 回生成して diff 空・tracked と一致(増えた `gen/allow` は名指し)
- 写し `728adfa`(run の外に置き、musearch は書かない)に 2 回当てて diff 空。exit 4 の back 22 行・警告 48 は動かさない
- **写しの `api/` に生成 `gen/allow` 全部と生成 root を被せて `cd api && gleam build` 0**(★ は 1 字も直さない)。被せられない allow module は名と理由を名指しし、3 本を超えたら止めて終端で返す
- 写しで、root 15 本と allow 22 本の生成物と musearch の ▲ の本文の対照表を作る(差は行ごとに理由)
- `docs/reports/yumemi-hw-2.md` に `## DDL`(無し)・`## 鷹野宛`・`## 追随便への申し送り`(musearch の ▲ のうち生成物で置ける file の一覧)。終端は承認かエスカレーション

## 鷹野の裁定(09-25)

- **2 本に割る。**壁時計が一番足りない予算(役員 人見)なので、最重の Actor を並走に出す。交わりは `yumemi_gen_test.gleam` への追記と、emit の登録の数行だけ。本便が reader / model / typing に触る必要があるなら、割らずに 1 本へ戻す
- **Actor の名は musearch の ▲ に揃える**(★ 140 行を動かさない)
- **Hex は 0.11.0**。hw-1 と本便の両方を merge してから、1 回で出す。本便の merge は hw-1 の後で、衝突(test の追記)は鷹野が畳む
- **見積(推定):**最短 2:00 / 中央 2:40 / 最長 4:15、予算 200 分(中央 × 1.25)
