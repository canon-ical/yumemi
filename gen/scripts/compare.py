#!/usr/bin/env python3
"""生成した ▲ と、手で書かれた ▲ を束ごとに数える検収の道具。

  python3 gen/scripts/compare.py <out dir> <app dir>

出すのは束ごとの「一致 / 不一致 / 片側だけ」と、不一致 1件ごとの行数。
判定は2段 ── 完全一致(バイト)と、本文一致(先頭の GENERATED 行を除く)。
"""

import os
import re
import sys


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def body(text):
    """先頭の GENERATED 行を落とす。gen-2 から header に入力ハッシュが入るので、
    完全一致(バイト)は 0 に落ちる ── 一致は本文一致で見る。"""
    lines = text.split("\n")
    if lines and ("GENERATED" in lines[0]):
        lines = lines[1:]
    return "\n".join(lines).strip()


def squeeze(text):
    return re.sub(r"\s+", " ", text).strip()


# 読み SQL の束に混ぜない補助束。verb SQL は下で専用束として数える。
OUT_OF_SCOPE = ("db/queries/allow/", "db/queries/framework/")


def in_scope(rel, include_verb=True):
    if rel.startswith(OUT_OF_SCOPE):
        return False
    if not include_verb and rel.startswith("db/queries/verb/"):
        return False
    return os.path.basename(rel) != "root.sql"


def files_under(root, rel, suffix, include_verb=True):
    base = os.path.join(root, rel)
    if not os.path.isdir(base):
        return []
    found = []
    for dirpath, _, names in os.walk(base):
        for name in sorted(names):
            if name.endswith(suffix):
                full = os.path.join(dirpath, name)
                relative = os.path.relpath(full, root)
                if in_scope(relative, include_verb):
                    found.append(relative)
    return sorted(found)


def compare_bundle(title, out_dir, app_dir, rel, suffix, include_verb=True):
    ours = files_under(out_dir, rel, suffix, include_verb)
    theirs = files_under(app_dir, rel, suffix, include_verb)
    both = [p for p in ours if p in theirs]
    only_ours = [p for p in ours if p not in theirs]
    only_theirs = [p for p in theirs if p not in ours]
    exact, body_same, differ = [], [], []
    for path in both:
        mine, yours = read(os.path.join(out_dir, path)), read(
            os.path.join(app_dir, path)
        )
        if mine == yours:
            exact.append(path)
        elif squeeze(body(mine)) == squeeze(body(yours)):
            body_same.append(path)
        else:
            differ.append(path)
    print(f"## {title}")
    print(f"  対象(両側にある): {len(both)}")
    print(f"  完全一致: {len(exact)}")
    print(f"  本文一致(GENERATED 行だけ違う / 空白の詰め方だけ違う): {len(body_same)}")
    print(f"  不一致: {len(differ)}")
    print(f"  生成器だけが出した: {len(only_ours)}")
    print(f"  手書きにだけある: {len(only_theirs)}")
    for path in body_same:
        print(f"    [本文一致] {path}")
    for path in differ:
        mine = read(os.path.join(out_dir, path)).split("\n")
        yours = read(os.path.join(app_dir, path)).split("\n")
        added = len([line for line in yours if line not in mine])
        dropped = len([line for line in mine if line not in yours])
        print(f"    [不一致] {path}  手書きだけの行 {added} / 生成だけの行 {dropped}")
    for path in only_ours:
        print(f"    [生成器だけ] {path}")
    for path in only_theirs:
        print(f"    [手書きだけ] {path}")
    print()
    return {
        "both": len(both),
        "exact": len(exact),
        "body": len(body_same),
        "differ": len(differ),
        "only_ours": len(only_ours),
        "only_theirs": len(only_theirs),
    }


def compare_file(title, out_dir, app_dir, path):
    """単一ファイルの束(src/gen/verb.gleam / phase.gleam)を数える。"""
    ours = [path] if os.path.isfile(os.path.join(out_dir, path)) else []
    theirs = [path] if os.path.isfile(os.path.join(app_dir, path)) else []
    both = bool(ours and theirs)
    exact = body_same = differ = False
    if both:
        mine, yours = read(os.path.join(out_dir, path)), read(
            os.path.join(app_dir, path)
        )
        exact = mine == yours
        body_same = not exact and squeeze(body(mine)) == squeeze(body(yours))
        differ = not exact and not body_same
    print(f"## {title}")
    print(f"  対象(両側にある): {int(both)}")
    print(f"  完全一致: {int(exact)}")
    print(f"  本文一致(GENERATED 行だけ違う / 空白の詰め方だけ違う): {int(body_same)}")
    print(f"  不一致: {int(differ)}")
    print(f"  生成器だけが出した: {int(bool(ours and not theirs))}")
    print(f"  手書きにだけある: {int(bool(theirs and not ours))}")
    if differ:
        mine = read(os.path.join(out_dir, path)).split("\n")
        yours = read(os.path.join(app_dir, path)).split("\n")
        added = len([line for line in yours if line not in mine])
        dropped = len([line for line in mine if line not in yours])
        print(f"    [不一致] {path}  手書きだけの行 {added} / 生成だけの行 {dropped}")
    print()
    return {
        "both": int(both),
        "exact": int(exact),
        "body": int(body_same),
        "differ": int(differ),
        "only_ours": int(bool(ours and not theirs)),
        "only_theirs": int(bool(theirs and not ours)),
    }


# 束2 は 2026-09-16 の裁定で 3 module に割れた。手書き ▲ は 1 module のまま。
QUERY_PARTS = ["src/gen/query.gleam", "src/gen/query/from.gleam",
               "src/gen/query/field.gleam"]


def compare_one(title, out_dir, app_dir, path):
    """束2 ── 生成は 3 module、手書きは 1 module。割れた分を分けて出す。"""
    parts = [p for p in QUERY_PARTS if os.path.exists(os.path.join(out_dir, p))]
    mine = []
    print(f"## {title}")
    for part in parts:
        lines = read(os.path.join(out_dir, part)).split("\n")
        print(f"  生成 {part}: {len(lines)} 行")
        mine += lines
    yours = read(os.path.join(app_dir, path)).split("\n")
    print(f"  行数: 生成 {len(mine)}(module {len(parts)} 本の合計) / 手書き {len(yours)}(1 本)")
    print(f"  手書きだけの行: {len([l for l in yours if l not in mine])}")
    print(f"  生成だけの行: {len([l for l in mine if l not in yours])}")
    print("  ※ module が割れた分 ── 生成側に header / import / 型別名の行が増える")
    print()


VARIANT_BLOCK = re.compile(r"pub type (\w+)\([^)]*\) \{\n(.*?)\n\}", re.S)
PLAIN_BLOCK = re.compile(r"pub type (\w+) \{\n(.*?)\n\}", re.S)


def variants(text):
    found = {}
    for pattern in (VARIANT_BLOCK, PLAIN_BLOCK):
        for name, block in pattern.findall(text):
            if name in found:
                continue
            items = []
            for line in block.split("\n"):
                line = line.strip()
                if not line or line.startswith("//"):
                    continue
                items.append(line.split("(")[0])
            found[name] = items
    return found


def compare_query(out_dir, app_dir):
    path = "src/gen/query.gleam"
    mine = {}
    for part in QUERY_PARTS:
        full = os.path.join(out_dir, part)
        if os.path.exists(full):
            for name, items in variants(read(full)).items():
                mine.setdefault(name, items)
    yours = variants(read(os.path.join(app_dir, path)))
    print("## 束2 src/gen/query.gleam ── 型ごとの variant")
    print("| 型 | 生成 | 手書き | 両方 | 生成だけ | 手書きだけ |")
    print("|---|---|---|---|---|---|")
    for name in ["From", "Field", "Arrow", "Operand", "Cond", "Agg", "CondAgg",
                 "Unit", "Group", "Order", "Along", "Limit", "Select"]:
        ours = mine.get(name, [])
        theirs = yours.get(name, [])
        both = [v for v in ours if v in theirs]
        print(
            f"| {name} | {len(ours)} | {len(theirs)} | {len(both)} | "
            f"{len([v for v in ours if v not in theirs])} | "
            f"{len([v for v in theirs if v not in ours])} |"
        )
    print()
    for name in ["From", "Field", "Arrow", "Operand", "Cond"]:
        ours = mine.get(name, [])
        theirs = yours.get(name, [])
        extra = [v for v in theirs if v not in ours]
        if extra:
            print(f"  手書きだけの {name}: {', '.join(extra)}")
    print()


def main():
    out_dir, app_dir = sys.argv[1], sys.argv[2]
    compare_bundle("束1 src/gen/types/*.gleam", out_dir, app_dir,
                   "src/gen/types", ".gleam")
    compare_one("束2 src/gen/query.gleam", out_dir, app_dir,
                "src/gen/query.gleam")
    compare_query(out_dir, app_dir)
    compare_bundle("束3 src/gen/reads/*.gleam", out_dir, app_dir,
                   "src/gen/reads", ".gleam")
    compare_bundle("束4 db/queries/<service>/<name>.sql", out_dir, app_dir,
                   "db/queries", ".sql", include_verb=False)
    compare_file("束5 src/gen/verb.gleam", out_dir, app_dir,
                 "src/gen/verb.gleam")
    compare_bundle("束6 db/queries/verb/*.sql", out_dir, app_dir,
                   "db/queries/verb", ".sql")
    compare_bundle("束7 src/gen/root/*.gleam", out_dir, app_dir,
                   "src/gen/root", ".gleam")
    compare_file("束8 src/gen/phase.gleam", out_dir, app_dir,
                 "src/gen/phase.gleam")


if __name__ == "__main__":
    main()
