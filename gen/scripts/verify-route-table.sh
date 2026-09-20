#!/usr/bin/env bash
set -eu

script_dir=$(cd "$(dirname "$0")" && pwd)
gen_dir=$(cd "$script_dir/.." && pwd)
work_dir=$(mktemp -d "$gen_dir/_out/verify-route-table.XXXXXX")
out_dir="$work_dir/article"
scratch_dir="$work_dir/scratch"

mkdir -p "$scratch_dir/src/gen/entry"

if ! (cd "$gen_dir" && gleam run -m yumemi_gen -- fixtures/article "$out_dir") >"$work_dir/generate.txt" 2>&1; then
  tail -n 30 "$work_dir/generate.txt"
  echo "verify-route-table: FAIL (generator)" >&2
  exit 1
fi

cp "$out_dir/src/gen/face.gleam" "$scratch_dir/src/gen/face.gleam"
cp "$out_dir/src/gen/entry/http.gleam" "$scratch_dir/src/gen/entry/http.gleam"
sed "s#__STDLIB_PATH__#$gen_dir/build/packages/gleam_stdlib#" \
  "$script_dir/route-table-scratch.gleam.toml" >"$scratch_dir/gleam.toml"

if ! (cd "$scratch_dir" && gleam build) >"$work_dir/build.txt" 2>&1; then
  tail -n 30 "$work_dir/build.txt"
  echo "verify-route-table: FAIL (scratch gleam build)" >&2
  exit 1
fi

rows=$(rg -c '^[[:space:]]+Route\(face: "' "$out_dir/src/gen/entry/http.gleam" || true)
if [ "$rows" -ne 7 ]; then
  echo "verify-route-table: FAIL (expected 7 rows, got $rows)" >&2
  exit 1
fi

echo "verify-route-table: PASS (7 rows, face/http scratch build)"
