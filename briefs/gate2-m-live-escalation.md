柏木:ゲート 2(m-live、`ae439c973..9aa8f502a`)のレビュー完了です。真壁の実装は BRIEF どおりで、実装の P0 はありません。ただし BRIEF が前提にした「札は allow の Entity を持つ読みに全部付ける」の形に認可の穴があり、実際に再現しました。裁定が要るので、判定はエスカレーションにします。

## エスカレーション(鷹野さんの裁定が要ります)

**公開の読みの札で、嬢の非公開の書きの時刻を、ログインしていない第三者が聞けます。**
- **どこから入るか:**`muse_top` は allow に `allow.Anyone` を持つ公開の読みです。session の無い browser(`_mb` cookie だけ)がこれを読むと、`muse:<id>` の札が返ります。
- **socket の口が通す:**口はその札で通ります。`Origin` を見ていますが、browser でない client は好きな値を付けられます。
- **何が聞こえるか:**嬢の顧客台帳への書き(`customer_add`、muse_link の入口だけで使う非公開の書き)が commit すると、`muse:<id>` に合図が出ます。
- **再現:**probe の test を `api/test` に一時的に置いて確かめました。commit はせず、確かめた後に消しています。
  - 札の中身:`{"to":"muse:8f1a…","party":null,browser 印あり}`
  - 口は受け付けた
  - 合図の記録:`published ["muse:8f1a…"]`
  - api の test は probe を含めて 1935/1935
- **同じ形になる root:**公開の読みと同じ root を持つ書きが全部当たります。
  - `muse`:`customer_add`・`customer_edit`・`customer_phone_merge`・`subscription_add` ほか
  - `muse_schedule`:`reservation_phone`・`reservation_request`・`schedule_earning_set` ほか
  - `article`:公開済みの記事の改稿(`article_revise` ほか)
  - `roster`・`store`:`roster_issue_code`・`store_schedule_put` ほか
- **漏れる量:**届くのは `1` の 1 語だけで、本文は出ません。ただし公開の頁を 1 時間ごとに読み直せば札を取り直せるので、嬢が台帳を触った時刻を、いつまでも即時に追えます。
- **chat は塞がっている:**root が `chat` の読みは `chat_read` だけで、当事者でない人は root で 404 になり、札は出ません。
- **なぜ差し戻しでないか:**設計 87 の「鷹野に確かめたいこと」は、全部の読みに札を付ける代金を HMAC の分としてだけ見ていました。同じ root に公開の読みと非公開の書きが並ぶ場合は検討されていません。真壁は BRIEF の 18 行目どおりに作っているので、差し戻しではなく裁定の話です。
- **案は 3 つ:**
  - (a) 合図は 1 語なので受け入れる。
  - (b) musearch の側で塞ぐ。★ の `worker_entry.mjs` で、`/_yumemi/live` に来た札の `to` が `chat:` で始まらなければ 403 にします。小さい変更で、後から戻せます。
  - (c) yumemi の 0.14.x で、札を `Live` の Block の読みだけ、または宣言した読みだけに付ける。
- **僕の推し:**production の deploy の前に (b) を入れ、(c) は yumemi の後の便に回す。staging の検収は、今のままで進めて構いません。

## P0 の一覧

P0 無し(実装について)。

## P1(サマリに残してください)

- **P1-1:退会・Chat の消去の後も socket が残る。**開いていた socket は、札の期限(最長 1 時間)まで `1` を受け続けます。以前は USER DO の `clear` が socket を閉じていました。取り直しは門と root で落ちるので、本文は出ません。設計 87 の「読めなくなった人」で受け入れ済みです。
- **P1-2:誰も聞いていない書きにも合図が出る。**root の Entity を持つ書きは、commit のたびに `YumemiLive` へ `publish` を 1 本撃ちます。DO の要求の数が、書きの数だけ増えます。
- **P1-3:鍵の置き方が既存の HMAC 鍵と違う。**既存の `IDEMPOTENCY_HASH_KEY`・`SECRET_HMAC` は Secrets Store の binding です。`YUMEMI_LIVE_KEY` を results の手どおり `wrangler secret put` で入れると、置き方が揃いません。yumemi はどちらの形でも読みます。INFRA なので鷹野さんの判断です。

## P2(直しました、commit `4ce9b9212`)

- **P2-1:**`www/test/r3-client-swap.test.mjs` の注記と assert の文言が `start2` のままでした(今の client では `start3`)。`start<N>` に替えました。直した後、この file の test は 3/3 で通っています。
- **P2-2:**results の「鷹野に残すこと」に、古いまま残る doc を足しました。島 `chat-live` の記述が `docs/spec.md` の `:877`・`:880`・`:907` にも残り、`docs/runbook.md:345` の lock の版も `0.13.1` のままです。doc 本体は鷹野さんの手なので触っていません。

## 見てほしいと言われた 5 点

1. **受信箱の道は残っています。**
   - CHAT DO(`chat_do.mjs`)は diff の外で、手が入っていません。
   - USER DO の adapter は `notify`・`inbox`・`markRead`・`clear`・`alarm` が残り、キャッチアップの alarm を張る判定も元のままです。
   - `notification_notify` は、受信箱に積んで確定する所で終わります(apply → commit → done)。
   - 縛っている test が 2 つあります。`m-live inbox` は本物の `UserDoAdapter` を受け手にし、届かない間は CHAT DO に 1 行残り、alarm の再送で受信箱に 1 行、同じ event の再送でも 1 行のままです。10c は開いた socket を偽物で置いても、送った数が 0 であることを縛っています。
2. **chat の札は当事者にしか出ません。**
   - 宛先は yumemi の `liveIssue` が root の行から作ります。
   - socket の口は、session の party と `Origin` の両方を見ます。
   - Chat を消した後は、書きが 404 になり合図は出ません。退会の後は P1-1 のとおりです。
   - api に「ブロック」の機能はありません(`api/src` を grep して 0 件)。一番近いのは `chat_close` で、閉じた後も客は設計どおり読めます。
   - chat 以外の読みについては、上のエスカレーションのとおりです。
3. **wrangler は既存の DO を壊しません。**
   - SEARCH_QUOTA_DO を足したときの前例(`1316675f8`)と同じ形です。
   - schema の説明にも「`exports` と `migrations` は併用できない」とあります。
   - `wrangler deploy --dry-run --env staging` は rc=0 で、binding の一覧に `env.YUMEMI_LIVE (YumemiLive)` と既存の 4 つの DO が並びました。
   - deploy の順(secret → api → 面)は正しいです。binding があって secret が無いと、読みと書きのたびに `live.key_missing` が 1 行ずつ出るので、secret は先に入れてください。
4. **Block の作りは合っています。**
   - 2 面とも `el.each_keyed` の鍵は `line.message` で、行の root(`li` か `div`)に付いています。
   - `el.fresh` は 2 面とも置かれています。
   - 送りの欄(`chat_compose`)の Args は新着で替わらないので、morph に触られません。
   - 画像は送る前に上がる順(`image_missing`)なので、合図との前後の穴はありません。
5. **全 package の test と生成器 2 回の結果:**
   - 生成器は 2 回とも `停止コード: 0`、後の `git status --short` は 0 行でした。警告は 51 行で、Live・鍵・`el.fresh` に関する行はありません。
   - `bash scripts/ci-unit-all.sh` は `packages=7 green=7 red=0` でした(auth 152・api 1934・www 483・muse_link 253・muse_editor 423・console 93・admin 23)。

## 確かめていないこと

- Playwright の 2 者の walk は回し直していません。真壁の証拠の表と `walk.mjs` の assert を読んだだけです。
- staging の実物と、Android・iOS の日本語入力は、見ていません。

判定:**エスカレーション**(実装の P0 は無し。production に上げる前に、上の札の範囲を鷹野さんに裁定してもらう必要があります)

以上、鷹野さんへ返します。