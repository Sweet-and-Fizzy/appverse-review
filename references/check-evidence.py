#!/usr/bin/env python3
"""Validate every finding's evidence citation against the reviewed repo.

    python3 references/check-evidence.py review-<slug>.findings.json --target <repo-dir>

A finding's `evidence` is free text. When it starts with `<path>:<n>` or
`<path>:<n>-<m>` (a bare path, then a colon, then one or two integers), only
that leading citation is parsed — anything after the digits (another
`:...`, trailing prose) is ignored, so `"form.yml:12:extra"` is read as
`form.yml` line 12. The path must name a real file under --target (matched
case-exactly: `readme.md` does not stand in for `README.md`, since some
filesystems accept that locally and CI would not) and every cited line
number must be within that file's length (1-indexed; 0 and anything past
EOF is BAD). A pseudo-anchor (the same fixed set check-keys.py treats as
not-a-real-file: LICENSE, README.md, CHANGELOG.md, .github/workflows,
releases, issues, contributors, commits, root — imported from repo_paths so
the two scripts cannot drift) is never a file, so citing a line number
against one is always BAD, even though the bare pseudo-anchor by itself (no
line, as in "GitHub releases API: 0") is fine — that phrase does not match
the `<path>:<n>` shape at all, since the digits are not glued to the anchor
with a colon.

The cited path must also be repo-relative: absolute paths, a `..` segment,
or a path that otherwise resolves outside --target are BAD ("path is not
repo-relative"), never walked out to the real filesystem.

Evidence that does not start with `<path>:<n>[-<m>]` (a free-text phrase, a
bare filename with no line, "(no file)", etc.) is left alone; this script
only checks the citations it can parse as a file:line reference.

Without --target, only the `<path>:<n>[-<m>]` shape, path-hygiene, and
pseudo-anchor rules are checked; file existence and line-length are skipped
(nothing to check them against).

Line counts are cached per path for the run (a file cited by several
findings is read once). A file over 5 MB is not read for a line count at
all — counted as "not checked" (reported in the summary line, not treated
as BAD) rather than paying to scan a large file just to bound-check a
citation.

Exit 0 when every evidence citation is valid, 1 when any is not (one BAD
line each, in the form `BAD <rule> <defect_key> <evidence> (<reason>)`),
2 when the input cannot be read or is malformed.
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_paths import PSEUDO_ANCHORS, exists_case_exact  # noqa: E402

MAX_LINE_COUNT_BYTES = 5 * 1024 * 1024  # 5 MB

# The leading "<path>:<n>" or "<path>:<n>-<m>" citation. The path is
# everything up to the first colon (colons are excluded from the path
# character class, so this cannot be fooled by a colon inside the path);
# whatever follows the digits (more ":...", trailing prose) is not part of
# the match and is ignored by design (a:1:2 -> path "a", line 1).
EVIDENCE_PREFIX = re.compile(
    r"^([^\s:][^:]*?):(\d+)(?:-(\d+))?"
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


def not_repo_relative(path, target):
    """Whether path is unsafe to resolve under target: absolute, a '..'
    segment, or (once joined to target) outside it. Checked without
    touching the filesystem for the absolute/'..' cases so a traversal
    attempt is rejected on its shape alone."""
    if os.path.isabs(path) or any(seg == ".." for seg in path.split("/")):
        return True
    resolved_target = os.path.realpath(target)
    resolved_path = os.path.realpath(os.path.join(target, path))
    return not (
        resolved_path == resolved_target
        or resolved_path.startswith(resolved_target + os.sep)
    )


def line_count(path, cache):
    """Number of lines in path, cached per run. Returns None (not counted,
    not BAD) for a file over MAX_LINE_COUNT_BYTES."""
    if path in cache:
        return cache[path]
    try:
        if os.path.getsize(path) > MAX_LINE_COUNT_BYTES:
            cache[path] = None
            return None
        with open(path, "rb") as f:
            n = sum(1 for _ in f)
    except OSError:
        n = None
    cache[path] = n
    return n


def validate(finding, target, line_cache, skipped):
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
    if not_repo_relative(path, target):
        return rule, key, evidence, "path is not repo-relative"
    resolved_target = os.path.realpath(target)
    full = os.path.join(resolved_target, path)
    if not os.path.isfile(full) or not exists_case_exact(resolved_target, path):
        return rule, key, evidence, "file not found (case-exact)"
    n_lines = line_count(full, line_cache)
    if n_lines is None:
        skipped.append((rule, key, evidence))
        return rule, key, evidence, None
    for n in lines:
        if n < 1 or n > n_lines:
            return rule, key, evidence, "line {} past end of file, has {} lines".format(n, n_lines)
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
    line_cache = {}
    skipped = []
    for finding in findings:
        rule, key, evidence, reason = validate(finding, args.target, line_cache, skipped)
        if reason:
            bad += 1
            print("BAD {} {} {} ({})".format(rule, key, evidence, reason))
    summary = "evidence: {}/{} valid".format(len(findings) - bad, len(findings))
    if skipped:
        summary += " ({} line count not checked: file over 5 MB)".format(len(skipped))
    print(summary)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
