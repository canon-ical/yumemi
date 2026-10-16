# BRIEF block-door ── 断片の口と yumemi.block を Live でない Block にも開ける(0.14.1)

便: block-door
基点: main `ec85d34`(release 0.14.0)。branch `impl/block-door`
起案: 鷹野[PDM]、2026-10-17
親: 役員 人見 2026-10-17「Live でない Block にも断片の口と yumemi.block を開ける。版は鷹野が決めてよい」→ 版は 0.14.1(足すだけで 0.14.0 の約束を壊さない)。裁定の記録は tech `~/canonical/tech/_drafts/gleam-framework/87-realtime/01-design.v0.md` の「断片の口は Live でない Block にも開ける」。きっかけは musearch `~/yumemism_repo/musearch-m-day-swipe/docs/m-day-swipe/results.md`(出勤の板の読み `schedule_day` は root の Entity が無く `Live` に置けない → `yumemi.block` が使えない)

**真壁さんへ(Opus)。**止め線は経過 2 時間。細かい設計は任せる。commit は `git-as 真壁`、push・tag・Hex は触らない(鷹野が出す)。終わったら柏木のゲート 2 を 1 回。

親ゴール: 逃げ道が、`Live` かどうかに関係なく、別の URL の Block を HTML と CSS ごと取って差し込める。musearch の day_swipe の取りと CSS の約 90 行を yumemi に移せる。
- 障害: 頁に出ていない読みが断片の口から漏れる(門と読みは頁と同じでなければならない)
- 障害: `Live` の約束(札・socket・合図での取り直し)が崩れる

## 現在地

- 0.14.0 の README「Live」の節:断片の口は `x-yumemi-block: <name>` の GET に、その頁の `Live` の Block だけ答える(他の名は 404)。`yumemi.block(name, { href })` は `Live` を持つ面の `mount(element, yumemi)` の 2 つ目にだけ渡り、`Live` の無い面には空の object
- 返る要素は `<yumemi-live name edge token>`(`display: contents`)。置いた要素は合図と `visibilitychange` で自分の `href` から読み直す(live-2 r2)

## どこまで

1. 断片の口:頁の `Fixed` の Block にも答える。門・宣言・同意・session の扱いと、叩く読み(その Block の読み + optional でない頁と Layout の読み)は `Live` と同じ。`Widget` と Layout の Block は今までどおり 404 でよい(要るなら理由を書いて広げてよい)
2. `Live` でない Block の断片は、札を持たず socket を張らない要素で返す(名前は任せる。例 `<yumemi-block name href>`、`display: contents`)。合図が無いので自分では読み直さない。`yumemi.block(name, { href })` を同じ URL で呼べば取り直して当てる
3. `yumemi.block` を `Live` の無い面にも渡す(全部の面の `mount` の 2 つ目)。`Live` の Block への振る舞いは 0.14.0 と同じ
4. CSS の規則を足す道(頁を移った後に作り直す表)は `Live` と同じ道を通す
5. test:`Fixed` の Block の断片(200・門の 302・404・名の無い Block)、`Live` の無い面での `yumemi.block` で別の URL の Block を取って `replaceWith`、CSS が足されること、頁を移った後。0.14.0 の `Live` の test が全部そのまま通ること。生成器の test
6. README の該当の節、CHANGELOG、`gleam.toml` を 0.14.1、fixture の lock を追随(rule 41)

## しないこと

`Live` の宣言・札・合図の形を替えること。0.15 の Dleam 専用のドライバ(`driver.mjs`)。musearch の day_swipe 自体(後の M2 の便)。

## 失敗例

- 断片の口が、頁に置かれていない Block の名でも読みを叩いて返す(漏れ)
- `Live` の無い面に `yumemi.block` を渡すため、`Live` の runtime を全部の面に読み込ませて重くする(要る分だけ)
- yumemi の作業木の test で `gen/fixtures/*/{admin,public}/node_modules` の古い symlink が EEXIST で落ちる。消してから `npm ci`

## 返すもの

`briefs/results-block-door.md`(1〜6 の充足、返す要素の形、test の表、確かめていないこと)。
