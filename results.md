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
