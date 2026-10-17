# results yumemi-0144 ── `PaddingLeft`(0.14.4)

1. `SpaceProperty` に `PaddingLeft`(doc 1 行、`Length` を取る)。`src/yumemi/front/css.gleam`
2. `sketch_css.gleam` の `space` に `css.PaddingLeft -> sketch_css.padding_left_(..)`。gen/ は `SpaceProperty` を名指ししておらず変更なし
3. `test/yumemi_0144_test.gleam` 2 本:`PaddingLeft` 単独で `padding-left: 8` を出し `padding:` を出さない/`Border(LeftEdge, ..)` と並べて両方出る(`border-left: 4.0px solid #123456;` と `padding-left: 8`)
4. `gleam.toml` を 0.14.4。fixture 4 面(article/cms × admin/public)で `gleam update yumemi`(v0.14.3 -> v0.14.4、manifest.toml のみ変更)
5. `CHANGELOG.md` に `## 0.14.4 (2026-10-17)`。事業名・人名なし。`git grep -i "musearch\|人見" -- README.md CHANGELOG.md src` は 2 行 ヒット ── どちらも `src/yumemi/entry.gleam:3-4` の既存コメント(今回の変更外、触っていない)。README・CHANGELOG は 0
6. root の `gleam test`:`535 passed, no failures`(出力 build/test.txt)

注: 最初の実行は `525 passed, 10 failures` ── worktree に node_modules が無く esbuild が無かったため。`npm ci` 後に再実行して上記。node_modules は git status に出ない。

確かめたこと: 上記 test。出力は `padding-left: 8`(単位表記は `8px` でなく sketch の出力に従う `8.0px` 等の可能性があり、test は前方一致で見ている)。
確かめていないこと: entry.gleam の既存コメントの 人見 を消すべきか(鷹野判断。Hex に載る src なので要判断)。fixture 面の個別 build。
