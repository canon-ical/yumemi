-- GENERATED from yumemi(数える口の器 Store)— 手で編集しない
-- ▲ app の DB に当てるのは DDL の便。表は印・訪問・event・集計の 4 つ、関数は記録と集計の 3 つ。
CREATE SCHEMA IF NOT EXISTS framework;

-- 印(ユニークの単位):browser の署名 cookie の id(32 桁の hex)
CREATE TABLE IF NOT EXISTS framework.pageview_mark (
  id text PRIMARY KEY CHECK (id ~ '^[0-9a-f]{32}$'),
  first_at timestamptz NOT NULL,
  last_at timestamptz NOT NULL
);

-- 訪問:同じ印の event が 30 分以内に続く並び
CREATE TABLE IF NOT EXISTS framework.pageview_visit (
  id uuid PRIMARY KEY,
  mark text NOT NULL REFERENCES framework.pageview_mark (id),
  started_at timestamptz NOT NULL,
  last_at timestamptz NOT NULL,
  landing_path text NOT NULL,
  referrer_host text
);
CREATE INDEX IF NOT EXISTS pageview_visit_mark_last ON framework.pageview_visit (mark, last_at DESC);

-- event:受け口が受けた 1 回の表示。excluded は app の exclude_when が真の event(行は作り、数字から除く)
CREATE TABLE IF NOT EXISTS framework.pageview_event (
  id uuid PRIMARY KEY,
  mark text NOT NULL REFERENCES framework.pageview_mark (id),
  visit uuid NOT NULL REFERENCES framework.pageview_visit (id),
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
CREATE INDEX IF NOT EXISTS pageview_event_mark_at ON framework.pageview_event (mark, at);
CREATE INDEX IF NOT EXISTS pageview_event_at ON framework.pageview_event (at);

-- 集計:面 × 日・月 × 次元('site' は value ''、'path'、rollup_by の欄の名)。UTC の日の境
CREATE TABLE IF NOT EXISTS framework.pageview_rollup (
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
CREATE OR REPLACE FUNCTION framework.pageview_record(
  p_id uuid, p_mark text, p_face text, p_at timestamptz, p_kind text, p_path text, p_prev uuid,
  p_referrer_path text, p_referrer_host text, p_client_at timestamptz, p_party text,
  p_extra jsonb, p_dims jsonb, p_excluded boolean
) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_visit uuid;
BEGIN
  INSERT INTO framework.pageview_mark (id, first_at, last_at) VALUES (p_mark, p_at, p_at)
  ON CONFLICT (id) DO UPDATE SET last_at = GREATEST(framework.pageview_mark.last_at, EXCLUDED.last_at);
  IF EXISTS (SELECT 1 FROM framework.pageview_event WHERE id = p_id) THEN
    RETURN 'duplicate';
  END IF;
  IF (SELECT count(*) FROM framework.pageview_event
      WHERE mark = p_mark AND at > p_at - interval '1 minute' AND at <= p_at) >= 60 THEN
    RETURN 'limited';
  END IF;
  SELECT id INTO v_visit FROM framework.pageview_visit
  WHERE mark = p_mark AND last_at >= p_at - interval '30 minutes' AND started_at <= p_at
  ORDER BY last_at DESC LIMIT 1;
  IF v_visit IS NULL THEN
    v_visit := gen_random_uuid();
    INSERT INTO framework.pageview_visit (id, mark, started_at, last_at, landing_path, referrer_host)
    VALUES (v_visit, p_mark, p_at, p_at, p_path, p_referrer_host);
  ELSE
    UPDATE framework.pageview_visit SET last_at = GREATEST(last_at, p_at) WHERE id = v_visit;
  END IF;
  INSERT INTO framework.pageview_event
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
CREATE OR REPLACE FUNCTION framework.pageview_rollup_period(p_period text, p_from date, p_to date)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM framework.pageview_rollup WHERE period = p_period AND starts = p_from;
  INSERT INTO framework.pageview_rollup (face, period, starts, dimension, value, pv, uniques, visits, roaming_visits)
  WITH e AS (
    SELECT face, mark, visit, path, dims FROM framework.pageview_event
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
CREATE OR REPLACE FUNCTION framework.pageview_rollup(p_at timestamptz)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE
  v_day date;
BEGIN
  FOR v_day IN
    SELECT generate_series(((p_at AT TIME ZONE 'UTC') - interval '1 day')::date, (p_at AT TIME ZONE 'UTC')::date, interval '1 day')::date
  LOOP
    PERFORM framework.pageview_rollup_period('day', v_day, v_day + 1);
    PERFORM framework.pageview_rollup_period(
      'month', date_trunc('month', v_day)::date, (date_trunc('month', v_day) + interval '1 month')::date);
  END LOOP;
  RETURN true;
END;
$$;
