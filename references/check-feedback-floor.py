#!/usr/bin/env python3
"""Check the Draft Feedback against the inclusion floor.

Every finding with result FAIL or WARN and severity low or above is a
fix-item and must be represented in the feedback section of the report:

  1. its defect_key is listed in a trailing HTML comment
       <!-- feedback-covers: key1, key2, ... -->
  2. if its evidence starts with a file path, that path (or its basename)
     appears in the feedback prose.

    python3 references/check-feedback-floor.py review-<slug>.findings.json review-<slug>.md

Exit 0 when every fix-item is covered, 1 when any is missing, 2 when an
input cannot be read or the report has no feedback section.
"""
import json
import os
import re
import sys

FIX_SEVERITIES = {"critical", "high", "medium", "low"}
FIX_RESULTS = {"FAIL", "WARN"}
SECTION_HEADINGS = (
    re.compile(r"^##\s+Draft feedback", re.IGNORECASE),
    re.compile(r"^##\s+Fix before submitting", re.IGNORECASE),
)
COVERS = re.compile(r"<!--\s*feedback-covers:\s*(.*?)\s*-->", re.DOTALL)
PATH_PREFIX = re.compile(r"^([A-Za-z0-9_./\-]+\.[A-Za-z0-9_.]+)(?::|\s|$)")


def feedback_section(report_text):
    lines = report_text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if any(h.match(line) for h in SECTION_HEADINGS):
            start = i + 1
            break
    if start is None:
        return None
    body = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        body.append(line)
    return "\n".join(body)


def evidence_path(evidence):
    m = PATH_PREFIX.match(str(evidence or "").strip())
    return m.group(1) if m else None


def main(argv):
    if len(argv) != 3:
        print("usage: check-feedback-floor.py <findings.json> <report.md>", file=sys.stderr)
        return 2
    try:
        with open(argv[1]) as f:
            findings = json.load(f)
        with open(argv[2]) as f:
            report = f.read()
    except (OSError, ValueError) as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    section = feedback_section(report)
    if section is None:
        print("error: no '## Draft feedback' or '## Fix before submitting' section", file=sys.stderr)
        return 2
    m = COVERS.search(section)
    covered = set()
    if m:
        covered = {k.strip() for k in m.group(1).split(",") if k.strip()}
    prose = COVERS.sub("", section)

    fix_items = [
        f for f in findings
        if str(f.get("result", "")).upper() in FIX_RESULTS
        and str(f.get("severity", "")).lower() in FIX_SEVERITIES
    ]
    missing = []
    for f in fix_items:
        key = f.get("defect_key", "")
        if key not in covered:
            missing.append((f, "not in feedback-covers"))
            continue
        path = evidence_path(f.get("evidence"))
        if path and path not in prose and os.path.basename(path) not in prose:
            missing.append((f, "file not named in feedback"))
    for f, reason in missing:
        print("MISSING {} {} ({})".format(f.get("rule", "?"), f.get("defect_key", "?"), reason))
    print("feedback floor: {}/{} fix-items covered".format(len(fix_items) - len(missing), len(fix_items)))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
