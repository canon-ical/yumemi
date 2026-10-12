//// GENERATED from db/queries/** [sha256:54f6b8da8abb] — 手で編集しない
export const SQL = {
  "framework/audit": "INSERT INTO framework.audit(request_id,stage,service,party,result,at) VALUES($1,$2,$3,$4,$5,$6);\n",
  "framework/idempotency_find": "-- GENERATED from framework.idempotency_find — 手で編集しない\nSELECT request_hash,result FROM framework.idempotency WHERE party=$1 AND key=$2;\n",
  "framework/idempotency_record": "-- GENERATED from framework.idempotency_record — 手で編集しない\nINSERT INTO framework.idempotency(party,key,request_hash,result,created_at) VALUES($1,$2,$3,$4::jsonb,$5::timestamptz);\n",
  "framework/idempotency_repair": "-- GENERATED from framework.idempotency_repair — 手で編集しない\nUPDATE framework.idempotency SET result=$3::jsonb WHERE party=$1 AND key=$2;\n",
  "framework/idempotency_sweep": "-- GENERATED from framework.idempotency_sweep — 手で編集しない\nDELETE FROM framework.idempotency WHERE created_at<$1::timestamptz;\n",
  "framework/outbox_claim": "-- GENERATED from framework.outbox_claim — 手で編集しない\nUPDATE framework.outbox SET sent_at=now() WHERE id=$1 AND done_at IS NULL\nAND (sent_at IS NULL OR sent_at<now()-interval '1 hour') RETURNING id;\n",
  "note_delete/root": "-- ★ root の 1 文。主体も相も無いので、id で 1 行読むだけ。\n-- root: arg:id\nSELECT n.* FROM app.note n WHERE n.id=$1::uuid;\n",
  "note_edit/root": "-- ★ root の 1 文。主体も相も無いので、id で 1 行読むだけ。\n-- root: arg:id\nSELECT n.* FROM app.note n WHERE n.id=$1::uuid;\n",
  "note_list/items": "-- GENERATED from service.note_list.items [sha256:b5ae9fbf02b1] — 手で編集しない\nSELECT n.*\nFROM app.note n\nWHERE ($2::timestamptz IS NULL OR (n.created_at,n.id)<($2,$3::uuid))\nORDER BY n.created_at DESC,n.id DESC\nLIMIT $1 + 1;\n",
  "note_read/root": "-- ★ root の 1 文。主体も相も無いので、id で 1 行読むだけ。\n-- root: arg:id\nSELECT n.* FROM app.note n WHERE n.id=$1::uuid;\n",
  "verb/create_note": "-- GENERATED from entity.note [sha256:7e3f483b7578] — 手で編集しない\nINSERT INTO app.note(id,title,body,created_at)\nVALUES($1::uuid,$2,$3,$4::timestamptz) RETURNING id,title,body,created_at;\n",
  "verb/delete_note": "-- GENERATED from entity.note [sha256:7e3f483b7578] — 手で編集しない\nDELETE FROM app.note WHERE id=$1::uuid;\n",
  "verb/edit_note": "-- GENERATED from entity.note [sha256:7e3f483b7578] — 手で編集しない\nWITH changed AS (UPDATE app.note SET title=$2,body=$3\nWHERE id=$1::uuid RETURNING id)\nSELECT framework.require_rows(count(*),'conflict') FROM changed;\n",
  "verb/update_note_created_at": "-- GENERATED from entity.note [sha256:7e3f483b7578] — 手で編集しない\nWITH changed AS (UPDATE app.note SET created_at=$2::timestamptz\nWHERE id=$1::uuid RETURNING id)\nSELECT framework.require_rows(count(*),'conflict') FROM changed;\n",
};
