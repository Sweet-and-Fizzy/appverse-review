#!/usr/bin/env python3
"""Validate every finding's evidence citation against the reviewed repo.

    python3 references/check-evidence.py review-<slug>.findings.json --target <repo-dir> [--report <report.md>]

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

A cited value must actually be on the line it is cited against. For every
finding, and (when --report is given) for every report table row that
carries a `check:` marker, each backtick-wrapped token in the summary (the
finding's `summary` field; the row's Summary cell) that looks like a
specific value rather than a code, a path or a number — a single token (no
spaces), 3 or more characters, not purely numeric, not a short two-letter
token, and not itself shaped like a path (containing `/` or `.`, which
would make `form.yml` or `template/script.sh.erb` a false positive) or a
lint code (uppercase letters followed directly by digits, shellcheck's
`SC2086` shape) — must occur as a substring on at least one line of the
evidence's (the row's Evidence cell's) cited range, in any citation group.
Otherwise `BAD <rule> <defect_key> <evidence> (`<value>` is not on
<path>:<N>)`, one line per offending value, citing the first cited line
that was checked. This catches a citation whose line is right but whose
quoted value is wrong (a stale line number after an edit, a copy-paste
from the wrong row) as well as a right value cited against the wrong line.
It is checked only where --target is given (nothing to read the line
against otherwise) and only for a group that already passed the
path/line-existence checks above (an already-BAD group is not also
value-checked).

Exit 0 when every evidence citation is valid, 1 when any is not (one BAD
line per bad citation group, in the form `BAD <rule> <defect_key>
<evidence> (<reason>)`; when the evidence has more than one group the
reason starts with the group's path, `(template/nope.sh: file not found
(case-exact))`). The summary counts findings: a finding is valid when all
its groups are, and (with --report) all its report rows are too.
2 when the input cannot be read or is malformed, or --report names a file
that cannot be read.
"""
import argparse
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from repo_paths import PSEUDO_ANCHORS, exists_case_exact, parse_citations  # noqa: E402
from report_parse import rows_by_check  # noqa: E402

MAX_LINE_COUNT_BYTES = 5 * 1024 * 1024  # 5 MB

BACKTICK_RE = re.compile(r"`([^`]+)`")
LINT_CODE_RE = re.compile(r"^[A-Z]+[0-9]+$")

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


def cited_values(text):
    """Backtick-wrapped tokens in text that look like a specific cited value
    rather than a code, a path or a number: a single token (no whitespace),
    3+ characters, not purely digits, not a two-letter token, not shaped
    like a path (a '/' or '.' in it — so `form.yml` and
    `template/script.sh.erb` are never candidates), and not shaped like a
    lint code (uppercase letters immediately followed by digits, `SC2086`
    or `E501`). No value is special-cased by name: only this shape test."""
    out = []
    if not isinstance(text, str):
        return out
    for m in BACKTICK_RE.finditer(text):
        v = m.group(1)
        if not v or " " in v or "\t" in v or len(v) < 3:
            continue
        if v.isdigit():
            continue
        if "/" in v or "." in v:
            continue
        if LINT_CODE_RE.match(v):
            continue
        out.append(v)
    return out


def line_text(path, n, cache):
    """The 1-indexed line n of path, or None when the file is not cached
    with line text (over MAX_LINE_COUNT_BYTES, unreadable, or n out of
    range). Caches the whole file's lines, keyed separately from
    line_count's cache since most citations never need line text."""
    if path not in cache:
        try:
            if os.path.getsize(path) > MAX_LINE_COUNT_BYTES:
                cache[path] = None
            else:
                with open(path, "rb") as f:
                    cache[path] = [line.decode("utf-8", "replace") for line in f.read().splitlines()]
        except OSError:
            cache[path] = None
    lines = cache[path]
    if lines is None or n < 1 or n > len(lines):
        return None
    return lines[n - 1]


def value_on_lines(value, path, lines, text_cache):
    """Whether value occurs as a substring on at least one of lines (1-
    indexed) of path. False when none of the lines could be read."""
    for n in lines:
        text = line_text(path, n, text_cache)
        if text is not None and value in text:
            return True
    return False


def check_group(path, lines, target, line_cache, skipped):
    """(reason, full_path) for one citation group: reason is None when the
    group is fine, full_path is the resolved file path when the group
    named a real, checkable file (None otherwise: a bare prose word, a
    pseudo-anchor, or a BAD group) so a caller can reuse it for a value
    check without re-resolving. Appends to skipped when the file is too
    large to count."""
    is_pseudo = path in PSEUDO_ANCHORS
    bare = "/" not in path and "." not in path and not is_pseudo
    if target is None:
        # Some pseudo-anchors (README.md, CHANGELOG.md, LICENSE) are also
        # real files a Documentation/Structure finding may legitimately cite
        # a line of; others (releases, commits, root, ...) never are. Without
        # --target there's no way to tell the two apart, so a pseudo-anchor
        # citing a line stays BAD in format-only mode.
        return ("pseudo-anchor, not a file" if is_pseudo else None), None
    if not_repo_relative(path, target):
        return "path is not repo-relative", None
    resolved_target = os.path.realpath(target)
    full = os.path.join(resolved_target, path)
    if not os.path.isfile(full) or not exists_case_exact(resolved_target, path):
        if bare:
            return None, None  # a bare word that is not a file is prose (python:3)
        if is_pseudo:
            return "pseudo-anchor, not a file", None
        return "file not found (case-exact)", None
    n_lines = line_count(full, line_cache)
    if n_lines is None:
        skipped.append(path)
        return None, None
    low = [n for n in lines if n < 1]
    high = [n for n in lines if n > n_lines]
    if low or high:
        n = low[0] if low else max(high)
        return "line {} past end of file, has {} lines".format(n, n_lines), None
    return None, full


def check_values(summary, groups, good_paths, text_cache):
    """One '`<value>` is not on <path>:<N>' reason per backtick value in
    summary not found on any line of any citation group that resolved to a
    real, checkable file (good_paths: {group path: full path}). The cited
    line reported is the first line of the first such group."""
    reasons = []
    checkable = [(path, good_paths[path], lines) for path, lines in groups if path in good_paths]
    if not checkable:
        return reasons
    for value in cited_values(summary):
        if any(value_on_lines(value, full, lines, text_cache) for _, full, lines in checkable):
            continue
        path, _, lines = checkable[0]
        reasons.append("`{}` is not on {}:{}".format(value, path, lines[0]))
    return reasons


def validate(finding, target, line_cache, skipped, text_cache=None):
    """(rule, key, evidence, [reason, ...]) — one reason per BAD citation
    group, plus (when text_cache is given and every group is fine) one per
    backtick value in `summary` not found on any cited line."""
    rule = finding.get("rule") or "<missing>"
    key = finding.get("defect_key") or "<missing>"
    evidence = finding.get("evidence")
    groups = parse_citations(evidence)
    reasons = []
    good_paths = {}
    before = len(skipped)
    for path, lines in groups:
        reason, full = check_group(path, lines, target, line_cache, skipped)
        if reason:
            reasons.append(reason if len(groups) == 1 else "{}: {}".format(path, reason))
        elif full:
            good_paths[path] = full
    if len(skipped) > before:
        del skipped[before + 1:]  # count a finding once in the not-checked tally
    if text_cache is not None and not reasons:
        reasons.extend(check_values(finding.get("summary"), groups, good_paths, text_cache))
    return rule, key, evidence, reasons


def report_rows(text):
    """[(check_id, evidence, summary), ...] for every table row, in any
    '## App:' section or not, that carries a `check:` marker in its Check
    column and a recognized Result. report_parse.rows_by_check walks tables
    the same way (split_row/is_separator/header_name/MARKER) and, since it
    keeps each row's Summary cell too, scanning the whole report text with
    it (it does not care about '## App:' boundaries) gives the same rows;
    this just flattens its {check_id: [row, ...]} grouping back into one
    tuple per row."""
    out = []
    for cid, rows in rows_by_check(text).items():
        for row in rows:
            out.append((cid, row["evidence"], row["summary"]))
    return out


def validate_row(check_id, evidence, summary, target, line_cache, skipped, text_cache):
    """Like validate(), for one report row: (check_id, evidence, [reason,
    ...])."""
    rule, key, ev, reasons = validate(
        {"rule": "report:" + check_id, "defect_key": check_id, "evidence": evidence, "summary": summary},
        target, line_cache, skipped, text_cache)
    return rule, key, ev, reasons


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("findings")
    ap.add_argument("--target", default=None, help="reviewed repo checkout; enables file/line existence checks")
    ap.add_argument("--report", default=None, help="review report .md; also checks its `check:`-marked table rows")
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
    report_text = None
    if args.report is not None:
        try:
            with open(args.report, encoding="utf-8") as f:
                report_text = f.read()
        except OSError as e:
            print("error: {}".format(e), file=sys.stderr)
            return 2
    bad = 0
    line_cache = {}
    skipped = []
    text_cache = {} if args.target is not None else None
    for finding in findings:
        rule, key, evidence, reasons = validate(finding, args.target, line_cache, skipped, text_cache)
        if reasons:
            bad += 1
        for reason in reasons:
            print("BAD {} {} {} ({})".format(rule, key, evidence, reason))
    summary = "evidence: {}/{} valid".format(len(findings) - bad, len(findings))
    if report_text is not None:
        rows = report_rows(report_text)
        row_bad = 0
        for check_id, evidence, row_summary in rows:
            rule, key, ev, reasons = validate_row(check_id, evidence, row_summary, args.target, line_cache, skipped, text_cache)
            if reasons:
                row_bad += 1
            for reason in reasons:
                print("BAD {} {} {} ({})".format(rule, key, ev, reason))
        summary += "; report rows: {}/{} valid".format(len(rows) - row_bad, len(rows))
        bad += row_bad
    if skipped:
        summary += " ({} line count not checked: file over 5 MB)".format(len(skipped))
    print(summary)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
