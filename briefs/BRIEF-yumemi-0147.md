# BRIEF yumemi-0147 ── client の遷移で、redirect を返す GET を 2 回送らない

便: yumemi-0147(branch `impl/nav-redirect`、作業木 `~/yumemism_repo/yumemi-0147`、基点 forgejo/main `d5002ba` = 0.14.6)
起案: 鷹野[PDM]、2026-10-18

**真壁さんへ(Sonnet)。**止め線は経過 45 分。commit は `git-as 真壁`。tag・push・publish は触らない(鷹野が打つ)。終端で柏木のゲート 2 を 1 回通す。

親ゴール: 面の client 遷移(`navigate.mjs`)で、同じ origin のリンクを 1 回押したら、302 を返す GET が server に 1 回だけ届く。
- 障害: redirect の後の URL が元の(副作用のある)URL のまま残り、再読み込みでもう一度副作用が走る
- 障害: 別の origin へ redirect する道で、別の origin に要求が 2 回飛ぶ
- 障害: redirect しない応答(200・失敗の頁・CSP 違い・HTML でない)の挙動が変わる

## 現在地

- `src/yumemi/front/navigate.mjs` の `start` の中の `swap`(forgejo/main で 340 行付近)が、行き先を `fetch(url, { redirect: "manual", … })` で取る。302 は `opaqueredirect` になり、`load(url)` = `location.replace(url)` で **同じ URL** を頁の読み込みでもう一度取る。副作用のある GET(使う側の面の例:押すと cookie を据えて `/` へ 302 するリンク `/?red=…`)が 2 回届く。使う側はこの便の前に操作を冪等にして吸収済み
- `manual` では応答の `Location` が読めない(opaque)ので、「行き先へ 1 回で行く」はできない
- test:`test/yumemi_012_y4_start_check.mjs`(偽の Navigation API・location・fetch、子の node で走る。`yumemi_012_y4_test_ffi.mjs` が呼ぶ)。74 行の `respond({ type: "opaqueredirect", … })` と「redirect falls back to load」が今の挙動を縛っている
- `src/yumemi/front/block.mjs` の `fetchBlock`(Block の断片の取得、`redirect: "manual"`)はこの便で触らない。今の頁の URL への読みで、redirect は「頁ごと取り直す」の合図

## 決めた形(鷹野)

**`swap` の fetch を `redirect: "follow"`・`mode: "same-origin"` に替え、`response.redirected` なら差し替えずに最終の URL を頁の読み込みで開く。**

- 印の付いたリンクだけ fetch を試さない案(案 A)は採らない。既存の面は変わらないが、副作用のある GET を足す人が印を忘れると黙って 2 回届く。罠が残る
- `follow` なら ブラウザが redirect を辿り、元の URL と途中の URL には 1 回ずつしか届かない。2 回取られるのは最終の頁(fetch と頁の読み込み)で、PRG の最終は表示の頁なので害が無い。今は元の URL が 2 回で最終が 1 回 ── 回数は同じで、2 回になる側が副作用の無い頁へ移る
- 最終の頁を差し替えに使わない理由:今の entry の URL は元の(副作用のある)URL のまま。差し替えると URL が残り、再読み込みでもう一度副作用が走る。`location.replace(最終)` なら URL も CSP の header も最終の頁のものになる
- `mode: "same-origin"`:別の origin への redirect は、別の origin に要求を送る前に fetch が失敗する(Fetch の main fetch の検査は redirect の度に走る)。失敗は今と同じ `load(url)` に落ちる。`cors` の既定のままだと別の origin に 1 回余計に飛ぶので、必ず付ける

## どこまで

1. `swap` の fetch の init を `redirect: "follow"`・`mode: "same-origin"` に。他の項目(`credentials`・`cache`・`headers`・`signal`)はそのまま
2. 応答が `response.redirected === true` なら、`new URL(response.url)` を頁の読み込みで開く(`load`、`location.replace`)。行き先の URL に `#` が無く、元の `url` に `#` があれば元の `#` を付ける(ブラウザの redirect と同じ)。`response.url` が空・読めない・別の origin なら今と同じ `load(url)`
3. redirect でない応答の判定(`swappableStatus`・content-type・`samePolicy`・`swappable`)と、通信の失敗・中断(`stopped`)は今のまま。`response.type === "opaqueredirect"` の検査は残してよい(害は無い)
4. 冒頭の注記(20 行付近「取れない(redirect・…)ときは、行き先を頁の読み込みで開き直す」)を、redirect は最終の URL を開く、に直す。理由を 2 行
5. test(`yumemi_012_y4_start_check.mjs`):
   - fetch の init が `redirect: "follow"`・`mode: "same-origin"`
   - `{ redirected: true, url: "https://www.example/a", status: 200, … }` で `replace` が 1 回、行き先は `/a`、元の `/b` は読み込まない
   - 元の URL に `#x` があり最終に無ければ `/a#x`
   - `response.url` が別の origin なら元の URL を `replace`
   - fetch が TypeError を投げる(別の origin への redirect を `same-origin` が止めた形)は今のまま元の URL を `replace`
   - 既存の 200 の差し替え・失敗の頁・ネットの失敗・中断の check は全部そのまま通る
6. **実ブラウザで 1 回を確かめる。**root の `node_modules` の `playwright-core` と手元の Chromium で、node の小さな server(`/` は 200 の頁、`/go` は 302 で `/`)に生成済みの `navigate.mjs` を載せた頁を開き、`/go` のリンクを click して、server が `/go` を **1 回**だけ受けたことを数える。直す前の `navigate.mjs`(forgejo/main)では 2 回になることも同じ台本で示す。台本は `test/` に置き、`gleam test` には繋がなくてよい(Chromium が無い台で落ちないように)。結果は results に
7. `gleam.toml` の version を `0.14.7`。fixture の各面(`gen/fixtures/{article,cms}/{admin,public}`)で `gleam update yumemi`、生成し直して `priv/static/_yumemi/client.mjs` が新しい `navigate.mjs` を持つこと(第 41 条が lock の `-dev` を止める)
8. `CHANGELOG.md` の頭に `## 0.14.7 (2026-10-18)` を 3〜5 行(英語、既存の書き方)。**事業名・人名を書かない**(Hex に載る)。`git grep -i "musearch\|人見" -- README.md CHANGELOG.md src` が 0
9. root の `gleam test`。合否は終了コードでなく出力の `passed` / `failures` の字で見る

## しないこと

`block.mjs`・`interactive.mjs` の redirect の扱い。最終の頁を差し替えに使って URL を書き換えること(`history.replaceState`・`precommitHandler` は入れない)。リンクに印を付ける仕組み。tag・push・Hex publish。

## 失敗例

- 版の行を替えて fixture の lock を直さず root の test が落ちた(0.14.4)
- 短縮の sha を `--ref` に渡して CI が黙って落ちた ── この便は CI を使わない
- 実ブラウザの検算を偽の fetch の test で代えない。偽の fetch は `mode` の挙動を持たない

## 返すもの

`briefs/results-yumemi-0147.md`(1〜9 の充足、test の数、実ブラウザの回数の表、確かめていないこと)。commit は 1〜3 個。
