//// GENERATED from docs/api-v1.md [sha256:49d7b8c8e291] — 手で編集しない

import framework/front/el
import framework/front/sketch_css
import gleam/list
import sketch/lustre/element/html
import style

pub fn nodes() -> List(el.Element(Nil)) {
  [
    heading1("MuseArch REST API"),
    paragraph([el.text("Version: "), inline_code("v1")]),
    paragraph([
      el.text(
        "This document is the source of truth for the store update API. The API base is ",
      ),
      inline_code("https://api.musearch.jp/api/v1/store"),
      el.text(" in production and "),
      inline_code("https://api.yumemism.dev/api/v1/store"),
      el.text(" in staging."),
    ]),
    heading2("Authentication"),
    paragraph([
      el.text(
        "Store API keys are issued and revoked through the authenticated store session:",
      ),
    ]),
    table_1(),
    paragraph([
      el.text("Send a v1 request with "),
      inline_code(
        "Authorization: Bearer msa_<64 lowercase hexadecimal characters>",
      ),
      el.text(
        ". The v1 host accepts API keys only. It does not use a session cookie or require an ",
      ),
      inline_code("Origin"),
      el.text(
        " header. The normal App host accepts session cookies only; it does not accept a Bearer key.",
      ),
    ]),
    heading3("Credentials by host"),
    heading4("API v1"),
    heading5("Bearer key"),
    heading6("Normal App"),
    unordered_list([
      [el.text("API v1 requests use a Bearer key.")],
      [el.text("Normal App requests use a session cookie.")],
    ]),
    paragraph([
      el.text("The plaintext key is "),
      inline_code("msa_"),
      el.text(
        " followed by 32 random bytes encoded as 64 lowercase hexadecimal characters. It is never stored or logged. The database stores only an HMAC-SHA256 value under the ",
      ),
      inline_code("store.api_key:"),
      el.text(
        " purpose label. Issuing a key immediately revokes the existing key. Requests using the old key return ",
      ),
      inline_code("401"),
      el.text(
        "; switch the update tool to the newly returned key. Requests can fail with ",
      ),
      inline_code("401"),
      el.text(" during this replacement."),
    ]),
    paragraph([
      el.text(
        "Missing, malformed, unknown, and revoked credentials all return the same response:",
      ),
    ]),
    fenced_code("{\"code\":\"unauthorized\"}"),
    paragraph([
      el.text("The response also contains "),
      inline_code("WWW-Authenticate: Bearer"),
      el.text(
        ". A credential failure does not execute the service or its root query. Each key has a Cloudflare Rate Limiting allowance of 60 requests per 60 seconds. An exceeded allowance returns ",
      ),
      inline_code("429"),
      el.text(" with "),
      inline_code("{\"code\":\"rate_limited\"}"),
      el.text(
        " before the service is executed. The production limit is best effort per Cloudflare colo; the contract-level boundary is verified with the adapter stub.",
      ),
    ]),
    heading2("Routes"),
    paragraph([
      el.text("Every v1 request uses the Store identified by its API key."),
    ]),
    table_2(),
    paragraph([
      inline_code("external_id"),
      el.text(
        " is scoped to the Store. The upsert route updates an Active row when the key exists and creates one when it does not. A Left row with the same key returns ",
      ),
      inline_code("422 {\"code\":\"not_active\"}"),
      el.text(
        "; re-entry uses a new external id. If two first requests for the same Store and key race, the request that loses the insert conflict re-reads the committed Active row and completes as an update. The path supplies ",
      ),
      inline_code("external_id"),
      el.text(
        "; the upsert body replaces all other profile fields and requires ",
      ),
      inline_code("name"),
      el.text(", "),
      inline_code("catch"),
      el.text(", "),
      inline_code("body"),
      el.text(", "),
      inline_code("age"),
      el.text(", "),
      inline_code("order"),
      el.text(", "),
      inline_code("visible"),
      el.text(", and "),
      inline_code("since"),
      el.text("; "),
      inline_code("height"),
      el.text(" and "),
      inline_code("size"),
      el.text(
        " are optional. It runs the same Screen check as the store console. A Screen rejection returns ",
      ),
      inline_code("422 {\"code\":\"screened\"}"),
      el.text(" and records a "),
      inline_code("screen_reject"),
      el.text(" row. A conflicting Active name returns "),
      inline_code("409"),
      el.text(" with "),
      inline_code("{\"code\":\"name_taken\",\"id\":\"<existing internal id>\"}"),
      el.text("."),
    ]),
    paragraph([
      el.text("The upsert service never changes "),
      inline_code("muse_id"),
      el.text(", "),
      inline_code("party"),
      el.text(", "),
      inline_code("claim_code"),
      el.text(", "),
      inline_code("claim_until"),
      el.text(", "),
      inline_code("claimed_at"),
      el.text(", "),
      inline_code("phase"),
      el.text(", "),
      inline_code("store_id"),
      el.text(", or "),
      inline_code("external_id"),
      el.text(
        ". One request creates or updates one Roster. The reorder body uses internal roster ids and must describe the store's complete Active set.",
      ),
    ]),
    paragraph([
      el.text("Photos use two requests: upload raw image bytes to "),
      inline_code("/api/v1/store/blobs"),
      el.text(
        ", then store the returned blob key at the requested order. Orders are 1 through 10; the first order is the main image. The schedule route keeps one schedule row per roster and date; a repeated date replaces the day's existing entry.",
      ),
    ]),
    paragraph([
      el.text("Successful writes return "),
      inline_code("200"),
      el.text(". Upsert responses contain "),
      inline_code("created: true"),
      el.text(" for a new row and "),
      inline_code("created: false"),
      el.text(" for an update. Invalid input returns "),
      inline_code("400"),
      el.text(" with "),
      inline_code("code: \"invalid_argument\""),
      el.text(" and a "),
      inline_code("field"),
      el.text("; missing resolved rows return "),
      inline_code("404"),
      el.text("; screened content returns "),
      inline_code("422"),
      el.text("; name conflicts return "),
      inline_code("409"),
      el.text("; and rate-limit overflow returns "),
      inline_code("429"),
      el.text(". The API does not promise a "),
      inline_code("Retry-After"),
      el.text(" header."),
    ]),
  ]
}

fn heading1(value: String) -> el.Element(Nil) {
  html.h1(sketch_css.class([style.heading, style.ink]), [], [el.text(value)])
}

fn heading2(value: String) -> el.Element(Nil) {
  html.h2(sketch_css.class([style.heading, style.ink]), [], [el.text(value)])
}

fn heading3(value: String) -> el.Element(Nil) {
  html.h3(sketch_css.class([style.heading, style.ink]), [], [el.text(value)])
}

fn heading4(value: String) -> el.Element(Nil) {
  html.h4(sketch_css.class([style.heading, style.ink]), [], [el.text(value)])
}

fn heading5(value: String) -> el.Element(Nil) {
  html.h5(sketch_css.class([style.heading, style.ink]), [], [el.text(value)])
}

fn heading6(value: String) -> el.Element(Nil) {
  html.h6(sketch_css.class([style.heading, style.ink]), [], [el.text(value)])
}

fn paragraph(children: List(el.Element(Nil))) -> el.Element(Nil) {
  html.p(sketch_css.class([style.body, style.ink]), [], children)
}

fn inline_code(value: String) -> el.Element(Nil) {
  html.code(sketch_css.class([style.body, style.ink]), [], [el.text(value)])
}

fn fenced_code(value: String) -> el.Element(Nil) {
  html.pre(sketch_css.class([style.body, style.ink]), [], [
    html.code(sketch_css.class([style.body, style.ink]), [], [el.text(value)]),
  ])
}

fn unordered_list(items: List(List(el.Element(Nil)))) -> el.Element(Nil) {
  html.ul(
    sketch_css.class([style.body, style.ink]),
    [],
    list.map(items, fn(children) {
      html.li(sketch_css.class([style.body, style.ink]), [], children)
    }),
  )
}

fn table_row(cells: List(el.Element(Nil))) -> el.Element(Nil) {
  html.tr(sketch_css.class([style.body, style.ink]), [], cells)
}

fn header_cell(children: List(el.Element(Nil))) -> el.Element(Nil) {
  html.th(sketch_css.class([style.body, style.ink]), [], children)
}

fn data_cell(children: List(el.Element(Nil))) -> el.Element(Nil) {
  html.td(sketch_css.class([style.body, style.ink]), [], children)
}

fn table_1() -> el.Element(Nil) {
  html.table(sketch_css.class([style.body, style.ink]), [], [
    html.thead(sketch_css.class([style.body, style.ink]), [], [
      table_row([
        header_cell([el.text("Method")]),
        header_cell([el.text("Path")]),
        header_cell([el.text("Result")]),
      ]),
    ]),
    html.tbody(sketch_css.class([style.body, style.ink]), [], [
      table_row([
        data_cell([el.text("POST")]),
        data_cell([inline_code("/api/store/api_key")]),
        data_cell([el.text("Returns the new plaintext key once")]),
      ]),
      table_row([
        data_cell([el.text("DELETE")]),
        data_cell([inline_code("/api/store/api_key")]),
        data_cell([el.text("Revokes the current key; repeated calls succeed")]),
      ]),
    ]),
  ])
}

fn table_2() -> el.Element(Nil) {
  html.table(sketch_css.class([style.body, style.ink]), [], [
    html.thead(sketch_css.class([style.body, style.ink]), [], [
      table_row([
        header_cell([el.text("Method")]),
        header_cell([el.text("Path")]),
        header_cell([el.text("Body")]),
        header_cell([el.text("Service")]),
      ]),
    ]),
    html.tbody(sketch_css.class([style.body, style.ink]), [], [
      table_row([
        data_cell([el.text("PUT")]),
        data_cell([inline_code("/api/v1/store/rosters/{external_id}")]),
        data_cell([el.text("Full roster object")]),
        data_cell([inline_code("roster_upsert")]),
      ]),
      table_row([
        data_cell([el.text("GET")]),
        data_cell([inline_code("/api/v1/store/rosters")]),
        data_cell([el.text("—")]),
        data_cell([inline_code("store_roster_list")]),
      ]),
      table_row([
        data_cell([el.text("DELETE")]),
        data_cell([inline_code("/api/v1/store/rosters/{external_id}")]),
        data_cell([el.text("—")]),
        data_cell([inline_code("roster_remove")]),
      ]),
      table_row([
        data_cell([el.text("PUT")]),
        data_cell([
          inline_code("/api/v1/store/rosters/{external_id}/photos/{order}"),
        ]),
        data_cell([inline_code("{ \"blob\": \"<key>\" }")]),
        data_cell([inline_code("roster_photo_put")]),
      ]),
      table_row([
        data_cell([el.text("PUT")]),
        data_cell([
          inline_code("/api/v1/store/rosters/{external_id}/schedule/{date}"),
        ]),
        data_cell([
          inline_code("{ \"starts_at\": \"18:00\", \"ends_at\": \"20:00\" }"),
        ]),
        data_cell([inline_code("store_schedule_put")]),
      ]),
      table_row([
        data_cell([el.text("PUT")]),
        data_cell([inline_code("/api/v1/store/rosters/order")]),
        data_cell([inline_code("{ \"ids\": [\"<internal roster id>\"] }")]),
        data_cell([inline_code("roster_reorder")]),
      ]),
      table_row([
        data_cell([el.text("POST")]),
        data_cell([inline_code("/api/v1/store/blobs")]),
        data_cell([el.text("Raw "), inline_code("image/*"), el.text(" body")]),
        data_cell([el.text("Blob adapter")]),
      ]),
    ]),
  ])
}
