# yumemi-1e 束 B' results

## DDL

無し。

## 実装

1. `gen/manifest.toml` と `gen/fixtures/article/public/manifest.toml` の yumemi lock を 0.9.0 に追随。変更後の基線は `167 passed`。
2. `Pin.Overlay` は `<div popover>` と `id = el.overlay_id_prefix <> area.name` で出力。Area の `z-index` / `position` は生成しない。
3. Overlay area を除いた Frame を `framework/front.resolved_template` に渡す。明示 template が Overlay を名指す場合は exit 4 で止める。
4. `el.opener` / `el.closer` の area 文字列リテラル、同じ Page / Layout での存在、`pin: Overlay` を検査。
5. `el.each_modal` の scope 文字列リテラルと Page + Layout 内の一意性を検査。row_key は Out の安定した key を渡す。
6. badge の位置 CSS と `[data-count=""]` / `[data-count="0"]` の非表示 CSS を生成器が出力。
7. fixture Page に Overlay、opener / closer、島を含む普通の Block を配置。Article / Summary の2つの一覧 Block に異なる scope の `each_modal` を配置。
8. 6種類の exit 4 負例 fixture と診断テストを追加。
9. `gen/scripts/verify-front-overlay.mjs` を追加。JavaScript 無効 context で開閉、行 modal の id と独立開閉、grid computed 値、badge computed style を確認。
10. `gen/test` は 174 tests に増加。

## 出力形

SSR の実測 HTML:

```html
<div data-yumemi-area="article-dialog" data-yumemi-overlay id="yumemi-overlay-article-dialog" popover>
```

Overlay ID は framework の `el.overlay_id_prefix` を使用。backdrop と badge は generator CSS:

```css
[data-yumemi-badge] {
  position: absolute;
  inset-block-start: 0;
  inset-inline-end: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 1.25rem;
  height: 1.25rem;
  padding-inline: 0.25rem;
  border-radius: 999px;
  color: var(--bg);
  background: var(--accent);
  font: 600 0.75rem/1 system-ui, sans-serif;
}
[data-yumemi-badge][data-count=""],
[data-yumemi-badge][data-count="0"] { display: none; }
[popover]::backdrop { background: rgba(0, 0, 0, 0.45); }
```

既定 / 明示以外の template 計算前に Overlay を frame.areas から除く。framework の `resolved_template` の意味は Overlay を含む Frame を受けるまま。fixture の SP computed 値は `"page" "rail"`、PC は `"page page" "rail aside"`。両方に `article-dialog` は無い。

exit 4 の診断文:

- `el.opener が同じ Page / Layout に無い area "missing-dialog" を名指している`
- `el.opener の area "plain-dialog" は pin: Overlay ではない`
- `el.opener の area は文字列リテラルでなければならない`
- `明示 template に Overlay area "article-dialog" を指定できない`
- `el.each_modal の scope は文字列リテラルでなければならない`
- `el.each_modal の scope "shared-row" が同じ Page + Layout 内で重複している`

一覧 row modal の実測 ID:

```text
yumemi-row-overlay-11-article-row-7-article
yumemi-row-overlay-11-summary-row-7-article
```

NO-JS 判定は `javaScriptEnabled: false` context で opener / closer を click し、対象要素の `matches(":popover-open")` を前後で比較。行 modal は全要素の同じ selector を列挙し、1つ目だけ open になることを確認。

## 検証

- `cd gen && gleam test`: **174 passed, no failures**。証跡 `gen/build/y1e-bp-gen-test-final.txt`。
- root `gleam build`: exit 0。warning は `src/framework/secret.gleam` の既存1件。証跡 `gen/build/y1e-bp-root-build.txt`。
- fixture 生成2回: 各 exit 0、各92 files。再生成 diff は0行。face build / runtime build / esbuild PASS、warning 0。証跡 `gen/build/y1e-bp-generate-final-one.txt`、`gen/build/y1e-bp-generate-final-two.txt`、`gen/build/y1e-bp-fixture-final-diff.txt`。
- generated 27 Gleam files と変更した source / fixture の `gleam format --check`: exit 0。証跡 `gen/build/y1e-bp-format-generated.txt`、`gen/build/y1e-bp-format-source.txt`、`gen/build/y1e-bp-format-negative-fixtures.txt`。
- `verify-front-ssr.mjs`, `verify-front-isolate.mjs`, `verify-front-given.mjs`, `verify-front-file.mjs`, `build-blocks.mjs`: ALL PASS。
- `verify-front-overlay.mjs` の出力は下記。証跡 `gen/build/y1e-bp-verify-overlay.txt`。

```text
OVERLAY HTML: <div data-yumemi-area="article-dialog" data-yumemi-overlay id="yumemi-overlay-article-dialog" popover>
SSR HTML: PASS (popover and popovertarget present)
NO-JS AREA: PASS (opener opened; closer closed)
ROW MODAL IDS: ["yumemi-row-overlay-11-article-row-7-article","yumemi-row-overlay-11-summary-row-7-article"]
NO-JS ROW: PASS (only its row popover opened)
GRID TEMPLATE: PASS ([{"name":"layout","areas":"\"header header\" \"page aside\" \"footer footer\""},{"name":"page:pages/article/arg_slug/page","areas":"\"page page\" \"rail aside\""}])
BADGE: PASS (None and Some(0) hidden; Some(3) visible and positioned)
ALL PASS
```

- fixture 生成 `db/` と指定基点 `/home/yumemism/.codex-agents/runs/niekawa-20260924-135307-601740-3464/out-fx-base/db` の `diff -r`: 0行。証跡 `gen/build/y1e-bp-fixture-db-diff.txt`。
- musearch `a109b47` snapshot は1回だけ生成。exit 2 = 0行、exit 4 = 20行。基線21行から増えていない。基線記録 `ms-a109b47/api/build/2b-4-a-generator-note.txt`。この生成は既存の exit 1 = 5行、exit 3 = 1行も報告した。証跡 `gen/build/y1e-bp-snapshot-run.txt`。
- `git diff --stat 8cb76af -- src/`: 0行。framework は変更なし。

## 51 v5 への追記材料

`Pin.Overlay` は top layer の popover として生成し、Overlay area を除いた Frame を使って生成器が grid template を解決する。`framework/front.resolved_template` 自体は Overlay を含む Frame を受ける意味を保つ。`el.opener(area, child)` / `el.closer(area, child)` は area を文字列リテラルで指定し、同じ Page + Layout 内の `pin: Overlay` を静的検査する。`el.badge(count: Option(Int), child)` は None / 0 / 正数で同形の DOM を出し、None と 0 は生成 CSS が隠す。`el.each_modal(scope, row_key, ...)` は scope を文字列リテラルかつ Page + Layout 内で一意にする。row_key は Out の安定した key を渡す。framework は id を組み立てる際に row_key の id 不適合文字を escape しない。

## 確かめていないこと

Chromium 以外のブラウザーと手動の実機表示は未確認。snapshot に報告された exit 1 / exit 3 の既存行はこの束の範囲外として未修正。
