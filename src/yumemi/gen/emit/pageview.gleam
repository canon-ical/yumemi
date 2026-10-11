//// 数える口の器 `Store`(0.12、51 v6「記録と集計の器」)── framework が持つ表の DDL と SQL。
////
//// - `db/framework/pageview.sql` ── 表(印・訪問・event・集計)と 3 つの関数の DDL。生成器が ▲ として吐き、
////   app の DB に当てるのは DDL の便(鷹野専管)。面の門のどれかが `Store` を宣言した app だけ
//// - SQL の既定 `framework/pageview_record`・`framework/pageview_rollup` ── `sql.mjs` に足す(app に ★ があれば勝つ)
////
//// 二重計数のうち、id の再送(2)・連打 60 件/分(5)・2 tab の同時(6)は `pageview_record` が印の行ロックの下で持つ。
//// 訪問は同じ印の event が 30 分以内に続く並び。集計は UTC の日と月で、`excluded` の event は数字から除く。

import gleam/list
import yumemi/gen/emit/types.{type File, File}
import yumemi/gen/model
import yumemi/schema

/// 面の門のどれかが器 `Store` を宣言したか。
pub fn stored(app: model.App) -> Bool {
  list.any(app.server.counted, fn(counted) {
    case counted.sink {
      model.StoreSink(..) -> True
      model.ServiceSink(..) -> False
    }
  })
}

/// 集計の仕事を回す cron の式(framework の決め打ち、毎日 01:00 UTC)。app の wrangler の triggers に要る。
pub const rollup_schedule = "0 1 * * *"

pub fn files(app: model.App) -> List(File) {
  case stored(app) {
    False -> []
    True -> [File(path: "db/framework/pageview.sql", text: ddl())]
  }
}

pub fn queries(app: model.App) -> List(#(String, String)) {
  case stored(app) {
    False -> []
    True -> [
      #(
        "framework/pageview_record",
        "-- GENERATED from framework.pageview_record — 手で編集しない\n"
          <> "SELECT "
          <> schema.framework
          <> ".pageview_record($1::uuid,$2,$3,$4::timestamptz,$5,$6,$7::uuid,$8,$9,$10::timestamptz,$11,$12::jsonb,$13::jsonb,$14::boolean) AS outcome;\n",
      ),
      #(
        "framework/pageview_rollup",
        "-- GENERATED from framework.pageview_rollup — 手で編集しない\n"
          <> "SELECT "
          <> schema.framework
          <> ".pageview_rollup($1::timestamptz) AS done;\n",
      ),
    ]
  }
}

pub fn ddl() -> String {
  let f = schema.framework
  "-- GENERATED from yumemi(数える口の器 Store)— 手で編集しない
-- ▲ app の DB に当てるのは DDL の便。表は印・訪問・event・集計の 4 つ、関数は記録と集計の 3 つ。
CREATE SCHEMA IF NOT EXISTS " <> f <> ";

-- 印(ユニークの単位):browser の署名 cookie の id(32 桁の hex)
CREATE TABLE IF NOT EXISTS " <> f <> ".pageview_mark (
  id text PRIMARY KEY CHECK (id ~ '^[0-9a-f]{32}$'),
  first_at timestamptz NOT NULL,
  last_at timestamptz NOT NULL
);

-- 訪問:同じ印の event が 30 分以内に続く並び
CREATE TABLE IF NOT EXISTS " <> f <> ".pageview_visit (
  id uuid PRIMARY KEY,
  mark text NOT NULL REFERENCES " <> f <> ".pageview_mark (id),
  started_at timestamptz NOT NULL,
  last_at timestamptz NOT NULL,
  landing_path text NOT NULL,
  referrer_host text
);
CREATE INDEX IF NOT EXISTS pageview_visit_mark_last ON " <> f <> ".pageview_visit (mark, last_at DESC);

-- event:受け口が受けた 1 回の表示。excluded は app の exclude_when が真の event(行は作り、数字から除く)
CREATE TABLE IF NOT EXISTS " <> f <> ".pageview_event (
  id uuid PRIMARY KEY,
  mark text NOT NULL REFERENCES " <> f <> ".pageview_mark (id),
  visit uuid NOT NULL REFERENCES " <> f <> ".pageview_visit (id),
  face text NOT NULL,
  at timestamptz NOT NULL,
  client_at timestamptz,
  kind text NOT NULL CHECK (kind IN ('initial', 'reload', 'spa')),
  path text NOT NULL,
  prev uuid,
  referrer_path text,
  referrer_host text,
  party text,
  extra jsonb NOT NULL DEFAULT '{}'::jsonb,
  dims jsonb NOT NULL DEFAULT '{}'::jsonb,
  excluded boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS pageview_event_mark_at ON " <> f <> ".pageview_event (mark, at);
CREATE INDEX IF NOT EXISTS pageview_event_at ON " <> f <> ".pageview_event (at);

-- 集計:面 × 日・月 × 次元('site' は value ''、'path'、rollup_by の欄の名)。UTC の日の境
CREATE TABLE IF NOT EXISTS " <> f <> ".pageview_rollup (
  face text NOT NULL,
  period text NOT NULL CHECK (period IN ('day', 'month')),
  starts date NOT NULL,
  dimension text NOT NULL,
  value text NOT NULL,
  pv bigint NOT NULL,
  uniques bigint NOT NULL,
  visits bigint NOT NULL,
  roaming_visits bigint NOT NULL,
  PRIMARY KEY (face, period, starts, dimension, value)
);

-- 1 event を記録する。印の行を upsert して行ロックを取り(同じ印の 2 tab の同時を直列に)、その下で
-- 同じ id の再送は何もしない('duplicate')、直前 1 分に 60 件あれば書かない('limited')、
-- 最新の訪問が 30 分以内なら続き、無ければ訪問を作る
CREATE OR REPLACE FUNCTION " <> f <> ".pageview_record(
  p_id uuid, p_mark text, p_face text, p_at timestamptz, p_kind text, p_path text, p_prev uuid,
  p_referrer_path text, p_referrer_host text, p_client_at timestamptz, p_party text,
  p_extra jsonb, p_dims jsonb, p_excluded boolean
) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_visit uuid;
BEGIN
  INSERT INTO " <> f <> ".pageview_mark (id, first_at, last_at) VALUES (p_mark, p_at, p_at)
  ON CONFLICT (id) DO UPDATE SET last_at = GREATEST(" <> f <> ".pageview_mark.last_at, EXCLUDED.last_at);
  IF EXISTS (SELECT 1 FROM " <> f <> ".pageview_event WHERE id = p_id) THEN
    RETURN 'duplicate';
  END IF;
  IF (SELECT count(*) FROM " <> f <> ".pageview_event
      WHERE mark = p_mark AND at > p_at - interval '1 minute' AND at <= p_at) >= 60 THEN
    RETURN 'limited';
  END IF;
  SELECT id INTO v_visit FROM " <> f <> ".pageview_visit
  WHERE mark = p_mark AND last_at >= p_at - interval '30 minutes' AND started_at <= p_at
  ORDER BY last_at DESC LIMIT 1;
  IF v_visit IS NULL THEN
    v_visit := gen_random_uuid();
    INSERT INTO " <> f <> ".pageview_visit (id, mark, started_at, last_at, landing_path, referrer_host)
    VALUES (v_visit, p_mark, p_at, p_at, p_path, p_referrer_host);
  ELSE
    UPDATE " <> f <> ".pageview_visit SET last_at = GREATEST(last_at, p_at) WHERE id = v_visit;
  END IF;
  INSERT INTO " <> f <> ".pageview_event
    (id, mark, visit, face, at, client_at, kind, path, prev, referrer_path, referrer_host, party, extra, dims, excluded)
  VALUES
    (p_id, p_mark, v_visit, p_face, p_at, p_client_at, p_kind, p_path, p_prev, p_referrer_path, p_referrer_host,
     p_party, coalesce(p_extra, '{}'::jsonb), coalesce(p_dims, '{}'::jsonb), coalesce(p_excluded, false))
  ON CONFLICT (id) DO NOTHING;
  RETURN 'recorded';
END;
$$;

-- 1 つの期間 [p_from, p_to)(UTC の日)を畳み直す。PV・ユニーク(印の数)・訪問数・回遊訪問数(その面で
-- PV が 2 以上の訪問)を、site・path・rollup_by の欄(dims)の次元ごとに
CREATE OR REPLACE FUNCTION " <> f <> ".pageview_rollup_period(p_period text, p_from date, p_to date)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM " <> f <> ".pageview_rollup WHERE period = p_period AND starts = p_from;
  INSERT INTO " <> f <> ".pageview_rollup (face, period, starts, dimension, value, pv, uniques, visits, roaming_visits)
  WITH e AS (
    SELECT face, mark, visit, path, dims FROM " <> f <> ".pageview_event
    WHERE NOT excluded
      AND at >= (p_from::timestamp AT TIME ZONE 'UTC') AND at < (p_to::timestamp AT TIME ZONE 'UTC')
  ), totals AS (
    SELECT face, visit, count(*) AS views FROM e GROUP BY face, visit
  ), dimensioned AS (
    SELECT face, 'site'::text AS dimension, ''::text AS value, mark, visit FROM e
    UNION ALL SELECT face, 'path', path, mark, visit FROM e
    UNION ALL SELECT e.face, d.key, d.value, e.mark, e.visit FROM e, jsonb_each_text(e.dims) AS d
  )
  SELECT d.face, p_period, p_from, d.dimension, d.value,
    count(*), count(DISTINCT d.mark), count(DISTINCT d.visit),
    count(DISTINCT d.visit) FILTER (WHERE t.views >= 2)
  FROM dimensioned d JOIN totals t ON t.face = d.face AND t.visit = d.visit
  GROUP BY d.face, d.dimension, d.value;
END;
$$;

-- 集計の仕事(cron):p_at の前の日と当日(UTC)の日と、その月を畳み直す。何度回しても同じ値
CREATE OR REPLACE FUNCTION " <> f <> ".pageview_rollup(p_at timestamptz)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE
  v_day date;
BEGIN
  FOR v_day IN
    SELECT generate_series(((p_at AT TIME ZONE 'UTC') - interval '1 day')::date, (p_at AT TIME ZONE 'UTC')::date, interval '1 day')::date
  LOOP
    PERFORM " <> f <> ".pageview_rollup_period('day', v_day, v_day + 1);
    PERFORM " <> f <> ".pageview_rollup_period(
      'month', date_trunc('month', v_day)::date, (date_trunc('month', v_day) + interval '1 month')::date);
  END LOOP;
  RETURN true;
END;
$$;
"
}
