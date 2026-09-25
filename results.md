# yumemi-hw-1 真壁 r1 ── back の宿題 6 件(2026-09-25)

## 状態

- 6 項(逆向き矢印・無診断・allow 句・札の素通り・`'draft'`・列の選択)を全部実装し、各項に正と負の test を付けた。詳細・契約・対照表は `docs/reports/yumemi-hw-1.md`
- **残り 1 点は鷹野の裁定待ち**:allow 句の owner `Self` は party の穴で表せないので、brief どおり exit 4 にした。写しでは読み 28 本の SQL が出なくなり、そこに musearch 採用済みの `store_roster_list/mine`・`link_import_{read,apply}/latest` も入る。案(subject の穴)は report の「鷹野宛」1
- hw-2 の持ち分(`emit/root.gleam`・`emit/allow.gleam`・`reader/allow.gleam`)と front は触っていない。新しい test は `gen/test/yumemi_gen_hw1_test.gleam` に置いた。`yumemi_gen_test.gleam` は、5 の helper 本体の 4 行と末尾への 1 本の追記だけ

## DDL

無し。

## 検証

- root `gleam build`: exit 0、warning 1(既存)。`gen/build/hw1/root-build-final.txt`
- `cd gen && gleam test`: **212 passed, no failures**(194 + 18)。`gleam format --check src test` は 0。`gen/build/hw1/test-3.txt`
- fixture article ×2: exit 0 で 112 file、diff は 0。tracked の生成物 51 file も一致。基線との差は allow 句 3 本と `gen/query.gleam`
- 写し `728adfa` ×2: exit 4、1344 file(back 697)。差は runtime build の記録の時間 1 行だけ。exit 1/3/4 = 3/1/139(back 22→50、+28 は全部 `Self`。face 89 は同一)。警告は 48(module 名 24 は同一)。`gen/build/hw1/snap-summary.txt`
- 札 24 名を `manual_verbs` へ移した写し:札の警告は 0、exit 4 は同一
- 生成した reads 4 本と、Pick の reads を写しの api に重ねて `gleam build`:exit 0。`gen/build/hw1/{overlay,pick-overlay}-build.txt`

## 確かめていないこと

- 生成した SQL(allow 句・Pick)を Postgres で走らせていない。musearch の runtime は `-- allow:` の行をまだ読まない(追随便の仕事)

# gen-7 柏木ゲート 2 P0 直し (巡 9)

## 状態

- bundle 用一時 package に生成された面を入力面の上から重ねる。esbuild の `import-is-undefined` を error にした。
- bundle 失敗は面ごとに `NotImplemented(1)` の Note として返し、`_diagnostics.txt` と stderr に各1行を残す。失敗面の素の `client.mjs` は削除する。
- 存在する `shell.gleam` の `lang` / `title` / `theme` const と theme の各欄が欠けると `Missing(3)`。file 自体が無い場合は従来どおり1件の `Missing(3)`。
- 診断の改行と一時パスを正規化して、同じ入力の `_diagnostics.txt` を byte 一致にした。Hex 依存の一時 package には入力面の `manifest.toml` を写し、再走時の Hex API rate limit を回避した。path 依存の fixture は従来どおり manifest を作り直す。
- fixture / snapshot の再走を完了し、`docs/reports/gen-7.md` の「3面とも本物の bundle」を撤回した。

## DDL

無し。migration / schema / database は変更していない。

## 検証

- `cd gen && gleam test`: **159 passed, no failures** (154 + 5)。`gen/build/gen7-g2-test-final.txt`。
- 追加試験: `client_bundle_uses_generated_output_over_input_test`、`client_bundle_stops_on_undefined_import_test`、`client_bundle_failures_remain_per_face_notes_test`、`present_shell_missing_consts_are_exit_three_test`、`present_shell_missing_theme_field_is_exit_three_test`。
- `gleam build` (root): exit 0、既存 warning 1 (`src/framework/secret.gleam:5`)。`build/gen7-g2-root-build.txt`。
- fixture generator: 各 exit 0 / **88 file**、最終2回の `diff -rq` 空。tracked `public/src/gen` / `priv` と untracked `src/gen` / `db` も出力と一致。`gen/build/gen7-g2-fixture-c.txt`、`-d.txt`、`gen7-g2-fixture-final-diff.txt`。
- fixture `public` の `gleam build`: exit 0 / warning 0。SSR、isolate、given は ALL PASS、Block preview は PASS (6 blocks)。`gen/build/gen7-g2-public-build.txt`、`gen/build/gen7-g2-verify-front-*.txt`、`gen/build/gen7-g2-build-blocks.txt`。
- snapshot `9c2b0bd`: run_dir の `ms-9c2b0bd/api` を読み、run_dir 内 `out-gen7-g2-f` / `out-gen7-g2-g` に出力。両回とも generator exit 4、生成報告1181 file、client 3件削除後の実体1178 file、再走 `diff -rq` 空。exit 1 = 5 (metrics 2 + client: www 1 / muses 1 / console 1)、exit 2 = 0、exit 3 = 1 (www shell)、exit 4 = 20、warning 29。各面の失敗は生成物を使った runtime build で発生。`gen/build/gen7-g2-snapshot-f.txt`、`-g.txt`、`gen7-g2-snapshot-final-diff.txt`。
- www の ★ component は5 fileで `view` 5本、`app` 0本。ただし snapshot は runtime build で先に止まったため、この入力で esbuild の未定義 import は未到達。合成 package の停止試験は通過。
- `gleam format --check`: fixture 52 `.gleam` / snapshot 816 `.gleam` で exit 0。先頭 sha256 header 欠けは fixture 88 file と snapshot 実体1178 fileで各0 (`_diagnostics.txt` を除く)。

## 確かめていないこと

- snapshot の3面 client は runtime build が止まるため実行・表示は未確認。www の `app` 未 export は実ソースで確認したが、snapshot の esbuild 段でのエラーは未到達。

# gen-7 束 E ── 動詞 → method 対応表

## DDL

無し。DDL / migration / schema は変更していない。

## 状態

- `entry.gleam` の route 対応を修正。add は key 型の引数があっても collection path にし、edit / remove は PUT / DELETE として動的 key path を使う。`root_for` は変更していない。
- 同一 face 内で method と path 形が重なる route を Conflict(exit 4)にする。`{id}` と `{slug}` も同じ path 形として検査する。`route_methods` fixture で create/add、put/edit、delete/remove の3組を置いた。
- front-scratch stub は未変更。Article fixture の route には add / edit / remove がなく、再生成した `public/src/gen/` は fresh output と diff 0。
- 対応表(一般形):

| 動詞 | 変更前 | 変更後 |
|---|---|---|
| create | POST `/<plural>` | POST `/<plural>` |
| read | GET `/<plural>/:id` | GET `/<plural>/:id` |
| list | GET `/<plural>` | GET `/<plural>` |
| delete | DELETE `/<plural>/:id` | DELETE `/<plural>/:id` |
| put | PUT `/<plural>/:id` | PUT `/<plural>/:id` |
| add | POST `/<plural>/add` or `/<plural>/:id/add` when a key matches | POST `/<plural>` |
| edit | POST `/<plural>/:id/edit` | PUT `/<plural>/:id` |
| remove | POST `/<plural>/:id/remove` | DELETE `/<plural>/:id` |

`add` の変更前は key 引数がある場合に `/:id` が入り、無ければ collection に `/add` が付いた。変更後は key 引数を path に載せない。edit は key 引数が無い `setting_edit` で `PUT /api/muse_settings` となった。

## 検証

- root `gleam build`: exit 0、warning 1件のみ (`src/framework/secret.gleam` の既存 unused private constructor)。`build/gen7-e-root-build-final.txt`
- `cd gen && gleam test`: **149 passed, no failures** (基線146 + 3)。`gen/build/gen7-e-test-final.txt`
- overlap CLI fixture: exit 4、3件の衝突を実測。`gen/build/gen7-e-route-overlap-cli.txt`
- `gleam run -m yumemi_gen -- fixtures/article fixtures/article`: exit 0 / 88 files。client Out decoder 5 modules、runtime build、esbuild PASS。fresh output と tracked `public/src/gen/` の diff 0。`gen/build/gen7-e-fixture-final.txt`、`gen/build/gen7-e-fixture-public-final-diff.txt`
- musearch 固定 snapshot `/home/yumemism/.codex-agents/runs/niekawa-20260924-044509-82060-7565/ms-9c2b0bd/api` を読み取り、生成先は同じ run 外の `out-ms-e-before/` と `out-ms-e/`。`musearch` には書いていない。
- snapshot の route は 390件→390件。add / edit / remove の変更は service URL 単位で **9 / 7 / 6**、face 展開後で **36 / 28 / 25**。`schedule_add` は前後とも既存の target ambiguity で route が無い。`roster_remove` は `/api/v1/store/...` の別 prefix を持つため unique method/path template は remove が7件。比較表: `gen/build/gen7-e-route-comparison.txt`。
- snapshot の既存 diagnostics は exit 4 が20件、warning が29件で前後同じ。新しい route overlap diagnostics は0件。各生成ログ: `gen/build/gen7-e-snapshot-before.log`、`gen/build/gen7-e-snapshot-after-final.log`。
- historical 「採用済み一致」290 は BRIEF の `c99c107` snapshot の数。今回の `ms-9c2b0bd` は別入力で、route registry checker も非system service数を87固定、今回の入力は103のためそのまま再計測できない。今回の registry method/path を直接突合すると **47→53**、生成 route row は390で不変。checker の固定数診断: `gen/build/gen7-e-route-audit-guard.txt`。

---

# gen-7 ── A 差し戻し r2 (P0 decoder compile)

## DDL

無し。migration / schema / database / src/framework/ / root gleam.toml は変更していない。

## 状態

- P0-1: custom type と opaque framework type の decoder を型に合わせ、fixture article_create.Out に別 module の enum field を追加した。
- P0-2: 完了。gen/fixtures/article 自身へ2回生成し、2回目の後で generated file manifest の SHA-256 差分が空。
- gen/src/yumemi_gen/emit/front.gleam の変更関数: decoder_for_type / named_decoder / model_ref_decoder / custom_or_alias_decoder / custom_decoder / relation_decoder / relation_property_decoder / opaque_model_decoder / collect_named / collect_model_named / relation_type / out_file。untagged custom union の decode.one_of と Nil / Key / PartyId の decoder を追加した。
- enum は enum_decoder の文字列値から variant への分岐、record は variant_decoder → field_decoder_chain、別 module の型は model_ref_decoder から module path を辿って同じ enum / record decoder を使う。AliasRedirect / ValueAlias は元宣言と backing type を辿る。
- fixture input は gen/fixtures/article/src/service/article_create.gleam を変更し、Out(slug: Slug, phase: article.Phase) を追加。logic も Out を返す。Page/Block の手書き file は変更していない。
- gen/src/yumemi_gen_ffi.mjs は client bundle 検証を分けた。現行生成 out/*.gleam 全件の decoder() を temporary Gleam package から import して型検査し、続いて input face の client module 群と現行生成 client.mjs で runtime build / esbuild を行う。snapshot にある未移行の SSR gen/load / API table / live module は client bundle の dependency ではないので runtime 側は input face のものを使う。

## 検証

- cd gen && gleam test: 138 passed, no failures。既存132 + 追加6。gen/build/gen7-r2-test-nil-typed.txt。
- 指定 snapshot に対する gleam run -m yumemi_gen -- <snapshot>/api <scratch>: 1175 files。client Out decoder build は console 17 modules PASS / muses 43 modules PASS / www 14 modules PASS。3面の runtime build と esbuild も PASS、生成 client.mjs は www 142863 bytes / muses 330453 bytes / console 279200 bytes。gen/build/gen7-r2-snapshot-probe10.log。
- snapshot 生成器全体は exit 4。基線の declaration diagnostics を返した。client Out decoder build / runtime build / esbuild の exit 1 は無し。snapshot の api/ は読み取りのみ。
- snapshot current output www/muses/console/src/gen/out/**/*.gleam の decode.dynamic は 0件。Nil は decode.new_primitive_decoder + dynamic.classify, Key は key(raw), PartyId は party.parse。Blob / framework time の placeholder parser は従来どおり。
- fixture scratch generation: 86 files、client Out decoder 5 modules PASS、runtime build / esbuild PASS。public/src/gen/out/article_create.gleam は phase: Phase と "Draft" -> decode.success(Draft) を含む。client client.mjs は 187578 bytes。gen/build/gen7-r2-fixture-probe3.log。
- fixture 自身への生成を同じ条件で2回実行。両方 86 files / Out decoder 5 modules PASS / runtime build / esbuild PASS。証拠: gen/build/gen7-r2-fixture-first.log、gen/build/gen7-r2-fixture-second.log。
- fixture generated output は public/src/gen 24 files、src/gen 28 files、db/queries 32 files、public/priv/static 2 files。既存 tracked output は22 file更新、新規 generator output は60 file。before/after SHA-256 manifest が一致: gen/build/gen7-r2-fixture-generated-before.sha256 / gen/build/gen7-r2-fixture-generated-after.sha256。
- public/src の差分は public/src/gen/ 内だけ。src/ の入力差分は P0-1 で追加した article_create.gleam だけで、widget_list.gleam / entry.gleam / types.gleam / widget*.gleam / service/ / entity/ / trailing_spread.gleam は未変更。
- cd gen && gleam test を fixture 再生成後にも実行し 138 passed, no failures。gen/build/gen7-r2-test-p0-2-final.txt。
- gleam format は変更した Gleam source / test に実行済み。
- full face package を現行 generated SSR/live files まで含めた試行では、P0 decoder 以外の snapshot migration 差分が残った。例: console/src/gen/load/switch/page.gleam が session_switch.view(Nil) を生成、muses の blocks_preview.gleam も widget_list.view(Nil)、www の既存 browser_adult / component は旧 gen/api / gen/live contract を参照する。この full face package build は PASS と確認していない。client bundle 検証はそれらを含めず、現行 Out decoder と client runtime の範囲を検査した。

### 追加した試験 (6)

- front_emit_decodes_custom_record_with_cross_module_enum_test
- front_emit_decodes_er_key_from_string_test
- front_emit_decodes_nil_out_with_typed_result_test
- front_emit_decodes_party_id_with_parser_test
- front_emit_decodes_untagged_custom_union_test
- front_emit_aliases_local_service_return_as_out_test

---

# gen-7 ── A1 生成器の口: 複数 variant decoder

## 状態

- `custom_decoder` が複数 variant の fields 型を共通の string-like 判別欄で分岐し、全 constructor と欄を保持する decoder を出す。`kind` を優先し、無い場合は唯一の共通候補欄を使う。未知 tag は decode failure にし、判別欄が曖昧なら `NotImplemented` で停止する。
- A1 の追加試験は4本: `front_emit_decodes_both_fixture_row_variants_test`、`front_emit_decodes_six_snapshot_style_row_variants_test`、`front_emit_decodes_non_row_custom_union_test`、`front_emit_undiscriminable_union_has_stop_diagnostic_test`。

## DDL

無し。

## 検証

- `cd gen && gleam test`: **132 passed, no failures**。`gen/build/gen7-a-test-a1.txt`。
- 指定 musearch snapshot 生成: parse を通過し、client build の型エラー3件で **exit 1**。診断 `[exit 2 ...]` は **0件**。`gen/build/gen7-a-snapshot-a1d.log`。
- snapshot `www/src/gen/out/widget_list.gleam`: tag 分岐 **6/6**。`Articles.articles`、`Links.links`、`HeavenDiary.heaven_public`、`HeavenReview.heaven_public` を constructor に保持。`gen/build/gen7-a-snapshot-a1d/www/src/gen/out/widget_list.gleam`。

## A2 — spread の後の末尾カンマ

- glance の `7.0.0` は維持。glexer token 列と bracket nesting から `[... ..rest,]` のカンマ位置を識別し、同じ位置を空白にしてから glance へ渡す。入力全体への正規表現置換はしていない。
- `gen/fixtures/article/src/trailing_spread.gleam` を1本追加。`source.load(fixture)` がその Unit を含めて parse する試験にし、Gleam formatter への `--stdin` 入力も exit 0 で受理された。formatter が fixture ファイル自身を正規化してカンマを消すため、入力 fixture は formatter に書き戻していない。
- `cd gen && gleam test`: **132 passed, no failures**。`gen/build/gen7-a2-test.txt`。
- `gleam run -m yumemi_gen -- fixtures/article build/gen7-a2-fixture`: **exit 0 / 86 files**。`gen/build/gen7-a2-fixture.log`。
- fixture と指定 snapshot の `.gleam` を同型 spread-comma で検索し、発見は追加 fixture 1箇所だけ。`fixtures/article/src/trailing_spread.gleam:4`。

## A3 — 生成 `.gleam` の format

- 出力を書いた後、生成一覧中の全 `.gleam` に `gleam format` を実行する。formatter の失敗は `NotImplemented` (exit 1) にする。
- fixture generation 2回: **各 exit 0 / 86 files**、`diff -qr` は空。`gleam format --check build/gen7-a-fixture-final1`: **exit 0**。50個の `.gleam` 全てに sha256 header あり。証拠: `gen/build/gen7-a-fixture-final1.log`、`gen/build/gen7-a-fixture-final2.log`。
- formatter 失敗注入: **exit 1**, `[exit 1 生成器の不足] gleam format に失敗した: status=73`。`gen/build/gen7-a-format-fail.log`。

## A4 — client bundle の失敗を停止にする

- client bundle 用 Gleam build / esbuild の失敗時は fallback entry を書かず、出力の `client.mjs` を除去して `NotImplemented` (exit 1) で停止する。
- build 失敗注入: **exit 1 / status 74**。esbuild 失敗注入: **exit 1 / status 81**。両方とも診断は `[exit 1 生成器の不足]`、出力 client file は存在しない。証拠: `gen/build/gen7-a4-build-fail.log`、`gen/build/gen7-a4-esbuild-fail.log`。
- repository root は面の `gleam.toml` にある `yumemi.path` を面ディレクトリから解決する。generator を cwd `gen/build`、out dir を別 scratch で起動し、**exit 0 / 86 files / bundle 成功**。証拠: `gen/build/gen7-a4-cwdroot.log`。
- 指定 snapshot は **1172 files** を生成して client bundle build の型エラー3件で exit 1。診断 **exit 2 は0件**、snapshot `widget_list` decoder は **6/6 variant** と `articles` / `links` / 2つの `heaven_public` を保持、出力 formatter check は exit 0。失敗した www client file は残っていない。証拠: `gen/build/gen7-a-snapshot-final.log`、`gen/build/gen7-a-snapshot-final/www/src/gen/out/widget_list.gleam`。

## 共通

- root `gleam build`: **exit 0**。既存 `src/framework/secret.gleam` の unused private constructor warning が1件。`gen/build/gen7-a-root-build.txt`。
- `cd gen && gleam test`: **132 passed, no failures** (既存128 + A1で追加4)。`gen/build/gen7-a-final-test.txt`。

---

# 指示 段B 差し戻し ── 写し `out/<service>.gleam` の import を正す

## 状態

- `gen/src/yumemi_gen/emit/front.gleam` の型解決を、許可された `gleam/*`・`framework/*`・`gen/service` 以外は back package の型宣言を再帰的に写す規則へ修正した。`gen/draft/*` は生成 draft を読み取り単位にして同じ規則で写し、トップレベル module も source unit から写す。
- `framework/blob` / `framework/time` は import に戻し、`framework/er` の `Has` / `Held` / `Multi` の透明再定義は維持した。型名衝突の候補は同一 file の予約名全体で `Row` へ綴り替える。
- `api.gleam` の path を `{x}` から `:x` へ変換した。fixture の checked-in front 生成物も追随させた。
- import allowlist の全 `out/*.gleam` 走査、`gen/draft`・トップレベル module・`framework/blob` の source-string 入力テストを追加した。既存テストは削除していない。

## DDL

無し。migration / schema / staging / production への適用はしていない。

## 検証

- root `gleam build`: **exit 0**。既存の `src/framework/secret.gleam` unused private constructor warning 1件。`build/gen6-b2-root-build.txt`
- `cd gen && gleam test`: **112 passed, no failures**。`gen/build/gen6-b2-test-code.txt`
- fixture generator: **exit 0 / 71 file**。back **60 file diff 0**、面 `src/gen` **11 file**。`gen/build/gen6-b2-fixture-generate.txt`、`gen/build/gen6-b2-fixture-back-diff-final.txt`、`gen/build/gen6-b2-counts-final.txt`
- fixture の ▲ 4本(`blocks.gleam`、`widgets.gleam`、`service.gleam`、`out/article_read.gleam`)は本文 diff **0**。`gen/build/gen6-b2-blocks-body-final.diff` ほか同名3本、`gen/build/gen6-b2-out-article-read-body-final.diff`
- `cd gen/fixtures/article/public && gleam build`: **exit 0**。`build/gen6-b2-public-build.txt`
- 指定 snapshot のみを入力に生成: **exit 4**、診断 **exit 0 = 29 / exit 3 = 0 / exit 4 = 18**、back **604 file diff 0**。`gen/build/gen6-b2-musearch-generate.txt`、`gen/build/gen6-b2-musearch-back-diff-final.txt`
- snapshot の `www/src/gen/**` の許可表外 import: **0件**。一時コピーした www package の build も **exit 0**。`gen/build/gen6-b2-face-import-violations-final.txt`、`gen/build/gen6-b2-musearch-www-build.txt`
- snapshot の `route.gleam` / `api.gleam`: `{x}` path **0件**、変数 path は colon 記法。`gen/build/gen6-b2-counts-final.txt`

## 鷹野宛

- 入力は `/home/yumemism/.codex-agents/runs/niekawa-20260922-061417-3399503-22265/ms-96fb8cc/api` の固定 snapshot のみ。live `musearch` へは読み書きしていない。
- back 側の emit・生成物、DDL、migration、Hex、push、`main` は触っていない。

# 指示 gen-6 段B ── 面の生成物6種

## 状態

- branch `gen-6`。front emit を追加し、面 `public` の出力先を
  `public/src/gen/` に固定した。back の出力先・生成束は変更していない。
- 面側に route / blocks / widgets / service / api と、back の全6 Service 分の
  `out/{article_create,article_list,article_publish,article_read,article_retract,widget_list}.gleam`
  を追加した。
- `out/` は再輸出をせず、Service の出力型・参照 Entity・gen/types の別名を写し、
  `framework/er` の `Has/Held/Multi`、`framework/time` の `Date/Datetime/Time`、
  `framework/blob` の `Blob` は面側で透明に再定義した。
- `widget_list` の `Row.Article` は同一 module の Entity `Article` 構成子と衝突するため、
  面側の写しだけ `ArticleRow` とした。面 package の build は通過している。

## DDL

無し。migration / schema / staging / production への適用はしていない。

## 検証

- root `gleam build`: **exit 0**。既存 `src/framework/secret.gleam` の unused private
  constructor warning 1件。証拠: `build/stage-b-root-build-final-3.txt`
- `cd gen && gleam test`: **110 passed, no failures**。証拠: `gen/build/stage-b-test-final-3.txt`
- fixture generator `gleam run -m yumemi_gen -- fixtures/article fixtures/article`:
  **exit 0 / 71 file**。証拠: `gen/build/stage-b-fixture-generate-final-2.txt`
- fixture `public` build: **exit 0**。既存 transitive dependency warning のみ。証拠:
  `gen/build/stage-b-public-build-final-2.txt`
- back は基線の **60 file** と file / 本文 / header sha の diff 0。証拠:
  `gen/build/stage-b-back-diff-final-3.txt`
- fixture の手書き ▲ 4本(`blocks.gleam`, `widgets.gleam`, `service.gleam`,
  `out/article_read.gleam`)は header 以外の本文 diff 0。証拠:
  `gen/build/stage-b-blocks-body-final-4.diff`、`stage-b-widgets-body-final-4.diff`、
  `stage-b-service-body-final-4.diff`、`stage-b-out-body-final-4.diff`
- musearch 固定 snapshot は **exit 4 / exit 0 警告 29 / exit 3 = 0 / exit 4 = 18 /
  back 604 file**。同一 snapshot の再生成で back 本文 diff 0。証拠:
  `gen/build/stage-b-musearch-final-2-run.txt`、`stage-b-musearch-final-2-counts.txt`、
  `stage-b-musearch-final-2-body-diff.txt`

## 鷹野宛

- musearch には書き込んでいない。入力は指定 snapshot のみ、出力は `gen/build/`。
- 段C以降の生成物はまだ出していない。

# 指示 A2 ── 検査 gate を外し、fixture の面を 51 v5 に合わせる

## 状態

- branch `gen-6`、開始 `819cdc8`。checkpoint `f0d6584`。push / `main` / live musearch の書込みは無し。
- 面が見つかった後の `front.notes` は `pages` 欄の有無によらず常時実行。面の発見条件と、入口/面不足の診断 gate は変更していない。
- fixture の Page path を `arg_id` から `arg_slug` へ変更し、layout/page の2つの Widget を `WidgetList` へ向けた。`WidgetKey`、rootless `widget_list` read、front の `WidgetList` variant を追加した。
- `src/widget.gleam` は `widget_list` の HTTP collection 名だけを与える非Entity宣言。query は `Article` だけを読むため、Widget Entity の追加・絞り込みはしていない。
- front/back の emit 種追加と back 生成器の変更は無し。front の手書き ▲ は `public/src/gen/service.gleam` の `WidgetList` 1 variant だけを変更した。

## DDL

無し。migration、schema、staging、production への適用はしていない。

## 検証

- root `gleam build`: compile 完了、既存 `src/framework/secret.gleam` の unused private constructor warning 1件。証拠: `build/a2-root-build.txt`
- `cd gen && gleam test`: **105 passed, no failures**。証拠: `gen/build/a2-test-final.txt`
- fixture generator: **exit 0 / 60 files**、診断ファイル無し。証拠: `gen/build/a2-fixture-generate.txt`
- fixture diff: `diff -r` は `gen/build/a2-fixture-diff.txt`。動いたのは次の5系統だけ。
  - `src/gen/entry/http.gleam`: 追加 read の Public/Admin route 2行と入力 hash。
  - `src/gen/face.gleam`: entry/service 入力 hash のみ。Face variant 本文は不変。
  - `src/gen/reads/widget_list.gleam`: `widget_list.items` の read。
  - `src/gen/root/widget_list.gleam`: rootless Service の器。
  - `db/queries/widget_list/items.sql`: Article を Published allow と公開時刻降順で読む SQL。
- musearch snapshot `/home/yumemism/.codex-agents/runs/niekawa-20260922-061417-3399503-22265/ms-96fb8cc/api` のみを入力: **exit 4 / exit 0 = 29 / exit 3 = 0 / exit 4 = 18 / 604 files**。基線との差は **0行**。証拠: `gen/build/a2-musearch-generate.txt`、`gen/build/a2-musearch-counts.txt`、`gen/build/a2-musearch-diff.txt`
- live `/home/yumemism/yumemism_repo/musearch` の `git status --short`: **0行**。証拠: `gen/build/a2-live-musearch-status.txt`
- `cd gen/fixtures/article/public && gleam build`: compile 完了。既存の transitive dependency warning のみ。証拠: `gen/build/a2-public-build.txt`

## 鷹野宛

- gate 無しで fixture の検査 8本は 0件。負例の符号・文言を含む既存 105 test は全て通過した。
- musearch の現物で front 検査を有効にする作業は本便の外。`api/src/entry.gleam` の `pages: AllPages` と `api/gleam.toml` の依存窓変更が別追随便に要る。

## musearch 追随便への申し送り

- **front の検査 8 本を musearch の現物で効かせるには、`api/src/entry.gleam` に `pages: AllPages` を書き、`api/gleam.toml` の yumemi 依存窓(現 `>= 0.5.0 and < 0.6.0`)を引き上げる**(鷹野の裁定 9、2026-09-22 06:15)。**本便の射程外** ── F4 の「どこまで A」に足す候補で、足すかどうかは鷹野が F4 の BRIEF に書く。gate を外した生成器を `96fb8cc` に当てても診断は 0 件なので、追随便で欄を書いた時点で初めて検査が効く。
- 入力は引き続き固定 snapshot `ms-96fb8cc`。live の `musearch` は入力にも出力にも使っていない。
- fixture の WidgetList は route 用の非Entity collection を持つが、Article の query と rootless read だけで成立している。既存 5 Service の Args と Entity は変更していない。

# 指示 gen-6 段A ── 面の発見と front model / 検査

## 状態

- branch `gen-6`、開始点 `6cbc9dd`。checkpoint `a0907a4` / `dac8d5b` を作業中に打った。
- fixture の面を `gen/fixtures/article/www/` から `public/` へ移し、入口 `public` と
  `gleam.toml` / Layout const / Page の layout 参照 / front harness の写し元を揃えた。
  `gen/fixtures/article/src/entry.gleam` は変更していない。
- `gen/src/yumemi_gen/face.gleam` が `dirname(app_dir)` と `app_dir` の直下だけを探索し、
  `Http` + `gleam.toml` + `src/layout.gleam` の3条件で面を選ぶ。`HttpApi` は面にしない。
  面の source は `src/gen/` を除いて parse し、parse failure は exit 2、入口/面の不足は
  `pages: AllPages` と3条件に従う exit 3 で診断する。
- `gen/src/yumemi_gen/reader/front.gleam` に Layout / Page / Frame / Area / Placement /
  Block / Component / Style / WidgetKey / Service variant の model と、検査8本の診断を追加。
  front の emit はまだ無い。`pages` 未宣言の面は model まで読み、legacy の既存入力を
  新診断で止めず、`AllPages` を明示した入口だけ front notes を CLI に載せる。
- back の `reader.gleam`、back emit、back 生成物、DDL、musearch は変更していない。

## DDL

無し。migration / schema は作成していない。staging / production にも適用していない。

## 検証証拠

- root `gleam build`: exit 0。既存の `src/framework/secret.gleam` unused private constructor
  warning 1件のみ。`build/root-gleam-build-gen6-stagea.txt`
- `cd gen && gleam test`: **105 passed, no failures**。`gen/build/gen6-test-final.txt`
- fixture generator: **exit 0 / 57 files**。current `/tmp/gen6-fx-current.emStLr` と main
  `/tmp/gen6-fx-main.FwWK7A` の `diff -r` は **0行**。
  `gen/build/gen6-fixture-diff.txt`、実行ログは `/tmp/gen6-fx-current-log.3mNfLG` /
  `/tmp/gen6-fx-main-log.j08VtV`
- `cd gen/fixtures/article/public && gleam build`: exit 0。既存の transitive dependency
  warning のみ。`gen/build/gen6-fixture-public-build.txt`
- musearch は指定 snapshot `/home/yumemism/.codex-agents/runs/niekawa-20260922-053343-3290951-5762/ms-96fb8cc` の `api/` だけを入力にした。
  `gleam run` は exit 4、`/tmp/gen6-ms` は **604 files**、`_diagnostics.txt` は
  `exit 0 = 29`、`exit 3 = 0`、`exit 4 = 18`。`gen/build/gen6-musearch-final.txt`
- live `/home/yumemism/yumemism_repo/musearch` の `git status --short` は空。
- source-string 負例: discovery 4本、model 4本、検査8本を `gen/test/yumemi_gen_test.gleam`
  に追加。各検査で stop class と1行文言を確認した。

## 鷹野宛

- front の出力はこの段では1種も追加していない。次段で `src/gen/route.gleam` などを
  model から emit する入口は `front.Front` に分離してある。
- `pages` 欄が無い入口は、指定どおり面 folder があれば読み、無ければ Missing を黙って
  飛ばす。既存の0.7.0未追随 package を止めないため、front content の stop は
  `pages: AllPages` を明示した入口に限定した。

## musearch 追随便への申し送り

- 入力は引き続き snapshot `ms-96fb8cc` を固定し、live `musearch` を generator の入力/出力に
  使わないこと。
- `www/` の source は face reader で読み、Page URL は folder 木から `/muse/{handle}` の形に
  なる。次段の emit は `www/src/gen/**` の手書き ▲ と `diff -r` で突き合わせる。

# front-1c 真壁 道具の向き直しと報告

## 状態

- branch: `front-1c`。道具と verify の checkpoint は 1 本(`0a5cb99`)へ squash 済み。
  便全体は 真壁 3 本(framework / 面 package / 道具と報告)と 贄川 の P2 2 本。
- `gen/scripts/` の front 4 本だけを backup 枝から写し、面の `www/src` を scratch の
  `src/` へコピーする形にした。`www/src/gen/**` も同時にコピーする。
- `docs/reports/front-1c.md` に 14 型表、v4 → v5、56 差分、数字、P1 / Y2 の申し送りを
  記録した。
- `gen/src/**` / `gen/test/**`、musearch の本体、staging、production は変更していない。
  push も無い。

## DDL

無し。migration / schema 変更は無く、staging / production へ適用していない。

## 検証証拠

- `gleam build`: compile 完了。`build/root-gleam-build-front-1c.txt`
- `cd gen && gleam test`: **86 passed, no failures**。
  `build/gen-gleam-test-front-1c.txt`
- `gleam run -m yumemi_gen -- fixtures/article _out/front-1c-report`:
  **57 files / input units 11**。`build/generate-front-1c.txt`
- `node gen/scripts/verify-front-ssr.mjs`: **ALL PASS**、JS 無し本文、style 1 本・body
  先頭、島 `❤ 1 -> ❤ 13`、browser error 0。
  `build/verify-front-ssr.txt`
- `node gen/scripts/verify-front-isolate.mjs`: **ALL PASS**、40 回、style 長 first 322 /
  second 191、marker 混入 0。`build/verify-front-isolate.txt`

# gen-5 真壁 route 段3 作業結果

## 状態

- branch: `gen-5`。段3をR0〜R5へ変更した。Entityは末尾語の最長一致、ER外moduleは`collection`宣言の完全一致だけで対象を引く。
- scratchpadの87 Serviceは正しく出る82、止まる5。停止は`schedule_add/list/withdraw`の曖昧、`pageview_record`の無一致、`store_roster_list`のR4入れ子。
- mainのmusearchは変更していない。台帳2 + metrics2のcollection宣言、`ledger`改名、参照書換は写しだけに行った。
- route registry突合は`gen/_out/gen-5/scratch/service-table-final.tsv`（87行）と`registry-compare-final.tsv`（98行）。検証器の`silent_mismatch`集計は0、raw URLの末尾形差は別欄。検証器の未知collectionを一致扱いするP1があり、0だけを完全な検出保証とは扱わない（`docs/reports/gen-5.md`）。

## DDL

無し。migration / schema変更は無く、staging / productionへ適用していない。

## 検証証拠

- `gen/build/gen-5-gleam-test-final.txt`: `gleam test` 72 passed, no failures。
- `gen/build/gen-5-probe-scratch-final2.txt`: probe 0 → 333 → 129 → 129。
- `gen/build/gen-5-verify-route-table-final.txt`: route table PASS、7 rows。
- `gen/build/gen-5-verify-gate2-sql-final.txt`: 7 checks PASS。
- `gen/build/gen-5-verify-root-ffi-final.txt`: 8 checks PASS。
- `gen/build/gen-5-audit-final.json`: Service 87、route 326、registry 98、正しく出る82・止まる5。
- ゲート2: `gen/_out/kashiwagi-gate2/route-build.txt` / `compiled-route.txt`。生成route表を独立buildし、コンパイル後の326行・82 Serviceの全フィールドをソースと照合した。probeの129エラーが残るbuildだけではこの確認は成立していなかった。

## gen-4 差分と残差

- 検証器の黙って誤り集計は0（前記P1の限界あり）。gen-4の正しく停止だった台帳2 + metrics2は、mainでは宣言無しで停止し、scratchpadではroute化した。
- 末尾形・単複・prefix・root/key・foldedのregistry差は残差として別欄に保持した。Logic / readsによる曖昧解消、`pageview_record`、`store_roster_list`の扱いは別便。

---

# gen-4 真壁 巡2 作業結果

## 状態

- branch: `gen-4`、開始HEAD: `5d84089550408f014d9e07774428642f7ae4c0a4`。
- 柏木ゲート2のP0 4件を修正した。
- prefix欠落・不正はentry名付きexit 4。faces必須検査はentry不在・entries空でも動く。
- root判定は複合key/path_keyの構成要素を照合し、root 2変数は許可、合計3変数はexit 4。
- SQLは単一FKのHas/Held/Linkに対するHas/HasNoneと、逆向きHeldのwithだけを生成する。順方向withとMultiへのHas/HasNoneは未生成・exit 1。
- NotImplementedだけの診断をexit 0にしていた`stop.worst`をexit 1へ修正した。
- musearch本体と正典ファイルは変更していない。生成器から`.mjs`は出していない。

## DDL

無し。migration / schema変更は無く、staging / productionへ適用していない。

## 検証証拠

- 回帰test: `build/gleam-test-final.txt` ── 68 passed, no failures（61 + 7）。
- 負例CLI: `build/regression-cli-final.txt` ── prefix / entry無し / entries空 / 未知面 / 3変数はexit 4、SQL 2形はexit 1。
- route表: `build/verify-route-table-final.txt` ── PASS、7 rows。
- PG SQL: `build/verify-gate2-sql-final.txt` ── 7 PASS。
- root FFI: `build/verify-root-ffi-final.txt` ── 8 PASS。
- 生成物比較: `build/artifact-comparison-final.txt` ── 本便4 SQLとarticle route表が修正前とbyte一致。
- current musearch: `build/generate-musearch-final.txt` / `build/r2-out/musearch/_diagnostics.txt`。

## 数字

- current musearch: 635 files、faces不足exit 4 = 92、prefix不足exit 4 = 5、exit 1 = 0、exit 3 = 1、warning = 21、`.mjs` = 0。停止コード4。
- fixture article: 55 files、route 7行。
- SQL負例fixture: 23 files、対象SQL 2本は未生成、停止コード1。

## 残差

- current musearchの5入口はprefix未追随、92 Serviceはfaces未追随。生成器は名指しで停止するが、musearch側は本便の書込範囲外。
- entry hashへのEntity追加(P1)、同host 2入口、付属入口、`along` / `FirstPerGroup` / `At` / `KeyOf`は未実装のまま。
- 対象Entity無し・動詞空は既存どおりexit 4を維持した。

---

# 指示 A2 ── P0 4件と仮宣言コピー(2026-09-21)

## 状態

- branch `verb-1`。開始 `eacd8b5`。checkpoint は `9bc9a99` / `69cd3a7`。main・staging・production・musearch本番は変更していない。
- boolean cast、通常 delete の `RETURNING` 除去、Draft/Created由来の create RETURNING、単一 phase gate、Update の完全名と `upsert_key` lookup を実装した。
- `verify-verb-sql` 段1は引用文字列・二重引用識別子・dollar quote の内側を保持して、外側の記号周りだけ正規化する self-test を追加した。
- 仮宣言コピーには手書き11本、E類2本、`reorder_widgets`、`update_roster_by_external` を追加。札3本(`advance_article` / `delete_roster_photo` / `delete_store_schedule`)は生成SQLから消え、headerに11名が出る。

## DDL

無し。gate2 harness の検証用 `article` DDL に `phase` / `entered_draft` と `$7` の試験値を追随させただけ。staging / productionへは適用していない。

## 検証証拠

- `build/a2-gleam-test.txt`: `75 passed, no failures`。
- `build/a2-route-table.txt`: route `7 rows` PASS。`build/a2-gate2.txt`: `7` PASS。`build/a2-root-ffi.txt`: `8` PASS。
- `build/a2-verify-main.txt`: generated `241` / handwritten `61` / both `28` / stage1 `6`。一致名は `delete_free_space`, `delete_link`, `delete_widget`, `update_free_space_title`, `update_free_space_visible`, `update_widget_visible`。
- `build/a2-verify-decl.txt`: generated `231` / both `27` / handwritten-only `34` / stage1 `6`。`reorder_widgets` と `update_roster_by_external` が出力。
- `build/a2-verb-self-test.txt`: quoted literal 不一致、`update_free_space_title` 段1一致の2本 PASS。
- `build/a2-diff.txt`: baselineとの差は `db/queries/verb/` 内だけ(241本、外は0、`Only in`も0)。
- 贄川[ORC]が同じ7検査を独立に再現した(run_dir `niekawa-20260921-054627-1324991-3859/evidence/n2-*.txt`)── `gleam test` 75 / route 7 / gate2 7 / root-ffi 8 / stage1 6 / self-test 2本 PASS / `diff -r`の差は`db/queries/verb/`内だけ。`a2-route-table.txt` / `a2-root-ffi.txt` / `a2-verb-self-test.txt` はその再現の写し。

## 残差

- 手書き側の `*Created` 不一致6本(`create_consent`, `create_muse`, `create_screen_reject`, `create_roster`, `create_article`, `create_muse_heaven`)は★手書きを生成へ寄せるF3。生成器の穴ではない。なお固定 `baseline-out/src/gen/draft/article.gleam` の `ArticleCreated` は実測9欄で、指示書の7欄前提とは不一致。生成は実物のDraft/Createdに合わせて9欄を維持した。
- `advance_muse_heaven` / `advance_roster`: ★ Entity に version/連番入力が無く、handの楽観ロックと bump を導けない。`update_article_posted_on`: generic updateのversion bump規則とhandが不一致。`update_store_verified`: generatorのrequire_rows包みとhandの素UPDATEが不一致。
- `update_muse_theme` は gateまで生成したが、★ Museに `version` Propertyが無いため bumpは推測せず未生成。`create_roster` の claim系欄も `auto_key` 宣言が無いため除外していない。

---

# 指示 A3 ── H 類と欠落キャスト(2026-09-21)

## 状態

- branch `verb-1`。A3 の生成器変更、突合器、gate2 検証ハーネス、fixture test、報告を作業域へ反映した。
- `musearch-main` は読み取りのみ。`musearch-decl` は指定された `free_space` / `link` の `ordered_by` 宣言だけを追加した。
- `create_widget` / `create_free_space` / `create_link` は親 `FOR UPDATE`、within 全列の `IS NOT DISTINCT FROM`、`COALESCE(max(...)+1,0)` を一文の CTE + INSERT で出す。`create_links` は語彙が無いため生成していない。

## DDL

無し。gate2 の一時 schema にだけ `category` 表と `cat` 行を追加し、ordered create の親 lock を検証した。staging / production へは当てていない。

## 検証証拠

- `gen/build/a3-h-gleam-test.txt`: `76 passed, no failures`。
- `gen/build/a3-h-route-table.txt`: `verify-route-table: PASS (7 rows, face/http scratch build)`。
- `gen/build/a3-h-gate2.txt`: P0-1 / P0-7 / P0-2 / P0-3 / Range / P0-5 / P0-4 の 7 行 PASS。
- `gen/build/a3-h-root-ffi.txt`: `verify-root-ffi: 8 checks PASS`。
- `gen/build/a3-h-main-generate.txt`: `書いた: 635 ファイル`、exit 4、exit 4 診断 34 行。
- `gen/build/a3-h-main-vs-n2.txt`: 差 0。`gen/build/a3-h-main-vs-baseline.txt`: 差分は `db/queries/verb/` 内だけ。
- `gen/build/a3-h-verify-main.txt`: generated 241 / handwritten 61 / both 28 / stage1 6 / stage2 10 / missing-cast-ph 5 / missing-cast-ty 4。by-placeholder は 7 placeholder、by-type は 5 cast。
- `gen/build/a3-h-verify-decl.txt`: generated 235 / both 29 / stage1 6 / stage2 11 / missing-cast-ph 2 / missing-cast-ty 1。by-placeholder は 3 placeholder、by-type は 1 cast。
- `gen/build/a3-h-verb-self-test.txt`: 既存 2 本 + A3 2 本、全 PASS。
- `gen/build/a3-h-diff-check.txt` と `gen/build/a3-h-node-check.txt`: 出力なし、問題なし。

詳細な 27 本の表、H SQL 本文、残差、20 への記述案は `docs/reports/verb-1.md`。

---

# 指示 A4 真壁 巡4 作業結果(2026-09-21)

## 状態

- branch `verb-1`。開始 `1472f19`。P0-6 を実装し、`ordered_by.field` を `*Draft` から除外、`*Created` には残した。
- 生成器 test に Draft 欄数と create SQL の呼び手入力 placeholder 数の一致検査を追加した。ordered create の有効 fixture 4本(`relation` / `article` / `verb_features` / `ordered_create`)と通常 create の `flag` を検査する。
- `verify-verb-sql` は型の多重集合を正典、placeholder 番号を参考として表示する表記だけを変更した。判定ロジックは変更していない。
- `docs/reports/verb-1.md` を裁定3の合格線、29本の全類別表、I の F3移送に合わせて更新した。
- 固定の `musearch-main` は読取のみ。`musearch-decl` に新しい宣言は足していない。musearch 実体、DDL、staging、production、push は未変更。

## DDL

無し。migration / schema変更は無く、staging / productionへ適用していない。

## 検証証拠

- `gen/build/a4-gleam-test-final.txt`: `77 passed, no failures`。
- `gen/build/a4-route-table.txt`: `verify-route-table: PASS (7 rows, face/http scratch build)`。
- `gen/build/a4-gate2.txt`: P0-1 / P0-7 / P0-2 / P0-3 / Range / P0-5 / P0-4 の7 checks PASS。
- `gen/build/a4-root-ffi.txt`: `verify-root-ffi: 8 checks PASS`。固定写しのソースと実体 build の codec/runtime を組み合わせた一時 harnessで実行。固定写し自体は変更していない。
- `gen/build/a4-main-generate.txt` / `gen/build/a4-output-counts.txt`: 固定写し clean run は635 files、exit 4、exit 4診断34行。全診断ファイルは56行で、exit 4行を34行として数えた。
- `gen/build/a4-main-vs-n2.txt`: `diff -r` の出力なし、差0。
- `gen/build/a4-draft-sql-counts.txt`: 仮宣言コピーの `free_space` は Draft4欄 / SQL4 placeholder、`link` は4 / 4、`widget` は16 / 16。`order` はCreatedに残る。
- `gen/build/a4-verify-main.txt`: by-type `4本/5`、by-placeholder `5本/7`、段2一致10、両側28。
- `gen/build/a4-verify-decl.txt`: by-type `1本/1`、by-placeholder `2本/3`、段2一致11、両側29。
- `gen/build/a4-verb-self-test.txt`: 既存2 + A3追加2の4 checks PASS。

## 残差

- 型の多重集合で残る唯一の欠落は `advance_roster[$2::integer]`。`advance_muse_heaven` は型の多重集合で欠落0。
- I(`create_roster`)は裁定3で本便から外しF3へ移した。`auto_key`相当の語彙追加、仮宣言の実演はしていない。指示書の対象本数は27→26へ更新した。
- Hの意味突合は `create_free_space` / `create_link` / `create_widget`。`create_links` は語彙に無い名指し残差。上限の推測実装はしていない。

---

# 指示 A5 ── ゲート2 P0-7 / P0-8(2026-09-21)

## 状態

- branch `verb-1`、開始 `dc2993a`。P0-7 と P0-8 の2件だけを実装した。
- `CreateMany` を単体 create と同じ欄・初期 phase 規則へ揃え、ordered Entity は親の鍵順 lock、full scope 単位の既存末尾、配列 ordinality の `row_number` で採番する。Draft JSON から `order` / phase / entered timestamp は読まない。
- Entity-local の `handwritten_verbs` は自身の候補名だけと照合し、ER 外 module の札は global 候補名と照合する。抑止側は変更していない。
- 固定の `musearch-main/app` / `musearch-decl/app` は読み取りだけ。framework の語彙、他の残差、musearch 本体、staging、production、push は未変更。A5 で新たに `exit 4` 停止へ回した形は無い。

## DDL

無し。migration / schema変更は無い。`verify-gate2-sql.mjs` が一時 schema `gate2_a5_create_many` に検証用の `category` / `article` 表を作成して削除しただけで、staging / production へは適用していない。

## 検証証拠

- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-gleam-test.txt`: `80 passed, no failures`。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-route-table.txt`: `verify-route-table: PASS (7 rows, face/http scratch build)`。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-gate2.txt`: 既存7行を維持し、CreateMany の同一 scope / 混在 scope / 既存末尾の3行を加えた計10行 PASS。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-root-ffi.txt`: `MUSEARCH_APP=/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/musearch-ffi/app` で `8 checks PASS`。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-verb-self-test.txt`: 4 checks PASS。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-main-generate.txt` と `a5-main-counts.txt`: 固定写し clean run は635 files / exit 4 / exit 4診断34行(全診断56行)。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-main-vs-n4.txt`: `diff -r out-n4 out-a5-main` は出力0行・差0。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-decl-vs-n4.txt`: `diff -rq out-decl-n4 out-a5-decl` は出力0行・差0。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-verify-main.txt`: 段2一致10、missing-cast(by-type) 4本 / 5 cast。
- `/home/yumemism/.codex-agents/runs/niekawa-20260921-054627-1324991-3859/evidence/a5-verify-decl.txt`: 段2一致11、missing-cast(by-type) 1本 / 1 cast。

# 指示 B1 ── ordered create の P0-9 / P0-10 / P0-11

## 状態

- branch `verb-1b`、開始HEAD `784ecd9`。`gen/src/yumemi_gen/emit/verb.gleam` の単体・一括 ordered create に、親 no-op UPDATE lock file、`FOR UPDATE NOWAIT`、`parent_gate`、`order_span` 起点を実装した。
- `gen/fixtures/ordered_create_negative` を追加し、`Range(min: -5, max: 10)` が reader を通り、開始値0になることを fixture test と実 PG で確認した。
- `gen/scripts/gate2c/ordered-create-repro.mjs` / `order-range-repro.mjs` は astra 原本の写し。判定文字列を「no reproduction = P0 が消えた」と明示し、lock SQL を先行実行する形にした。
- musearch の3つの写しは読取のみ。DDL、`src/framework/`、staging、production、push、main への commit は無い。

## DDL

無し。検証スクリプトの一時 schema は実行後に `DROP SCHEMA ... CASCADE` で削除した。migration / schema変更を作っていない。

## 検証証拠

証拠の基点は `/home/yumemism/.codex-agents/runs/niekawa-20260921-131116-1974475-16200/a1`。

- `(cd gen && gleam test)` ── `83 passed, no failures`。`a1/evidence/gleam-test.txt`。
- `bash gen/scripts/verify-route-table.sh` ── `PASS (7 rows, face/http scratch build)`。`a1/evidence/route-table.txt`。
- `verify-gate2-sql.mjs` ── 既存10行を維持。T1は37箱(①あり/なし、3組、3 isolation、UNIQUEあり/なし + rollback)で、全箱重複0。T2は4行、T3は4行、status 0。stdout は `a1/evidence/gate2-final.txt`。
- T1: ①ありの READ COMMITTED は全3組・UNIQUE両方で `0,1`、REPEATABLE READ / SERIALIZABLE はB① `40001`。①無しは競合中のB② `55P03`。rollback 箱はBが0を取得。
- T2: `Range(1,10)` の単体1、宣言無しの単体0、宣言無し CreateMany `0,1,2`、負の下端0。
- T3: 正常入力は通過。valid+missing、全件missing、単体missing はすべて `P0001/conflict` かつ表0行。FKは張っていない。
- `node gen/scripts/verify-verb-sql.mjs --self-test ...` ── 4 checks PASS。`a1/evidence/verify-verb-self-test.txt`。
- 仮宣言の `verify-verb-sql` ── `stage2=11`、`missing-cast(by-type)=1本/1`。`a1/evidence/verify-verb-decl.txt`。
- `verify-root-ffi.mjs` ── `8 checks PASS`。`MUSEARCH_APP` は指定の `musearch-ffi/app`。`a1/evidence/root-ffi.txt`。
- main clean run ── exit 4、exit 4診断34行、警告21行。`diff -rq base-main-out a1/main-out` は差0。`a1/evidence/main-generate.txt` / `diff-main.txt`。
- decl clean run ── exit 4。`diff -rq base-decl-out a1/decl-out` の差は ordered create の既存3本と lock SQL 6本だけ。`a1/evidence/decl-generate.txt` / `diff-decl.txt`。
- astra ordered create ── `P0-9 ordered-create astra direction: no reproduction = PASS`。`a1/evidence/repro-ordered-create.txt`。
- astra Range ── `P0-10 order-range astra direction: no reproduction = PASS`。`a1/evidence/repro-order-range.txt`。
- `git diff --check` ── 出力なし。

## 残差

- `hi` 超過時の飽和の綴りは語彙に無い。
- ①を飛ばした RR 以上の呼び手は、②だけでは救えない。`55P03` は競合が重なったときだけである。
- 親 Entity が引けない `ordered_by`（`within` 先頭が関係でない形）には lock 文が出ない。
- 親欠落の失敗コードは汎用の `'conflict'`。専用名は語彙が要る。
- 負の下端の開始値 `int.max(lo, 0)` は鷹野の裁定 C(2026-09-21 14:45)で確定した。BRIEF「どこまで 2」の括弧書き(`lo`)はこの裁定で更正されたので残差ではない。試験 `T2 negative lower bound starts at 0` はそのまま。
- `within` 先頭が optional の形では NULL scope を親検査・親 lock から外す実装にしたが、専用 fixture と独立した実 PG 箱は未実行。

# 指示 B2 ── lock SQL の出力条件・一括行ロック順・第5引数

## 状態

- branch `verb-1b`、開始点 `3d7a9ba`。commit `c71d0a2` で P0-1b-1 / P1-1b-1 / P2 の実装を入れた。
- `create_<module>_lock.sql` は `emits(app, entity, "create_" <> entity.module)` の真偽に従う。`create_<collection>_lock.sql` は `CreateManyRule` の宣言があり、かつ `emits(app, entity, "create_" <> entity.collection)` が真のときだけ出す。単体と一括は別条件で出力する。
- 一括 lock は `WITH locked AS (...)` の `ORDER BY <親鍵> FOR UPDATE` で親行を鍵順に取り、その後の no-op `UPDATE` で親行の版を進める2段構成にした。単体 lock の SQL 形は変えていない。
- `verify-gate2-sql.mjs` の第5引数(負の下端 fixture 出力)を必須化した。省略時は usage + exit 2、stack trace なし。
- DDL、`src/framework/`、musearch 3コピー、staging、production、push は変更していない。

## DDL

無し。生成・PG検証で一時 schema を使ったが、検証後に削除した。migration / schema は書いていない。

## 検証証拠

- `/home/yumemism/.codex-agents/runs/niekawa-20260921-131116-1974475-16200/a1/evidence/gleam-test-b2.txt`: **86 passed, no failures**。
- `gate2-b2.txt` / `gate2-counts-b2.txt`: 19 PASS、status 0。T1は37行で `no duplicate scope/order`、T2は4行、T3は4行。
- `diff-main-b2.txt` / `diff-main-b2-status.txt`: `base-main-out` との差0、diff status 0。
- `diff-decl-b2.txt` / `diff-decl-b2-status.txt`: `create_free_space` / `create_link` / `create_widget` と対応する `*_lock.sql` の6行だけ、diff status 1(差分ありの通常値)。
- `verify-verb-self-test-b2.txt`: 4 checks PASS。`verify-verb-decl-b2.txt`: stage2=11、missing-cast-ty=1。
- `route-table-b2.txt`: `PASS (7 rows, face/http scratch build)`。`root-ffi-b2.txt`: `verify-root-ffi: 8 checks PASS`。
- `main-counts-b2.txt`: generator status 4、`書いた: 635 ファイル`、exit4=34行/9 service、exit3=0、警告21行。
- `gate2-missing-negative-b2.txt` / status: 第5引数無しは usage のみ、exit 2。stack trace は出ていない。
- `fx-relation-b2` の lock file は `create_photo_lock.sql` の1本。`fx-article-b2/create_articles_lock.sql` は親鍵 `name` の `ORDER BY name FOR UPDATE` と後段 no-op `UPDATE` を持つ。

## 残差

- `hi` 超過時の飽和の綴りは語彙に無い。
- lock 呼び出しを省略した REPEATABLE READ 以上の呼び手は、create 本体だけでは安全にならず、従来どおり transaction 単位の再試行が必要。
- 親 Entity が解決できない `ordered_by` には lock 文が出ない。optional scope の専用 fixture と独立した実 PG 箱は未実行。

# 指示 front-1d ── 束 A

## 状態

- branch `front-1d`、開始点 `13ca007`。root version を `0.7.0` に上げた。
- `src/framework/front/live.gleam` だけに `given` / `Given` / `After` の型を追加した。
  `gen/src/**`、musearch、DDL、push、publish は変更していない。
- `pick-tag` の見本島、`yumemi-done`、front-scratch の `ReloadPage` listener、
  `/api/article/tag` の POST 口、検証器の RELOAD 検査を追加した。
- `docs/reports/front-1d.md` に型差分、51 v5 案、P5b / Y2 / 鷹野さんへの申し送りを記録した。

## DDL

無し。migration / schema / 索引は書いていない。staging / production へ適用していない。

## 検証証拠

- root `gleam build`: **exit 0**。`build/front-1d-root-build.txt`。
- `cd gen && gleam test`: **86 passed, no failures**。`gen/build/front-1d-gen-test.txt`。
- `cd gen/fixtures/article/www && gleam build`: **exit 0**。
  `gen/fixtures/article/www/build/front-1d-fixture-build.txt`。
- `gleam run -m yumemi_gen -- fixtures/article _out/front-1d-a`: **exit 0、57 ファイル**。
  `gen/build/front-1d-generate.txt`。入力 source units は **11**。
- `git diff --stat 13ca007 -- gen/src`: 空。
- `node gen/scripts/verify-front-ssr.mjs`: **NO-JS PASS / ISLAND PASS / RELOAD PASS /
  ALL PASS**。同じ document URL の列は 2 件（初回 + 再要求 1 回）。
  `gen/build/front-1d-ssr.txt`。
- `node gen/scripts/verify-front-isolate.mjs`: **ALL PASS**。40 requests、style length は
  first **322** / second **191**。`gen/build/front-1d-isolate.txt`。
- `git diff --stat 13ca007 -- src/framework/`: `src/framework/front/live.gleam` の 1 file。
  他 4 module は 0 行。

## 残差

無し。commit 前に最終 status / diff / 全検証を再確認する。

# 指示 front-1d ── 巡2 P0

## 状態

- P0-1: Block の `pick-tag` に `selected="fixture"` を追加した。島の属性 callback は
  `selected` から `live.Set(Nil, value)` を作り、`update` / `view` は変更していない。
- P0-2: `pick_tag.gleam` に `pub const calls: List(service.Service) = []` を追加した。
  fixture にタグ書きの Service が無いため `[]` とし、実 Service への結線は Y2 / P5b。
- SSR 検査は別 page で未選択の POST body `fixture` を捕捉する。既存 page の
  `selectOption("gleam")` 経路も POST body `gleam` を捕捉する。
- 束Bの commit `cd5d4e4` は本便の範囲外であり、完了条件 `gen/src` 差分なしに
  合わせて最終成果から除外する。生成器への新規変更はない。

## DDL

無し。

## 検証証拠

- root `gleam build`: exit 0、`build/front-1d-r2-root-build.txt`。
- `cd gen && gleam test`: **89 passed, no failures**(束 B の 3 test を含む)。
- fixture `gleam build`: exit 0、
  `gen/fixtures/article/www/build/front-1d-r2-fixture-build.txt`。
- generator: exit 0、**57 files**、入力 units **11**。
  `gen/build/front-1d-r2-generate.txt`、出力は `gen/_out/m2`。
- SSR: `NO-JS / INITIAL fixture / ISLAND / SELECTED gleam / RELOAD / ALL PASS`。
  `gen/build/front-1d-r2-ssr.txt`。
- isolate: 40 requests、first 322 / second 191、`ALL PASS`。
  `gen/build/front-1d-r2-isolate.txt`。
- `git diff --stat 13ca007 -- src/framework/`: `front/live.gleam` の 1 file だけ。
- `git diff --stat 13ca007 -- gen/src`: 束 B の `reader.gleam` / `emit/verb.gleam` の 2 file
  (本便の 2 束目そのもの)。`git status --short` に `_out/` なし。
- musearch main `api/` への clean run(読むだけ): exit 4 / 597 files / exit 4 行 18 /
  警告 29。巡 1 の出力と `diff -rq` 差 0、`*_id_id` 0 件、musearch の
  `git status --short` は実行前後で不変。

# 指示 yumemi-gen-6 / 巡6 ── 束B後始末 + 段C前半

## DDL

無し。migration / schema / staging / production への適用はしていない。

## 鷹野宛

- 束1: 面の写しに構成子予約表を追加。Entity と Row の衝突は Entity を残して Row を `*Row` に綴り替え、Row と enum の衝突は enum を `String` 別名へ落とした。fixture の `ArticleRow` は維持した。
- 束2: `gen/types` へ直結する別名連鎖を転送に畳み、`course_add` は `pub type LedgerStoreId = String` 1 本になった。
- 束3: fixture 面へ `SiteHeader` / `Feed` / `RowArticle` / `RowSummary` を追加し、layout / Page の Fixed・One・ByKind を 51 v5 §180 の型へ合わせた。back `gen/fixtures/article/src/**` は変更していない。
- 束4: `src/gen/load/layout.gleam` と Page と同じ道の `src/gen/load/<page path>/page.gleam` を生成。Data / load / view のみを出し、ByKind は Row variant の直接 `case` にした。
- root `gleam build`: **exit 0**。既存 `src/framework/secret.gleam` の unused private constructor warning 1件。`gen/build/gen6-r6-root-build-final.txt`
- `cd gen && gleam test`: **119 passed, no failures**。`gen/build/gen6-r6-test-final.txt`
- fixture generator: **exit 0 / 73 files**。`diff -rq base-fixture-out-a2 /tmp/gen6-r6-fx --exclude=public`: **差 0**、back **60 files**。`gen/build/gen6-r6-fixture-generate-final2.txt`、`gen/build/gen6-r6-fixture-back-diff-final2.txt`
- `cd gen/fixtures/article/public && gleam build`: **exit 0**、`Compiling public` **1**。`gen/build/gen6-r6-public-build-final.txt`
- 指定 snapshot generator: **exit 4**、診断 `exit 0 = 29` / `exit 3 = 0` / `exit 4 = 18`、back **604 files**。`diff -rq base-ms-snap-a2 /tmp/gen6-r6-ms --exclude=www`: **差 0**。`gen/build/gen6-r6-musearch-generate-final2.txt`、`gen/build/gen6-r6-musearch-back-diff-final2.txt`
- musearch 面の temp copy build: **exit 0**、`error:` **0**、`Compiling www` **1**。`gen/build/gen6-r6-face-build.txt`。snapshot の package 名が `musearch_www` のため、grep 証跡を合わせる `name = "www"` と yumemi path 依存の変更は `/tmp/gen6-r6-face` のみへ行った。
- `git status --short` で live `~/yumemism_repo/musearch` は参照していない。live musearch へは 1 byte も書いていない。

## musearch 追随便への申し送り

- 入力は固定 snapshot `ms-96fb8cc` のみ。生成出力は `/tmp/gen6-r6-ms` と `/tmp/gen6-r6-face` に置いた。
- `www/src/gen/load/muse/arg_handle/page.gleam` を含む面の source が実際に compile され、`Compiling www` 1 / `error:` 0 を確認した。
- 段Dの `render` / `render_view` / `theme_global` / `style.css` / SSR `<style>`、生成物8の live service、島の update / calls は未着手。
# 指示 段C後半 ── 生成 live と島の仕上げ

## 状態

- 束1: `emit/front.gleam` の未使用引数、未使用 `plain_area`、網羅済み `ByKind` の末尾分岐、二重 `list.flatten`、不要な Option 構成子 import を修正した。
- 束2: fixture の `public` 入口を `All`、`article_create` / `article_publish` の faces を `[Public, Admin]` にした。`article_retract` は `[Admin]` のまま。
- 束3-4: `src/gen/live/article_publish.gleam` と `article_create.gleam` を追加。島の手書き `State` / `Event` / `init` / `update` と FFI 2本を削除した。`reloads` は `#(Slug, service.ArticleList)` を読む形。

## DDL

無し。migration、staging、production、Hex、push、main は触っていない。

## 束2で動いた back の file

base `/home/yumemism/.codex-agents/runs/niekawa-20260922-061417-3399503-22265/base-fixture-out-a2` との差分は10 file。生成物の行数と理由は次のとおり。SQL / reads / root は本文でなく Service hash header の更新。

- `db/queries/article_create/to_category.sql` 5行 ── create の faces 変更に連動。
- `db/queries/article_create/to_tags.sql` 5行 ── 同上。
- `db/queries/article_publish/to_category.sql` 5行 ── publish の faces 変更に連動。
- `db/queries/article_publish/to_tags.sql` 5行 ── 同上。
- `src/gen/entry/http.gleam` 25行 ── public の create / publish route を追加。
- `src/gen/face.gleam` 6行 ── entry hash の更新。
- `src/gen/reads/article_create.gleam` 63行 ── Service hash header の更新。
- `src/gen/reads/article_publish.gleam` 63行 ── 同上。
- `src/gen/root/article_create.gleam` 23行 ── 同上。
- `src/gen/root/article_publish.gleam` 23行 ── 同上。

証拠: `gen/build/gen6-final-fixture-back-diff.txt`。それ以外の back は diff 0。

## 生成物8の形と島から消したもの

- `route / load / blocks / widgets / service / api / out` は既存の front 写し。checked-in `public/src/gen/**` と最終生成物の diff は0、15 file 全てに sha256 header がある。
- `live/article_publish.gleam` は `Field = Slug`、`State(Args, Nil, article_publish.Out, Error)`、Pattern 検査、Stay 分岐。
- `live/article_create.gleam` は `Field = Slug | Title | Body | Category | Tags`、`State(Args, article_list.Out, article_create.Out, Error)`、Slug/Title/Body の Spec 検査、ReloadPage の `yumemi-done` 合図。
- 島に残るのは `view`、`calls`、`reloads`、`after_send`、`app`。`fn update` は0本、`*_ffi.mjs` は0本、非空 `calls` は2本。

## 検証

- root `gleam build`: exit 0。既存 `src/framework/secret.gleam` warning 1件。`gen/build/gen6-final-root-build.txt`
- `cd gen && gleam test`: **120 passed, no failures**。`gen/build/gen6-final-gen-test.txt`
- fixture generator: exit 0 / **75 file**。back 60 file、face 15 file、live 2 file。`gen/build/gen6-final-fixture-generate.txt`
- fixture public build: exit 0、`error:` 0、生成コードの Unused / Unreachable / Redundant warning 0。`gen/build/gen6-final-public-build.txt`
- musearch snapshot のみを入力: exit 4、exit0 warning **29** / exit3 **0** / exit4 **18**、back **604 file**、back diff **0**、face **105 file**、live **0 file**、total **709 file**。`gen/build/gen6-final-musearch-generate.txt`、`gen/build/gen6-final-musearch-counts.txt`、`gen/build/gen6-final-musearch-back-diff.txt`
- 一時 `/tmp/gen6-final-face.0wPoZB/www` に生成面を差し替えて build: exit 0、`error:` 0、`Compiling musearch_www` あり。`gen/build/gen6-final-musearch-www-build.txt`

## 鷹野宛

- musearch は指定 snapshot `ms-96fb8cc` の `api/` と、同 snapshot の `www/` を読むだけ。`~/yumemism_repo/musearch` には触っていない。
- 入口の admit / subject / prefix は束2で変更していない。`article_retract` を面に出さない形も維持した。

## 巡 8(段 D1)

### 状態

- 生成物10は fixture 面の `public/src/gen/live/` 2本、`public/priv/static/_yumemi/client.mjs` 1本。client は bundle 後 181,827 bytes。面15種の Gleam + `transport_ffi.mjs` + client の形で、島0本の musearch 面には追加なし。
- `transport_ffi.mjs` は Service 分岐を持たない汎用 `send(method, path, body, onOk, onError)`。live の `send` は `api.gleam` の method/path を literal 化し、Args を JSON object にして送る。Out decoder は `gen/out/<service>` に `gleam/dynamic/decode` で生成。
- client は `like-button` と `pick-tag` を register。given は `data-yumemi-given` を JSON decode し、属性無し/失敗時は register せず、`ReloadPage` は `yumemi-done` から同一 URL を1回だけ再要求する。
- worker の SSR に `pick-tag` の given JSON を追加し、POST を `/api/articles` と `/api/articles/:slug/publish` に変更。verify の assert は旧 `/api/article/tag` と raw body を生成 route/JSON body に変更した。NO-JS、初回 POST、島の表示変化、再要求、isolate 40回の assert は削除していない。

### DDL

無し。migration / schema / staging / production / Hex publish は未実施。

### 検証

- root build: exit 0、既存 `src/framework/secret.gleam` warning 1件。`gen/build/gen6-d1-root-build.txt`
- `cd gen && gleam test`: **123 passed, no failures**。`gen/build/gen6-d1-gen-test.txt`
- fixture generator: exit 0 / 77 file、back 60 file と基線 diff 0、face Gleam 15 + transport 1 + client 1。`gen/build/gen6-d1-fixture-generate.txt`、`gen/build/gen6-d1-fixture-counts.txt`、`gen/build/gen6-d1-fixture-generated-diff.txt`
- fixture public build: exit 0、非 transitive warning 0。`gen/build/gen6-d1-public-build.txt`
- verify SSR: **ALL PASS**（NO-JS、INITIAL JSON、ISLAND `いいね -> ❤ 13`、SELECTED JSON、RELOAD 1回）。`gen/build/gen6-d1-verify-ssr.txt`
- verify isolate: **ALL PASS**（40 requests、混入0）。`gen/build/gen6-d1-verify-isolate.txt`
- musearch snapshotのみ: exit 4、exit0 warning 29 / exit3 0 / exit4 18、back 604 file diff 0、face 105 file、transport/client 0。`gen/build/gen6-d1-musearch-generate.txt`、`gen/build/gen6-d1-musearch-counts.txt`、`gen/build/gen6-d1-musearch-diagnostics-counts.txt`
- snapshot `www` の一時コピーを worktree の yumemi path dependency と生成面に差し替え: exit 0、`Compiling musearch_www`、`error:` 0、face 非 transitive warning 0。`gen/build/gen6-d1-musearch-www-build.txt`
- generated header violations 0、面 import allowlist violations 0、back module imports 0。`gen/build/gen6-d1-generated-header-check.txt`、`gen/build/gen6-d1-import-check.txt`

### 鷹野宛

musearch 本体には触れていない。入力は指定 snapshot、出力と一時 build は `gen/_out` / `/tmp` のみ。fixture back は変更していない。

## 巡 9(段 D2・完了)

### 状態

- 束1: live.Send を validate 経由に変更。Invalid/Failed を生成。
- 束2: 面の shell reader と既定値を追加。fixture の shell.gleam を追加。
- 束3: article_read.Out に PageTheme/theme を追加。生成 load/page に render・theme を追加。
- 束4: 生成物 `src/gen/shell.mjs` と page/layout Service decoder を追加。
- 束5: SSR 用 grid CSS と `priv/static/_yumemi/style.css` を生成。
- 束6: verify harness を生成 shell entry + APP/SVELTE stub に張り替え。手書き worker/ffi を削除。

### DDL

無し。migration / schema / staging / production には触れていない。

### 検証

- root `gleam build`: exit 0。既存 `src/framework/secret.gleam` warning 1件。`build/d2-final-root-build.txt`
- `cd gen && gleam test`: **123 passed, no failures**。`gen/build/d2-final-gen-test.txt`
- fixture generator: exit 0 / **79 file**。front src **17 file**、static **2 file**、生成結果との差分0。`gen/build/d2-final-generate.txt`
- fixture public build: exit 0、`error:` 0件。`gen/build/d2-final-public-build.txt`
- verify SSR: **ALL PASS**（SVELTE fallback、NO-JS、INITIAL valid JSON、ISLAND `いいね -> ❤ 13`、SELECTED JSON、RELOAD 1回）。`gen/build/d2-final-verify-ssr.txt`
- verify isolate: **ALL PASS**（40 requests、style長2228、混入なし）。`gen/build/d2-final-verify-isolate.txt`

### 連動した back 生成物(贄川が実測で差し替え)

`fixtures/article/src/service/article_read.gleam` に `PageTheme` 型と `Out.theme` を足した(裁定 9 / 10 と同型の fixture の穴埋め、贄川が裁いた)。**これに連動して動いた back の生成物は 6 file、全部ヘッダの sha256 行だけで本文は 1 行も動いていない。**

| file | 理由 |
|---|---|
| `src/gen/reads/article_read.gleam` | `service.article_read` の入力 hash が動いた(ヘッダのみ) |
| `src/gen/root/article_read.gleam` | 同上(ヘッダのみ) |
| `db/queries/article_read/to_category.sql` | 同上(ヘッダのみ) |
| `db/queries/article_read/to_tags.sql` | 同上(ヘッダのみ) |
| `src/gen/entry/http.gleam` | `entry.gleam / service declarations` の合成 hash が動いた(ヘッダのみ) |
| `src/gen/face.gleam` | 同上(ヘッダのみ) |

`effect` / `faces` / `Args` / `allow` / `admit` / `subject` / `prefix` / 他の 5 Service / `entity/**` / `db/` の DDL は 1 文字も動いていない。**musearch の back 604 file は本文 diff 0**(動いたのは `_diagnostics.txt` の警告 1 行だけ ── §面の `shell.gleam` 不在)。

面の生成物(`public/src/gen/**`)は back ではない ── `out/article_read.gleam` / `api.gleam` / `service.gleam` / `live/**` / `load/**` / `shell.mjs` はこの巡の成果物そのもの。

## 巡10(P0-4 decoder、test、生成物12/13)

### 状態

- 束1: `named_decoder` が Entity の型名一致時だけ record decoder に落ちるよう修正。型名が一致しないもの(`muse.Phase` など)は写しの宣言側へ落ち、variant 名で分岐する enum decoder になる。constructor は宣言側の `mapped_constructor`(`Muse` → `MusePublic`)、Blob / Date / Datetime / Time は framework の parser(`blob.parse` / `time.date` / `time.datetime` / `time.time`)経由にした。framework は変更していない。
- 束2: `live.Send -> validate`、shell 値/既定値/警告、grid CSS、decoder の宣言構成子検査を追加。`gleam test` は **128 passed, no failures**。
- 束3: 参照される6 Blockの `src/gen/skeleton/*.gleam` と `blocks_preview.gleam` を生成。`src/blocks/**` と `src/components/**` は変更していない。
- 束4: dev 限定 `/_blocks`、PC固定 preview、runtime 経由の `build-blocks.mjs` を追加。`build/blocks.html` は gitignore 対象のため commit していない。

### DDL

無し。migration / schema / staging / production / framework / `~/yumemism_repo/musearch` は変更していない。

### 検証

- root `gleam build`: `Compiled in 0.03s`。既存 `src/framework/secret.gleam` の unused private constructor warning 1件。`build/r10-final-root-build-2.txt`
- `cd gen && gleam test`: **128 passed, no failures**。`gen/build/r10-final-gen-test-2.txt`
- fixture generator: **86 files**。`public/src/gen` と static の生成結果との差分 **0**。`gen/build/r10-final-fixture-generate-exact.txt`
- fixture public build: `error:` **0**、生成コード由来の unused warning **0**。Gleam の transitive dependency notice は preview import の5件。`gen/build/r10-final-fixture-public-build-2.txt`
- verify SSR: **ALL PASS**（NO-JS、INITIAL、ISLAND、SELECTED、RELOAD 1回）。`gen/build/r10-final-verify-ssr-3.txt`
- verify isolate: **ALL PASS**（40 requests、first/second style length 2228、混入なし）。`gen/build/r10-final-verify-isolate-3.txt`
- `node gen/scripts/build-blocks.mjs`: **BLOCKS: PASS (6 blocks)**。`gen/fixtures/article/public/build/blocks.html` は 2194 bytes、6 module label、inline style、client reference を含む。`gen/build/r10-final-build-blocks-2.txt`
- musearch snapshot generator: **生成 exit 4**。診断 `exit 0=30 / exit 3=0 / exit 4=18`、back **604 files**。`build/r10-final-musearch-generate-2.txt`
- musearch 面 build: **build exit 0 / error 0**。snapshot の transitive dependency notice 56件。`build/r10-final-musearch-face-build-2.txt`
- generated header check: `.gleam` / `.mjs` とも違反 **0**。

未実行: 無し。

### 基線(この巡で動いた数字)

| 項 | 巡 9 | 巡 10 | 理由 |
|---|---|---|---|
| fixture 生成 file | 79 | **86** | skeleton 6 本 + `blocks_preview.gleam` |
| musearch 面の生成 file | 107 | **119** | skeleton 11 本 + `blocks_preview.gleam` |
| musearch back file | 604 | **604** | 本文 diff 0 |
| 診断 | exit 0 = 30 / exit 3 = 0 / exit 4 = 18 | **同じ** | 不変 |
| `gleam test` | 123 | **128** | 束 2 の 5 本 |

### 鷹野宛(この巡で贄川が裁いた設計判断 2 点)

1. **生成物 12 の「初回だけ」は `src/blocks/**` に掛かり、`src/gen/skeleton/**` には掛からない。**51 v5 §328 は置き場を `src/gen/skeleton/<block>.gleam` と書いており、`src/gen/` は ▲ の領域なので毎回作り直すのが筋。開発者はここから `src/blocks/<name>.gleam` へ 1 度だけ写し、以後その ★ を生成器は一切触らない ── これが「初回だけ」。存在で gate すると fixture も musearch も既に 6 / 11 本の ★ を持つので**この巡で 1 本も出ず、検収が原理的に効かない**。一方、`src/gen/` の外に出る面の package の骨組み(`gleam.toml` / `src/layout.gleam` / `src/pages/page.gleam`)は存在で gate する ── この巡は両方の面が既に持つので 0 本が正。
2. **生成物 13 は「生成器が HTML を直に書く」のでなく「生成した Gleam を面の runtime に走らせて 1 枚落とす」。**Block の view は ★ の Gleam なので、生成器の file writer からは実行できない。51 v5 §333 は `<style>` 同梱・島が動く・各 Block に module 名と `of` と `Out` を添えると書いており、**view の実行が要る**。生成物 10(`client.mjs` + bundle)と同じく build の段を 1 つ挟む形にした ── (a) 生成物 `src/gen/blocks_preview.gleam`、(b) `shell.mjs` が dev のときだけ `/_blocks` で配る(**本番の route 表には生えない**)、(c) `gen/scripts/build-blocks.mjs` が面の worker を 1 回叩いて `build/blocks.html` を保存。`build/` は gitignore の中なので成果物は commit されない(dev の道具、本番に出ない)。

### この巡の P1(直していない)

1. **`build/blocks.html` の header / nav / footer の区画に Layout の Block が入らない** ── 現物は `header` / `aside` / `footer` の literal が置かれるだけ。51 v5 §333 の「header / nav / footer の Block を Layout どおりに置き」の半分。`page` の区画に全 Block を縦に並べる方は成立している。dev の道具なので本便では直さない
2. **生成された decoder が `let assert Ok(default_value) = parse("placeholder")` の形を持つ**(4 本、`decode.failure` の既定値)。literal は 4 つとも今の framework の検査を通るので落ちないが、opaque の検査が後の便で厳しくなると生成コードが panic する。`decode.new_primitive_decoder` なら既定値が要らない

# 指示 段E ── 突合と報告

## DDL

無し。`git diff --stat 6cbc9dd..HEAD -- db/ gen/fixtures/article/db/` は空。migration / schema / staging / production には触れていない。

## 鷹野宛

- 巡6: 面の `route / load / blocks / widgets / service / api / out` は back と別の `www/src/gen/**` に置き、Page の Data/load/view と型写しだけを生成する。musearch は snapshot を読むだけにする。
- 巡8: 島の transport は Service 分岐を持たない汎用送信、route/method/path は `api.gleam` から literal 化し、`given` と `reloads` は client runtime が扱う。FFI の業務分岐は残さない。
- 巡9: shell は Page/decoder/theme/grid CSS を生成し、route 表外は `SVELTE` へ元 Request のまま fallback する。`www/src/shell.gleam` 不在時は既定値と warning 1 本を使う。
- 巡10: skeleton は `src/gen/skeleton/**` へ毎回生成し、Block の ★ は `src/blocks/**` に残す。Block list は生成 Gleam を面 runtime で実行して `build/blocks.html` に落とす。生成 decoder の placeholder assert は P1 のまま。
- 本巡: ▲ の header だけは無視し、意図差 2 系統は生成物を正、▲ の古さは追随便で置換、生成側の Row decoder / Block preview の欠落は P1 とした(Row decoder の射程は柏木ゲート 2 で訂正 ── fixture にも同じ穴が在り SSR の source として現に通っている)。面の `api.gleam` は**同じ run が吐いた back の route 表と 87 route 全一致**で、生成器の穴は無い(古い `registry.mjs` との差は世代差)。`gen/src/**`・`src/**`・`gen/fixtures/**` は変更していない。

## musearch 追随便への申し送り

- 入力は `ms-96fb8cc`、出力は `out-ms10` を保存したままにする。まず `out/widget_list.gleam` の Row decoder(P1 E-1)を解消した生成結果を別 output で作り、face build と back 604 file 本文 diff 0 を確認する。**E-1 は「musearch の面が ▲ だから誰も踏まない」ではない** ── 根は `emit/front.gleam:3956` の `custom_decoder` が fields 付き複数 variant の先頭だけを採る形で、fixture の `out/widget_list.gleam`(`Row { ArticleRow Summary }`)も同じ穴を持ち `shell.mjs` の SSR source として現に通している。面を生成物へ差し替える前に必ず閉じる。
- **面だけを差し替えない ── back の生成物も同じ世代に揃える。**musearch が今持つ `api/src/gen/registry.mjs` と `entry/http.gleam` は古い世代の back 生成物で、生成した面の `api.gleam` とは 48 route で method / path が食い違う(面と back を同じ run で出せば差は 0、`gen/build/gen6-e-api-vs-backroutes.txt`)。追随便は面 15 file と back 604 file を 1 つの生成で同時に取る。
- 追随便では `www/src/gen/` の ▲ 15 fileをバックアップし、生成物の同名 15 fileを同じ path へ差し替える。動く file は `route.gleam`、`widgets.gleam`、`load/layout.gleam`、`blocks.gleam`、`service.gleam`、`api.gleam`、`load/muse/arg_handle/page.gleam`、`shell.mjs`、`out/article_list.gleam`、`out/link_list.gleam`、`out/space_list.gleam`、`out/muse_heaven_list.gleam`、`out/subscription_read.gleam`、`out/muse_read.gleam`、`out/widget_list.gleam`。
- 差し替え後に `www` package を build し、Page/SSR/isolate と registry の route/method/path を検査する。`www/src/media.gleam` は ★ なので置き換えない。musearch の main へは鷹野の承認後まで書かない。
- 生成物 **14 種目**(back の静的資料の写し ── 外部送信 6 件 / API v1 本文)は P4 の ▲ が置かれた後の便で、源は `.mjs` を読む口か `api/priv/` の置き直しかを鷹野が P4 の results を見て裁く(裁定 7)。
- musearch の現物で検査 8 本を効かせるには `api/src/entry.gleam` に `pages: AllPages` と `api/gleam.toml` の依存窓の引き上げが要る(裁定 9)。
- **`www/src/shell.gleam` 6 行を置く**(`muses/` も同型)── 置くまで警告 1 本が出続ける(裁定 10)。
- `www/gleam.toml` に `sketch` / `sketch_lustre` の直接依存が無く、生成 `page.gleam` の build が notice を出す(本便の面 build で 56〜57 件)。

# 指示 段F ── ゲート 2 の P0-1

## DDL

無し。migration / schema / staging / production / Hex / framework には触れていない。

## 状態

- branch `gen-6`、開始点 `ad0d6ba`。checkpoint は `bb8eadc`（先に落ちる検査）と `c1e4228`（SSR 修正）。最後にこの便の checkpoint を1本へ squashする。
- `addGivenAttributes` の SSR だけを修正した。`replace(marker, () => ...)` に変え、`JSON.stringify` の escape を `&` → `"` → `<` の順にした。`indexOf` で文書順の位置を進め、同じ tag の未処理 island へ given を1対1で割り当て、既存 `data-yumemi-given` は飛ばす。island / given の数が合わなくても落とさない。
- client 側の per-element given は未修正。現行 Lustre の `register` は `App(Nil, ...)` 固定で、`build/packages/lustre/src/lustre/runtime/client/component.ffi.mjs` の `customElements.define` は tag 単位に1回だけなので、framework API の変更が必要。P1 に積んだ。

## 束0の再現

- 修正前: `build/gen6-f-repro-before.txt`。同じ入力で `attributeClose: 86`、生の `<script>alert(document.domain)</script>` は `scriptOffset: 124`。属性の外へ escape 前のマークアップが出た。
- 修正後: `build/gen6-f-repro-after.txt`。`attributeClose: 154`、`scriptOffset: -1`。出力 given は `$` をそのまま保持し、`<script>` は `&lt;script>` になった。
- 同じ tag 2本の旧挙動は、先頭 island への属性二重挿入と2本目の属性欠落。`build/gen6-f-same-tag-before-after.txt` に修正前後を保存した。修正後は `GIVEN SAME TAG ISLANDS: PASS` で各1個、値の入れ違いなし。

## 検証

- `node gen/scripts/verify-front-given.mjs`: 修正前 `GIVEN ESCAPE: FAIL`（`build/gen6-f-given-before.txt`）→ 修正後 `GIVEN ESCAPE: PASS`、`GIVEN SAME TAG ISLANDS: PASS`、`GIVEN EXISTING ATTRIBUTE: PASS`、`GIVEN TESTS: PASS`（`build/gen6-f-given-after.txt`）。生成済み `shell.mjs` を切り出して実行している。
- `gleam build`: exit 0、`Compiled in 0.03s`。既存 `src/framework/secret.gleam` の unused private constructor warning 1件。`build/gen6-f-root-build.txt`
- `cd gen && gleam test`: **128 passed, no failures**。`build/gen6-f-gleam-test.txt`
- `cd gen/fixtures/article/public && gleam build`: exit 0、error / warning なし。`build/gen6-f-public-build.txt`
- `gleam run -m yumemi_gen -- fixtures/article _out/gen6-f-given`: exit 0、**86 file**。生成された `shell.mjs` と fixture の shell diff はこの便の関数部分だけ。`build/gen6-f-given-generate-temp.txt`、`build/gen6-f-given-shell.diff`
- `node gen/scripts/verify-front-ssr.mjs`: exit 0、SVELTE fallback / NO-JS / INITIAL / ISLAND / SELECTED / RELOAD / ALL PASS。`build/gen6-f-verify-front-ssr.txt`
- `node gen/scripts/verify-front-isolate.mjs`: exit 0、**40 requests**、style length **2228 / 2228**、ALL PASS。`build/gen6-f-verify-front-isolate.txt`

## 動いた file

- `gen/src/yumemi_gen/emit/front.gleam`: `addGivenAttributes` の生成文字列を修正。
- `gen/scripts/verify-front-given.mjs`: generated `shell.mjs` を実行する escape / 同じ tag 2本 / 既存属性の検査を追加。
- `gen/fixtures/article/public/src/gen/shell.mjs`: generator の出力を fixture に追随。fixture の source、back、client bundle、framework は変更していない。
- `docs/reports/gen-6.md`: front-1 / Y1c の同項を SSR で覆えた内容へ更新し、framework 待ちの client 部分を P1 に追加。
- `results.md`: 本節を追加。

P1、back 側、musearch、DDL、Hex publish、push、main、push は触っていない。

## 贄川の P2(検収で見つけた回帰、贄川が直して commit)

真壁の `addGivenAttributes` は `searchFrom` を **givens をまたいで共有**していた(`let searchFrom = 0;` が `for` の外)。このため **spec の given の順が文書順と逆**だと、先に在る島に属性が付かない ── 旧コードでは付いていたので**この巡で入った回帰**。

- 再現(修正前の生成物 `out-fx12/public/src/gen/shell.mjs`):文書順 `<like-button>` → `<pick-tag>`、givens は `[pick-tag, like-button]` → **`like-button` に `data-yumemi-given` が付かない**(`pick-tag` だけ付く)
- 直し:`let searchFrom = 0;` を `for (const given of givens) {` の**中**へ移す(`emit/front.gleam:3449`、1 行)。同 tag 2 本は既存 `data-yumemi-given` を飛ばす分岐が拾うので壊れない
- 検査:`gen/scripts/verify-front-given.mjs` に **`GIVEN CROSS TAG ORDER`** を足した。修正前の生成物で **FAIL**、修正後で **PASS**(4 本とも PASS)

# 束 B ── framework の reads・Target・grid API (2026-09-24)

## 状態

- branch `impl/gen-7-fw`、開始点 `0c59f35`。Page / Layout に `reads: List(service)` を追加し、`reads` は Page / Layout ごとに型付けされた Service の列として保持する。
- `framework/front.Target(service, attached)` と `Of` / `Entry` を追加。fixture の島 `calls` を `List(front.Target(service.Service, Nil))` へ揃えた。
- Frame に `cols` / `rows` / `template` を追加。空欄は framework の `resolved_cols` / `resolved_template` が breakpoint 既定値へ解決する。Track、Fixed の Cell、`GridTracks` を追加し、既存 `Grid(Int, gap)` は維持した。
- fixture の Page は `ArticleRead`、Layout は空の `reads`。Fixed は `cell: Flow`、Frame は `cols: []` / `rows: []` / `template: []` を明記した。
- fixture の手書き file に `api.Entry(...)` は無かった。fixture 再生成と面 build は未実行(生成器側の束 B' の作業)。

## DDL

無し。

## 検証

- `gleam build`: exit 0、`Compiled in 0.03s`。既存 warning 1件(`src/framework/secret.gleam` の unused private constructor)。`build/bundle-b-gleam-build.txt`。
- `gleam test`: exit 0、`Running yumemi_test.main`、**4 groups / 23 assertions passed**。同じ既存 warning 1件。`build/bundle-b-gleam-test.txt`。
- `git diff --check`: 出力無し。Fixture の `src/gen/`、`gen/src/`、`docs/` に差分は無い。
- 生成器側の Service.Out と Block.In の不一致検査(exit 4)はこの木の範囲外で、未実行。

## 変更した file

- `src/framework/front.gleam`, `src/framework/front/css.gleam`, `src/framework/front/sketch_css.gleam`, `src/framework/front/track.gleam`
- `gleam.toml`, `test/yumemi_test.gleam`
- `gen/fixtures/article/public/src/layout.gleam`, `gen/fixtures/article/public/src/pages/article/arg_slug/page.gleam`, `gen/fixtures/article/public/src/components/pick_tag.gleam`, `gen/fixtures/article/public/src/components/like_button.gleam`
- `results.md`

# gen-7 B' ── 生成器を framework 0.8.0 へ追随 (2026-09-24)

## 状態

- branch `impl/gen-7`、開始 HEAD `45192ac`、squash 基点 `0c59f35`。
- reader / emitter / loader を framework 0.8.0 の `Frame` / `Cell` / `GridTracks` / `reads` / `Target` に追随させた。`src/framework/` と root `gleam.toml` は変更していない。
- `git diff HEAD -- src/framework/ gleam.toml gen/fixtures/article/public/src/{layout.gleam,pages,blocks,components}` は空。指定の squash 基点が HEAD より前のため、最終 1 commit の base diff にはすでに merge 済みの束 B も含まれる。
- `Page.reads` の fixture 現物は依頼文の説明と異なり `[service.ArticleRead]`。`Page.of` も同じ Service で、生成 Data は `article_read.Out` 1 欄に束ねられる。★ のため入力は修正していない。

## DDL

無し。migration / schema / index は変更していない。

## 実装

- `reader/front.gleam`: `parse_layout` / `parse_page` が `reads` を field から読む。`parse_frame` が `cols` / `rows` / `template`、`parse_track` が `Fr` / `Rem` / `Px` / `Minmax`、`parse_placement` が `Fixed.cell` を保持する。`parse_grid_tracks` は `Area.flow` の `GridTracks` を保持し、`call_target_list` / `target_of` が `Of` と `Entry` を識別する。
- `emit/front.gleam`: `static_grid_css` / `frame_columns_css` / `frame_template_css` が framework の `resolved_cols` / `resolved_template` を使い、Track を CSS 化する。Page の明示 grid は Page ごとの selector と wrapper を生成する。`fixed_placement_body` が `Span` / `At` を wrapper の `grid-column` / `grid-row` にする。`layout_sources` / `page_sources` が `reads` の Service.Out を Data に束ね、`unique_load_sources` が重複引数を除く。
- `reader.gleam` / `model.gleam`: Service の `Out` 型参照を保持する。`reads_type_notes` が読み対象 Service.Out と、配置先 Block.In の不一致を stop code 4 で報告する。
- `yumemi_gen.gleam` / `emit/front.gleam`: `api/src/gen/http_runtime.mjs` の付属入口表を読む。生成 `gen/api.gleam` は既存の `Method` / `Route` / `routes` 名を維持し、`Attached` / `AttachedRoute` / `attached` を出す。`Target` は `front.Target(service.Service, Attached)` の alias とし、`Of` / `Entry` の型所有を framework に揃えた。

## 検証

- 基準 `cd gen && gleam test`: **130 passed / 8 failures**。失敗は `calls` の `Of(service.X)` を `Of` という未知 Service として扱っていたため live files と service references が欠けていた。修正後は全 8 件が閉じた。
- 最終 `cd gen && gleam test`: **142 passed / no failures**。追加した試験は `front_emit_grid_tracks_template_and_fixed_cells_test`、`front_emit_page_frame_grid_and_reads_test`、`front_reads_are_loaded_and_block_inputs_are_checked_test`、`front_calls_parse_framework_target_of_and_entry_test` の 4 本。`build/gen-7-final-test.txt`。
- `gleam build` (root): exit 0、warning 1。既存の `src/framework/secret.gleam` unused private constructor。`build/gen-7-root-build.txt`。
- `cd gen && gleam build`: exit 0、warning 0。`gen/build/gen-7-gen-build.txt`。
- `cd gen/fixtures/article/public && gleam build`: exit 0、`Compiled in 0.04s`。`gen/fixtures/article/public/build/gen-7-fixture-build.txt`。
- 出力不変条件: 作業前 `/tmp/gen7-before.xblKiC` と実装後 `/tmp/gen7-fixture-check.NI3GEK` の `style.css`、`load/layout.gleam`、`load/article/arg_slug/page.gleam` を `diff -u` し、**各 diff 0 行**。`Frame.cols/rows/template` の省略と `Fixed.cell: Flow` の現行出力を維持した。
- Fixture 生成 1 回目 / 2 回目: どちらも exit 0、**86 files**。`gen/build/gen-7-fixture-output-final-1.sha256` と `gen/build/gen-7-fixture-output-final-2.sha256` の比較は **差分 0**。再生成ログは `gen/build/gen-7-fixture-generate-final-1.txt` / `gen/build/gen-7-fixture-generate-final-2.txt`。
- fixture の `gleam.toml` は 0.7.0 の path lock を保持していた。`gleam build` 自体では lock が動かなかったため、`cd gen` と fixture face で `gleam update yumemi` を実行して 0.8.0 に選び直し、その後の各 build が exit 0。両 manifest は 0.8.0。
- `node gen/scripts/verify-front-ssr.mjs`: **ALL PASS**。NO-JS / initial POST / island / selected POST / 同一 URL reload を確認。`gen/build/gen-7-front-ssr.txt`。
- `node gen/scripts/verify-front-isolate.mjs`: **40 requests、ALL PASS**。各 response の style は length 2228 で安定。`gen/build/gen-7-front-isolate.txt`。stub の route I/O は維持されたため `worker-entry.mjs` は変更していない。
- 指定 snapshot の read-only trial は `/home/yumemism/.codex-agents/runs/niekawa-20260924-044509-82060-7565/ms-9c2b0bd/api` から `/tmp/gen7-musearch-trial.n6nXW3` へ出力し、1175 files。生成 `www/src/gen/api.gleam` の付属入口表は 6 行。generator は既存 API service diagnostics 20 件で stop code 4、warning 30 件。入力 snapshot は変更していない。`gen/build/gen-7-snapshot-trial.txt`。
- `Span` / `At` wrapper の Gleam 構文は `/tmp/gen7-grid-custom.xYBfhL` の複製 fixture で生成後に face build し、exit 0。複製の layout source、tracked fixture、snapshot は変更していない。generator log `gen/build/gen-7-grid-custom-generate.txt`。

## 変更 file

- `gen/src/yumemi_gen.gleam`, `gen/src/yumemi_gen/model.gleam`, `gen/src/yumemi_gen/reader.gleam`, `gen/src/yumemi_gen/reader/front.gleam`, `gen/src/yumemi_gen/emit/front.gleam`, `gen/test/yumemi_gen_test.gleam`
- `gen/manifest.toml`, `gen/fixtures/article/public/manifest.toml`
- `gen/fixtures/article/public/priv/static/_yumemi/client.mjs`, `style.css`
- `gen/fixtures/article/public/src/gen/api.gleam`, `blocks_preview.gleam`, `live/article_create.gleam`, `live/article_publish.gleam`, `live/transport_ffi.mjs`, `load/article/arg_slug/page.gleam`, `load/layout.gleam`, `route.gleam`, `shell.mjs`, `widgets.gleam`
- `results.md`

`gen/fixtures/article/db/` と `gen/fixtures/article/src/gen/` は生成で作られた untracked のまま。commit に入れない。

# gen-7 C+D ── 静的資料の写しと shell 必須化 (2026-09-24)

## 状態

- branch `impl/gen-7`、開始 HEAD `b5ed2cf`、squash 基点 `0c59f35`。
- 束 C: 面の `.gleam` 走査と別に `<app>/src/external_hosts.mjs` / `<repo-root>/docs/api-v1.md` を読む口を追加。`.mjs` は `Object.freeze([...])` の限定字句読みで6欄を検査し、形が変われば stop。Markdown は解釈せず、原文を `el.text` に写す。生成名は front-4 の `Side` / `Host` / `hosts` / `nodes()` を維持し、sha256 12桁を付けた。
- 診断分類: 入力が無い = `Missing` / exit 3。I/O で読めない、または `.mjs` の形を読めない = `Syntax` / exit 2。空の表へ置き換えて続行しない。
- 付属入口: fixture に `api/src/gen/http_runtime.mjs` の2件を置き、`api.gleam` の件数・name・method・path の一致試験を追加。
- 束 D: `src/shell.gleam` がない面は空の仮値を保持して `Missing` / exit 3 を追加する。既定色・言語・package 名を無い面へ補わない。理由は gen-6 裁定10「手書きが先、生成器が後」の逆転防止。専用 unit test で shell unit を除いて検査し、fixture の ★ は変更していない。
- `src/framework/`、root `gleam.toml`、fixture の既存 `public/src/shell.gleam` は変更していない。

## DDL

無し。migration / schema は作成・変更していない。

## 検証

- `cd gen && gleam test`: **146 passed, no failures**。`gen/build/gen-7-cd-test.txt`。
- `gleam build` (root): exit 0、既存 warning 1件 (`src/framework/secret.gleam:5` unused private constructor)。`build/gen-7-root-build.txt`。
- fixture generation を同条件で2回実行: 両方 exit 0 / **88 files**。生成対象88ファイルの SHA-256 manifest は一致。`gen/build/gen-7-fixture-first.txt`、`gen/build/gen-7-fixture-second.txt`、`gen/build/gen-7-generated-first.sha256`、`gen/build/gen-7-generated-second.sha256`。
- `cd gen/fixtures/article/public && gleam build`: exit 0、`Compiled in 0.04s`。`gen/build/gen-7-fixture-build.txt`。
- musearch snapshot の read-only trial は `.../ms-9c2b0bd/api` から `.../scratch-gen-7-cd-attempt1` へ出力。**1181 files = 1175 + 6**、exit 2 が0、exit 3 が1、exit 4 が20、警告29。`gen/build/gen-7-snapshot.txt`。付属入口は `http_runtime.mjs` の6件と、www / muses / console 各 `api.gleam` の6件を name / method / path で比較し全て一致。
- snapshot の shell 状態は指示前提と異なる。read-only 確認で `www/src/shell.gleam` は無く、`muses/src/shell.gleam` と `console/src/shell.gleam` は存在した。そのため exit 3 は www の1件のみ。snapshot は変更していない。
- 確かめたこと: 上記 build / test / 2回生成差分 / snapshot 診断数と付属入口表の比較。
- 確かめていないこと: `doc/api_v1.gleam` の画面上の表示確認。build で型検査済み。

# gen-7 F ── gen-6 P1 残り

## 状態

- 作業木 `impl/gen-7`。gen-6 P1 #3, #5, #10, #2, #7 はすべて実装・検証済み。
- Blob/Time 等の primitive decoder は `decode.new_primitive_decoder` で dynamic 値を parse する。invalid string / 非 string は decode error になり、失敗時だけ固定 placeholder を parse して primitive decoder の同型 error 値にする。入力ごとの `let assert` は無い。既知の固定 placeholder 自体が将来 parse 不能になった場合だけ fallback の `panic` に入るが、現在の Blob / Time 値は試験で parse 成功を確認した。
- `gen/fixtures/article/public` の ★ は変更していない。

## DDL

無し。

## 検証

- `cd gen && gleam test`: final **154 passed, no failures**。`gen/build/gen7-final-gen-test.txt`。`front_emit_opaque_decoders_reject_invalid_input_without_assert_test` は空 Blob、不正 Time、非文字列 Blob を decode error として確認。
- fixture generator final runs: exit 0 / **88 files**、A/B diff 空、tracked `public/src/gen` / static bundle と untracked `db/` / `src/gen/` が出力と一致。`gen/build/gen7-final-fixture-a.txt`、`gen/build/gen7-final-fixture-b.txt`。
- `gleam build` (root): exit 0、既存 warning 1件 (`src/framework/secret.gleam:5`, unused private constructor)。`build/gen7-final-root-build.txt`。

## gen-6 P1 #5 ── Blob 背景画像の CSS URL

- `option_background` の Blob branch は `to_string(value)` をそのまま返さず、`url("…")` に包む生成 Gleam を出すよう変更。
- `front_emit_blob_theme_wraps_image_in_quoted_css_url_test` を追加。合成 PageTheme の `background_image: Option(Blob)` から生成された page source に、引用符付き `url(...)` を確認。
- `cd gen && gleam test`: **151 passed, no failures**。`gen/build/gen7-p1-5-tests.txt`。
- fixture generator 2回: exit 0 / **88 files**、出力間 diff 空。tracked fixture 出力および既存 untracked `db/`・`src/gen/` と一致。`gen/build/gen7-p1-5-fixture-a.txt`、`gen/build/gen7-p1-5-fixture-b.txt`。
- fixture の PageTheme は `Option(String)` のため、tracked page に変更は無い。Blob branch は合成試験で確認。

## gen-6 P1 #10 ── widget_list Summary logic

- `service/widget_list.logic` now branches on `args.widget`: `ArticleFeed` rows become `Article`, and `ArticleKinds` rows become `Summary`, both built from the returned article row.
- `widget_list_logic_builds_summary_for_article_kinds_test` checks both constructor branches in the fixture service source.
- Fixture generation: exit 0 / **88 files**; `build/gen7-p1-10-fixture-b` and `-c` are identical. Generated tracked `public/src/gen` and client bundle match the generator. The generated `api.gleam`, `service.gleam`, `out/widget_list.gleam`, `blocks_preview.gleam`, `shell.mjs`, `transport_ffi.mjs`, and `client.mjs` changed only in their SHA-256 headers; the Out decoder body stayed the same. Back `src/gen/` and `db/` were refreshed and remain untracked.
- `cd gen && gleam test`: **152 passed, no failures** (`gen/build/gen7-p1-10-tests-final.txt`). Standalone `public` package `gleam build` exited 0 (`gen/build/gen7-p1-10-public-build.txt`); this incremental build log contains 42 transitive-dependency notices.

## gen-6 P1 #2 ── Block preview の Layout 配置

- `blocks_preview.gleam` 生成時に Layout の PC / tablet / SP placements を集め、header/nav/footer 等の area に対応 Block を描画。page area の全 Block listing は維持し、Layout 配置が無い area は名前表示を維持。
- `front_emit_blocks_preview_places_layout_blocks_by_area_test` を追加。合成 Layout の header/nav/footer 各 Block と、実 fixture の PC placements が空で SP にだけある `SiteHeader` を確認。
- 生成 tracked `blocks_preview.gleam` は header の `el.text("header")` から `site_header.view(Nil)` へ変化。
- `node gen/scripts/build-blocks.mjs`: **BLOCKS: PASS (6 blocks)**。`public/build/blocks.html` の実出力も確認し、header area 内に `blocks/site_header | of Nil | Nil` と `<header class=...>記事</header>` がある。HTML は build 出力。
- fixture generator 2回: exit 0 / **88 files**、出力差分空。tracked `public/src/gen`、static bundle、および untracked `db/`・`src/gen/` は generator 出力と一致。`gen/build/gen7-p1-2-fixture-a.txt`、`gen/build/gen7-p1-2-fixture-b.txt`。
- `cd gen && gleam test`: **153 passed, no failures**。`gen/build/gen7-p1-2-tests.txt`。

## gen-6 P1 #7 ── validate failure messages

- `validate_text` now passes a constraint-specific message to `validate_field`. Pattern / Text / Markdown / Range / UUID / URL specs produce messages that identify their constraint; failed validation returns that message with its `Field`.
- `front_emit_validate_errors_name_the_failed_constraint_test` checks generated `ArticleCreate` and `ArticlePublish` sources for concrete Slug / Title / Markdown messages and absence of the old `"invalid"` payload.
- Generated `article_create.gleam` now reports the 1–64 character slug pattern, the 1–120 character title limit, or the Markdown constraint. `article_publish.gleam` reports the slug pattern. The bundled `client.mjs` carries the same `message` argument through its validation error tuple.
- fixture generator outputs: **88 files**. First output's client bundle reflected the previous tracked live files; after syncing that generated source and bundle, the next two runs (`fixture-b` and `fixture-c`) were byte-identical. `public/src/gen`, static bundle, untracked `src/gen/`, and `db/` match the final generated output. Logs: `gen/build/gen7-p1-7-fixture-a.txt`, `-b.txt`, `-c.txt`.
- `cd gen && gleam test`: **154 passed, no failures** (`gen/build/gen7-p1-7-tests-final.txt`). Standalone public package build exited 0; the incremental output contained 29 transitive-dependency notices (`gen/build/gen7-p1-7-public-build.txt`).

## 最終検証

- `node gen/scripts/verify-front-ssr.mjs`: **ALL PASS**。NO-JS / INITIAL / SELECTED / ISLAND / RELOAD を確認し、document request は2回。`gen/build/gen7-final-front-ssr.txt`。
- `node gen/scripts/verify-front-isolate.mjs`: **ALL PASS**、40 requests、first / second style は各2228 chars。`gen/build/gen7-final-front-isolate.txt`。
- `node gen/scripts/verify-front-given.mjs`: ESCAPE / SAME TAG ISLANDS / EXISTING ATTRIBUTE / CROSS TAG ORDER が全 PASS。`gen/build/gen7-final-front-given.txt`。
- `node gen/scripts/build-blocks.mjs`: **BLOCKS: PASS (6 blocks)**。最終 `blocks.html` の header area 内に `site_header.view(Nil)` 相当の本文と実 `<header>` がある。`gen/build/gen7-final-blocks.txt`。
- Musearch は指定 snapshot `/home/yumemism/.codex-agents/runs/niekawa-20260924-044509-82060-7565/ms-9c2b0bd/api` から読み、出力は同 run_dir の `out-gen7-f-final-b` / `out-gen7-f-final-c` に置いた。両方 **1181 files**、`diff -rq` は空、generator exit **4**。診断は exit1 **2** (`metrics_muse` / `metrics_store`: `entity/visit.Source` の discriminator 不足)、exit2 **0**、exit3 **1** (`www/src/shell.gleam` 不在)、exit4 **20**、warning **29**。gen-7 C+D の件数から変化なし。各面の Out decoder/runtime build は console 17 / muses 43 / www 14 modules で PASS、esbuild も PASS。`gen/build/gen7-f-snapshot-b.txt`、`gen/build/gen7-f-snapshot-c.txt`。
- 修正前の snapshot 試走では opaque decoder の括弧付き let 式が formatter に拒否され exit1 になった。生成式を decoder callback 内の let/case に直した後の2回は上記のとおり formatter / Out decoder build を通過した。
- 確かめていないこと: screenshot による responsive viewport の見た目レビュー。fixture SSR / isolate / given / Block preview の実行確認は済み。

# gen-7 G ── 本記述と最終統合 (2026-09-24)

## 状態

- 作業開始時は branch `impl/gen-7`、HEAD `0505883`、基点 `0c59f35`。完了報告と全分類は [`docs/reports/gen-7.md`](docs/reports/gen-7.md) にまとめた。
- gen-6 P1 13件と束 A〜F / 本便の追加分を分類し、未分類0件を確認対象にした。束 D の exit 3 は www のみ1件と訂正した。musearch snapshot の最終値は exit 1 が2件、exit 2 が0件、exit 3 が1件、exit 4 が20行、warning 29、1181 file、再走 diff 空。
- 動詞対応は add / edit / remove の URL が service 単位で9 / 7 / 6、face 展開後36 / 28 / 25。registry method/path 直接一致は47 → 53。履歴値「採用済み一致」290は別 snapshot (`c99c107`) の値で、今回の基点と直接比較しない。
- 作業差分は `docs/reports/gen-7.md` と root `results.md` の2 file。生成器 `gen/src/`、framework `src/framework/`、fixture `gen/fixtures/` のソースは変更していない。
- `gen/fixtures/article/db/` と `gen/fixtures/article/src/gen/` は既存の untracked のまま、commit 対象外。

## DDL

無し。DB / migration / schema は変更していない。

## 追随便への申し送り

- yumemi-5 は Page 39・Layout 3・Frame 57・Fixed 69 の const と `calls` 46本を、`reads: []` / `cell: Flow` / `cols: []` / `rows: []` / `template: []` を含む形へ追随する。
- `entity/visit.Source` の複数 variant を判別できず exit 1 が2件出た。`kind` 欄か判別規則を決める。
- `gen/scripts/audit-route-registry.mjs` の非 system service 数87は今回 snapshot の103と不一致。snapshot で registry 監査を回す便で修正する。
- `api/src/gen/http_runtime.mjs:413` は GENERATED header を持つ付属入口表の現ソース。back の世代を揃えると移動または消失する可能性がある。
- `transport_ffi.mjs` の hash 入力 `hash.entry <> string.inspect(front.components)` は reader model の変更だけでも変化する。minify (gen-6 P1-6)は申し送り最後尾、per-element given (P1-13)は Lustre 待ち。P1-4 / P1-9 / P1-11 も残る。
- Hex 0.8.0 の publish は鷹野(承認後、yumemi-5 の前)。

## 確かめたこと

- `git diff --check`: 出力無し。
- `git diff --stat 0c59f35 -- db/ gen/fixtures/article/db/`: 空。
- `git log --oneline 0c59f35..impl/gen-7`: 最終 squash 後に1 commit。
- `git status --short`: untracked は指定の `gen/fixtures/article/db/` と `gen/fixtures/article/src/gen/` の2本。
- この便で build / test は実行していない。前巡の最終値と検証証跡は [`docs/reports/gen-7.md`](docs/reports/gen-7.md) に記載した。

## 確かめていないこと

- 追加の build / test は未実行。今回の依頼に含まれる履歴・差分・untracked・DDL の検証を行う。

# yumemi-1f 巡 2 束 A 続き (2026-09-25)

## 状態

- priority 1: root vars test、commit `bbe39c2`。
- priority 2: Widget 枠名 / 生成 `WidgetKey` を除去。Widget の全 Service Args を同名 Var から解決し、同一 Service の load source を統合。fixture の `widget_list` は `widget: Option(String)` を `Query("widget")` から読む。commit `7f36852`。
- priority 3: 7検査の負ケースと未使用 Var の警告を検証。診断は対象 source path、検査番号、Block / Arg、1行性を assert。commit `cdaff6b`。
- `Track.Auto` と `TrackSize` の auto CSS を実装。Gleam は同一 module に同名構成子を定義できず、`TrackSize.Auto` はコンパイル不可のため、`AutoSize` を置いた(`FrSize` / `RemSize` / `PxSize` の流儀、贄川が P2 で改名)。CSS は `auto` を出力する。
- AuthOrigin は public 面の Layout に置いた。Vars はページごとの `src/gen/load/<page>.gleam` に生成する。DDL 無し。

## 検証

- root `gleam build`: exit 0、既存 warning 1 (`src/framework/secret.gleam:5`)。`gen/build/y1f-a-root-build.txt`。
- root `gleam test`: exit 0、`Framework checks passed: 8 groups`。`gen/build/y1f-a-root-test.txt`。
- `cd gen && gleam test`: **189 passed, no failures**。`gen/build/y1f-a-gen-test.txt`。
- fixture generation を2回: 各 exit 0 / 111 files、`diff -qr` 空。`gen/build/y1f-a-fixture-final-{one,two}.txt` / `gen/build/y1f-a-fixture-final-diff.txt`。
- 生成物を `gen/fixtures/article/{public,admin}/src/gen` に同期し、各 diff は空。public / admin face build は exit 0、warning 0。`gen/build/y1f-a-{public,admin}-build.txt` と `gen/build/y1f-a-fixture-{public,admin}-sync.txt`。
- root と gen の変更対象 `gleam format --check` は exit 0。public / admin の `src/gen` format check も exit 0。44 generated `.gleam` の SHA-256 header 欠けは0。
- 変数検査 1〜7 の CLI 負 fixture は各 exit 4、各ログに検査番号と file / Block / 欄が出た。`gen/build/y1f-a-neg-{arg_without_var,path_without_segment,query_to_string,required_service_arg_missing,layout_path_var,bundled_input,of_not_placed}.txt`。
- snapshot `/home/yumemism/.codex-agents/runs/niekawa-20260924-220716-1228501-25668/ms-8eed4d8/api` は read-only 入力、out は `gen/build/y1f-a-ms1`。1,372 files。診断: exit 0 警告48、exit 1=3、exit 2=0、exit 3=1、exit 4=111。`gen/build/y1f-a-ms1.txt`。親 run directory を誤指定した最初の probe は `src/types.gleam` 不在で exit 3 になり、出力前に停止した。
- repo 全体の `gleam format --check` は既存の未整形ファイルで exit 1。今回変更した範囲と生成物の targeted check は通過。証跡は `gen/build/y1f-a-root-format.txt` / `gen/build/y1f-a-gen-format.txt`。
- `gen/fixtures/article/db/` と `gen/fixtures/article/src/gen/` は開始時から存在せず、差分も空。指示書記載の場当たり生成物として出力に含めていない。

## 残り / 次巡

- 殻の実値読み (`/api/session`、env、Path / Query / Service Args、`given`、401) は次巡。今回の `shell.mjs` は Vars を空値で作って load に渡す仮配線。
- `TrackSize.Auto` と `Track.Auto` の別構成子名は Gleam の module namespace 制約に衝突する。贄川が `AutoSize`(`<X>Size` の流儀)に決めた。
- root / gen 全体の format check を通すための無関係な既存未整形ファイルは今回の作業域外。

# yumemi-1f 巡 3 束 A (2026-09-25)

## 状態

- B (impl/yumemi-1f-b, 334dc0d) を no-ff merge。report と patch 2本の計3 file。
- shell は Path / Query / Session / Origin / AuthOrigin から Vars を読む。Session は Page ごとに最大1回 /api/session を呼び、Cookie を転送する。
- reader の PageServiceArgs に page root Service の解決も追加。shell は source / given ごとに Args 欄, Vars 欄, Option の3値組を生成器から受け、Args と request path / query を組む。shell 内に対応表は置かない。
- String の Session 欄が欠けたら renderPage が 401、Option 欄は None。Origin env が欠けたら renderPage が 500 を返し、本文に env 名を出す。redirect と既定 origin は置かない。
- verify 用 no-session Page を public fixture に追加。fixture app 内へは生成せず、out と preview は gen/build/y1f-a-* に出した。DDL 無し。

## 確かめたこと

- fixture generation を2回: 各 112 files、diff -qr は0行。gen/build/y1f-a-generated-v4-one/、-v4-two/、gen/build/y1f-a-generated-v4-diff.txt。
- 両 out の gleam format --check exit 0。各74 .gleam、SHA-256 header 欠け0。gen/build/y1f-a-generated-format-check.txt、header 集計は実行ログ。
- root gleam build: exit 0、既存 warning 1 (src/framework/secret.gleam:5)。gen/build/y1f-a-root-build.txt。
- cd gen && gleam test: 189 passed, no failures。gen/build/y1f-a-gen-test.txt。
- public / admin scratch build: 両方 exit 0。warning は既存の secret constructor 1件のみ。gen/build/y1f-a-verify/gleam-build.txt、gen/build/y1f-a-verify-admin/gleam-build.txt。
- SSR / isolate / given / file / overlay はすべて ALL PASS。証跡は gen/build/y1f-a-verify-{ssr,isolate,given,file,overlay}.txt。Block preview は public 7 Blocks、admin 1 Block が PASS、gen/build/y1f-a-blocks-preview/{public,admin}-blocks.html。
- SSR request 列: GET /api/session → GET /api/widgets?widget=summary&slug=42 → GET /api/articles/42 → GET /api/articles。gen/build/y1f-a-verify/requests.txt。public Session は匿名 / subject 無し / handle 無しで 200 + None、Session Var 無し Page は0回。admin は3条件で401、subject ありで200。Origin env 欠落は env 名を含む500。
- code after r8 の git diff --check は exit 0。基点 e82121e から全体では exit 2、B から統合した patch artifact の空 diff 行に trailing whitespace があり、f5min 38行 / f6 156行。証跡: gen/build/y1f-a-final-diff-check.txt、gen/build/y1f-a-code-diff-check.txt。

## 確かめていないこと

- root gleam test は未実行。今回の指示対象は root build と gen test。

## 残り

- 1〜3 の完了条件はすべて満たした。merge commit を残し、今回の実装・検証 checkpoint は1本へ squash した。
- B の patch artifact に含まれる whitespace 194箇所はそのまま保持。今回の実装・verify 差分の whitespace は0件。
