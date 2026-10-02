#!/usr/bin/env python3
"""Check that the report's Catalog checks section carries the block the
pre-review step wrote from the catalog.

    python3 references/check-catalog.py <report.md> <pre-review-out-dir>

The pre-review step reads the catalog and writes catalog-checks.md; the
orchestrator pastes it under "## Catalog checks". Every non-blank line of
catalog-checks.md must appear in that section, compared with whitespace
collapsed. That includes the Duplicate-check rationale placeholder: the
rationale is the reviewer's to write, so a report that fills it in fails.

When catalog-checks.md does not exist (a pre-review run that predates the
catalog step), there is nothing to compare: the check is not run, which is
not a problem.

Output: one MISSING line per absent line, then a summary line.
Exit 0 when every line is present or the check does not apply, 1 when a
line is missing or the section is absent, 2 when the report cannot be read.
"""
import os
import re
import sys

SECTION = "## Catalog checks"


def norm(line):
    return " ".join(line.split())


def section(text):
    m = re.search(r"^## Catalog checks[ \t]*$(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1) if m else None


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
    have = {norm(l) for l in sec.splitlines() if l.strip()}
    missing = [l for l in expected if l not in have]
    for l in missing:
        print("MISSING catalog line: %s" % (l if len(l) <= 160 else l[:157] + "..."))
    print("catalog: %d/%d lines of catalog-checks.md present" % (len(expected) - len(missing), len(expected)))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
