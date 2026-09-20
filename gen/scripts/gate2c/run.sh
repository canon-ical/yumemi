#!/usr/bin/env bash
# 柏木ゲート 2(3 回目)の再現 4 本を、gen-3b の生成物と harness で**そのままの経路**で走らせる。
#
#   PGHOST=127.0.0.1 PGPORT=55432 PGUSER=yumemism \
#   gen/scripts/gate2c/run.sh <musearch-out> <article-out> <flag-out> <relation-out> <work-dir>
#
# 前提:<work-dir>/musearch-harness は verify-root-ffi.mjs が作る(同じ引数で先に走らせる)。
# DB は gate2c_kashiwagi_3947(無ければ作る)。終了コードは 4 本の和 ── 再現スクリプトは「再現したら 0」なので、
# reorder-negative / root-real は **非 0 で終わるのが閉じた印**。
set -uo pipefail
musearch_out=${1:?musearch out}; article_out=${2:?article out}; flag_out=${3:?flag out}; relation_out=${4:?relation out}; work=${5:?work dir}
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
export PGHOST=${PGHOST:-127.0.0.1} PGPORT=${PGPORT:-55432} PGUSER=${PGUSER:-yumemism}
export PGDATABASE=${PGDATABASE:-gate2c_kashiwagi_3947}
psql -X -At -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -c "SELECT 1 FROM pg_database WHERE datname='$PGDATABASE'" | grep -q 1 \
  || psql -X -At -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -c "CREATE DATABASE $PGDATABASE" >/dev/null

# draft harness(柏木の draft-harness と同じ構成:flag fixture の types + 生成 verb / draft / types + probe)
draft="$work/draft-harness"
rm -rf "$draft"; mkdir -p "$draft/src/gen"
cat > "$draft/gleam.toml" <<TOML
name = "gate_draft"
version = "0.1.0"
target = "javascript"
[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
yumemi = { path = "$repo" }
TOML
cp "$repo/gen/fixtures/flag/src/types.gleam" "$draft/src/types.gleam"
cp -r "$flag_out/src/gen/types" "$flag_out/src/gen/draft" "$draft/src/gen/"
cp "$flag_out/src/gen/verb.gleam" "$draft/src/gen/verb.gleam"
echo 'export const stage=(context,name,input)=>context.stage(name,input);' > "$draft/src/operations_ffi.mjs"
printf 'import gen/draft/chunk\nimport gen/verb\npub fn operation() { verb.create_chunk(chunk.ChunkDraft(a: 11, b: 7, c: 1, text: "typed-composite-key")) }\n' > "$draft/src/probe.gleam"
(cd "$draft" && gleam build --target javascript >/dev/null 2>&1) || { echo "draft harness build failed"; exit 9; }

export ARTICLE_OUT="$article_out" FLAG_OUT="$flag_out" ROOT_HARNESS="$work/musearch-harness" DRAFT_HARNESS="$draft"
status=0
for script in reorder-negative root-real reorder-concurrent draft-typed; do
  echo "== $script.mjs"
  node "$here/$script.mjs" 2>&1 | tail -6
  code=${PIPESTATUS[0]}
  echo "exit=$code"
  status=$((status + code))
done
exit $status
