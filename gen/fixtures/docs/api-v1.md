# MuseArch REST API

Version: `v1`

This document is the source of truth for the store update API. The API base is
`https://api.musearch.jp/api/v1/store` in production and
`https://api.yumemism.dev/api/v1/store` in staging.

## Authentication

Store API keys are issued and revoked through the authenticated store session:

| Method | Path | Result |
|---|---|---|
| POST | `/api/store/api_key` | Returns the new plaintext key once |
| DELETE | `/api/store/api_key` | Revokes the current key; repeated calls succeed |

Send a v1 request with `Authorization: Bearer msa_<64 lowercase hexadecimal
characters>`. The v1 host accepts API keys only. It does not use a session
cookie or require an `Origin` header. The normal App host accepts session
cookies only; it does not accept a Bearer key.

### Credentials by host

#### API v1

##### Bearer key

###### Normal App

- API v1 requests use a Bearer key.
- Normal App requests use a session cookie.

The plaintext key is `msa_` followed by 32 random bytes encoded as 64
lowercase hexadecimal characters. It is never stored or logged. The database
stores only an HMAC-SHA256 value under the `store.api_key:` purpose label.
Issuing a key immediately revokes the existing key. Requests using the old key
return `401`; switch the update tool to the newly returned key. Requests can fail
with `401` during this replacement.

Missing, malformed, unknown, and revoked credentials all return the same
response:

```json
{"code":"unauthorized"}
```

The response also contains `WWW-Authenticate: Bearer`. A credential failure
does not execute the service or its root query. Each key has a Cloudflare Rate
Limiting allowance of 60 requests per 60 seconds. An exceeded allowance
returns `429` with `{"code":"rate_limited"}` before the service is executed.
The production limit is best effort per Cloudflare colo; the contract-level
boundary is verified with the adapter stub.

## Routes

Every v1 request uses the Store identified by its API key.

| Method | Path | Body | Service |
|---|---|---|---|
| PUT | `/api/v1/store/rosters/{external_id}` | Full roster object | `roster_upsert` |
| GET | `/api/v1/store/rosters` | — | `store_roster_list` |
| DELETE | `/api/v1/store/rosters/{external_id}` | — | `roster_remove` |
| PUT | `/api/v1/store/rosters/{external_id}/photos/{order}` | `{ "blob": "<key>" }` | `roster_photo_put` |
| PUT | `/api/v1/store/rosters/{external_id}/schedule/{date}` | `{ "starts_at": "18:00", "ends_at": "20:00" }` | `store_schedule_put` |
| PUT | `/api/v1/store/rosters/order` | `{ "ids": ["<internal roster id>"] }` | `roster_reorder` |
| POST | `/api/v1/store/blobs` | Raw `image/*` body | Blob adapter |

`external_id` is scoped to the Store. The upsert route updates an Active row
when the key exists and creates one when it does not. A Left row with the same
key returns `422 {"code":"not_active"}`; re-entry uses a new external id. If
two first requests for the same Store and key race, the request that loses the
insert conflict re-reads the committed Active row and completes as an update.
The path supplies `external_id`; the upsert body replaces all other profile
fields and requires `name`, `catch`, `body`, `age`, `order`, `visible`, and
`since`; `height` and `size` are optional. It runs the same Screen check as the store console. A
Screen rejection returns `422 {"code":"screened"}` and records a
`screen_reject` row. A conflicting Active name returns `409` with
`{"code":"name_taken","id":"<existing internal id>"}`.

The upsert service never changes `muse_id`, `party`, `claim_code`,
`claim_until`, `claimed_at`, `phase`, `store_id`, or `external_id`. One request
creates or updates one Roster. The reorder body uses internal roster ids and
must describe the store's complete Active set.

Photos use two requests: upload raw image bytes to `/api/v1/store/blobs`, then
store the returned blob key at the requested order. Orders are 1 through 10;
the first order is the main image. The schedule route keeps one schedule row
per roster and date; a repeated date replaces the day's existing entry.

Successful writes return `200`. Upsert responses contain `created: true` for a
new row and `created: false` for an update. Invalid input returns `400` with
`code: "invalid_argument"` and a `field`; missing resolved rows return `404`;
screened content returns `422`; name conflicts return `409`; and rate-limit
overflow returns `429`. The API does not promise a `Retry-After` header.
