# gen-3 verb 実装結果

## 実装

- src/framework/verbs.gleam を追加。Rule / Gate / Bump / Order を正典どおり追加。
- reader / model が Entity の verbs / ordered_by / upsert_key / edges を読むように拡張。
- key の組を全列で保持。複合 key の verb 関数、SQL の WHERE / RETURNING に全列を出す。部分 key しか表せない形は exit 1 で止める。
- src/gen/verb.gleam、gen/sql/queries/verb/*.sql、src/gen/phase.gleam の emitter を追加。
- AdvanceAll は exit 5、親列への DeleteWhere は exit 4。Article fixture で6動詞と集合削除・集合作成を検証。
- gen/draft/* は出していない。verb の型参照だけを出す。

## 検証

- cd gen && gleam check: 成功。
- cd gen && gleam test: 39 passed, no failures。
- Article probe: exit 0、31ファイル。verb SQL 18本。SQL内の Service 名ヒットなし。
- fixtures/flag の複合 key: update_chunk_text.sql / delete_chunk.sql の WHERE と RETURNING が a,b,c 全列。
- fixtures/flag_advance_all: exit 5。System Service と 10-model:258 を含む理由行。
- fixtures/flag_parent: exit 4。親列 parent を理由に停止。
- musearch は読み取り probe のみ。書き込みはしていない。

## 詰まった所

- AdvanceAll は生成器が途中で止まるため、複合 key の正常系と同じ fixture には置かず、flag_advance_all と flag_parent を検証用 fixture として分離した。
- 既存 flag の mixed-direction keyset は従来どおり exit 1 の診断を出す。

## r2 ── key 無し Entity の verb 縮退(P0)

### 実装

- `reader` は `key` が無いレコード Entity を読み続け、`path_key` だけの Entity は key として採用する。レコード型の無い `entity/ledger` は Entity 束から除外し、`entity/ledger: key 関数が無い` を Missing note に集約する。
- key 無し Entity は create / create-many だけを出し、update / named Update / delete / advance / DeleteWhere / reorder / put は Gleam と SQL の両方を出さない。create SQL の `RETURNING` は key が無い場合に Entity の persisted Property 列へ縮退する。
- `gen/fixtures/flag_no_key` と test を追加。no-key Lifecycle の create-only、全束書き切り、exit 3 note、`path_key` fallback を検証する。

### 検証

- `cd gen && gleam test`: **42 passed, no failures** (`build/gen3-p0-test.txt`)
- `cd gen && gleam check`: 成功 (`build/gen3-p0-check.txt`)
- musearch 読み取り生成: **411 files**, types 83 / query submodules 2(+`query.gleam`) / reads 34 / read SQL 48 / verb SQL 240。終了 **3**。stderr と `build/gen3-p0-musearch.2j3SYU/_diagnostics.txt` に `entity/ledger: key 関数が無い`。
- musearch の生成前後 `git status --short` は同一。既存の `?? docs/__pycache__/` 以外の状態変化なし。
