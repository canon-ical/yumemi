#!/usr/bin/env bash
# 生成した4束を、実物のアプリへ差し替えて gleam build にかける検算。
# アプリは読むだけ ── 複製へ差し替えるので元のワークツリーは触らない。
#
#   gen/scripts/probe-compile.sh <app dir> <out dir> <work dir>
#
# 出るのは「差し替えた版の error の数」。基準(差し替え前)は 0。
set -euo pipefail

app=${1:?app dir}
out=${2:?out dir}
work=${3:?work dir}

rm -rf "$work"
mkdir -p "$work"
cp -r "$app/../framework" "$work/framework"
cp -r "$app" "$work/app"
rm -rf "$work/app/build"

echo "== 基準(手書きの ▲ そのまま)"
(cd "$work/app" && gleam build 2>&1 | grep -c '^error' || true)

cp "$out"/src/gen/types/*.gleam "$work/app/src/gen/types/"
cp "$out"/src/gen/query.gleam "$work/app/src/gen/query.gleam"
cp "$out"/src/gen/reads/*.gleam "$work/app/src/gen/reads/"

echo "== 差し替え後(4束を生成物に置き換え)"
(cd "$work/app" && gleam build 2>&1 | grep -c '^error' || true)
sites() {
  (cd "$work/app" && gleam build 2>&1 | grep -B1 -E '^\s+┌─' \
    | grep -E '^error|┌─' | sed "s|.*$work/app/||" \
    | awk '/^error/{e=$0; next} e!=""{print e" @ "$1; e=""}' | sort -u || true)
}
echo "== error の在処"
sites

# 段2 ── 既知の2件(名前の衝突と、★ が呼ぶ gen/types の手書き関数)を外して残りを見る。
echo
echo "== 段2:既知の2件を除いた残り"
for name in $(sed -n 's/^名前の衝突 gen\/query.gleam: \([A-Za-z0-9_]*\).*/\1/p' "$out/_diagnostics.txt"); do
  # From と重なった Field の行を1本だけ外す(2つ目の出現)
  awk -v target="  $name" 'BEGIN{seen=0} $0==target{seen++; if(seen==2) next} {print}' \
    "$work/app/src/gen/query.gleam" > "$work/query.tmp"
  mv "$work/query.tmp" "$work/app/src/gen/query.gleam"
done
for path in "$app"/src/gen/types/*.gleam; do
  name=$(basename "$path")
  if ! diff -q "$out/src/gen/types/$name" "$path" >/dev/null 2>&1; then
    cp "$path" "$work/app/src/gen/types/$name"
  fi
done
(cd "$work/app" && gleam build 2>&1 | grep -c '^error' || true)
sites
