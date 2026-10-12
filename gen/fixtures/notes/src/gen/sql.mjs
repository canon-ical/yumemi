//// GENERATED from db/queries/** [sha256:fe4ede23cb20] — 手で編集しない
export const SQL = {
  "framework/audit": "INSERT INTO framework.audit(request_id,stage,service,party,result,at) VALUES($1,$2,$3,$4,$5,$6);\n",
  "framework/outbox_claim": "-- GENERATED from framework.outbox_claim — 手で編集しない\nUPDATE framework.outbox SET sent_at=now() WHERE id=$1 AND done_at IS NULL\nAND (sent_at IS NULL OR sent_at<now()-interval '1 hour') RETURNING id;\n",
  "note_delete/root": "-- ★ root の 1 文。主体も相も無いので、id で 1 行読むだけ。\n-- root: arg:id\nSELECT n.* FROM app.note n WHERE n.id=$1::uuid;\n",
  "note_edit/root": "-- ★ root の 1 文。主体も相も無いので、id で 1 行読むだけ。\n-- root: arg:id\nSELECT n.* FROM app.note n WHERE n.id=$1::uuid;\n",
  "note_list/items": "-- GENERATED from service.note_list.items [sha256:66a620776caf] — 手で編集しない\nSELECT n.*\nFROM app.note n\nWHERE ($2::timestamptz IS NULL OR (n.created_at,n.id)<($2,$3::uuid))\nORDER BY n.created_at DESC,n.id DESC\nLIMIT $1 + 1;\n",
  "note_read/root": "-- ★ root の 1 文。主体も相も無いので、id で 1 行読むだけ。\n-- root: arg:id\nSELECT n.* FROM app.note n WHERE n.id=$1::uuid;\n",
  "verb/create_note": "-- GENERATED from entity.note [sha256:1603a38d9df4] — 手で編集しない\nINSERT INTO app.note(id,title,body,created_at)\nVALUES($1::uuid,$2,$3,$4::timestamptz) RETURNING id,title,body,created_at;\n",
  "verb/delete_note": "-- GENERATED from entity.note [sha256:1603a38d9df4] — 手で編集しない\nDELETE FROM app.note WHERE id=$1::uuid;\n",
  "verb/edit_note": "-- GENERATED from entity.note [sha256:1603a38d9df4] — 手で編集しない\nWITH changed AS (UPDATE app.note SET title=$2,body=$3\nWHERE id=$1::uuid RETURNING id)\nSELECT framework.require_rows(count(*),'conflict') FROM changed;\n",
  "verb/update_note_created_at": "-- GENERATED from entity.note [sha256:1603a38d9df4] — 手で編集しない\nWITH changed AS (UPDATE app.note SET created_at=$2::timestamptz\nWHERE id=$1::uuid RETURNING id)\nSELECT framework.require_rows(count(*),'conflict') FROM changed;\n",
};
