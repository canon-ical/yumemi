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
