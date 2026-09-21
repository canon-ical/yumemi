# front-1d ── 島の `given` と書きの後

## 結果

`src/framework/front/live.gleam` に、SSR / `reloads` の読みを置く `given`、runtime
だけが作る `Given`、書きの後を表す `After` を追加した。関数・const・helper は
framework に追加していない。

見本の `pick-tag` 島は、Block が `tags` 属性を comma 区切りで渡し、島の
`app()` の `on_attribute_change` が `live.Given(List(String))` を作る。島の
`update` は選択中の `args` を差し替え、POST 成功時に `yumemi-done` を emit する。
`after_send = live.ReloadPage` の分岐は front-scratch の client 雛形に置き、
`location.assign(location.href)` 相当の再要求を行う。

柏木ゲート2の P0-1 は、Block の `pick-tag` に `selected="fixture"` を足し、
`app()` の `on_attribute_change("selected", callback)` が
`live.Set(Nil, value)` を作る形に直した。`tags` は `Given`、`selected` は `Set` として
属性 callback だけで取り込み、`update` / `view` には計算を足していない。
`verify-front-ssr.mjs` は別 page で選択操作なしの POST body `fixture` を検査し、
`SSR INITIAL: PASS (posted "fixture")` を出す。既存 page では選び直した `gleam` の
POST body も検査し、既存の NO-JS / ISLAND / RELOAD の assert は変更していない。

P0-2 は `pick_tag.gleam` に `import gen/service` と
`pub const calls: List(service.Service) = []` を置いた。fixture の Service 5 種には
タグ書きが無いため `calls = []` とし、実 Service への結線は Y2 / P5b に残す。

## 型の差分

### 変更前 (`live.gleam`)

```gleam
pub type State(args, out, error) {
  State(args: args, last: Option(Result(out, error)), waiting: Bool)
}

pub type Event(field, out, error) {
  Set(field, String)
  Send
  Done(Result(out, error))
}
```

### 変更後 (`live.gleam`)

```gleam
pub type State(args, given, out, error) {
  State(
    args: args,
    given: given,
    last: Option(Result(out, error)),
    waiting: Bool,
  )
}

pub type Event(field, given, out, error) {
  Set(field, String)
  Send
  Given(given)
  Done(Result(out, error))
}

pub type After {
  Stay
  ReloadPage
}
```

`given` は SSR が属性で渡した読みの `Out` の欄であり、`reloads` が叩き直した
戻りも同じ欄に置く。`Given` は `app()` の属性変更 callback だけで作り、
`update` は `given` を差し替えるだけにした。

## 51 v5 に足す文の案

1. 「島の `args` の初期値は、属性で渡る。」
2. 「`given` は外から来た読みの置き場であり、`reloads` の戻りもここに置く。」
3. 「書きの後の動作は `after_send` の `Stay` / `ReloadPage` の 2 値で宣言する。」

## 実物

`gen/fixtures/article/www/src/components/pick_tag.gleam` は、島 1 つ分の写し方を
示す。

```gleam
pub type State = live.State(String, List(String), Nil, Nil)
pub type Event = live.Event(Nil, List(String), Nil, Nil)
pub const calls: List(service.Service) = []
pub const after_send: live.After = live.ReloadPage

component.on_attribute_change("tags", fn(value) {
  let tags =
    value
    |> string.split(",")
    |> list.filter(fn(tag) { tag != "" })

  Ok(live.Given(tags))
})
```

`view` は `given` を `select` の `option` にし、`event.on_change` で
`live.Set(Nil, value)`、ボタンで `live.Send` を送る。属性の decoder は JSON を
使わず `,` 区切りに固定した。書きの成功時だけ `lustre/event.emit(
"yumemi-done", json.null())` を返す。

## P5b (`musearch-console-1b`) への申し送り

- 上の `pick_tag` が実物。`given` は `State` の読み欄で受け、
  `pub const after_send: live.After = live.Stay` または `live.ReloadPage` を島に置き、
  `app()` の `component.on_attribute_change("tags", callback)` で属性を decode して
  `Ok(live.Given(...))` にする。
- `muses/` の依存は `>= 0.7.0 and < 0.8.0` にする。
- `www/gleam.toml` に残る `yumemi` の `< 0.7.0` 制約も 1 行上げる。本便の fixture は
  path dependency なので、`gleam_json >= 3.1.0 and < 4.0.0` だけを直接追加した。

## Y2 (`gen-6`) への申し送り

生成器が吐く `src/gen/live/<service>.gleam` は、次の形を雛形にする。

- `Field` enum と `live.Event(Field, Given, Out, Error)` を作る。
- `live.State(Args, Given, Out, Error)` の `Given` は、属性 decoder から runtime の
  `live.Given(given)` へ配線し、`update` では `given` 欄を差し替える。
- 読み直し用の `reloads` は 1 本だけ置き、その戻りも `given` に入れる。
- 書きの成功後は `after_send` の `Stay` / `ReloadPage` を見て分岐する。

本便の手書き `pick_tag.update` がそのまま雛形である。島が候補を組み立てたり、
別の島・Block を名指ししたりしない。

## 鷹野さんへの申し送り

51 v5 の改訂箇所は次の 3 点。

- §243 の `reloads` の文: 戻りは別欄ではなく `given` に置く。
- §236 の `State` の図: `args` / `given` / `last` / `waiting` の 4 欄にする。
- 「外から起きる合図」の禁則: runtime が作る `Given` と、書きの後を宣言する
  `after_send` (`Stay` / `ReloadPage`) が食い違わないか確認する。

## 数字と検証

- root `gleam.toml`: version **0.7.0**。root の依存 package は **10** のまま。
- `gleam build`: **exit 0**。`build/front-1d-root-build.txt`。
- `cd gen && gleam test`: **86 passed, no failures**。
- `cd gen/fixtures/article/www && gleam build`: **exit 0**。
- `gleam run -m yumemi_gen -- fixtures/article _out/front-1d-a`: **exit 0、57 ファイル**。
  入力 `source.load` の対象 units は **11** (`gen/fixtures/article/src/**/*.gleam`)。
- `git diff --stat 13ca007 -- gen/src`: **空**。
- `node gen/scripts/verify-front-ssr.mjs`: **NO-JS PASS / ISLAND PASS / RELOAD PASS /
  ALL PASS**。document request は同じ URL 2 回（初回 + 再要求 1 回）。
- `node gen/scripts/verify-front-isolate.mjs`: **ALL PASS**。40 requests、first 322、
  second 191、marker 混入 0。
- `git diff --stat 13ca007 -- src/framework/`: `src/framework/front/live.gleam` の
  **1 file**だけ。`front.gleam` / `css.gleam` / `el.gleam` / `sketch_css.gleam` は 0 行。
- `gen/fixtures/article/www/gleam.toml` の direct dependency は `gleam_json >= 3.1.0 and
  < 4.0.0` だけを追加した。root には追加していない。

証拠ログは `build/front-1d-root-build.txt`、`gen/build/front-1d-gen-test.txt`、
`gen/fixtures/article/www/build/front-1d-fixture-build.txt`、
`gen/build/front-1d-generate.txt`、`gen/build/front-1d-ssr.txt`、
`gen/build/front-1d-isolate.txt` にある。

柏木ゲート 2 の P0 修正後の実測では、SSR は `SSR INITIAL: PASS (posted "fixture")` と
`SSR SELECTED: PASS (posted "gleam")` を含めて `ALL PASS`、isolate も `ALL PASS`。
root / fixture build と 57 files 生成(入力 units 11)も成功し、`gleam test` は
**89 passed, no failures**。`gen/src` の差分は束 B(生成器の列名推論)の
`reader.gleam` / `emit/verb.gleam` の 2 file で、これは本便の 2 束目そのものであり想定内。

## DDL

本便は無し。migration / schema / 索引は書いていない。staging / production にも
適用していない。
