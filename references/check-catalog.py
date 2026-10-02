#!/usr/bin/env python3
"""Check that the report's Catalog checks section is exactly the block the
pre-review step wrote from the catalog.

    python3 references/check-catalog.py <report.md> <pre-review-out-dir>

references/insert-catalog.py writes that section mechanically, so the
section's non-blank lines must equal catalog-checks.md's, in order,
compared with whitespace collapsed. A line missing, changed, reordered or
added is a problem: that is how a report that rewrote the catalog results,
or filled in a duplicate rationale, is caught. The heading is matched
ignoring case.

When catalog-checks.md does not exist (a pre-review run that predates the
catalog step), there is nothing to compare: the check is not run, which is
not a problem.

Output: MISSING and EXTRA lines, then a summary line. Exit 0 when the
section matches or the check does not apply, 1 when it does not match, 2
when the report cannot be read or has no Catalog checks section.
"""
import difflib
import os
import re
import sys

SECTION = "## Catalog checks"
HEADING_RE = re.compile(r"^##[ \t]+catalog checks[ \t]*$", re.I | re.M)


def norm(line):
    return " ".join(line.split())


def short(line):
    return line if len(line) <= 160 else line[:157] + "..."


def section(text):
    m = HEADING_RE.search(text)
    if not m:
        return None
    nxt = re.search(r"^## ", text[m.end():], re.M)
    return text[m.end():m.end() + nxt.start()] if nxt else text[m.end():]


def main(argv):
    if len(argv) != 3:
        print("usage: check-catalog.py <report.md> <pre-review-out-dir>", file=sys.stderr)
        return 2
    report, pre = argv[1], argv[2]
    try:
        with open(report, encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        print("error: cannot read report %s (%s)" % (report, e.strerror))
        return 2
    block_path = os.path.join(pre, "catalog-checks.md")
    if not os.path.isfile(block_path):
        print("catalog: not checked (no catalog-checks.md in the pre-review output)")
        return 0
    with open(block_path, encoding="utf-8") as f:
        expected = [norm(l) for l in f.read().splitlines() if l.strip()]
    sec = section(text)
    if sec is None:
        print("error: report has no '%s' section" % SECTION)
        return 2
    have = [norm(l) for l in sec.splitlines() if l.strip()]
    problems = 0
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(a=expected, b=have, autojunk=False).get_opcodes():
        if tag in ("delete", "replace"):
            for l in expected[i1:i2]:
                print("MISSING catalog line: %s" % short(l))
                problems += 1
        if tag in ("insert", "replace"):
            for l in have[j1:j2]:
                print("EXTRA catalog line: %s" % short(l))
                problems += 1
    if problems:
        print("catalog: section differs from catalog-checks.md (%d line%s); run insert-catalog.py"
              % (problems, "" if problems == 1 else "s"))
        return 1
    print("catalog: section matches catalog-checks.md (%d lines)" % len(expected))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
