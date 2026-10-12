//// 冪等キー(0.13)── framework が持つ表 `framework.idempotency` の DDL と SQL。
////
//// - `db/framework/idempotency.sql` ── 表と索引の DDL。生成器が ▲ として吐き、app の DB に当てるのは DDL の便
////   (鷹野専管)。`src/server.gleam` を宣言した app には全部吐く(書きの Service への要求がキーを持てば runtime が使う)
//// - SQL の既定 `framework/idempotency_{find,record,repair,sweep}` ── `sql.mjs` に足す(app に ★ があれば勝つ)
////
//// 記録は書きの transaction の先頭に入る(`yumemi/server/runtime.mjs` の finish)。(party, key) の一意の制約が、
//// 並んで来た 2 本目を transaction ごと落とす。古い行は cron が保持期間(既定 24 時間、env
//// `IDEMPOTENCY_RETENTION_HOURS`)の後に消す(`yumemi/server/cron.mjs` の `purgeIdempotency`)。

import yumemi/gen/digest
import yumemi/gen/emit/types.{type File, File}
import yumemi/schema

pub fn files() -> List(File) {
  [File(path: "db/framework/idempotency.sql", text: ddl())]
}

pub fn queries() -> List(#(String, String)) {
  let f = schema.framework
  [
    #(
      "framework/idempotency_find",
      "-- GENERATED from framework.idempotency_find — 手で編集しない\n"
        <> "SELECT request_hash,result FROM "
        <> f
        <> ".idempotency WHERE party=$1 AND key=$2;\n",
    ),
    #(
      "framework/idempotency_record",
      "-- GENERATED from framework.idempotency_record — 手で編集しない\n"
        <> "INSERT INTO "
        <> f
        <> ".idempotency(party,key,request_hash,result,created_at) VALUES($1,$2,$3,$4::jsonb,$5::timestamptz);\n",
    ),
    #(
      "framework/idempotency_repair",
      "-- GENERATED from framework.idempotency_repair — 手で編集しない\n"
        <> "UPDATE "
        <> f
        <> ".idempotency SET result=$3::jsonb WHERE party=$1 AND key=$2;\n",
    ),
    #(
      "framework/idempotency_sweep",
      "-- GENERATED from framework.idempotency_sweep — 手で編集しない\n"
        <> "DELETE FROM "
        <> f
        <> ".idempotency WHERE created_at<$1::timestamptz;\n",
    ),
  ]
}

/// header の hash は DDL の本文から(app の入力に依らない、framework の版で変わる)。
pub fn ddl() -> String {
  let body = ddl_body()
  "-- GENERATED from yumemi framework.idempotency [sha256:"
  <> digest.short(body)
  <> "] — 手で編集しない\n"
  <> body
}

fn ddl_body() -> String {
  let f = schema.framework
  "-- ▲ app の DB に当てるのは DDL の便。書きの要求の `Idempotency-Key` ごとに、結果の応答を 1 行。
-- party は session・API key の party、無ければ browser の印(`browser:<id>`)か `anonymous`。
-- request_hash は Service の名と欄の SHA-256(同じキーで違う本文は 409)。result は応答の status・型・本文。
CREATE SCHEMA IF NOT EXISTS " <> f <> ";

CREATE TABLE IF NOT EXISTS " <> f <> ".idempotency (
  party text NOT NULL,
  key text NOT NULL,
  request_hash text NOT NULL,
  result jsonb NOT NULL,
  created_at timestamptz NOT NULL,
  CONSTRAINT idempotency_pkey PRIMARY KEY (party, key)
);
-- 保持期間を過ぎた行を cron が消す(`framework/idempotency_sweep`)
CREATE INDEX IF NOT EXISTS idempotency_created_at ON " <> f <> ".idempotency (created_at);
"
}
