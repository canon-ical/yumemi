# yumemi-hw-2 ゲート所見(柏木[CM]、2026-09-25)

対象は `git diff c2519de 9381d1e`(8 file、+1613 −54)。要求は `BRIEF-yumemi-hw-2.md`、真壁の報告は `docs/reports/yumemi-hw-2.md`。コードは直していない。証拠のログは `gen/build/kashiwagi-hw2/`(git 管理外)に置いた。

**判定:承認(P0 無し)。**P1 は 2 件、P2 は 3 件。

## 再走した検収

| 項目 | 結果 | 証拠 |
|---|---|---|
| `cd gen && gleam test` | **212 passed, no failures**(exit 0) | `test.txt` |
| root `gleam build` | exit 0、警告 1(既存の `src/framework/secret.gleam`) | `root-build.txt` |
| Article fixture を 2 回生成 | 2 回とも exit 0 で 113 file、`diff -r` 0 行。tracked の生成物 51 本は byte 一致。増えたのは `src/gen/allow/article.gleam` だけ | `fx1.log` `fx2.log` |
| 写し `728adfa` に 2 回当てる(`git archive` から `/tmp` へ取った。musearch は読んだだけで、`git status` は clean) | 2 回とも exit 4 で 1394 file。差は `{muses,www}/_diagnostics/*-runtime.txt` の `Downloaded 11 packages in 0.01s / 0.02s` の 2 行だけ(P2-2) | `s1.log` `s2.log` `snap-diff.txt` |
| 基線の生成器(`c2519de` の木を丸ごと取った)で写しに当てる | 1372 file。**`_diagnostics.txt` は本便の出力と完全に一致**(164 行、exit 4 は 111 行、警告 48)。差は `src/gen/allow` の 22 本の追加と、Sum の root 21 本だけ | `sb.log` `sb-s1.txt` |
| 写しの `api/` に生成物を被せて `gleam build` | allow 21 本(`page_view` 以外)と root 103 本(報告の 19 本以外)を被せて **exit 0**。★ は 1 字も直していない。生成した allow / root から出る警告は 0(警告が出た root 2 本 `muse_edit_profile` / `muse_onboard` は被せていない ▲)。全部被せると exit 1 で、落ちるのは `service/{pageview_record,schedule_availability,roster_remove}` と `gen/reads/{roster_read,store_request_notify}` ── 除いた 19 本と allow `page_view` の理由と合う | `ov-build.txt` `ov-all-build.txt` |
| 生成物の書式とヘッダ | 写しの `src/gen/{allow,root}` は `gleam format --check` 0。sha256 ヘッダの欠けは 0 | ― |
| root 15 本の対照表 | ▲ を `gleam format` して 1 行目を除いて比べた。差無し 11 本、`muse_read` 1 行、`article_search` / `pageview_record` / `roster_read` の差の中身は報告の表と一致 | ― |
| hw-1 との試し merge(`git merge-tree impl/yumemi-hw-1 impl/yumemi-hw-2`) | 衝突無し。merge 後の木で `gleam test` **230 passed, no failures**。merge 後の生成器で写しに当てた `src/gen/{allow,root}` は本便の出力と 0 行差 | `merged-test.txt` `sm.log` |

## 見ること 1〜5

1. **「どこまで」と「検収」:満たしている。**読む口は `reader/allow.gleam` に閉じ、登録は `yumemi_gen.gleam` の emit / notes と import(+12 −2)、input hash は `emit/allow.gleam` の中。検収は上の表のとおり再走で確かめた
2. **生成 allow の判定と `Via<X>Party` は、musearch の ▲ と意味で一致している。認可が緩む向きの差は無い**
   - 句の評価は `http_runtime.mjs:560-580` が `c.tag(x.who)` / `c.tag(x.at)` / `c.tag(x.owner)` で構成子の class 名から取る(`codec.mjs:135`)。生成物の `Who` / `At` / `Owner` の構成子の名は ★ の句から取っているので、tag は ▲ と同じになる。★ が使わない構成子を出さないことは、評価を変えない
   - `is_self`:muse / store は `muse_id.to_string(a) == muse_id.to_string(b)` が `a == b` になった。`MuseId(value: String)` の `to_string` は `value.value` を返すだけなので、同値。roster は比べる左右が入れ替わっただけ。どれも最後の枝は `_ -> False`
   - `is_staff`(store / roster)と `party_of`(muse)は ▲ と同一。course の `is_staff` は ★ が呼ばないので出ない(被せた build が 0 で裏付く)
   - `Via<X>Party` の規則は診断(exit 4 / 5)にしか効かない。owner の意味は tag(`via_muse_party` / `via_store_party`)で SQL 側が決める。規則の綴りは hw-1 と 1 点ずれている(P2-1)
   - `runtime.mjs` と `queue_runtime.mjs` が名指しで組む allow の構成子 23 種と、`runtime.mjs:228` が module を選んで組む `PartyActor`(fan / consent / subscription / notification / muse)を生成物と照合した。無いのは `article.AuthenticatedActor` と `page_view.AuthenticatedActor` の 2 つだけで、報告と一致
3. **鷹野宛 1(既存 test 3 行の書き換え)は、裁定 3 の必然。**`root_bundle_uses_allow_and_args_key_test` は fixture の `article_read`(Anyone + Staff の Sum)が `pub type Actor {` / `Anonymous` / `AsStaff(staff.Staff)` を持つことを固定している。「Sum なら別名」にすると 3 行とも偽になるので、test を直すか fixture を変えるしかない。3 行をその場で置き換えたのが最小の変更。hw-1 の同じ file の変更(1619 行付近と末尾の追記)とは hunk が重ならず、試し merge は衝突しない。失敗例に当たることを隠さず鷹野宛に上げた扱いも正しい
4. **鷹野宛 3 は、musearch が生成物を採ったときに実行時の失敗になる。認可の穴にはならない。**
   - `runtime.mjs:233` の既定の枝に落ちる HTTP の Service は、写しの 122 本のうち `article_read` だけ(`reservation_notify` / `store_request_notify` は `queue_runtime.mjs` が actor を組む)
   - 被せた build の JS で `new allowArticle.AuthenticatedActor(...)` を実際に呼ぶと、`TypeError: a.AuthenticatedActor is not a constructor` で投げる。例外は `http_runtime.mjs:422` の catch が失敗応答にするので、閉じる向きに倒れる。ログインした利用者の `article_read` が失敗応答になる、という形の不具合
   - ★ `article_read` は `_by` を使わない。匿名の枝の `allowArticle.AnyActor` は生成物にも在る
   - 同じ形の穴は、`schedule_availability` の root を生成物にしたときの `runtime.mjs:217-219`(`record.root.AsMuse` など)にもある。報告の申し送りに書いてある
5. **hw-1 の持ち分には触っていない。**`reader.gleam` / `model.gleam` / `emit/{typing,reads,query,sql,verb}.gleam` と front は、差分の file 一覧に 1 本も無い

## P0

無し。

## P1(技術的負債。サマリに残す)

- **P1-1 生成 allow `article` を採る便では、`runtime.mjs:233` を同時に直す**(鷹野宛 3)。直さずに ▲ を外すと、ログインした利用者の `article_read` が `TypeError` で失敗応答になる。閉じる向きなので認可の穴ではない。`schedule_availability` の root と `runtime.mjs:217-219` も同じ(鷹野宛 2)
- **P1-2 `allow.is_<x>(` の `<x>` が Entity でなくても、診断を出さずに `False` を返す関数を出す**(`emit/allow.gleam:404-407`、`:544-547`)。`<x>` が Entity で、その主体の variant が無い場合の `False` は正しい(その値は作れない)。ところが `is_anonymous` / `is_authenticated` のような Entity でない名でも、同じく黙って常に `False` になる。★ が「`is_<x>` なら拒む」と書くと、拒むべきものを通す向きに倒れる。いまの ★ と fixture が呼ぶのは `is_self` / `is_staff` / `party_of` だけなので、実害は無い。`<x>` が Entity の module に無ければ exit 4 か 5 の診断を出すのがよい

## P2(不整合・追従漏れ。今回は直していない)

- **P2-1 `Via<X>Party` の X の引き方が hw-1 と違う。**本便は `type_name` で探し(`emit/allow.gleam:246`、`:610-615` の `entity_by_type`)、hw-1 は `name` で探す(`impl/yumemi-hw-1` の `emit/sql.gleam:1006` の `model.entity_by_name`)。報告は「hw-1 の SQL 側と同じ規則」と書いているが、`type_name` と `name` が違う Entity では結果が分かれる。写しでは `consent_version`(`name` は `ConsentVersion`、`type_name` は `ConsentVersionRow`)が当たる。★ に `ViaConsentVersionParty` は無いので、いまは表に出ない。分かれてもどちらかが exit 4 を出すので、緩む向きではない。merge のときに `model.entity_by_name` へ 1 行で揃えられる
- **P2-2 報告の数字が 2 か所、実物と違う。**(a) 「警告は 138 → 120」:`hw2-overlay-build.txt` は `Compiled in 0.21s` の差分ビルドで、recompile した module の警告しか数えていない。丸ごと build し直すと 138 → **135**。「生成した allow / root に警告は 0」は正しい。(b) 写しへの 2 回生成の「`diff -r` 0 行」:front の runtime のビルドログ(`{muses,www}/_diagnostics/*-runtime.txt`)にある `Downloaded … in 0.0Ns` の時間で揺れる。僕の再走では 2 行ずつの差が出た。これは本便の前からある揺れで、本便の出力(`src/gen/*`、`_diagnostics.txt`)は 0 行差
- **P2-3 `Only([x.Y])` の `x` が `entity/` の外の module を指すと、`reader/allow.gleam:205-214` は道をそのまま返し、生成物は `import entity/<道>` と `Only(List(<道>.Phase))` という壊れた行になる。**診断は出ないが、compile で落ちるので黙っては通らない。写しと fixture には当たる句が無い

## 走らせたコマンド

```
cd gen && gleam test                                                     # 212 passed, no failures
gleam build(worktree の root)                                            # exit 0、警告 1
gleam run -m yumemi_gen -- fixtures/article /tmp/kashiwagi-hw2/fx{1,2}   # exit 0 ×2、113 file、diff -r 0
gleam run -m yumemi_gen -- /tmp/kashiwagi-hw2/ms/api /tmp/kashiwagi-hw2/s{1,2}   # exit 4 ×2、1394 file
(c2519de の木) gleam run -m yumemi_gen -- …/ms/api …/sb                 # exit 4、1372 file、_diagnostics 一致
(写しの api、allow 21 + root 103 を被せる) gleam build                   # exit 0、警告 135(基線 138)
(git merge-tree の木) cd gen && gleam test                              # 230 passed, no failures
node:被せた build の gen/allow/article.mjs で new AuthenticatedActor    # TypeError
```

## 判定

**承認。P0 無し。**
