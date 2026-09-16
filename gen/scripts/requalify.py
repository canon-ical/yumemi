#!/usr/bin/env python3
"""From / Field が別 module へ割れた分だけ、アプリの ★ の綴りを機械で付け替える。

  python3 gen/scripts/requalify.py <app dir(書き換える複製)> <out dir(生成物)>

2026-09-16 の裁定で `From` は `gen/query/from`、`Field` は `gen/query/field` へ移った。
Gleam は構成子を再輸出できない(`import` した名前は外から `q.X` で引けない)ので、
`import gen/query as q` のままでは `q.Article` / `q.ArticleSlug` が引けない。
**アプリの ★ の書き換えが1度だけ要る** ── その書き換えが機械で済むことを示すのがこの道具で、
probe-compile の段2 が /tmp の複製に対してだけ使う。musearch のワークツリーには触らない。
"""

import os
import re
import sys


def variants(path):
    text = open(path, encoding="utf-8").read()
    block = re.search(r"pub type \w+ \{\n(.*?)\n\}", text, re.S)
    if not block:
        return []
    found = []
    for line in block.group(1).split("\n"):
        line = line.strip()
        if line and not line.startswith("//"):
            found.append(line.split("(")[0])
    return found


def main():
    app_dir, out_dir = sys.argv[1], sys.argv[2]
    froms = variants(os.path.join(out_dir, "src/gen/query/from.gleam"))
    fields = variants(os.path.join(out_dir, "src/gen/query/field.gleam"))
    # 同名(From と Field の衝突)は from 側に寄せる ── `from:` の欄にしか出ない。
    fields = [name for name in fields if name not in froms]
    touched = 0
    for dirpath, _, names in os.walk(os.path.join(app_dir, "src")):
        if "/gen" in dirpath.replace(app_dir, ""):
            continue
        for name in sorted(names):
            if not name.endswith(".gleam"):
                continue
            full = os.path.join(dirpath, name)
            text = open(full, encoding="utf-8").read()
            if "gen/query as q" not in text:
                continue
            before = text
            text = text.replace(
                "import gen/query as q",
                "import gen/query as q\n"
                "import gen/query/field\n"
                "import gen/query/from",
                1,
            )
            for variant in froms:
                text = re.sub(rf"\bq\.{variant}\b", f"from.{variant}", text)
            for variant in fields:
                text = re.sub(rf"\bq\.{variant}\b", f"field.{variant}", text)
            if text != before:
                open(full, "w", encoding="utf-8").write(text)
                touched += 1
    print(f"  書き換えた ★: {touched} ファイル(From {len(froms)} / Field {len(fields)})")


if __name__ == "__main__":
    main()
