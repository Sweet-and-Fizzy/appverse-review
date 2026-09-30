#!/usr/bin/env python3
"""Validate every finding's evidence citation against the reviewed repo.

    python3 references/check-evidence.py review-<slug>.findings.json --target <repo-dir>

A finding's `evidence` is free text. Every citation group in it is
validated, not only a leading one: repo_paths.parse_citations (the grammar
check-rows.py and compare-runs.py share) finds each `path:N`, `path:N-M`,
`path:N–M` or `path:N,M` anywhere in the string, the `; reviewed OK:`
segment included, with a leading `./`, wrapping backticks and `*`/`**`
emphasis stripped from the path. Anything after the line list (another
`:...`, trailing prose) is not part of the citation, so `"form.yml:12:extra"`
is read as `form.yml` line 12. Each path must name a real file under
--target (matched case-exactly: `readme.md` does not stand in for
`README.md`, since some filesystems accept that locally and CI would not)
and every cited line, every comma item and both ends of every range, must
be within that file's length (1-indexed; 0 and anything past EOF is BAD).

A bare word with no `/` or `.` that is not a pseudo-anchor (`python:3` in a
quoted command) is validated only when it names a real file under --target
(`Dockerfile:3`); otherwise it is prose and left alone.

A pseudo-anchor (the same fixed set check-keys.py treats as not-a-real-file:
LICENSE, README.md, CHANGELOG.md, .github/workflows, releases, issues,
contributors, commits, root — imported from repo_paths so the two scripts
cannot drift) citing a line number is BAD only when that path does not also
exist as a real, case-exact file under --target. Some pseudo-anchors
(README.md, CHANGELOG.md, LICENSE) commonly ARE real files too, and a
Documentation or Structure finding must be able to cite a line of one (e.g.
"README.md:2"); others (releases, issues, contributors, commits, root,
.github/workflows-as-a-bare-string) are never real files, so a line number
against one of those stays BAD. When the pseudo-anchor path does exist as a
file, it is validated exactly like any other path (case-exact existence,
line within length). Without --target there is no way to tell which case
applies, so a pseudo-anchor citing a line stays BAD in format-only mode. The
bare pseudo-anchor by itself (no line, as in "GitHub releases API: 0") is
always fine regardless — that phrase does not match the `<path>:<n>` shape
at all, since the digits are not glued to the anchor with a colon.

The cited path must also be repo-relative: absolute paths, a `..` segment,
or a path that otherwise resolves outside --target are BAD ("path is not
repo-relative"), never walked out to the real filesystem.

Evidence with no citation group (a free-text phrase, a bare filename with
no line, "(no file)", etc.) is left alone; this script only checks the
citations it can parse as a file:line reference.

Without --target, only the citation shape, path-hygiene, and
pseudo-anchor rules are checked; file existence and line-length are skipped
(nothing to check them against).

Line counts are cached per path for the run (a file cited by several
findings is read once). A file over 5 MB is not read for a line count at
all — counted as "not checked" (reported in the summary line, not treated
as BAD) rather than paying to scan a large file just to bound-check a
citation.

Exit 0 when every evidence citation is valid, 1 when any is not (one BAD
line per bad citation group, in the form `BAD <rule> <defect_key>
<evidence> (<reason>)`; when the evidence has more than one group the
reason starts with the group's path, `(template/nope.sh: file not found
(case-exact))`). The summary counts findings: a finding is valid when all
its groups are.
2 when the input cannot be read or is malformed.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_paths import PSEUDO_ANCHORS, exists_case_exact, parse_citations  # noqa: E402

MAX_LINE_COUNT_BYTES = 5 * 1024 * 1024  # 5 MB

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


def check_group(path, lines, target, line_cache, skipped):
    """The reason one citation group is BAD, or None. Appends to skipped
    when the file is too large to count."""
    is_pseudo = path in PSEUDO_ANCHORS
    bare = "/" not in path and "." not in path and not is_pseudo
    if target is None:
        # Some pseudo-anchors (README.md, CHANGELOG.md, LICENSE) are also
        # real files a Documentation/Structure finding may legitimately cite
        # a line of; others (releases, commits, root, ...) never are. Without
        # --target there's no way to tell the two apart, so a pseudo-anchor
        # citing a line stays BAD in format-only mode.
        return "pseudo-anchor, not a file" if is_pseudo else None
    if not_repo_relative(path, target):
        return "path is not repo-relative"
    resolved_target = os.path.realpath(target)
    full = os.path.join(resolved_target, path)
    if not os.path.isfile(full) or not exists_case_exact(resolved_target, path):
        if bare:
            return None  # a bare word that is not a file is prose (python:3)
        if is_pseudo:
            return "pseudo-anchor, not a file"
        return "file not found (case-exact)"
    n_lines = line_count(full, line_cache)
    if n_lines is None:
        skipped.append(path)
        return None
    low = [n for n in lines if n < 1]
    high = [n for n in lines if n > n_lines]
    if low or high:
        n = low[0] if low else max(high)
        return "line {} past end of file, has {} lines".format(n, n_lines)
    return None


def validate(finding, target, line_cache, skipped):
    """(rule, key, evidence, [reason, ...]) — one reason per BAD group."""
    rule = finding.get("rule") or "<missing>"
    key = finding.get("defect_key") or "<missing>"
    evidence = finding.get("evidence")
    groups = parse_citations(evidence)
    reasons = []
    before = len(skipped)
    for path, lines in groups:
        reason = check_group(path, lines, target, line_cache, skipped)
        if reason:
            reasons.append(reason if len(groups) == 1 else "{}: {}".format(path, reason))
    if len(skipped) > before:
        del skipped[before + 1:]  # count a finding once in the not-checked tally
    return rule, key, evidence, reasons


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
        rule, key, evidence, reasons = validate(finding, args.target, line_cache, skipped)
        if reasons:
            bad += 1
        for reason in reasons:
            print("BAD {} {} {} ({})".format(rule, key, evidence, reason))
    summary = "evidence: {}/{} valid".format(len(findings) - bad, len(findings))
    if skipped:
        summary += " ({} line count not checked: file over 5 MB)".format(len(skipped))
    print(summary)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
