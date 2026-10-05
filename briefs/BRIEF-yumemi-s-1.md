# 真壁[IM]へ ── yumemi 0.11.5(便 yumemi-s-1、門の戻り先と生成器の穴 2 つ、直書き、鷹野[PDM] 2026-09-28)

便: yumemi-s-1

作業木 `~/yumemism_repo/yumemi-s-1`(branch `impl/yumemi-s-1`、基点 yumemi main の本 BRIEF の commit = v0.11.4 の上)。本便は 1 session で直に書き、終端で柏木のゲートを 1 回だけ受ける。記録は `results-s-1.md`(リポ直下、先例 `results.md`)。commit は `git-as makabe`(path 指定)、`main` に触らない、push・tag・Hex の publish は鷹野。**版は 0.11.5**(`gleam.toml` と `gen/` の版)。

**親ゴール:** musearch の門が、止めた要求を戻り先付きで送れる。生成器が、実行時に 503 や認可の抜けになる宣言を生成の時に止める(musearch 第2便 2c の小便 S-1、tech `_drafts/musearch/69-impl-batch-2c.v0.md` の S-1 の行と、66 の宿題 2・4)。
- 障害:門の `Fail` に「戻り先を付けて面の中へ送る」語が無い(`src/framework/gate.gleam:57-64`)。musearch は成人の申告の無い客を `/?returnTo=<path+search>` へ、店の初回 sign-in を `/switch?next=…`・`/consent?next=…` へ送れない
- 障害:`To.Fixed` が query を落とす(musearch 2c-3 で `/me/feed` → `/tl` を門で書けず Worker の入口に逃がした)
- 障害:root を持つ Service に `db/queries/<name>/root.sql` が無くても生成器は exit 0 で `sql:null` を出し、実行時に 503(musearch S-3 で `store_edit` が踏んだ)
- 障害:`faces` が 2 つ以上 4 未満の Service(例 `[Console, Admin]`)は registry に `entry` が付かず、実行時の門にならない(musearch S-3 r2 の真壁の所見)。面を絞った宣言が他の host から通る

## どこまで

1. **`Fail.RedirectBack(location: String, param: String)`** ── 302 で面の中の `location` へ。query `param` に要求の path + search を URL 符号化して付ける。`param` の値が面の中の path でなければ付けない(open redirect にしない ── `SafeParam` の判定を共有する)。client 遷移(0.11.4 の全面 SPA)の門の応答でも同じに効く
2. **`To.Fixed` に query を保つ形** ── `Fixed(location)` は今のまま、`FixedKeep(location)` を足して要求の query と(client 遷移なら)hash を保つ。既存の生成物は変わらない
3. **root.sql の欠けを生成で止める** ── root を宣言した Service の `db/queries/<name>/root.sql` が無ければ、生成器は Service 名を出して非 0 で止まる。**musearch の今の 141 本で止まらないこと**を、musearch main を入力にして確かめる(root を別の経路で作る 4 本 ── port・Rootless・queue の base ── は止めない)
4. **面の部分集合を実行時の門にする** ── registry に `entries`(許す入口の集合)を出し、runtime はその集合に無い入口の要求を 403 にする。4 面全部の Service と 1 面の Service の振る舞いは変えない(今の `entry` の形を保つか、`entries` に畳むかは実装の選択、results に書く)。musearch main を入力にして、`[Console, Admin]` の `course_*` が www の host で 403 になる生成物が出ることを確かめる(musearch への取り込みは S-2b)
5. **docs** ── `docs/` の門と registry の節、CHANGELOG(あれば)に 0.11.5

**しないこと:**既存の公開型の変更・削除(足すだけ)、musearch への書き込み(読むのは入力として)、push・tag・publish。

## 失敗例(これをやったら差し戻し)

`RedirectBack` が外の origin へ送れる。既存の `Fixed` の振る舞いを変える。3 で musearch の今の宣言が止まる。4 で 4 面全部の Service が 403 になる。生成物の既定の出力が 0.11.4 と黙って変わる(変わるのは 3・4 で宣言したものだけ)。

## 検収

- root の build 0、`gen` の test(0.11.4 の 305 本 + 足した分)、format 0
- 1・2:門の test(面の中 / 外 / 符号化 / client 遷移)、open redirect の負例
- 3:root.sql を 1 本抜いた fixture で非 0、musearch main の入力で 0
- 4:musearch main を入力に生成して、registry の `course_*` に許す入口 2 つ、www の要求が 403(runtime の test)、4 面の Service と 1 面の Service の生成物の差 0(sha の頭の行を除く)
- musearch main を入力にした生成で、1〜4 で宣言していない Service の生成物の差 0

## 見積

中央 2:00。直書きの比で真壁 0:30〜0:50、柏木 0:20。**止め線は経過 2 時間(壁時計ではない)。**
