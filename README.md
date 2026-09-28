# yumemi

**Have a sweet Gleam.** 設計を書けば、コードが生まれる。

A framework for [Gleam](https://gleam.run) on Cloudflare Workers. You describe an application in five words — Entity, Property, Type, Service, Authorization — and yumemi derives the Gleam implementation and every entrance to it: HTTP, MCP, CLI.

Open source, coming soon. https://gleam.canon-ical.com/

## Status

Extracted from the `framework/` directory of a production application on 2026-09-16, history included. Module namespace is still `framework/*`; the package name is `yumemi`. Published on Hex as [`yumemi`](https://hex.pm/packages/yumemi) (0.2.0 = the 2026-09-16 extraction; the generator and gen-3/gen-4 changes ship from 0.3.0).

## Layout

| Module | What |
|---|---|
| `framework/spec` `framework/er` | Entity / Property / Type ── the model and its derivation |
| `framework/entry` `framework/verb` `framework/party` `framework/require` | Entrances and Authorization |
| `framework/step` `framework/effect` `framework/query` `framework/io` | Service logic: read / guard / apply / call / done |
| `framework/connector` `framework/page` `framework/blob` `framework/vector` | Connectors, SSR pages, R2, Vectorize |
| `framework/secret` `framework/sealed` `framework/time` | Secrets, sealed values, time |

```
gleam build
```

## `framework/server` ── what the app must provide (0.11.1)

The back-end runtime (`framework/server/*.mjs`) is JavaScript that the generated `src/gen/*.mjs` imports. It knows no application names: route names, cookie names, key bindings and the party a queue consumer reads its borrowed root as come from the app's `src/server.gleam` (`attached_roles`, `browser`, `hooks`, `roots`' `QueueParty`). The generated face gate (`<face>/src/gen/gate.mjs`, declared in `<face>/src/gate.gleam` with `framework/gate`) reads the session through the `ReadSession` attached route. Gleam packages cannot declare npm dependencies, so the app supplies the following itself.

Generated live modules (0.11.2) send Args by their declared type: `Bool` as a JSON boolean (the live field's `"true"` / `"false"`), `Int` / `Float` as numbers. On a `GET` route the Args that are not path holes go on the query string (an empty `Option` is left out), and the runtime reads `bool` (`true` / `false`) and `float` spellings from the query of `GET` / `HEAD` requests. `POST` / `PUT` / `DELETE` bodies are read as JSON as before.

A live field for a `List(X)` Arg (X a scalar, value type, id or enum) holds a JSON array of strings (`["a","b"]`, an empty field is `[]`); each item is sent by X's rule. A field for a record, tuple, `Dict` or a `List` of those holds the JSON body itself (for example `{"background":"#112233"}`), which is sent as is and read by the back-end decoder. A field that does not parse is sent as a string, and the back end answers `invalid_argument`. Sum types with several constructors are sent as strings.

A Service whose logic runs `step.commit` and continues after it (and is not a queue consumer that only uses the commit as a boundary) ends in `Accepted` over HTTP: the runtime answers 202 with a one-field body (`{"<root>": id}`, a `respond` hook may rename the field). The generated live for such a Service (0.11.3) holds `Reply` instead of the Service's `Out`: `Accepted(id)` for the 202 body and `Replied(out)` for a 200 that ends before the commit. Both arrive as `Done(Ok(_))` and go on to `after_send` (for example `ReloadPage`). Lives of other Services are unchanged.

0.11.4 adds, without changing the existing public types:

- **Reads time out and retry once.** `driver.mjs` cuts a read-only statement (one `SELECT` / `WITH` / `VALUES` / `TABLE` with no write keyword — `INTO` and row locks count as writes — and no call to a function outside the built-in allow list, read after one pass that strips strings, quoted identifiers and comments; see `framework/server/read_retry.mjs`) after `DATABASE_READ_TIMEOUT_MS` (default 10000) and retries it once when the failure is outside the database (timeout, fetch failure, HTTP 5xx; not an SQLSTATE). Writes and transactions are never retried and get no timeout. Every failure outside the database, read or write, is logged as one JSON line (`{"yumemi":"driver.failed",kind,key,attempt,ms,code,status,name,body}`, `kind` is `read` / `write` / `transaction`) with the response body.
- **Attached routes with a framework role that reads a body** send it: the live for a `SwitchSubject` route has `Args(kind, id)` and sends `{kind, id}`. Other attached lives are unchanged (no Args, `null` body).
- **The `BlobCopy` live copies a URL.** Besides the file upload (`Send`), `copy_from(state, url)` sends `{from: url}` to the same route and reads `{key}` into `Done(Ok(key))`.
- **Split records decode.** A record Property stored with `Split` is rebuilt from its columns in `src/gen/codec.mjs`.
- **Islands render sketch classes.** The generated client registers each island through `framework/front/island_style.mjs`'s `styled(app)`: the island gets its own sketch stylesheet while its view runs, and the CSS goes into a `<style>` inside the island (only when the island uses classes and does not render its own stylesheet).
- **Client navigation between Pages.** The generated client calls `framework/front/navigate.mjs`'s `start({routes, boot, pageview})`. A plain left click on a same-origin link, from a Page to a Page that are both in the face's route table (minus the gate's `frame_src` Pages), fetches the next page with one request (the gate, the adult declaration and the session go through the server as before), swaps `<head>` and `<body>`, re-runs the island registrations and pushes history; back / forward do the same. A redirect, a non-200, a `content-security-policy` header, a page with scripts other than the client, an already-registered given island, a modified click, `target` or `download` fall back to a page load.
- **Pageviews count once per navigation.** The navigation fetch carries `x-yumemi-navigate: 1`; for it the gate puts `<meta name="yumemi-pageview">` in `<head>` instead of the pageview script (same conditions: adult session, 200 HTML, a `pageview` Page) and adds `vary: x-yumemi-navigate`. The client posts the pageview (`kind` `spa`) only after it swapped that page in; a fallback to a page load gets the script as before.
- **Reload after a write stays in the page.** An island's `yumemi-done` calls `navigate.reload()`: on a routed Page it refetches the current URL the same way (no history entry, scroll kept, pageview `kind` `reload`); otherwise it reloads the page.

0.11.5 adds, without changing or removing the existing public types:

- **Gate: send back with a return path.** `Fail.RedirectBack(location, param)` answers 302 to the face path `location` and puts the request's path + search, URL-encoded, in the query `param` (joined with `&` when `location` already has a query). When the request's path + search is not a face path (the `SafeParam` check: it starts with `//`, or has a backslash or a control character) the param is left out, so the gate never sends anyone to another origin. `location` must start with `/`, not `//`, and carry no `#`; `param` is `[A-Za-z0-9_.-]+` — the generator stops otherwise (exit 4). A client navigation fetch gets the same 302; the client falls back to a page load as for any redirect.
- **Gate: a fixed redirect that keeps the query.** `To.FixedKeep(location)` answers 302 to `location` plus the request's query. `Fixed(location)` is unchanged (drops the query). The hash never reaches the server; on a page load the browser carries the original hash across a redirect without one, and a client navigation falls back to that page load. `location` has no `?` and no `#`.
- A gate that uses neither word gets the same `gate.mjs` as 0.11.4, character for character.
- **A missing root statement stops generation.** A Service with a root Entity reads its root with `db/queries/<service>/root.sql`. Without it the runtime answers 503, so the generator now stops with exit 3 naming the Service. Services that build their root another way are not stopped: a Service answered by a `service_<name>` hook (a Durable Object port), a queue consumer that borrows the root of a Service that has a root statement and calls it through the queue, `Rootless`, and roots with no Entity (`Carried` only).
- **Faces narrower than the entries are enforced at runtime.** A Service that declares two or more faces gets `entries: [..]` in `src/gen/registry.mjs` when an entry outside its faces could still route it (same credential kind; a `ReadOnly` entry only for a Read Service), and check 7 answers 403 on any other entry. A Service with one face keeps `entry: '<name>'` as before; a Service whose faces hold every entry that could route it (all four session faces in musearch) gets neither.

**Imports outside the package**

| Import | Imported by | Provided by |
|---|---|---|
| `@neondatabase/serverless` | `framework/server/driver.mjs` (Neon HTTP transport, `database(env, observe)`) | the app's `package.json` |
| `cloudflare:workers` | `framework/server/worker.mjs` (`DurableObject` / `WorkerEntrypoint`) | the Workers runtime (wrangler / workerd); not an npm package, so modules that import `worker.mjs` (the generated `shell.mjs`) do not load under plain node |

**SQL** — the runtime runs these keys through the app's SQL bundle (`src/gen/sql.mjs`, built from `db/queries/**`). The app writes them as `db/queries/framework/<name>.sql` against its own `framework` schema (DDL is the app's). Holes are positional, in the order below.

| Key | Holes | Used for |
|---|---|---|
| `framework/session_resolve_staff` | session id, at, first try | resolve a session cookie (a row with `retry` asks for a second pass) |
| `framework/api_key_resolve` | key digest, at | resolve an API key entrance |
| `framework/session_issue` | party, session id, credential version, expires at | issue a session (auth binding) |
| `framework/credential_floor` | party, floor | raise the credential version floor |
| `framework/session_revoke_party` | party, version | revoke a party's sessions below a version |
| `framework/session_revoke` | session id | revoke one session (auth binding) |
| `framework/session_onboard` | session id, party, subject id | bind a created subject to the session |
| `framework/session_subject_staff` | session id, party, kind, subject id | the `SwitchSubject` attached route |
| `framework/browser` | browser id, at | the `DeclareBrowser` attached route |
| `framework/audit` | seed, stage, service, party, outcome, at | one row per entrance stage |
| `framework/outbox_parent` | id, dedupe key, payload (json), event id, at, folded | outbox parent row of a write |
| `framework/outbox_child` | id, kind, payload (json), parent id, at | outbox child row (one queue message) |
| `framework/outbox_done` | event id | mark a consumed event done |
| `framework/outbox_get` | id | load a queued message |
| `framework/outbox_sent` | id | mark a swept message sent |
| `framework/outbox_sweep` | kinds | list unsent messages to resend |

**Worker env** — `DATABASE_URL`, `COOKIE_DOMAIN`, `OUTBOX` (queue binding), `<ENTRY>_HOST` per entrance, the `key_binding` of `browser` (a Secret Store binding), the KEK bindings of `Sealed` properties, and optionally `ISOLATE_MARKER=1` (test header).
