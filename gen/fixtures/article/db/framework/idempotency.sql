-- GENERATED from yumemi framework.idempotency [sha256:1c4c4261fd41] — 手で編集しない
-- ▲ app の DB に当てるのは DDL の便。書きの要求の `Idempotency-Key` ごとに、結果の応答を 1 行。
-- party は session・API key の party、無ければ browser の印(`browser:<id>`)か `anonymous`。
-- request_hash は Service の名と欄の SHA-256(同じキーで違う本文は 409)。result は応答の status・型・本文。
CREATE SCHEMA IF NOT EXISTS framework;

CREATE TABLE IF NOT EXISTS framework.idempotency (
  party text NOT NULL,
  key text NOT NULL,
  request_hash text NOT NULL,
  result jsonb NOT NULL,
  created_at timestamptz NOT NULL,
  CONSTRAINT idempotency_pkey PRIMARY KEY (party, key)
);
-- 保持期間を過ぎた行を cron が消す(`framework/idempotency_sweep`)
CREATE INDEX IF NOT EXISTS idempotency_created_at ON framework.idempotency (created_at);
