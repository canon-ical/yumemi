// yumemi framework/server ── 読みの timeout と 1 回の再試行(0.11.4、H10)。`driver.mjs` が読みの文だけに使う。
// 書き(INSERT / UPDATE / DELETE を含む文、transaction)は再試行しない ── 1 回目が commit 済みで応答だけ落ちたとき二重に書くため。
// 再試行するのは DB の外の失敗(timeout・fetch の失敗・HTTP の 5xx)だけ。SQLSTATE を持つ失敗は同じ文で同じ結果なので 1 回で返す。

/// 既定の 1 回の読みの上限(ms)。env `DATABASE_READ_TIMEOUT_MS` で上書きする。
export const defaultReadTimeoutMs = 5000;

// 文字列・識別子の引用と注釈を空白に替えてから語を見る(`'update'` や `-- DELETE` で書きに数えない)
const bare = text => String(text)
 .replace(/--[^\n]*/g, ' ')
 .replace(/\/\*[\s\S]*?\*\//g, ' ')
 .replace(/'(?:[^']|'')*'/g, "''")
 .replace(/"(?:[^"]|"")*"/g, '""');
const writing = /\b(insert|update|delete|merge|truncate|create|drop|alter|grant|revoke|copy|call|do|lock|vacuum|refresh|nextval|setval|pg_advisory_\w*|pg_notify|set_config)\b/i;

// schema で修飾した関数の呼び出し(`framework.insert_links_guarded(`)は app の関数 ── 中で書くことがあるので読みに数えない
const qualifiedCall = /\b[a-z_][a-z0-9_$]*\s*\.\s*(?:[a-z_][a-z0-9_$]*|"")\s*\(/i;

/// 文が読みだけか。1 文で `SELECT` / `WITH` / `VALUES` / `TABLE` で始まり、書きの語(`FOR UPDATE` の行の鍵、
/// nextval を含む)も schema で修飾した関数の呼び出しも持たない。迷う文は書きに数える(やり直さない側)。
export function readOnly(text) {
 const body = bare(text).trim();
 if (!/^(select|with|values|table)\b/i.test(body)) return false;
 if (body.replace(/;\s*$/, '').includes(';')) return false;
 return !writing.test(body) && !qualifiedCall.test(body);
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
