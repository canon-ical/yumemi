# 真壁[IM]へ ── yumemi 0.12 段 B(便 yumemi-012-y4、遷移を Navigation API に寄せて navigate.mjs を薄くする、直書き、鷹野[PDM] 2026-10-12)

便: yumemi-012-y4(yumemi リポ、Opus 真壁の直書き、終端で柏木のゲートを便に 1 回 ── `KASHIWAGI_ROUTE=opus`)

**1 session で直に書く。細かい設計は真壁さんが決める(役員 人見 2026-10-12)。**作業木 `~/yumemism_repo/yumemi-012-y4`(branch `impl/012-y4`、基点は本 BRIEF の commit = 段 A の merge 後の forgejo main `087b2d8` の上)。記録は `briefs/results-yumemi-012-y4.md`、証跡は `build/012-y4-*`(git の外)。commit は `git-as makabe`、main に触らない。push・tag・Hex の publish は鷹野。**版の行(`0.12.0-dev`)に触らない。止め線は経過 1 時間 30 分。**

**並行の便:**同じ基点から Y2(`briefs/BRIEF-yumemi-012-y2.md`、要素の木と Css)と Y5(`briefs/BRIEF-yumemi-012-y5.md`、門と CMS の機能)が別の作業木で走る。file の持ち場は下の「持ち場」と tech `_drafts/gleam-framework/81-stage-b-ownership.v0.md`。merge は Y2 → Y4 → Y5 の順で、本便は 2 番目(Y2 が遅れれば先でもよい)。

**親:**tech `_drafts/gleam-framework/51-front-types.v6.md` の「遷移」と「interactive Component の runtime」の given の行、`73-navigation.v0.md`(navigate.mjs の 16 の責務と仕分け、枝「client の遷移を残し、Navigation API に寄せて薄くする」)、`70-brief-front-rethink.md` 末尾の段 3 の行、yumemi `briefs/results-yumemi-01115.md` の実測の節、tech `_drafts/musearch/104-www-navigation.v0.md` の「測り方」。

**親ゴール:**頁の間の移動は client の遷移のまま、ブラウザの仕事(click の横取り・履歴・scroll・focus・中断・#)をブラウザに返し、framework に残るのは 7 つだけにする。10-11 に直した「嬢のページの中の移動が、頁ごと読み直したと見えない」(素の時間 0ms)を保つ。
- 障害:navigate.mjs(377 行)がブラウザの頁の読み込みの仕事を JS で写し直し、写しの漏れがそのまま使い心地の漏れになっている ── 戻る・進むで scroll が戻らない、差し替えの後の focus を扱っていない(73 の責務 10・11)
- 障害:薄くする途中で 0.11.15 の head の差分と stylesheet の待ちを崩し、素の頁が戻る(役員 人見「SPA じゃないっぽい」2026-10-11)
- 障害:Y5 の数える口と、遷移の後の pageview の印の受け渡しが食い違い、client の遷移を 0 回か 2 回数える

## 現在地(段 A の merge 後の main。置き場は `src/yumemi/` と `src/yumemi/gen/`)
- navigate.mjs の責務は 16(73)。click を自前で横取りし、`pushState` / `replaceState` / `popstate` と表示中の印 `shown` を持つ。scroll は push と書いた後の取り直しだけ当て直し、戻る・進むでは何もしない。focus の処理は無い。差し替えの後に `boot()` を呼び、`yumemi-navigated` を出し、pageview を送る(`spa` / `reload`、前の event の鎖、失敗で 1 回送り直す)
- 生成の client.mjs は `startNavigation({ routes, boot, csp?, pageview? })` と `reloadPage()`(書いた後の取り直し)で navigate を使う(`emit/front.gleam` の `navigation` と `client_text`)
- 差し替えてよいかは「来た頁の script が client の 1 本だけ」と「登録済みの given の島を持たない」の 2 つ。given は段 C の Y3 で消える
- 取れない・CSP が違う・HTML でない・redirect の応答は頁の読み込みに落ち、server は同じ GET を 2 回受ける(0.11.4 の柏木の P1、残置)
- 門は頁の読み込みには inline の pageview の script を、client の遷移の fetch(`x-yumemi-navigate: 1`)には `<meta name="yumemi-pageview">` を差す(`emit/gate.gleam`、Y5 の持ち場)
- Navigation API は Baseline newly(low 2026-01-13、Chrome 102・Firefox 147・Safari 26.2)

## どこまで
1. **click の横取り・履歴・戻る / 進む・scroll・focus・中断・# を、Navigation API の `navigate` イベントと `intercept()` に渡す。**戻る・進むで scroll が戻り(`scroll` の既定)、差し替えの後の focus が body か `autofocus` の要素へ移る(`focusReset` の既定)
2. **framework に残すのは 7 つ ── 取得・差し替えの判定・head の差分・stylesheet の待ち・body の差し替え・interactive Component の再起動・pageview の印。**head の差分と stylesheet の待ちは 0.11.15 の振る舞いのまま
3. **Navigation API の無い browser では横取りしない(頁の読み込み)。**差し替えられない応答も頁の読み込みに落ちる(今の型のまま)
4. **書いた後の取り直し(After の `ReloadPage` の実体)は、Navigation API の reload を横取りする形にする。**履歴を積まず、scroll を保つ。client.mjs から呼ぶ口の名と引数は変えない
5. **interactive Component の再起動は今の形のまま繋ぐ。**差し替えの後に client が渡した `boot` を呼ぶ。差し替えの判定の given の条件も残す(どちらも Y3 で外れる。下の「鷹野に返す点」1)
6. **pageview は送らず、印は残す。**navigate.mjs から送りの code(欄の組み立て・鎖・送り直し)を外す。client の遷移が確定したとき(`navigatesuccess` の時点)、来た頁の `<meta name="yumemi-pageview">` が今の document にあり、前の頁の印が残っていないことを保証する。書いた後の取り直しは Navigation API の上で `reload` の種類、戻る・進むは `traverse` の種類として見えること。送るのは Y5 の client 側の送り手で、本便の後・Y5 の merge の前の main では client の遷移の pageview は送られない(musearch は段 D まで 0.11 のままなので本番に効かない)
7. **`yumemi-navigated` の合図は出さない(`navigatesuccess` に任せる)。**musearch で聞いている所(`muses/src/components/muse_nav_ffi.mjs:7-13`)を results に挙げる(段 D の材料)
8. `navigation` の生成から pageview の欄(`endpoint`・`source`・`key`)を外す。README の遷移の節を現物に直す

## 持ち場(並行の便との切り分け。全体は 81)
- **本便の file:**`src/yumemi/front/navigate.mjs`(名前は変えない。client.mjs に畳むのは段 C 以降)、`emit/front.gleam` の `navigation` と、`client_text` の遷移の行(navigate の import・`startNavigation`・`reloadPage`)、遷移を見る既存の test(`yumemi_01115_test` とその ffi・`yumemi_01115_stage_check.mjs`、`yumemi_fix_0114_test` の遷移の関数。`navigation_keeps_counted_pages_and_passes_pageview_test` は Y5 も直すので、本便は pageview の期待を消すだけ)と本便の新しい test
- `navigation` の中の CSP の行(`gate.frame_src` を読む所)は触らない。Y5 が門の `csp` への替えに合わせて書き換える。pageview の行は本便が消し、Y5 も消す(同じ行を消すだけなので merge で解ける)
- **触らない:**`client_text` の島の登録(`client_registration`・`island_style` の import。Y2 と Y3)、`emit/gate.gleam` と門の生成物(inline の pageview の script を含む。Y5)、`emit/front.gleam` の SSR・CSS・頁の色・面の写し(Y2)と `gate_file`〜`gate_notes`・client.mjs を出す条件(Y5)、`shell_page_tables`・`shell_given_rows`、`src/yumemi/front/` の navigate.mjs の外
- route の照合を門と同じ表で共有すること(51 v6「遷移」)は本便でしない(段 C の継ぎ目)
- 生成物(fixture の `src/gen/`・`priv/static/_yumemi/`・`_diagnostics.txt`)の衝突は、merge のとき鷹野が ours で取って生成し直す

## しないこと
route の照合の共有、given を消すこと・`boot` を外すこと・島の登録の書き換え(Y3)、pageview の送り手・門の inline の script・数える口の宣言(Y5)、View Transitions・Speculation rules・`moveBefore()`、取れないときの 2 回の GET を直すこと(直せたなら results に)、navigate.mjs を client.mjs に畳むこと・改名、musearch の source(写しだけ)、版の行・tag・publish・push。

## 失敗例(差し戻し)
- 素の時間が 0 でなくなる。TOP ⇄ 記事・タブで `window` が残らない(頁の読み込みに落ちる)
- Navigation API の無い browser で link が動かない、JS の error が出る
- 書いた後の取り直しで履歴が積まれる、scroll が頭へ飛ぶ
- CSP の違う頁へ差し替えで入る
- client の遷移の後、来た頁の pageview の印が今の document に無い、または前の頁の印が残る
- 薄くしたと言いながら、履歴と scroll の自前の処理(`pushState`・`popstate`・scroll の当て直し)が残る(残すなら理由を results に)
- Y2・Y5 の持ち場の file・行を触る

## 検収
- root `gleam test` が通り、本数は基点から減っていない(before / after を results に。期待値を書き換えた test は名と理由を列で)。`gleam format --check` 0
- navigate.mjs の行数の before / after と、73 の 16 の責務それぞれの行き先(Navigation API・framework・要らない)を results に 1 行ずつ
- **musearch の写し:**origin/main(`~/yumemism_repo/musearch`)を `.scratch/musearch` に置き、Y1 と同じ名前の置き換えだけをして、yumemi を本作業木への path にする。api の package から全面を生成して停止コード 0・2 回目の差 0。基点(段 A の merge 後の main)で生成したものとの差は、client.mjs の遷移の部分と bundle の navigate.mjs だけ。4 面の `npm run build`・`npm test` が通る(落ちた test は名と理由。client の遷移の pageview の送りに依るものは期待どおりとして列で)。auth は触らない。写しは捨てる
- **実測:**0.11.15 の probe と serve(`~/yumemism_repo/yumemi-01115/build/01115-probe.mjs`・`01115-serve.mjs`)を本便の build に写して使う。電話相当(360×780・DPR 2・touch、RTT 150ms・下り 1.6Mbps・上り 750kbps・CPU 4 倍)で、TOP → 記事 1 件・TOP → スケジュール・スケジュール → 記事を各 3 回、before = 基点・after = 本作業木。after の 9 回とも client の遷移(`window` の印が残る)・素の時間 0ms・pageerror と console の error 0
- **同じ probe に足す確かめ:**長い頁を scroll してから移って戻ると scroll の位置が戻る / push の後の `document.activeElement` / init script で `window.navigation` を消した browser では 3 通りとも頁の読み込みになり error 0 / CSP の違う頁へは頁の読み込み / 移った先の島(購読のボタンほか)が起きている(custom element が define 済みで中身がある) / 移った先の document に pageview の印 meta が 1 つだけ / 書いた後の取り直しで `history.length` が増えず scroll が保たれる
- iOS の実機は撮らない(鷹野の検収で見る)

## 鷹野の裁き(2026-10-12)
1. interactive Component の起こし直しは今の形のまま繋ぐ(差し替えの後に `boot`、given の条件も残す)。外すのは Y3
2. Y4 の merge から Y5 の merge までの main で client の遷移の pageview が送られないのは許す(musearch は段 D まで 0.11)。Y5 が閉じられなければ鷹野が Y5 の r2 を起こす
3. 止め線は経過 1 時間 30 分
4. 段 B の 3 便の merge 順は Y2 → Y4 → Y5(Y2 が遅れたら Y4 を先に)。どの便も単独で閉じられない継ぎ目 7 つ(`el.Src` と `gen/media.src`、地の画像の URL、route の照合の共有、逃げ道の数えの統合、`boot` を外す、共存の外し、`el.dialog`)は段 C の Y3 に「段 B の継ぎ目」として載せる。
