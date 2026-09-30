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
finding's `summary` field; the row's Summary cell) that reads as a literal
the summary asserts is present is looked for on the evidence's (the row's
Evidence cell's) cited lines, in any citation group. A token reads as a
literal (trailing `.,;:` inside the backticks stripped first) when it has
no whitespace or `/`, is not purely digits or a lint code (`SC2086`), and
is 6+ characters or holds a digit, `=` or a quote, or holds a `.` without
naming a file (a file under --target, by path or basename, or a file
extension: hostnames and versions count, `form.yml` and `script.sh.erb`
do not). Bare short identifiers (`max`, `pattern`) are skipped. A token is
also skipped when its own sentence, before it, holds a negation or
recommendation word (NEGATION_WORDS: no, not, missing, absent, without,
lacks, lacking, should, recommend, recommended, add, consider, e.g., such
as, instead), since the summary then says the value is absent or
suggested. With --pre-review <dir>, a cited line that is a check-rows
candidate line (read through check-rows.py's candidates() over
<dir>/apps.json and checks.json; no tolerance when apps.json is absent) is
searched within +/-2 lines, because check-rows fixes the row at the
candidate site while the value it names can sit a line or two away. A
value not found gives `NOTE <rule> <defect_key> <evidence> (`<value>` is
not on <path>:<N>)`, citing the first cited line checked. It is a NOTE,
not a BAD, and does not change the exit code or the valid counts: over the
committed corpus the rule's precision was 64% (9 real of 14), under the
80% a BAD needs (VALUE_VERDICT). It is checked only where --target is given
and only for a group that already passed the path/line-existence checks
above.

A citation written `content: <path>:N` (the quality skill's form for a
Documentation rung met by a cited line rather than a matching heading)
must also cite content when the path is a README or Markdown file (its
basename starts with README, any case, or ends in .md; any other path gets
only the existence checks): each cited line must be what pre-review.py's
readme_line_kinds calls a content line (the one definition readme.json's
content_line_count counts), else `<path>:N is a heading, not content`, `is
inside a code fence`, `is a placeholder line`, `is blank`, and so on. This
applies to a finding's evidence, a `check:` row's Evidence cell and, with
--report, every other `content:` citation in the report text (the
Documentation "Evidence per rung" lines are not table rows); those
report-text citations are reported as `BAD report:content content
<citation> (<reason>)` and, when there are any, counted in the summary as
`; content citations: X/Y valid`. Checked only with --target.

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
import importlib.util
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from repo_paths import CITATION_RE, PSEUDO_ANCHORS, exists_case_exact, parse_citations  # noqa: E402
from report_parse import rows_by_check  # noqa: E402

MAX_LINE_COUNT_BYTES = 5 * 1024 * 1024  # 5 MB

BACKTICK_RE = re.compile(r"`([^`]+)`")
CONTENT_RE = re.compile(r"(?<![\w-])content:\s*[`*]*")
KIND_PHRASE = {
    "heading": "a heading", "fence": "inside a code fence", "comment": "an HTML comment",
    "blank": "blank", "placeholder": "a placeholder line", "contact": "a contact line",
    "badge": "a badge or image line", "table-header": "a table header row",
    "table-rule": "a table rule row",
}
_PRE_REVIEW = []
_KINDS = {}  # full path -> readme_line_kinds, per run


def pre_review():
    """pre-review.py, imported once, for readme_line_kinds and the
    placeholder phrases (the file name has a hyphen, so by path)."""
    if not _PRE_REVIEW:
        spec = importlib.util.spec_from_file_location("pre_review", os.path.join(SCRIPT_DIR, "pre-review.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _PRE_REVIEW.append((mod, mod.load_placeholders()))
    return _PRE_REVIEW[0]


def content_citations(text):
    """[(path, [lines], citation text), ...] for every citation written
    directly after `content:` in text."""
    out = []
    if not isinstance(text, str):
        return out
    for m in CONTENT_RE.finditer(text):
        c = CITATION_RE.match(text[m.end():])
        if c:
            out.append((c.group(1), parse_citations(c.group(0))[0][1], c.group(0).rstrip("`*")))
    return out


def is_markdown(path):
    """Whether a content: citation's path is one readme_line_kinds reads:
    a README (basename starts with README, any case) or a .md file."""
    base = os.path.basename(path)
    return base.lower().startswith("readme") or base.lower().endswith(".md")


def content_reason(path, full, lines, kinds_cache=_KINDS):
    """None when every cited line of full is a content line, else the
    reason naming the first line that is not."""
    if full not in kinds_cache:
        mod, placeholders = pre_review()
        try:
            with open(full, "rb") as f:
                text = f.read().decode("utf-8", "replace")
        except OSError:
            text = None
        kinds_cache[full] = None if text is None else mod.readme_line_kinds(text, placeholders)
    kinds = kinds_cache[full]
    if kinds is None:
        return None
    for n in lines:
        kind = kinds[n - 1] if 1 <= n <= len(kinds) else "blank"  # a trailing empty line
        if kind != "content":
            return "{}:{} is {}, not content".format(path, n, KIND_PHRASE.get(kind, kind))
    return None
LINT_CODE_RE = re.compile(r"^[A-Z]+[0-9]+$")
# BAD, or NOTE while the cited-value rule's corpus precision is under 80%
# (a NOTE line does not change the exit code or the valid counts). Measured
# 2026-09-30 over the eleven corpus runs: 9 real of 14 lines, 64%.
VALUE_VERDICT = "NOTE"

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


NEGATION_WORDS = {"no", "not", "missing", "absent", "without", "lacks", "lacking", "should",
                  "recommend", "recommended", "add", "consider", "e.g.", "such as", "instead"}
_NEGATION_RE = re.compile(
    r"(?<![\w.])(?:" + "|".join(sorted((re.escape(w).replace(r"\ ", r"\s+") for w in NEGATION_WORDS),
                                      key=len, reverse=True)) + r")(?![\w])", re.I)
# A sentence ends at '.', ';', '!' or '?' followed by whitespace, or at a
# newline; the dots of "e.g." and "i.e." do not end one.
_SENTENCE_END_RE = re.compile(r"(?<!\be\.g)(?<!\bi\.e)[.;!?](?=\s)|\n", re.I)
FILE_EXTENSIONS = {"yml", "yaml", "erb", "sh", "md", "py", "rb", "js", "json", "txt", "xml",
                   "html", "css", "toml", "cfg", "ini", "conf", "lock", "png", "svg", "jpg", "log"}
_TARGET_FILES = {}  # target -> (basenames, extensions) of every file under it


def target_files(target):
    """(basenames, extensions) of every file under target, .git excluded,
    cached per run."""
    if target not in _TARGET_FILES:
        names, exts = set(), set()
        for root, dirs, files in os.walk(target):
            dirs[:] = [d for d in dirs if d != ".git"]
            for name in files:
                names.add(name)
                if "." in name.lstrip("."):
                    exts.add(name.rsplit(".", 1)[1].lower())
        _TARGET_FILES[target] = (names, exts)
    return _TARGET_FILES[target]


def names_a_file(value, target):
    """Whether a dotted value is a file name rather than a literal: it names
    a file under target (by path or basename) or ends in a file extension
    (one a file under target carries, or a common one)."""
    names, exts = target_files(target) if target else (set(), set())
    if value in names or os.path.basename(value) in names:
        return True
    if target and os.path.isfile(os.path.join(target, value)):
        return True
    ext = value.rsplit(".", 1)[1].lower()
    return ext in FILE_EXTENSIONS or ext in exts


def is_literal(value, target=None):
    """Whether a backticked token reads as a literal value worth finding on
    the cited line: no whitespace, no '/', not purely digits, not a lint
    code, and then 6+ characters, or a digit, '=' or quote in it, or a '.'
    that does not make it a file name (hostnames and versions count;
    `form.yml` and `script.sh.erb` do not). A dotted token is never a
    literal on length alone. Bare short identifiers (`max`, `min`,
    `pattern`) are skipped: they name a key, often one the summary says is
    absent. No value is special-cased by name: only this shape test."""
    if not value or re.search(r"\s", value) or "/" in value or value.isdigit():
        return False
    if LINT_CODE_RE.match(value):
        return False
    if "." in value:
        return not names_a_file(value, target)
    return len(value) >= 6 or bool(re.search(r"[0-9=\"']", value))


def negated_before(text, start):
    """Whether the sentence holding text[start] has a NEGATION_WORDS word or
    phrase before that position ("no `max`", "recommend `--time=04:00:00`",
    "e.g. `--wrap=cmd`"): the value is then absent or suggested, not
    claimed to be on the cited line. Backticked spans before it are
    blanked so their contents are not read as words."""
    prefix = BACKTICK_RE.sub(lambda m: " " * len(m.group(0)), text[:start])
    ends = list(_SENTENCE_END_RE.finditer(prefix))
    sentence = prefix[ends[-1].end():] if ends else prefix
    return _NEGATION_RE.search(sentence) is not None


def cited_values(text, target=None):
    """Backtick-wrapped tokens in text that the summary asserts are present
    on the cited line: a literal (is_literal; trailing '.', ',', ';', ':'
    inside the backticks are stripped first) not preceded, in its own
    sentence, by a negation or recommendation word (negated_before)."""
    out = []
    if not isinstance(text, str):
        return out
    for m in BACKTICK_RE.finditer(text):
        v = m.group(1).strip().rstrip(".,;:")
        if not is_literal(v, target) or negated_before(text, m.start()):
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


def check_values(summary, groups, good_paths, text_cache, target=None, candidate_lines=frozenset()):
    """One '`<value>` is not on <path>:<N>' reason per cited value in summary
    (cited_values) not found on any line of any citation group that
    resolved to a real, checkable file (good_paths: {group path: full
    path}). A cited line that is a check-rows candidate line
    (candidate_lines: {(path, line)}) is searched within +/-2 lines, since
    check-rows fixes the row's line at the candidate site while the value
    the summary names can sit a line or two away (an attribute above the
    interpolation that uses it). The cited line reported is the first line
    of the first such group."""
    reasons = []
    checkable = []
    for path, lines in groups:
        if path not in good_paths:
            continue
        wide = set(lines)
        for n in lines:
            if (path, n) in candidate_lines:
                wide.update(range(max(1, n - 2), n + 3))
        checkable.append((path, good_paths[path], lines, sorted(wide)))
    if not checkable:
        return reasons
    for value in cited_values(summary, target):
        if any(value_on_lines(value, full, wide, text_cache) for _, full, _, wide in checkable):
            continue
        path, _, lines, _ = checkable[0]
        reasons.append("`{}` is not on {}:{}".format(value, path, lines[0]))
    return reasons


def validate(finding, target, line_cache, skipped, text_cache=None, candidate_lines=frozenset()):
    """(rule, key, evidence, [reason, ...], [value reason, ...]) — one reason
    per BAD citation group, and (when text_cache is given and every group is
    fine) one value reason per cited value in `summary` not found on any
    cited line (check_values)."""
    rule = finding.get("rule") or "<missing>"
    key = finding.get("defect_key") or "<missing>"
    evidence = finding.get("evidence")
    groups = parse_citations(evidence)
    content = content_citations(evidence)
    # `content:README.md:3` (no space) is not a citation to parse_citations
    groups += [(p, l) for p, l, _ in content if (p, l) not in groups]
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
    if text_cache is not None:
        for path, lines, _ in content:
            if path in good_paths and is_markdown(path):
                reason = content_reason(path, good_paths[path], lines)
                if reason:
                    reasons.append(reason)
    values = []
    if text_cache is not None and not reasons:
        values = check_values(finding.get("summary"), groups, good_paths, text_cache, target, candidate_lines)
    return rule, key, evidence, reasons, values


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


def validate_row(check_id, evidence, summary, target, line_cache, skipped, text_cache,
                 candidate_lines=frozenset()):
    """Like validate(), for one report row."""
    return validate(
        {"rule": "report:" + check_id, "defect_key": check_id, "evidence": evidence, "summary": summary},
        target, line_cache, skipped, text_cache, candidate_lines)


def candidate_lines(pre_review_dir):
    """{(path, line)} of every check-rows candidate site with a line, over
    every app in <pre_review_dir>/apps.json and every check in checks.json,
    read through check-rows.py's own candidates() so the two cannot drift.
    Empty when apps.json or checks.json is absent or unreadable (facts
    written before apps.json existed): the tolerance then never applies."""
    try:
        with open(os.path.join(pre_review_dir, "apps.json"), encoding="utf-8") as f:
            apps = json.load(f)
        with open(os.path.join(SCRIPT_DIR, "checks.json"), encoding="utf-8") as f:
            checks = json.load(f).get("checks")
    except (OSError, ValueError, AttributeError):
        return frozenset()
    if not isinstance(apps, list) or not isinstance(checks, list):
        return frozenset()
    spec = importlib.util.spec_from_file_location("check_rows", os.path.join(SCRIPT_DIR, "check-rows.py"))
    rows_mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(rows_mod)
    out = set()
    for app in apps:
        if not isinstance(app, dict) or not app.get("app_id"):
            continue
        for check in checks:
            if not isinstance(check, dict) or not check.get("id"):
                continue
            for _, cites, _ in rows_mod.candidates(check, app, pre_review_dir):
                out.update((p, n) for p, n in cites if isinstance(n, int))
    return frozenset(out)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("findings")
    ap.add_argument("--target", default=None, help="reviewed repo checkout; enables file/line existence checks")
    ap.add_argument("--report", default=None, help="review report .md; also checks its `check:`-marked table rows")
    ap.add_argument("--pre-review", default=None, dest="pre_review",
                    help="pre-review output dir; a cited value may sit within 2 lines of a candidate line")
    args = ap.parse_args(argv[1:])
    if args.target is not None and (not args.target or not os.path.isdir(args.target)):
        # An empty --target would silently mean the cwd and reject every real path.
        print("error: --target is not a directory: '{}'".format(args.target), file=sys.stderr)
        return 2
    if args.pre_review is not None and (not args.pre_review or not os.path.isdir(args.pre_review)):
        print("error: --pre-review is not a directory: '{}'".format(args.pre_review), file=sys.stderr)
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
    cands = candidate_lines(args.pre_review) if args.pre_review else frozenset()
    line_cache = {}
    skipped = []
    text_cache = {} if args.target is not None else None

    def report(rule, key, evidence, reasons, values):
        """Print one line per reason; whether this finding or row counts as
        not valid."""
        for reason in reasons:
            print("BAD {} {} {} ({})".format(rule, key, evidence, reason))
        for reason in values:
            print("{} {} {} {} ({})".format(VALUE_VERDICT, rule, key, evidence, reason))
        return bool(reasons) or (bool(values) and VALUE_VERDICT == "BAD")

    bad = 0
    for finding in findings:
        bad += report(*validate(finding, args.target, line_cache, skipped, text_cache, cands))
    summary = "evidence: {}/{} valid".format(len(findings) - bad, len(findings))
    if report_text is not None:
        rows = report_rows(report_text)
        row_bad = 0
        for check_id, evidence, row_summary in rows:
            row_bad += report(*validate_row(check_id, evidence, row_summary, args.target, line_cache,
                                            skipped, text_cache, cands))
        summary += "; report rows: {}/{} valid".format(len(rows) - row_bad, len(rows))
        bad += row_bad
        if args.target is not None:
            prose = "\n".join(l for l in report_text.splitlines() if not l.lstrip().startswith("|"))
            cites = content_citations(prose)
            content_bad = 0
            for _, _, cite in cites:
                rule, key, ev, reasons, _ = validate(
                    {"rule": "report:content", "defect_key": "content", "evidence": "content: " + cite},
                    args.target, line_cache, skipped, text_cache)
                content_bad += report(rule, key, ev, reasons, [])
            if cites:
                summary += "; content citations: {}/{} valid".format(len(cites) - content_bad, len(cites))
            bad += content_bad
    if skipped:
        summary += " ({} line count not checked: file over 5 MB)".format(len(skipped))
    print(summary)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
