#!/usr/bin/env python3
"""Put the pre-review step's catalog block into the report's Catalog checks
section.

    python3 references/insert-catalog.py <report.md> <pre-review-out-dir>

The model writes only the "## Catalog checks" heading (and a
<!-- catalog-checks --> marker); this script replaces that section's body
with <pre-review>/catalog-checks.md, so the deterministic catalog results
are never retyped. A report with no such section gets one, placed before
"## Overall recommendation" (or "## Draft feedback", "## Fix before
submitting", else at the end). The heading is matched ignoring case.

Exit 0 when the block was inserted, or when there is no catalog-checks.md
to insert (a pre-review run that predates the catalog step); 2 when the
report cannot be read or written.
"""
import os
import re
import sys

HEADING_RE = re.compile(r"^##[ \t]+catalog checks[ \t]*$", re.I | re.M)
NEXT_H2_RE = re.compile(r"^## ", re.M)
ANCHORS = ("## Overall recommendation", "## Draft feedback", "## Fix before submitting")


def insert(text, block):
    body = "\n" + block.strip("\n") + "\n\n"
    m = HEADING_RE.search(text)
    if m:
        nxt = NEXT_H2_RE.search(text, m.end())
        end = nxt.start() if nxt else len(text)
        return text[:m.end()] + "\n" + body + text[end:]
    section = "## Catalog checks\n" + body
    for anchor in ANCHORS:
        a = re.search(r"^" + re.escape(anchor), text, re.M)
        if a:
            return text[:a.start()] + section + text[a.start():]
    return text.rstrip("\n") + "\n\n" + section


def main(argv):
    if len(argv) != 3:
        print("usage: insert-catalog.py <report.md> <pre-review-out-dir>", file=sys.stderr)
        return 2
    report, pre = argv[1], argv[2]
    block_path = os.path.join(pre, "catalog-checks.md")
    if not os.path.isfile(block_path):
        print("insert-catalog: no catalog-checks.md in %s; report unchanged" % pre)
        return 0
    try:
        with open(report, encoding="utf-8") as f:
            text = f.read()
        with open(block_path, encoding="utf-8") as f:
            block = f.read()
        new = insert(text, block)
        tmp = report + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(new)
        os.replace(tmp, report)
    except OSError as e:
        print("error: %s" % e)
        return 2
    print("insert-catalog: Catalog checks section written from catalog-checks.md")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
