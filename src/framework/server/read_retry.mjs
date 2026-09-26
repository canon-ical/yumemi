// yumemi framework/server ── 読みの timeout と 1 回の再試行(0.11.4、H10)。`driver.mjs` が読みの文だけに使う。
// 書き(INSERT / UPDATE / DELETE を含む文、transaction)は再試行しない ── 1 回目が commit 済みで応答だけ落ちたとき二重に書くため。
// 再試行するのは DB の外の失敗(timeout・fetch の失敗・HTTP の 5xx)だけ。SQLSTATE を持つ失敗は同じ文で同じ結果なので 1 回で返す。

/// 既定の 1 回の読みの上限(ms)。env `DATABASE_READ_TIMEOUT_MS` で上書きする。
/// metrics(`percentile_cont`・`generate_series`)や vector の近さのような重い読みも切らない幅(r2 で 5000 → 10000)。
export const defaultReadTimeoutMs = 10000;

/// 文を 1 回の走査で語の列に替える(r2、柏木 P1-1)。文字列(`'…'`・`E'…'`・`$tag$…$tag$`)は `''` に、
/// 引用識別子(`"…"`)は `"q"` に、注釈(`--`・入れ子の `/* */`)は空白に替える。前から順に読むので、
/// literal の中の `--` や注釈の中の `'` が、その後ろの字を隠さない。
export function strip(text) {
 const s = String(text);
 let out = '';
 let i = 0;
 const word = c => /[A-Za-z0-9_$]/.test(c ?? '');
 while (i < s.length) {
  const c = s[i];
  if (c === '-' && s[i + 1] === '-') {
   while (i < s.length && s[i] !== '\n') i++;
   out += ' ';
  } else if (c === '/' && s[i + 1] === '*') {
   let depth = 0;
   while (i < s.length) {
    if (s[i] === '/' && s[i + 1] === '*') { depth++; i += 2; }
    else if (s[i] === '*' && s[i + 1] === '/') { depth--; i += 2; if (depth === 0) break; }
    else i++;
   }
   out += ' ';
  } else if (c === "'") {
   // E'…' は \ で逃がす(直前の e が語の頭のとき)
   const escaped = /[eE]/.test(s[i - 1] ?? '') && !word(s[i - 2]);
   if (escaped) out = out.slice(0, -1);
   i++;
   while (i < s.length) {
    if (escaped && s[i] === '\\') { i += 2; continue; }
    if (s[i] === "'") { if (s[i + 1] === "'") { i += 2; continue; } i++; break; }
    i++;
   }
   out += " '' ";
  } else if (c === '"') {
   i++;
   while (i < s.length) {
    if (s[i] === '"') { if (s[i + 1] === '"') { i += 2; continue; } i++; break; }
    i++;
   }
   out += ' "q" ';
  } else if (c === '$' && !word(s[i - 1]) && /^\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$/.test(s.slice(i))) {
   const tag = s.slice(i).match(/^\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$/)[0];
   const close = s.indexOf(tag, i + tag.length);
   i = close < 0 ? s.length : close + tag.length;
   out += " '' ";
  } else {
   out += c;
   i++;
  }
 }
 return out;
}

const writing = /\bfor\s+(?:key\s+)?share\b|\b(insert|update|delete|merge|truncate|create|drop|alter|grant|revoke|copy|call|do|lock|into|vacuum|refresh|nextval|setval|pg_advisory_\w*|pg_try_advisory_\w*|pg_notify|set_config)\b/i;

// `(` の前に来てよい語:SQL の語(`EXISTS (`・`OVER (`・`AS MATERIALIZED (` ほか)と、書かない組み込みの関数。
// この表に無い名の呼び出し(利用者の関数 `do_write(`、schema 付き `framework.fn(`、引用付き `"fn"(`)は書きに数える。
const callable = new Set(`
 select from where and or not in exists any all some values as on using join lateral over filter within group by
 partition order having limit offset between like ilike similar union except intersect when then else case is
 distinct materialized operator array row cast interval numeric decimal varchar char character timestamp
 timestamptz time date bit varbit float real
 coalesce nullif greatest least count sum avg min max bool_and bool_or every string_agg array_agg jsonb_agg
 json_agg jsonb_object_agg json_object_agg percentile_cont percentile_disc mode stddev variance
 row_number rank dense_rank ntile lag lead first_value last_value nth_value cume_dist percent_rank
 now current_date current_timestamp clock_timestamp statement_timestamp transaction_timestamp timezone
 date_trunc date_part date_bin extract age make_date make_time make_timestamp make_timestamptz make_interval
 to_char to_date to_timestamp to_number to_json to_jsonb
 lower upper length char_length octet_length substring substr position strpos trim btrim ltrim rtrim lpad rpad
 concat concat_ws replace split_part left right reverse repeat format initcap translate starts_with md5 encode decode
 regexp_replace regexp_match regexp_matches regexp_split_to_array regexp_split_to_table regexp_like regexp_count
 abs ceil ceiling floor round trunc mod power sqrt ln log exp sign div width_bucket random
 generate_series generate_subscripts unnest array_length array_position array_positions array_remove
 array_append array_prepend array_cat array_to_string string_to_array cardinality array_upper array_lower
 jsonb_build_object jsonb_build_array json_build_object json_build_array jsonb_array_elements
 jsonb_array_elements_text json_array_elements json_array_elements_text jsonb_array_length json_array_length
 jsonb_each jsonb_each_text json_each json_each_text jsonb_object_keys json_object_keys jsonb_typeof json_typeof
 jsonb_extract_path jsonb_extract_path_text jsonb_strip_nulls jsonb_set jsonb_insert jsonb_path_query
 jsonb_path_query_array jsonb_path_query_first jsonb_path_exists jsonb_path_match jsonb_populate_record
 jsonb_populate_recordset jsonb_to_record jsonb_to_recordset jsonb_pretty row_to_json array_to_json
 gen_random_uuid uuid_generate_v4 isfinite num_nonnulls num_nulls
`.trim().split(/\s+/));

// 語の後に `(` が来る所(呼び出し・型の幅・別名の列)。`::` の後の型と `AS` の後の別名の列は呼び出しでない
const call = /(::\s*)?((?:(?:[a-z_][a-z0-9_$]*|"q")\s*\.\s*)*)([a-z_][a-z0-9_$]*|"q")\s*\(/gi;

/// 文が読みだけか。1 文で `SELECT` / `WITH` / `VALUES` / `TABLE` で始まり、書きの語(`INTO`・`FOR UPDATE` の行の鍵・
/// nextval を含む)も、組み込みの許可表に無い関数の呼び出しも持たない。迷う文は書きに数える(やり直さない側)。
export function readOnly(text) {
 const body = strip(text).trim();
 if (!/^(select|with|values|table)\b/i.test(body)) return false;
 if (body.replace(/;\s*$/, '').includes(';')) return false;
 if (writing.test(body)) return false;
 for (const match of body.matchAll(call)) {
  if (match[1]) continue;
  if (match[2] !== '' || match[3] === '"q"') return false;
  const before = body.slice(0, match.index).trimEnd();
  if (/\bas$/i.test(before)) continue;
  if (!callable.has(match[3].toLowerCase())) return false;
 }
 return true;
}

/// SQLSTATE(5 桁)を持たない失敗(DB の外)か。
export function transient(error) {
 return !/^[0-9A-Z]{5}$/.test(error?.code ?? '');
}

/// 失敗の本文を log の 1 行に。Neon の HTTP の失敗は message に応答の本文を持つ。
export function failureLine(key, attempt, ms, error, kind = 'read') {
 const body = error?.name === 'AbortError' || error?.name === 'TimeoutError' ? 'timeout' : String(error?.message ?? error);
 return JSON.stringify({
  yumemi: 'driver.failed', kind, key: key ?? null, attempt, ms: Math.round(ms),
  code: error?.code ?? null, status: error?.status ?? null, name: error?.name ?? null, body: body.slice(0, 2000),
 });
}

/// 読みを `timeoutMs` で切り、DB の外の失敗なら 1 回だけやり直す。`run(signal)` は 1 回の読み。
/// 2 回とも落ちたら 2 回目の失敗を投げる。DB の外の失敗は各回 `log` に 1 行ずつ出す(SQLSTATE の失敗は app が読む)。
export async function readWithRetry(run, { key, timeoutMs = defaultReadTimeoutMs, log = line => console.error(line), now = () => performance.now() } = {}) {
 for (let attempt = 1; ; attempt++) {
  const controller = new AbortController();
  let timer;
  const start = now();
  const timeout = new Promise((_, reject) => {
   timer = setTimeout(() => {
    const error = new Error(`read timed out after ${timeoutMs} ms`);
    error.name = 'TimeoutError';
    controller.abort(error);
    reject(error);
   }, timeoutMs);
  });
  try {
   return await Promise.race([run(controller.signal), timeout]);
  } catch (error) {
   if (!transient(error)) throw error;
   log(failureLine(key, attempt, now() - start, error));
   if (attempt >= 2) throw error;
  } finally {
   clearTimeout(timer);
  }
 }
}
