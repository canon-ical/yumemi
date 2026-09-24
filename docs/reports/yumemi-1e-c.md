# yumemi-1e C ── File 入力を生成 live Service に接続

## 実装

- File 選択は生成 live module の `<field>_file_input()` が受け、`Set(field, String)` へ runtime 発行札を渡す。札は `~yumemi-file:<UUID>` とし、runtime の `selectedFiles` / `uploadedFiles` 表への完全一致でだけ判定する。Blob 以外の Args は上げない。
- `Send` は Blob 欄ごとに札を `/api/blobs` へ送り、返った `key` に差し替えてから Service を呼ぶ。既存 key は表に無いのでそのまま通す。`Option(Blob)` の空値は JSON `null`、既存 key は文字列で送る。上げ失敗時は既存 `Failed` 枝で `Done(Error(Failed))` を返し、Service fetch へ進まない。
- Entry 用 `blob_copy` live module は `gen/api.gleam` の `Attached` / `attached` から method/path を引き、上げた key を島内に表示する。`live.Event` / `Set` / `src/framework/front/live.gleam` は変更していない。
- fixture に `article_blob_save` Service (`Blob`, `Option(Blob)` Args) と `/api/blobs` Attached route を足した。Entity/schema は不変。`verify-front-file.mjs` は `/api/blobs` と Service を固定応答する。
- fixture face manifest に使う Gleam/Lustre packages を直接宣言し、static-doc fixture で heading/list renderer も使う。これにより face build の未使用 helper / transitive-import warning を残さない。

## musearch の ★ 対応表

| 元 file | 画面 (Block) | 新しい Service / Entry | 消える島またぎ |
|---|---|---|---|
| `muses/src/components/blob_copy.gleam` (+旧 FFI) | `/settings`, `Settings` | `muse_edit_profile` Service を持つ単一 `blob-copy` 島 | FFI の `document.getElementById` による `icon` 属性書き込みと `yumemi-blob-done` emit。旧 `muse_edit_profile` 島は統合 |
| `muses/src/components/article_blob_copy.gleam` (+旧 FFI) | `/articles/new`, `/articles/:id`, `ArticleForm` | `Target.Entry(api.BlobCopy)` | FFI の File 保持・POST を生成 live runtime に統合。key 表示は同じ島 |
| `console/src/blob_copy.gleam` (+ `blob_copy_ffi.mjs`) → `console/src/components/blob_copy.gleam` | `/rosters/:id`, `RosterEditor` | `roster_photo_put` Service | `document` 引きと FFI の POST→PUT 連投を除去。Service の Blob 欄へ統合 |

## 検証

- 起点の `cd gen && gleam test`: **164 passed**。変更後: **167 passed, no failures** (`gen/build/y1e-c-generator-test-final-3.txt`)。
- fixture 生成: **92 files**, exit 0。別 output への2回生成 `diff -r`: **0 lines**。生成 `db/`: **32 files**, `out-fx-base/db` との差 **0 lines**。
- 生成 `public/src/gen` の `gleam format --check`: exit 0。fixture face の `gleam build --target javascript`: exit 0、warning **0**。root `gleam build`: exit 0、warning 1 (`src/framework/secret.gleam:5`, unused private constructor)。framework は未変更。
- `verify-front-file.mjs`, `verify-front-ssr.mjs`, `verify-front-isolate.mjs`, `verify-front-given.mjs`, `build-blocks.mjs`: **ALL PASS**。

`verify-front-file.mjs` が記録した request 列:

```json
[{"method":"POST","path":"/api/articles/article/blob_save","body":{"slug":"article","blob":"stored-image-key","existing":"stored-optional-key"}},{"method":"POST","path":"/api/blobs","contentType":"image/png"},{"method":"POST","path":"/api/articles/article/blob_save","body":{"slug":"article","blob":"uploaded-image-key","existing":"stored-optional-key"}},{"method":"POST","path":"/api/blobs","contentType":"image/fail"},{"method":"POST","path":"/api/blobs","contentType":"image/png"}]
```

この順で既存 key の Service 直送、新規 File の `/api/blobs` → Service、失敗時の `/api/blobs` のみ、Entry 島の `/api/blobs` のみを確認した。Entry 島は返った `uploaded-image-key` を表示。

## DDL

無し。Blob は Service Args のみ。fixture Entity / migration / schema は変更せず、生成 `db/` は基線と一致。

## F5 写し

固定 snapshot `a109b47` から `ms-probe-f5-c` を作成し、各 face の `src/gen` / `build` を除去、face manifest の `yumemi` を本作業木へ向けて生成・build した。起点 `4c8a655` の写しと比較し、build error は www **57→57**、muses **38→38**、console **43→43**。error を持つ file 集合も各 face で同一。3つの新しい sample file と、本便が加えた `muses/src/gen/live/{blob_copy,muse_edit_profile}.gleam` / `console/src/gen/live/roster_photo_put.gleam` / `gen/api.gleam` は error **0**。F5 全体の build は両側とも既存 error で exit 1。全 stdout/stderr と generator logs は `/home/yumemism/.codex-agents/runs/niekawa-20260924-135307-601740-3464/evidence/probe-c-*`。

実 musearch には書いていない。確認時の `git status --short` は開始時・終了時とも 0 行だった。HEAD は開始時 `3fdf5470c1aa8380cc074e23b872dcafc39fc8d9`、終了時 `cebb88bfee64a9a12ddad8fc016d2dcc09ff632f` で、作業中に進んだため固定 snapshot `a109b47` を使い続けた。DDL/schema は無し。実サーバーの認証・Blob 保存は試さず、Playwright は指示どおり固定 route 応答で検証した。
