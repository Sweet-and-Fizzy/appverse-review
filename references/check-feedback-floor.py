#!/usr/bin/env python3
"""Check the Draft Feedback against the inclusion floor.

Every finding with result FAIL or WARN and severity low or above is a
fix-item and must be represented in the feedback section of the report:

  1. its defect_key is listed in a trailing HTML comment
       <!-- feedback-covers: key1, key2, ... -->
  2. if its evidence starts with a file path, that path appears in the
     feedback prose as a whole token. For a root-level finding
     (app_id == "root") the path's basename also satisfies this; for a
     finding scoped to a specific app (app_id != "root", e.g. a monorepo
     subpath) only the full evidence path counts, since the basename alone
     is ambiguous across apps. A path is recognized either by a file
     extension (a dot) or, for extensionless files like LICENSE or
     Dockerfile, by evidence of the form "NAME:<digit>" — the colon must
     immediately follow the name, with no space, so "GitHub releases API: 0"
     is not mistaken for a path.
  3. when a path was recognized in step 2, the prose also names the defect,
     not just the file: either the primary line number from its evidence
     appears as ":<n>" or "line <n>" or "lines <n>" immediately after the
     file name or anywhere in the same paragraph as the file name, OR every
     word of the mechanism tag (the part of defect_key after the last ":",
     hyphens split into words, a trailing "{qualifier}" after a second colon
     ignored) appears in that paragraph, case-insensitive.

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
PATH_PREFIX = re.compile(
    r"^([A-Za-z0-9_./\-]+\.[A-Za-z0-9_.]+)(?::|\s|$)"  # has a file extension
    r"|^([A-Za-z0-9_./\-]+)(?=:\d)"                    # extensionless, e.g. LICENSE:1
)


def feedback_section(report_text):
    lines = report_text.splitlines()
    start = None
    in_fence = False
    for i, line in enumerate(lines):
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence and any(h.match(line) for h in SECTION_HEADINGS):
            start = i + 1
            break
    if start is None:
        return None
    body = []
    in_fence = False
    for line in lines[start:]:
        if line.startswith("```"):
            in_fence = not in_fence
            body.append(line)
            continue
        if not in_fence and line.startswith("## "):
            break
        body.append(line)
    return "\n".join(body)


def evidence_path(evidence):
    m = PATH_PREFIX.match(str(evidence or "").strip())
    if not m:
        return None
    return m.group(1) if m.group(1) is not None else m.group(2)


def token_in_prose(candidate, prose):
    # '.' is excluded from the boundary class: paths routinely end a
    # sentence ("...in submit.yml.erb.") and '.' is also a valid path
    # character, so treating it as non-boundary would reject that case.
    pattern = r"(?<![A-Za-z0-9_/-])" + re.escape(candidate) + r"(?![A-Za-z0-9_/-])"
    return re.search(pattern, prose) is not None


def paragraphs(prose):
    return [p for p in re.split(r"\n\s*\n", prose) if p.strip()]


def paragraph_naming(candidates, prose):
    """The paragraph(s) in which any of `candidates` appears as a whole token."""
    return [p for p in paragraphs(prose) if any(token_in_prose(c, p) for c in candidates)]


def primary_line_number(evidence):
    """First integer after the path's trailing colon, e.g. "15" from
    "submit.yml.erb:15-19" or "63" from "form.yml:63"."""
    m = re.search(r":(\d+)", str(evidence or ""))
    return m.group(1) if m else None


def mechanism_words(defect_key):
    """Words of the mechanism tag (defect_key after the last ':'), hyphens
    split into words, a trailing '{qualifier}' after a second colon ignored."""
    tag = str(defect_key or "").rsplit(":", 1)[-1]
    tag = tag.split(":", 1)[0]  # drop a trailing {qualifier} after a second colon
    return [w for w in re.split(r"-", tag) if w]


def defect_named(candidates, evidence, defect_key, named_paragraphs):
    line = primary_line_number(evidence)
    line_patterns = [r"(?i)\blines?\s+" + re.escape(line) + r"(?!\d)"] if line else []
    if line:
        for c in candidates:
            line_patterns.append(re.escape(c) + r":" + re.escape(line) + r"(?!\d)")

    words = mechanism_words(defect_key)

    for p in named_paragraphs:
        if any(re.search(pat, p) for pat in line_patterns):
            return True
        if words and all(re.search(r"(?i)\b" + re.escape(w) + r"\b", p) for w in words):
            return True
    return False


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
        if path:
            candidates = (path, os.path.basename(path)) if f.get("app_id") == "root" else (path,)
            named_paragraphs = paragraph_naming(candidates, prose)
            if not named_paragraphs:
                missing.append((f, "file not named in feedback"))
                continue
            if not defect_named(candidates, f.get("evidence"), f.get("defect_key", ""), named_paragraphs):
                missing.append((f, "defect not described in feedback"))
    for f, reason in missing:
        print("MISSING {} {} ({})".format(f.get("rule", "?"), f.get("defect_key", "?"), reason))
    print("feedback floor: {}/{} fix-items covered".format(len(fix_items) - len(missing), len(fix_items)))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
