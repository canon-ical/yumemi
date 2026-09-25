# yumemi-fix-0113 真壁 ── 生成器の穴 H4、版 0.11.3(2026-09-26)

## 状態

- 完了。報告は `docs/reports/yumemi-fix-0113.md`
- H4:commit の後に続きを持つ Service(source に `step.commit(`、runtime の `boundaries` でない)の生成の live は Out の代わりに `Reply`(`Replied(Out)` / `Accepted(id)`)を持ち、202 の 1 欄の本文を `Accepted(id)` に読んで `Done(Ok(_))` → after_send へ。`emit/accepted.gleam`(新)、`emit/front.gleam`。runtime の `boundaries` の判定を `accepted.boundary` に寄せた(生成物の差 0)
- 版 0.11.3(`gleam.toml`、`gen/manifest.toml`)、README に 1 段落
- 公開型は変えていない。`git diff v0.11.0 -- src/framework` は `A` 11、+1349 / -0

## 検収(証跡は `gen/build/fix0113/`)

- root build 0、gen test 292 / 0、format 0、fixture ×2 差 0(tracked 66 と一致)
- 写し `2a36ce5c`:1 手 ×2 exit 0・差 0、警告 33(0112 と同じ集合)。commit 済みとの差は 202 の Service の live 6 本(muses reservation_approve / _reschedule / _cancel / article_publish / article_revise、www reservation_request)と muses / www の client.mjs だけ
- 写し:api 700 / 700、3 面 build 0・format 0・npm build 0・test 52 / 16 / 18
- 実 API(wrangler 8841 → bridge 8840 → PG 55540):live の承認・再調整・取消・申込が 202 → `Done(Ok(Accepted(id)))` → emit `yumemi-done`、DB も変わった。0.11.2 の Out の decoder は同じ本文で Error。取消 2 回目は 422 → `Refused`、emit 無し
- PG 55540(pid 3159741)・wrangler(3161407)・bridge(3161406 / 3162034)は pid で止めた

## DDL

無し。

## 残り

- Chromium で島を押す形は回していない。www `reserve-request` の島は `Done(Ok)` で文言を出し live の読み直しの effect を捨てる(musearch の島の書き方)
