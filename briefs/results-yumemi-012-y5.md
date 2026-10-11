# results ── yumemi-012-y5(0.12 段 B、門と業務付き CMS の機能、真壁 r1、Opus 直書き)

基点 `31db577`(BRIEF の commit、段 A の merge 後の main `087b2d8` の上)。branch `impl/012-y5`。証跡は `build/012-y5-*`(git の外)。経過は 04:20 起動 → 04:58 で squash(止め線 2 時間 30 分の内)。

## やったこと

- **申告 `Declared(kind)`**(第 32・33 条):門の検査 `Declared(kind, fail)`・条件 `WhenDeclared(kind)`・要件 `require.Declared(kind)`・役 `Declare(attached, kind)` / `NeedsDeclared(attached, kind)` の 4 か所。`BrowserCookie(cookie, key_binding, max_age_days, declarations: List(Declaration(kind, claim, max_age_days)))`。runtime(`server/http.mjs`)の `verifyBrowser` は署名と印(`id`)を見て `{id, claims, declared}` を返し、申告は種類ごとに claim の時刻が `max_age_days` の内かで読む(cookie が有効でも古い申告は「申告なし」)。`Declare` は他の種類の欄を残して同じ印に足し、`framework/browser` を `[id, at, kind]` で呼ぶ。失敗は 403 `{"code":"declaration_missing","declaration":"<kind>"}`。session の読みは `declared: {<kind>: true}`
- **同意 `Consented(kind)` / `ConsentedFor(kind, subject:)`**(第 40 条):門の `Consent` は `Consented` に改名。session の読みは party の同意を全部 `consents: {<kind>: true}`。失敗は 403 `{"code":"consent_missing","consent":"<kind>"}`。`identity` の名の分岐は消えた(対象の突き合わせは `ConsentedFor` の形)。`src/server.gleam` の `pub const consents: List(String)` を生成器が読み、要件と門の綴りを止める
- **数える口 `Pageview(pages, only, fields, sink)`**(第 34・35 条):欄は閉じた語彙(`NavKind`・`ClientAt`・`Path`・`Previous`・`Referrer`・`FromQuery(name, param, Slug(max))`、正規表現の文字列を受けない)、id は framework が常に足す、鎖の鍵は `yumemi:pageview:<面>`、30 分と 60 件/分は決め打ち。**門は頁の読み込みでも client の遷移の fetch でも `<meta name="yumemi-pageview">` だけを差す**(inline の script・`vary`・`x-yumemi-navigate` の分岐は門から消えた)。**送り手は新しい `src/yumemi/front/pageview.mjs` 1 つ**(`requestIdleCallback` の後、prerender は `prerenderingchange` を待つ、bfcache は数えない、`navigatesuccess` で今の document の印を見る、fragment だけの遷移は数えない、kind は `initial` / `reload` / `spa`)。`pageview` を宣言した面は島が無くても client.mjs を出す。navigate.mjs には触っていない(`startNavigation` に pageview の設定を渡さなくなっただけ)
- **器 `Store(resolve, rollup_by, exclude_when)`**(第 37 条):受け口は入口の `<prefix>/_yumemi/pageviews`、応答は常に 202(どの段で落ちても)。bot と監視(`cf.verifiedBotCategory`・UA)・先読み(`Sec-Purpose` / `Purpose`)・形の外れた event は行を作らない。再送・連打・2 tab は SQL 関数 `framework.pageview_record` が印の行ロックの下で持つ。集計は `framework.pageview_rollup`(前日と当日の UTC の日、その月を畳み直す)。DDL は生成器が `db/framework/pageview.sql` に ▲ として吐き、SQL の既定 `framework/pageview_record`・`framework/pageview_rollup` を `sql.mjs` に足す(app に ★ があれば勝つ)。集計の仕事は生成の `shell.mjs` の `scheduled` に `0 1 * * *` で足す(`yumemi/server/cron.mjs` の `rollupPageviews`)
- **`ToService(service)`**(第 36 条):受け口の検査を通した event を Service に渡す(Args は event の欄から `decodeArgs`、印は `s.browser` で既存の `Carried(.., "browser", ..)` が root に運ぶ)。Args の欄は event の欄の名に限り、載らないことがある欄は `Option`。使った面ごとに exit 0 の警告 1 行(`_diagnostics.txt` にも出る)
- **ユニークの印**(第 37 条の 3):数える条件を満たした最初の event で、有効な cookie の無い browser に印だけの cookie(payload `{id}`)を焼く。後の `Declare` は同じ印に欄を足す。`Store` で `browser` が無ければ exit 3、`ToService` の Service が `Carried(.., "browser", ..)` を持つのに `browser` が無ければ exit 3
- **CSP**(第 38 条):門の `csp: List(Csp(pages, directives))`、指令は `FrameSrc` / `ImgSrc` / `ConnectSrc` / `MediaSrc`。同じ Page に当たる宣言は宣言順に足し、同じ指令の host は 1 つにまとめる。入口 `Http` / `HttpApi` の `frame_src` と門の `frame_src` は消えた。client の遷移の表(`navigation` の CSP の行)は route ごとの同じ字
- **media の variant**(第 39 条):`server.Media(path, variants: List(ImageVariant(name, width, height, fit)), theme_background)` を読み、面ごとに `src/gen/media.gleam`(`Variant`・`name`・`theme_background`・`url`)。生成は新しい module `gen/emit/media.gleam`、`emit/front.gleam` の `emit` には呼び出しと append の 2 行
- **失敗の文言**:門と生成の shell が自分で返す本文は `forbidden`(403)と `not found`(404)だけ。門の session の読みの失敗は 404 → `not found`、他は 403 `forbidden`(0.11 は読みの status のまま `session read failed`)
- **検査の module** `gen/reader/cms.gleam`(第 32・33・36・37・39・40 条)、門の側(第 34・35・38 条)は `gen/reader/gate.gleam`。`gen.gleam` は面の門の `pageview` を `app.server.counted` に入れてから back を生成する(`http_runtime.mjs` の `pageviews` と DDL と cron の材料)
- **fixture** `gen/fixtures/cms`(article の写しに、申告 2 種・同意 3 種・`Declare` / `NeedsDeclared`・CSP 4 指令・`Store`(resolve `page_resolve`、rollup `section`、exclude `own`)・media を宣言)。`gen/fixtures/article` は生成し直しただけ
- **README**:「The gate and the CMS features (0.12)」の節を足し、`yumemi/server` の節の SQL の表(`framework/browser` の穴に kind、`framework/pageview_*`)・cron・0.11.4 の pageview の行(0.12 で置き換わる注)を直した

## 検収

- **root `gleam test`**:before `Framework checks passed: 25 groups` + `345 passed, no failures`(`build/012-y5-before-test.txt`)→ after `25 groups` + `364 passed, no failures`(`build/012-y5-after-test.txt`)。+19 は新しい `test/yumemi_012_y5_test.gleam`。`gleam format --check src test` 0
- **期待値を書き換えた test**(どれも 0.12 の型の替えに合わせた)

| test | 理由 |
|---|---|
| `gate_test` の `www_gate`・`entry_source`(const)| `Adult` → `Declared("adult")`、`WhenAdult` → `WhenDeclared`、`frame_src` → `csp`、`Pageview` の新しい形、入口の `frame_src` を消す |
| `gate_test.gate_declaration_reads_prefix_rules_and_redirects_test` | `frame_hosts` → `csp`、`Redirect.when_adult` → `when` |
| `gate_test.anonymous_face_without_declaration_has_no_gate_test` | `frame_hosts` → `csp` |
| `gate_test.gate_mjs_carries_rules_csp_and_expanded_pageview_routes_test` | `frameSrc` → `cspRoutes`、pageview の script の期待 → `pageviewOnly` と「`<script` も `keepalive` も無い」 |
| `gate_test.empty_gate_mjs_does_not_read_session_test` | `pageviewScript = null`・`frameSrc = null` → `pageviewRoutes = []`・`cspRoutes = {}` |
| `gate_test.gate_marks_navigation_fetch_instead_of_script_test` と ffi | 頁の読み込みも script でなく印。`vary` の検査を消し 5 → 4 行。session の模擬を `declared` に |
| `yumemi_s1_test` の `back_gate`・入口の source と `redirect_back_and_fixed_keep_are_read_test`、ffi の session の模擬 | `Adult` → `Declared`、`frame_src` を消す、`adult: true` → `declared: {adult: true}` |
| `yumemi_fix_0114_test` の `counting_gate`・`navigation_keeps_counted_pages_and_passes_pageview_test` | pageview の行を消した(`startNavigation` に pageview を渡さない)。Y4 も同じ関数を直す |
| `yumemi_fix_0114_test.navigation_carries_csp_pages_test` | CSP を入口の `frame_src` でなく門の `csp` で宣言 |
| `yumemi_gen_wgy_test` の 3 本(`attached_roles_and_browser_cookie_follow_the_declaration_test`・`attached_roles_without_their_attached_are_exit_four_test`・`subject_free_follows_the_declaration_test`)| `DeclareBrowser` / `NeedsBrowser` / `claim` → `Declare` / `NeedsDeclared` / `declarations`、`browser` の無い申告の名指しは `reader/cms`、export の列に `pageviews`。**BRIEF の持ち場の test の列に無い file**(門と browser の宣言を見る test なので直した) |

- **fixture の生成**:`gen/fixtures/cms` と `gen/fixtures/article` をその場で生成して停止コード 0(cms は診断 0 行で `_diagnostics.txt` 無し)、2 回目の差 0(`build/012-y5-gen-*-{1,2,final}.txt`)
- **第 32〜40 条**(`test/yumemi_012_y5_test.gleam`、cms の写しを 1 か所ずつ壊して `generate`):32 = 門の `WhenDeclared("teen")`・要件の `Declared("aldut")`・役の kind・`browser` の無い申告で exit 4、33 = kind / claim の重なり・`Region`・`401 > 400` で 4、34 = `pageview` の `Exact("/nope")` で 4、35 = `Path` 2 つ・`FromQuery` の名が `path`・`r-x`・`Slug(max: 65)`・pattern に文字列で 4、36 = `ToService("ghost")`・Args に `slug` で 4、通れば 0 の警告 1 行、`Option` でない `source_key` で 4、37 = resolve `ghost`・rollup `shop`・exclude が Bool でない で 4、`browser` 無しで 3、38 = `Exact("/gone")`・`https://img.example/x` で 4、39 = 名の重なり・`w2400`・`W800` で 4、40 = 要件の `terms`・門の `tos`・0.11 の `Use` で 4
- **runtime(node)**(`build/012-y5-runtime-sender.txt`、test と同じ ffi)20 項:`declaration_missing` / `consent_missing` の本文、宣言した同意 `handling` が通る、`ConsentedFor` の対象の一致と不一致、`Declare` 2 種(同じ印に足す)、session の読み(申告 2 種・同意 3 種、`adult` の欄が無い)、匿名の session、期間の切れた申告は「申告なし」、0.11 の payload を申告として読む、`NeedsDeclared`、受け口(宣言した欄だけ・条件の外は行も印も無い・bot / 先読み / 形の外れ)、印だけの cookie(属性)と後の申告が同じ印、`ToService` が Args を組んで Service を呼び印を運ぶ、bot と申告の無い event は呼ばない
- **門(fixture cms の生成 `gate.mjs`)** 7 項:宣言した同意で通り CSP 2 指令と印、同意が無ければ sign-in、申告が無ければ `RedirectBack`、`/status` の CSP、`WhenDeclared("region")` の redirect、読みの 404 は `not found`、他は 403 `forbidden`
- **器(使い捨ての PG 16、port 55581)**(`build/012-y5-store.txt`、script は `build/012-y5-store.mjs`):生成した DDL を当て(`build/012-y5-ddl-apply.txt`、表 4・索引 3・関数 3)、runtime の受け口から送った。常に 202、bot の UA・`cf.verifiedBotCategory`・`Sec-Purpose: prefetch` は行 0、同じ id の再送は 1 行、1 分に 61 件で 60 行、2 本の同時(`Promise.all`、pool 8)で訪問 1、`exclude_when` の真は行があり集計に無い、申告の無い browser は印も行も無い。集計(2 回回して同じ):10-10 の site `[pv 4, uniques 2, visits 3, 回遊 1]`・path `/article/a` `[3,2,3,1]`・section `article` `[4,2,3,1]`、10-11 の site `[2,1,1,1]`、10 月の site `[66,4,5,3]`。PG は止めて data を消した
- **送り手(Chromium、playwright の chromium-1243)**(`build/012-y5-chromium.txt`、script は `build/012-y5-sender.mjs`):fixture cms の生成 `gate.mjs` と束ねた `client.mjs` を node の server で配り、頁の読み込みで 1 回(`initial`、`source_key` は `r` から、`x` の query は載らない、id は UUID)、HTML に印があり inline の script 0、reload で 1 回(`reload`、`prev` が前の id)、fragment だけの遷移は 0 回、Navigation API の intercept で移った `navigatesuccess` で 1 回(`spa`)、page error 0。client の遷移(Y4)の後の 1 回は Y4 の merge の後に鷹野が見る(81 の約束)
- **失敗の文言**:fixture の生成物(`src/gen`・`priv`)と `src/` を grep して `adult declaration`・`muse not found`・`page not found`・`session read failed`・`adult_declaration` 0 file。生成物の 403 / 404 の本文は `forbidden` 16・`not found` 12 だけ。`adult` の綴りは生成物では app の値(`kind: "adult"`・`adult_declared_at`)だけ
- **`adult` の綴り**:`src/**/*.{gleam,mjs}` と README に 0(test `adult_is_gone_from_framework_test`)。**例外 2 つ ── Y4 の持ち場**:`src/yumemi/front/navigate.mjs` の注釈 2 行(19・243)と README「Client navigation」の節の 84 行。Y4 が書き換える前提で検査から外した(merge の後に鷹野が grep で見る)
- **musearch の写し**(origin/main `1b0244412` の `git archive` を `.scratch/musearch`、node_modules は手元の写し、5 package を本作業木への path 依存、検収の後に捨てた)
  - Y1 の置き換え(`import framework/<module>` ほか)に加え、宣言の書き換え:★ 164 file と test の Gleam 2 file(計 166、`build/012-y5-ms-star.diff`、Y1 の置き換えを当てた基点との差)── `api/src/service/*.gleam` 155(`[Adult]` 29 → `[Declared("adult")]`、`[Use]` 107・`[Use, Handling]` 18・`Identity(from:)` 1 → `Consented` / `ConsentedFor("identity", subject: source)`、import の行)、`www/src/gate.gleam`(`Adult` 3・`WhenAdult` 2・`frame_src` → `csp`・`pageview` → `ToService("pageview_record")`)、`console/src/gate.gleam`(`Consent` → `Consented`)、`muses`・`admin` の `gate.gleam`(`frame_src: []` → `csp: []`)、`api/src/entry.gleam`(`frame_src` 5 行を消す)、`api/src/server.gleam`(`Declare`・`NeedsDeclared` 2・`BrowserCookie` の `declarations`・`consents`・`media`・`gleam/option` の import)、`api/db/queries/framework/browser.sql`(`$3` の kind、`adult` のときだけ書く)、`api/src/media_runtime.mjs:333`(`state.browser?.declared?.adult`、`declaration_missing`)、`muses/src/worker_entry.mjs:175`(`session?.declared?.adult`)、test の Gleam 2 file(`api/test/fixtures/entry_extra.gleam`・`api/compile_fail/cases/subject_type.gleam`、同じ宣言の書き換え)。`pageview_record` の Args と `Carried` は書き換え不要だった
  - api の package から全面を生成:停止コード 0、4 面とも `client Out decoder build PASS; runtime build and esbuild PASS`、書いた 2073 file、警告に `www: 逃げ道 ToService を 1 つ使っている(数える口 → service.pageview_record。…)`。2 回目 停止コード 0・差 0(`build/012-y5-ms-gen{1,2}.txt`)
  - 4 面 `npm run build`:4 面とも exit 0(muses・console・admin は 1 回目が Hex の rate limit で exit 1、間を置いて回し直した。`build/012-y5-ms-build-*.txt`)
  - 4 面 `npm test`:console 89/89、admin 21/21、muses 473/475、www は書き換えのままで 221/428 → test の模擬の session の形だけを機械的に替えて(`adult: true` → `declared: {adult: true}`、43 file 117 行、test の file だけ)421/428(`build/012-y5-ms-test-*.txt`)。落ちた 9 本の理由:門の inline の pageview の script の字(`musearch:last-pageview`)を読む 1、`island-harness.mjs` が `gate.mjs` の旧い定数 `frameSrc` を正規表現で読む 2(www・muses)、模擬の session の省略形 `{anonymous: true, adult}` が置き換えに掛からない 4(www の S-4c 3・muses の onboard 1)、`start({routes, boot, csp, ..})` の後ろの `,`(pageview の欄)を前提にした正規表現 2。どれも 0.12 で消した形を読む test
  - api `npm test`(PG 16 を新しい port 55583、`api/test/postgres.sh`、auth は手を入れずに `gleam build`):1725 本中 1698 pass、27 fail(`build/012-y5-ms-test-api.txt`)。理由:符号の綴り `adult_declaration_missing` を期待 6(`2b-5` の順・`2d-5m`・`N6`・`HTTP-ERROR`・`N2`・`MEDIA` の本文の byte)、test の helper が 0.11 の形の `signBrowser(env, id, at)`(3 つ目が時刻の文字列)で `_mb` を焼き申告として読まれない 9(`2b-5` 2・`retire-fix r3`・`m012` 3・`st-hide`・`T2` 2)、media の test が `state.browser` を 0.11 の形(申告の欄の無い値)で渡す 6(`media variant` 5・`2d-1a`)、session / 申告の応答の形 `adult: true` を期待 2、★ の字の固定 3(`2d-5a` が `requires = [Use]` を正規表現で、`2d-5m` が `needs_browser` の役の字を、`source_contract` が ★ の hash を)、SQL の穴の数を固定 1(`SQL:framework/browser` が 2 つで呼ぶ)。PG は止めた
  - **配った形の `_mb`**(`build/012-y5-ms-mb.txt`、script は `build/012-y5-ms-mb.mjs`):0.11.15 の `signBrowser` の写しで payload `{id, adult_declared_at}` を焼き、写しの生成 `http_runtime.mjs` の `verifyBrowser`(0.12)で読んで、30 日前は `declared.adult === true`、396 日前は印が残り申告なし、署名を 1 字替えると null
  - auth は触っていない。写しは捨てた(`.scratch/` は空)

## DDL

生成器が吐く ▲ `db/framework/pageview.sql`(面の門のどれかが `Store` を宣言した app だけ。fixture cms の生成物と同じ字)。**本便は使い捨ての PG(port 55581)に当てただけで、staging・production には当てていない。**

```sql
-- GENERATED from yumemi(数える口の器 Store)— 手で編集しない
-- ▲ app の DB に当てるのは DDL の便。表は印・訪問・event・集計の 4 つ、関数は記録と集計の 3 つ。
CREATE SCHEMA IF NOT EXISTS framework;

-- 印(ユニークの単位):browser の署名 cookie の id(32 桁の hex)
CREATE TABLE IF NOT EXISTS framework.pageview_mark (
  id text PRIMARY KEY CHECK (id ~ '^[0-9a-f]{32}$'),
  first_at timestamptz NOT NULL,
  last_at timestamptz NOT NULL
);

-- 訪問:同じ印の event が 30 分以内に続く並び
CREATE TABLE IF NOT EXISTS framework.pageview_visit (
  id uuid PRIMARY KEY,
  mark text NOT NULL REFERENCES framework.pageview_mark (id),
  started_at timestamptz NOT NULL,
  last_at timestamptz NOT NULL,
  landing_path text NOT NULL,
  referrer_host text
);
CREATE INDEX IF NOT EXISTS pageview_visit_mark_last ON framework.pageview_visit (mark, last_at DESC);

-- event:受け口が受けた 1 回の表示。excluded は app の exclude_when が真の event(行は作り、数字から除く)
CREATE TABLE IF NOT EXISTS framework.pageview_event (
  id uuid PRIMARY KEY,
  mark text NOT NULL REFERENCES framework.pageview_mark (id),
  visit uuid NOT NULL REFERENCES framework.pageview_visit (id),
  face text NOT NULL,
  at timestamptz NOT NULL,
  client_at timestamptz,
  kind text NOT NULL CHECK (kind IN ('initial', 'reload', 'spa')),
  path text NOT NULL,
  prev uuid,
  referrer_path text,
  referrer_host text,
  party text,
  extra jsonb NOT NULL DEFAULT '{}'::jsonb,
  dims jsonb NOT NULL DEFAULT '{}'::jsonb,
  excluded boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS pageview_event_mark_at ON framework.pageview_event (mark, at);
CREATE INDEX IF NOT EXISTS pageview_event_at ON framework.pageview_event (at);

-- 集計:面 × 日・月 × 次元('site' は value ''、'path'、rollup_by の欄の名)。UTC の日の境
CREATE TABLE IF NOT EXISTS framework.pageview_rollup (
  face text NOT NULL,
  period text NOT NULL CHECK (period IN ('day', 'month')),
  starts date NOT NULL,
  dimension text NOT NULL,
  value text NOT NULL,
  pv bigint NOT NULL,
  uniques bigint NOT NULL,
  visits bigint NOT NULL,
  roaming_visits bigint NOT NULL,
  PRIMARY KEY (face, period, starts, dimension, value)
);

-- 1 event を記録する。印の行を upsert して行ロックを取り(同じ印の 2 tab の同時を直列に)、その下で
-- 同じ id の再送は何もしない('duplicate')、直前 1 分に 60 件あれば書かない('limited')、
-- 最新の訪問が 30 分以内なら続き、無ければ訪問を作る
CREATE OR REPLACE FUNCTION framework.pageview_record(
  p_id uuid, p_mark text, p_face text, p_at timestamptz, p_kind text, p_path text, p_prev uuid,
  p_referrer_path text, p_referrer_host text, p_client_at timestamptz, p_party text,
  p_extra jsonb, p_dims jsonb, p_excluded boolean
) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_visit uuid;
BEGIN
  INSERT INTO framework.pageview_mark (id, first_at, last_at) VALUES (p_mark, p_at, p_at)
  ON CONFLICT (id) DO UPDATE SET last_at = GREATEST(framework.pageview_mark.last_at, EXCLUDED.last_at);
  IF EXISTS (SELECT 1 FROM framework.pageview_event WHERE id = p_id) THEN
    RETURN 'duplicate';
  END IF;
  IF (SELECT count(*) FROM framework.pageview_event
      WHERE mark = p_mark AND at > p_at - interval '1 minute' AND at <= p_at) >= 60 THEN
    RETURN 'limited';
  END IF;
  SELECT id INTO v_visit FROM framework.pageview_visit
  WHERE mark = p_mark AND last_at >= p_at - interval '30 minutes' AND started_at <= p_at
  ORDER BY last_at DESC LIMIT 1;
  IF v_visit IS NULL THEN
    v_visit := gen_random_uuid();
    INSERT INTO framework.pageview_visit (id, mark, started_at, last_at, landing_path, referrer_host)
    VALUES (v_visit, p_mark, p_at, p_at, p_path, p_referrer_host);
  ELSE
    UPDATE framework.pageview_visit SET last_at = GREATEST(last_at, p_at) WHERE id = v_visit;
  END IF;
  INSERT INTO framework.pageview_event
    (id, mark, visit, face, at, client_at, kind, path, prev, referrer_path, referrer_host, party, extra, dims, excluded)
  VALUES
    (p_id, p_mark, v_visit, p_face, p_at, p_client_at, p_kind, p_path, p_prev, p_referrer_path, p_referrer_host,
     p_party, coalesce(p_extra, '{}'::jsonb), coalesce(p_dims, '{}'::jsonb), coalesce(p_excluded, false))
  ON CONFLICT (id) DO NOTHING;
  RETURN 'recorded';
END;
$$;

-- 1 つの期間 [p_from, p_to)(UTC の日)を畳み直す。PV・ユニーク(印の数)・訪問数・回遊訪問数(その面で
-- PV が 2 以上の訪問)を、site・path・rollup_by の欄(dims)の次元ごとに
CREATE OR REPLACE FUNCTION framework.pageview_rollup_period(p_period text, p_from date, p_to date)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM framework.pageview_rollup WHERE period = p_period AND starts = p_from;
  INSERT INTO framework.pageview_rollup (face, period, starts, dimension, value, pv, uniques, visits, roaming_visits)
  WITH e AS (
    SELECT face, mark, visit, path, dims FROM framework.pageview_event
    WHERE NOT excluded
      AND at >= (p_from::timestamp AT TIME ZONE 'UTC') AND at < (p_to::timestamp AT TIME ZONE 'UTC')
  ), totals AS (
    SELECT face, visit, count(*) AS views FROM e GROUP BY face, visit
  ), dimensioned AS (
    SELECT face, 'site'::text AS dimension, ''::text AS value, mark, visit FROM e
    UNION ALL SELECT face, 'path', path, mark, visit FROM e
    UNION ALL SELECT e.face, d.key, d.value, e.mark, e.visit FROM e, jsonb_each_text(e.dims) AS d
  )
  SELECT d.face, p_period, p_from, d.dimension, d.value,
    count(*), count(DISTINCT d.mark), count(DISTINCT d.visit),
    count(DISTINCT d.visit) FILTER (WHERE t.views >= 2)
  FROM dimensioned d JOIN totals t ON t.face = d.face AND t.visit = d.visit
  GROUP BY d.face, d.dimension, d.value;
END;
$$;

-- 集計の仕事(cron):p_at の前の日と当日(UTC)の日と、その月を畳み直す。何度回しても同じ値
CREATE OR REPLACE FUNCTION framework.pageview_rollup(p_at timestamptz)
RETURNS boolean LANGUAGE plpgsql AS $$
DECLARE
  v_day date;
BEGIN
  FOR v_day IN
    SELECT generate_series(((p_at AT TIME ZONE 'UTC') - interval '1 day')::date, (p_at AT TIME ZONE 'UTC')::date, interval '1 day')::date
  LOOP
    PERFORM framework.pageview_rollup_period('day', v_day, v_day + 1);
    PERFORM framework.pageview_rollup_period(
      'month', date_trunc('month', v_day)::date, (date_trunc('month', v_day) + interval '1 month')::date);
  END LOOP;
  RETURN true;
END;
$$;
```

- 変える表:`framework.pageview_mark`(印)・`framework.pageview_visit`(訪問)・`framework.pageview_event`(event、`excluded`・`dims`・`extra` は jsonb)・`framework.pageview_rollup`(面 × 日・月 × 次元の PV・ユニーク・訪問・回遊)。索引 3、関数 3(`pageview_record`・`pageview_rollup_period`・`pageview_rollup`)。どれも `IF NOT EXISTS` / `OR REPLACE`
- schema の全体像への追随:app の `framework` schema に表 4 と関数 3 が足される。既存の表には触らない
- **app の DB に当てる便への申し送り**:musearch は 0.12 では `ToService` に留まるので、この DDL は要らない(生成器も吐かない)。`Store` を宣言する app で初めて要る。`gen_random_uuid()` は PG 13 以上の組み込み。集計は UTC の日で、cron の式 `0 1 * * *` を wrangler の `triggers.crons` に足すのは app の側
- 別に、**`framework/browser` の SQL は穴が 3 つ**(`[id, at, kind]`)になった。app の `db/queries/framework/browser.sql` は 0.12 に上げる便で書き換える(musearch の写しで書いた形は上の「musearch の写し」)。表の形(app の `browser` の列)は app のまま

## 印の cookie

大橋[PJM]への材料(法の読みは鷹野が確かめる。実装は止めていない)。

- **焼く条件**:面の門が `pageview` を宣言し、その面の受け口 `<入口の prefix>/_yumemi/pageviews` に、**`only` の条件を全部満たす** event が届き(bot・監視・先読み・形の外れた event は除く)、その browser に有効な署名 cookie が無いとき。応答 202 の `Set-Cookie` で 1 回。利用者の操作(申告のボタン等)は要らない ── 頁を開くと client.mjs が自動で送るので、**`only` が空の面では、最初の閲覧で焼かれる**。`only: [WhenDeclared(kind)]` の面(musearch はこれ)では、申告(利用者の操作)の後にしか届かないので、印だけの cookie は生まれない
- **cookie の名と属性**:名は app の `browser.cookie`(musearch は `_mb`)。`Path=/; Domain=<env COOKIE_DOMAIN>; HttpOnly; Secure; SameSite=Lax; Max-Age=<browser.max_age_days × 86400>`。申告の cookie と同じ名・同じ属性(同じ 1 つの cookie)
- **payload**:`base64url(JSON {"id": "<32 桁の hex、crypto.getRandomValues の 16 byte>"}) + "." + base64url(HMAC-SHA256)`。鍵は app の `browser.key_binding` の Secret。申告すると同じ id に `"<claim>": "<申告の時刻 ISO>"` が足される。個人を指す値(IP・UA・party・session)は入れない
- **外へ送らない**:印の id は自分の origin の受け口(app の Worker)と自分の DB(`framework.pageview_mark` / `_event`、`Store` のとき)にだけ届く。第三者の origin・計測の外部サービスへは送らない。HttpOnly なので頁の JS からも読めない。client が送る本文(`kind`・`client_at`・`path`・`prev`・`referrer_*`・宣言した query の欄・event の id)にも印は載らない(印は cookie で届き、受け口が読む)
- **使い道**:ユニーク(期間の中の印の数)と訪問(同じ印の 30 分以内の並び)の数え。行の保存期間と purge は 1.0 の後(本便は持たない)
- (柏木 ゲート 2 で追記)**器 `Store` の event の行は、サインイン中の要求なら session の party を `framework.pageview_event.party` に記録する**(`server/http.mjs` の受け口が `s.resolved?.party` を渡す)。cookie の payload に party は入らないが、DB の上では印と party が結び付く。82 の「確認できなかったこと」の 2 つ目(器が party を記録するか)の答えで、82 の 2(容易照合性で個人情報になる)が `Store` を使うどのアプリにも当たる

## BRIEF との食い違い・判断したこと

- **`ToService` の入口の検査は 1・3・4 と欄・条件・印まで**。BRIEF と 51 v6 は「二重計数の 1〜5 を通した event」と書くが、2(再送の id)と 5(60 件/分)は DB の行が要り、`ToService` にも framework の表を要らせると musearch が DDL の便無しに 0.12 へ上がれない。`ToService` では 2・5・6 を Service の側(musearch は今の SQL のまま)とし、README にもそう書いた。器 `Store` は 1〜6 を全部持つ
- **印・party・主体を root に運ぶのは既存の `Carried(.., "browser", ..)` のまま**。framework が `ToService` の Service に自動で `Carried` を足す形にはしていない(root の生成に手を入れる量が大きい)。musearch は今の `Carried` 3 本で足りた
- **`only` が空の数える口は session を読まない**(`reads_session` は `only` を持つ pageview だけ)。0.11 は `pageview` があれば読んでいた
- **集計の日の境は UTC**、式 `0 1 * * *` は framework の決め打ち。51 v6 の「毎日 01:00 は musearch の今の値」は時刻帯を書いていない。app に選ばせるなら式と時刻帯の欄が要る(段 C 以降の問い)
- **`Store` の `resolve` の Service の Args は `path` 1 つに限った**(第 37 条の検査に足した)。51 v6 は「event の path を Args に受け」とだけ書く
- **門の session の読みの失敗**:0.11 は読みの status のまま `session read failed` を返していた。0.12 は 404 だけ `not found`、他は 403 `forbidden`(本文を 2 つに絞るため、5xx も 403 になる)
- **`shell_runtime_text` の文言は 3 行**(403 と 404 の 2 行に加え、route の外の `page not found` → `not found`)。BRIEF の「2 行」の外の 1 行を替えた
- **`emit` の file の列**は `media_files` の let と append の 2 か所(BRIEF は「1 行」)。client.mjs を出す条件は 3 つ目の主語(`pageview_client`)を足し、島のある面は `client_text(..) <> pageview_client` で後ろに足した(`client_text` の中は触っていない)
- **`signBrowser(env, id, claims)` の 3 つ目は claim の名 → 時刻の object** に替えた(0.11 は時刻の文字列)。musearch の ★ は `verifyBrowser` しか呼ばず、`signBrowser` を呼ぶのは test の helper だけ(api の 9 本が落ちる理由)
- **musearch の写しで test の file も書き換えた**:Gleam の test fixture 2 file(compile が通らないため、宣言の書き換えと同じ)。www の模擬の session の形(43 file)は書き換え前と後の両方の数を上に書いた

## 段 C・merge への申し送り

- 81 の取り合いの見込みのうち本便が触ったもの:`navigation`(CSP の行を `gate_emit.csp_routes` に、pageview の行を消した)、`shell_runtime_text` の 3 行、`emit` の client.mjs の条件と media、`emit/http.gleam`(`browser_cookie`・`roles`・`pageviews`・`pageview_js` ── `Color` の関数とは別)、生成器の入口(`gen.gleam` の `counted` を入れる `let app` と `cms.notes` の 1 行)
- `yumemi_fix_0114_test.navigation_keeps_counted_pages_and_passes_pageview_test` は期待を `startNavigation({ routes: [..], boot });` にした(Y4 の形に合わせて解く)
- Y4 の merge 後に、navigate.mjs の注釈と README の遷移の節に `adult` が残っていないか、client の遷移で beacon が 1 回か(81 の確かめること 1)
- (柏木 ゲート 2 で追記)送り手は `navigatesuccess` の時点で `navigation.transition` が null なら数えない形にした(Y4 の README・results の約束「送り手は transition が null でない時だけ数える」への追随)。直す前は、島の `history.replaceState` / `pushState`(頁は替わらない)で `spa` が 1 回ずつ余分に送られていた(Chromium で再現)。この形では、Y4 の前の navigate.mjs(fetch・差し替えの後に `pushState`、intercept しない)の click の遷移は数えない ── 81 の「間の main では client の遷移の pageview が送られない」と同じ
- 継ぎ目(鷹野の裁き 4 の 7 つ)のうち本便の側:`gen/media` の `src`(`el.Src`)と地の画像の URL は未着手、`ToService` の数えは警告 1 行のまま(段 C で 1 行へ統合)

## 確かめていないこと

- musearch の写しで、framework の受け口 `/api/_yumemi/pageviews` から `pageview_record` までを本物の api の Worker と DB で通すこと(runtime の test で偽の Service を呼ぶ形と、写しの全 test までは見た)
- 2 tab の同時が本当に重なったか(`Promise.all` で 2 本、訪問 1 を見た。PG の側で行ロックを待った記録は取っていない)
- client の遷移(Y4 の Navigation API)の後の 1 回(Y4 の merge の後に鷹野)
- Safari / Firefox(Navigation API の無い browser は頁の読み込みの道で数える前提。当てていない)
- 生成した `gen/media.gleam` の `url` の実際の文字列(fixture の面の build で compile が通ることだけを見た)
- staging・production の DB(当てていない)
- api の 27 本の理由のうち `signBrowser` の 9 本は、落ちた test の file が 0.11 の形で `signBrowser` を呼んでいること(`2b-5`・`m012-slots`・`st-hide`・`t2-today`)と本文 `declaration_missing` の 403 から読んだ。1 本ずつ直して通るかは見ていない
