#!/usr/bin/env python3
"""Validate every finding's evidence citation against the reviewed repo.

    python3 references/check-evidence.py review-<slug>.findings.json --target <repo-dir>

A finding's `evidence` is free text. When it starts with `<path>:<n>` or
`<path>:<n>-<m>` (a bare path, then a colon, then one or two integers), the
path must name a real file under --target and every cited line number must
be within that file's length (1-indexed; 0 and anything past EOF is BAD). A
pseudo-anchor (the same fixed set check-keys.py treats as not-a-real-file:
LICENSE, README.md, CHANGELOG.md, .github/workflows, releases, issues,
contributors, commits, root) is never a file, so citing a line number against
one is always BAD, even though the bare pseudo-anchor by itself (no line, as
in "GitHub releases API: 0") is fine — that phrase does not match the
`<path>:<n>` shape at all, since the digits are not glued to the anchor with
a colon.

Evidence that does not start with `<path>:<n>[-<m>]` (a free-text phrase, a
bare filename with no line, "(no file)", etc.) is left alone; this script
only checks the citations it can parse as a file:line reference.

Without --target, only the `<path>:<n>[-<m>]` shape and pseudo-anchor rule
are checked; file existence and line-length are skipped (nothing to check
them against).

Exit 0 when every evidence citation is valid, 1 when any is not (one BAD
line each, in the form `BAD <rule> <defect_key> <evidence> (<reason>)`),
2 when the input cannot be read or is malformed.
"""
import argparse
import json
import os
import re
import sys

PSEUDO_ANCHORS = {
    "LICENSE", "README.md", "CHANGELOG.md", ".github/workflows",
    "releases", "issues", "contributors", "commits", "root",
}

# A leading "<path>:<n>" or "<path>:<n>-<m>" citation. The path is everything
# up to the colon that immediately precedes the digits (no space), so
# "GitHub releases API: 0" (a space before the digits) does not match.
EVIDENCE_PREFIX = re.compile(
    r"^([^\s:][^:]*?):(\d+)(?:-(\d+))?(?=[\s(]|$)"
)


def parse_citation(evidence):
    """Return (path, [line numbers]) if evidence starts with a <path>:<n>
    or <path>:<n>-<m> citation, else None."""
    m = EVIDENCE_PREFIX.match(str(evidence or "").strip())
    if not m:
        return None
    path, start, end = m.group(1), m.group(2), m.group(3)
    lines = [int(start)] if end is None else [int(start), int(end)]
    return path, lines


def validate(finding, target):
    rule = finding.get("rule") or "<missing>"
    key = finding.get("defect_key") or "<missing>"
    evidence = finding.get("evidence")
    parsed = parse_citation(evidence)
    if parsed is None:
        return rule, key, evidence, None
    path, lines = parsed
    if path in PSEUDO_ANCHORS:
        return rule, key, evidence, "pseudo-anchor, not a file"
    if target is None:
        return rule, key, evidence, None
    full = os.path.join(target, path)
    if not os.path.isfile(full):
        return rule, key, evidence, "file does not exist"
    try:
        with open(full, "rb") as f:
            length = sum(1 for _ in f)
    except OSError as e:
        return rule, key, evidence, "cannot read file: {}".format(e)
    for n in lines:
        if n < 1 or n > length:
            return rule, key, evidence, "line {} past end of file, has {} lines".format(n, length)
    return rule, key, evidence, None


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("findings")
    ap.add_argument("--target", default=None, help="reviewed repo checkout; enables file/line existence checks")
    args = ap.parse_args(argv[1:])
    if args.target is not None and (not args.target or not os.path.isdir(args.target)):
        # An empty --target would silently mean the cwd and reject every real path.
        print("error: --target is not a directory: '{}'".format(args.target), file=sys.stderr)
        return 2
    try:
        with open(args.findings) as f:
            findings = json.load(f)
    except (OSError, ValueError) as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    if not isinstance(findings, list) or not all(isinstance(x, dict) for x in findings):
        print("error: findings must be a JSON list of objects", file=sys.stderr)
        return 2
    bad = 0
    for finding in findings:
        rule, key, evidence, reason = validate(finding, args.target)
        if reason:
            bad += 1
            print("BAD {} {} {} ({})".format(rule, key, evidence, reason))
    print("evidence: {}/{} valid".format(len(findings) - bad, len(findings)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
