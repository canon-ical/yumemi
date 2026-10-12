// yumemi-0122 ── 最小の app が起動→一覧まで通らない穴のうち、framework の runtime の 2 つを子の node で回す。
// `host`:入口の host を、生成の `hosts`(入口の名 -> `<NAME>_HOST`)で引く。Host の variant の名で引かない。
// `page`:`Paged(size: Param(..))` の頁を、SQL の `LIMIT $n + 1` に渡したのと同じ値で切る。size が定数の頁は今までどおり。
// `yumemi_0122_test_ffi.mjs` が `node test/yumemi_0122_check.mjs <host|page>` で走らせ、1 行 1 件の ok / NG を出す。
import { http } from "../build/dev/javascript/yumemi/yumemi/server/http.mjs";
import { runtime } from "../build/dev/javascript/yumemi/yumemi/server/runtime.mjs";

const out = [];
const check = (name, ok, got) => out.push((ok ? "ok " : "NG ") + name + (ok ? "" : " " + JSON.stringify(got)));

async function host() {
  class Ok { constructor(value) { this[0] = value; } }
  class Er { constructor(value) { this[0] = value; } }
  // Host の variant(★ の `entry.gleam` の型)。名は constructor の名から取られる(`c.tag`)
  class ApiHost {}
  class Www {}
  const tag = (value) => value.constructor.name.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toLowerCase();
  const c = { tag };
  // 生成の `http_runtime.mjs` の `hosts` と同じ形:入口の名 -> env の変数名
  const h = http({ c, registry: [], attached: [], Ok, Error: Er, hosts: { api: "API_HOST", www: "WWW_HOST" }, runtime: {}, roles: {} });
  const entries = [
    { name: "api", hosts: [new ApiHost()] },
    { name: "www", hosts: [new Www()] },
  ];
  const env = { API_HOST: "api.test", WWW_HOST: "www.test" };
  const run = async (url) => {
    const result = await h.host({ request: new Request(url), env }, entries);
    return result instanceof Ok ? { entry: result[0].entry.name, hosts: result[0].hosts } : { status: result[0]?.status };
  };
  let got = await run("https://api.test/api/notes");
  check("a Host variant named apart from its entry finds the entry", got.entry === "api", got);
  check("the origin hosts list every entry's host", JSON.stringify(got.hosts) === JSON.stringify(["api.test", "www.test"]), got);
  got = await run("https://www.test/api/x");
  check("a Host variant named like its entry still finds the entry", got.entry === "www", got);
  got = await run("https://other.test/api/notes");
  check("an unknown host is 404", got.status === 404, got);
  // Host の variant を 1 つも持たない入口は、env に `<NAME>_HOST` があってもどの host にも出ず、Origin にも入らない
  const bare = [{ name: "api", hosts: [] }, { name: "www", hosts: [new Www()] }];
  const none = await h.host({ request: new Request("https://api.test/api/notes"), env }, bare);
  check("an entry without hosts is not reached", !(none instanceof Ok) && none[0]?.status === 404, none[0]?.status);
  const other = await h.host({ request: new Request("https://www.test/api/x"), env }, bare);
  check("an entry without hosts is left out of the origin hosts", other instanceof Ok && JSON.stringify(other[0].hosts) === JSON.stringify(["www.test"]), other[0]?.hosts);
}

async function page() {
  class Page { constructor(items, next) { this.items = items; this.next = next; } }
  const c = {
    toList: (items) => items,
    option: (value, f = (x) => x) => (value == null ? null : f(value)),
    unwrap: (value) => value,
    text: (value) => value,
    encode: (value) => value,
    checked: (value) => value,
    page: { Page, cursor: (raw) => raw },
  };
  const keyset = { uniform: true, columns: [["n", "value"]] };
  const spec = {
    c, roots: {}, actors: {}, verbs: {}, manualVerbs: { names: new Set() }, connectors: {}, connectorNames: {},
    folds: {}, enqueues: {}, boundaries: new Set(), relationDecoders: {}, phaseModules: {}, drafts: {}, subjects: [],
    encoders: {}, carried: {},
    SQL: { "notes/sized": "-- LIMIT $1 + 1", "notes/fixed": "-- LIMIT 4", "notes/later": "-- LIMIT $2 + 1" },
    reads: {
      // `Paged(size: Param(Limit), after: Param(Cursor))`:size の穴は args の 0 番
      "notes/sized": { key: "notes/sized", args: [["enc"], ["cursor"]], allow: [], out: ["page", ["int", "n"]], keyset: { size: 20, sizeArg: 0, ...keyset } },
      // size の穴が 2 番目の穴(前に条件の穴がある)
      "notes/later": { key: "notes/later", args: [["enc"], ["enc"], ["cursor"]], allow: [], out: ["page", ["int", "n"]], keyset: { size: 20, sizeArg: 1, ...keyset } },
      // `Paged(size: Num(3), ..)`:定数の size は今までどおり keyset の size で切る
      "notes/fixed": { key: "notes/fixed", args: [["cursor"]], allow: [], out: ["page", ["int", "n"]], keyset: { size: 3, ...keyset } },
    },
  };
  // SQL の `LIMIT <size> + 1` を真似る偽の db:渡された size の穴の値 + 1 行を返す(定数の文は 4 行)
  const rows = Array.from({ length: 50 }, (_, i) => ({ n: i + 1 }));
  const seen = [];
  const db = {
    async query(text, params, key) {
      seen.push([key, params]);
      if (key === "notes/fixed") return rows.slice(0, 4);
      const size = key === "notes/later" ? params[1] : params[0];
      return rows.slice(0, size + 1);
    },
  };
  const { makeContext } = runtime(spec);
  const ctx = makeContext({ record: { name: "notes" }, db, root: null, at: 0, seed: "s" });
  for (const size of [1, 5, 20]) {
    const got = await ctx.read("sized", [size, null]);
    check(`size ${size}: ${size} items`, got.items.length === size, got.items.length);
    check(`size ${size}: next is set`, got.next != null, got.next);
  }
  // 最後の頁:size より少ない行なら next は無い
  const short = await ctx.read("sized", [100, null]);
  check("size above the rows: every row, no next", short.items.length === 50 && short.next == null, [short.items.length, short.next]);
  const later = await ctx.read("later", ["x", 5, null]);
  check("size hole after another hole: 5 items and next", later.items.length === 5 && later.next != null, [later.items.length, later.next]);
  const fixed = await ctx.read("fixed", null);
  check("a constant size still cuts at the keyset size", fixed.items.length === 3 && fixed.next != null, [fixed.items.length, fixed.next]);
  check("the size hole reaches SQL as given", JSON.stringify(seen[0]) === JSON.stringify(["notes/sized", [1, null]]), seen[0]);
}

const which = process.argv[2];
if (which === "host") await host();
else if (which === "page") await page();
else out.push("NG unknown check " + which);
console.log(out.join("\n"));
