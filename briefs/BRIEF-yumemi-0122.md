# BRIEF yumemi-0122 ── 0.12.2:最小の app が生成→起動→一覧まで通らない 4 つの穴

便: yumemi-0122
基点: yumemi main `d770c59`(tag `v0.12.1`)
起案: 鷹野[PDM]、2026-10-13
親: `~/canonical/tech/_drafts/gleam-framework/51-front-types.v6.md`(型の正本案)、`80-baton-012.md`

親ゴール: musearch 以外の、素直に書いた最小の app が、yumemi 0.12 で生成→workerd で起動→CRUD と一覧の頁送りまで手書きの橋なしで通る。
障害: musearch の形(Host の名 = 入口の名、queue・subject あり、手書きの FFI あり、size 20)でしか通らず、ほかの形の app は 404・bundle の停止・頁の取りこぼしで黙って壊れる/直しで musearch の生成物が変わり、musearch の書き直しが要る。

## 現在地

cloud の Claude がベンチの notes app で見つけた 4 点と、その直しの patch が `.scratch/yumemi-fix-bench-findings.patch`(`git apply --check` は main に当たる)。**patch は材料で、裁定ではない。**ベンチの app は手元に無い。patch の申告(gleam test 454 passed、workerd で CRUD・limit 1/5/20・2 頁目)は誰も再現していない。

patch の 4 点(要約、詳細は patch の本文):
1. `server/http.mjs`:入口の host を Host の variant 名で引いている。生成物の hosts は入口の名 → `<NAME>_HOST`。`ApiHost` と入口 `api` のように名がずれる app で全要求が 404
2. `gen/emit/verb`:`gen/verb.gleam` の FFI の import 先が `../operations_ffi.mjs`。生成物は `gen/` 直下に置かれるので、src に手書きの橋が無い app で bundle が止まる
3. `gen/emit/back`・`gen/emit/runtime`:queue の kind が無い app に `gen/queue_runtime.mjs` を吐かない(shell と cron は import する)。subject の Entity が無い app でも `./subject.mjs` を import する
4. `server/runtime.mjs`・`gen/emit/runtime`:`Paged(size: Param(..))` の頁を固定 20 で切る。SQL は `LIMIT $n + 1` なので、limit≠20 で limit+1 件返り、next が null

## どこまで

1. **4 点それぞれを、直す前に落ちる test で再現する。**再現しない点は直さず results に「再現せず」と根拠を書く
2. **再現した点を直す。**patch をそのまま当ててもよいが、直し方は真壁が決める(patch より筋の良い形があればそちら)
3. **最小の app の fixture を 1 つ足す**(`gen/fixtures/` の下。Host の variant 名 ≠ 入口の名、queue・subject なし、手書きの橋なし、`Paged(size: Param(..))`)。生成器 2 回 exit 0・差 0、workerd で起こして CRUD と limit 1・5・20・2 頁目を叩いた結果を results に貼る

★ の書き方は変えない。

## しないこと

- 版を替えない・tag を打たない・publish しない(鷹野がする)
- results-yumemi-0121「次の版へ」と 80 の宿題は今回の外。触れるなら results に「次の版へ」で
- 事業名と役員の名を src・README・commit message・fixture に書かない(fixture の題材は notes 等の一般名)
- Hono・PHP 等との比較ベンチは作らない(別に振る)

## 失敗例

- 3 を直すのに、queue を使う app の `queue_runtime.mjs` の中身まで変える
- 4 を直して size が定数の `Paged` の頁の切り方を変える
- `gleam test | grep passed` の終了コードで合否を読む(字で見る)

## 確かめ

root で `npm ci` → `gleam test`。既存の fixture の各面で生成器 2 回 exit 0・差 0、**既存 fixture の生成物の差分は results に全部挙げて理由を添える**。musearch の写し(`~/yumemism_repo/musearch` main を `.scratch/` に)で path 依存にして各面を生成し直し、生成器 exit 0 と www・muses の test が通ること(Hex の rate limit で落ちたら間を置いて回し直し、results に書く)。

## 返すもの

`briefs/results-yumemi-0122.md`(4 点ごとの再現の有無・直し・test 名、fixture の実測、musearch の写しの結果、既存 fixture の差分)。commit は `git-as 真壁`。
