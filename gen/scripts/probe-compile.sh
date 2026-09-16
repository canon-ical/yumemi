#!/usr/bin/env bash
# 生成した4束を、実物のアプリへ差し替えて gleam build にかける検算。
# アプリは読むだけ ── 複製へ差し替えるので元のワークツリーは触らない。
#
#   gen/scripts/probe-compile.sh <app dir> <out dir> <work dir>
#
# 4段で数える。
#   基準 ── 手書きの ▲ そのまま(0)
#   段1 ── 4束を生成物へ差し替え。From / Field が別 module へ割れた分の error がここに出る
#   段2 ── ★ の綴りを機械で付け替える(requalify.py)。割れた分だけが消える
#   段3 ── 既知の1件(★ が呼ぶ gen/types の手書き関数)を外した残り
set -euo pipefail

app=${1:?app dir}
out=${2:?out dir}
work=${3:?work dir}
here=$(cd "$(dirname "$0")" && pwd)

rm -rf "$work"
mkdir -p "$work"
cp -r "$app/../framework" "$work/framework"
cp -r "$app" "$work/app"
rm -rf "$work/app/build"

errors() {
  (cd "$work/app" && gleam build 2>&1 | grep -c '^error' || true)
}
sites() {
  (cd "$work/app" && gleam build 2>&1 | grep -B1 -E '^\s+┌─' \
    | grep -E '^error|┌─' | sed "s|.*$work/app/||" \
    | awk '/^error/{e=$0; next} e!=""{print e" @ "$1; e=""}' | sort -u || true)
}

echo "== 基準(手書きの ▲ そのまま)"
errors

cp "$out"/src/gen/types/*.gleam "$work/app/src/gen/types/"
cp "$out"/src/gen/query.gleam "$work/app/src/gen/query.gleam"
mkdir -p "$work/app/src/gen/query"
cp "$out"/src/gen/query/*.gleam "$work/app/src/gen/query/"
cp "$out"/src/gen/reads/*.gleam "$work/app/src/gen/reads/"

echo "== 段1:差し替え後(4束を生成物に置き換え)"
errors
echo "== 段1 の error の在処(先頭 20)"
sites | head -20

# 段2 ── From / Field が割れた分。★ の `q.X` を `qfrom.X` / `qfield.X` へ機械で付け替える。
echo
echo "== 段2:★ の綴りを機械で付け替えた後(module 分割の分だけが消える)"
python3 "$here/requalify.py" "$work/app" "$out"
errors
sites

# 段3 ── 既知の1件(★ が呼ぶ gen/types の手書き関数)を外して残りを見る。
echo
echo "== 段3:既知の1件(gen/types の手書き関数)を除いた残り"
for path in "$app"/src/gen/types/*.gleam; do
  name=$(basename "$path")
  if ! diff -q "$out/src/gen/types/$name" "$path" >/dev/null 2>&1; then
    cp "$path" "$work/app/src/gen/types/$name"
  fi
done
errors
sites
