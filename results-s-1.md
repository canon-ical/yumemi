# yumemi-s-1 真壁 ── 0.11.5:門の戻り先(RedirectBack・FixedKeep)、root.sql の欠けを生成で止める、面の部分集合を実行時の門に(2026-09-28)

証跡は `gen/build/s1-*.txt`(git の外)。入力の musearch は main `fb911d6b` を `git archive` した写し(musearch には書いていない)。

## 状態

- 1〜5 は全部済み。版 0.11.5(`gleam.toml`・`gen/manifest.toml`)
- root build 0、format 0(root・gen)、gen test 314 / 0(0.11.4 の 305 + 足した 9)、fixture ×2 差 0
- musearch main を入力にした生成:exit 0、診断は基点と同じ行、1773 file のうち差は `src/gen/registry.mjs` の 7 行だけ(`s1-ms-diff.txt`・`s1-registry-diff.txt`)

## 1・2 門

- `framework/gate` に `Fail.RedirectBack(location, param)` と `To.FixedKeep(location)` を足した(既存の型は変えていない)
- RedirectBack:302 で `location` へ、`param` に要求の path + search を `encodeURIComponent`。`location` が query を持てば `&`。path + search は門の `safeParam` で判定し、面の中の path でなければ(`//` で始まる等)param を付けない。宣言で `location` が `/` 始まり・`//` でない・`#` 無し、`param` が `[A-Za-z0-9_.-]+` でなければ exit 4
- FixedKeep:302 で `location` + 要求の search。`location` に `?`・`#` があれば exit 4。`Fixed` は今のまま(query を落とす)
- client 遷移:fetch は `redirect: "manual"` なので門の 302 は opaqueredirect になり、`navigate.mjs` は `url.href`(hash 付き)の頁の読み込みに落ちる。門の応答は印の header があっても無くても同じ 302(test で確認)。hash は server に届かないので、Location に hash を持たない 302 の上で browser が元の hash を引き継ぐ形で保つ
- **使わない門の `gate.mjs` は 0.11.4 と同じ字**。redirectBack の関数と分岐・fixed-keep の分岐は、宣言がその語を使う門にだけ足す(`emit/gate.gleam` の `runtime_for`)。musearch 4 面・fixture の gate.mjs は差 0

## 3 root.sql

- `emit/back.gleam` の `root_sql_notes`:root の Entity を持つ Service(`root.root_for` が Some)で `db/queries/<name>/root.sql`(生成の SQL も含む束)が無ければ exit 3、Service 名と Entity を出す
- 止めないもの:hook `service_<name>` を持つ Service(port、musearch の `notification_mark_read`)、root の 1 文を持つ Service から queue で呼ばれる consumer(`reservation_notify`・`store_request_notify`)、`Rootless`(`pageview_record`)と Entity の無い root。musearch の `sql:null` の 4 本はこの 3 つに全部入る
- musearch main:exit 0。写しから `store_edit/root.sql` を抜くと exit 3「service.store_edit: root(store)を読む db/queries/store_edit/root.sql が無い(実行時に 503)」(`s1-ms-cut.txt`)
- **fixture `article` に root.sql を 4 本足した**(`gen/fixtures/article/db/queries/article_{create,publish,read,retract}/root.sql`)。fixture は root(article)を宣言しながら root.sql を持たず、新しい検査にそのまま掛かる(実行すれば 503 の形)。足した分だけ tracked の `runtime.mjs` の roots 4 行と `sql.mjs` の 4 本が変わる。他の fixture の生成物は差 0

## 4 面の部分集合

- 選んだ形:**`entry` は今のまま残し、`entries` を足す**。面 1 つ → `entry: '<name>'`(0.11.4 と同じ)。面 2 つ以上で、この Service の行に検査 2 で当たりうる入口 ── 媒体(Session / ApiKey、本体の行と `server.aliases` の媒体)が合い、ReadOnly の入口なら Read の Service ── が面の外に残るときだけ `entries: [..]`。当たりうる入口を全部面に持つ Service には何も付けない
- 理由:musearch の 4 面(`[Www, Muses, Console, Admin]`)は入口 5 本の全部ではない(api は ApiKey)。「全部の入口」で判定すると 98 本に `entries` が付いて生成物が変わる。当たりうる入口で判定すると 4 面・5 面とも付かない
- runtime:`framework/server/http.mjs` の検査 7 に `if(s.record?.entries&&!s.record.entries.includes(s.entry.name)) fail('forbidden',403)` を 1 行
- musearch main:`course_{add,edit,retire}` に `entries: ['console', 'admin']`、`chat_{list,open,read}`・`message_send` に `entries: ['www', 'muses']`。この 7 行の他は registry も全 file も差 0。生成した行を検査 7 に通すと course_* は www・muses で 403、console・admin で 200(`s1-ms-403.txt`)

## test(gen/test/yumemi_s1_test.gleam、9 本)

- 読み 2(RedirectBack・FixedKeep、負例 7 形:外の origin・`//`・`#`・`=` 入りの param・空の param・`?` 付き FixedKeep・`//` の FixedKeep)
- gate.mjs 2(使わない門の runtime が 0.11.4 の字、node で 10 手:面の中の符号化・query 無し・`&` の連結・client 遷移の fetch・`//evil.example` で param 無し・通る・FixedKeep の query 有り / 無し・Fixed は落とす・未 sign-in で FixedKeep しない)
- root.sql 2(fixture の写しで 1 本抜くと exit 3、port の hook があれば止めない)
- entries 3(fixture は付かない、ReadOnly の Session 入口と ApiKey 入口を足すと Read の Service だけ `entries`・Write は付かない・面 1 つは `entry`、検査 7 を node で 6 手)

## DDL

無し。

## 残り

- musearch への取り込み(門の宣言を RedirectBack / FixedKeep に書き換え、registry の差し替え)は S-2b
- 実 API・Workerd で門の 302 と検査 7 の 403 を押していない(node で gate.mjs と http.mjs を直に回した)
- `RedirectBack` の 302 に browser が元の hash を引き継ぐと、戻り先の頁の URL に hash が付く(`/?returnTo=%2Fme#x`)。param の値には hash は入らない
