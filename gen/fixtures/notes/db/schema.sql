-- ★ db/schema.sql ── notes の DDL(app のもの。生成器は読まない)。workerd で起こす確かめが空の PG に当てる。
CREATE SCHEMA app;
CREATE SCHEMA framework;

CREATE TABLE app.note (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 title text NOT NULL,
 body text NOT NULL,
 created_at timestamptz NOT NULL
);
CREATE INDEX note_created_at ON app.note (created_at DESC, id DESC);

-- 書きの要求は段ごとに 1 行(`db/queries/framework/audit.sql`)
CREATE TABLE framework.audit (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 request_id uuid NOT NULL,
 stage text NOT NULL,
 service text,
 party text,
 result text NOT NULL,
 at timestamptz NOT NULL
);

-- 生成の更新の文(`verb/edit_note`)が 0 行で止めるのに使う
CREATE FUNCTION framework.require_rows(affected bigint, code text) RETURNS bigint LANGUAGE plpgsql AS $$
BEGIN
 IF affected = 0 THEN RAISE EXCEPTION USING ERRCODE='P0001', MESSAGE=code; END IF;
 RETURN affected;
END $$;
