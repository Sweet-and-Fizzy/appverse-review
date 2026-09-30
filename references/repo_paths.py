"""Shared repo-path helpers for the finding checkers: the fixed pseudo-anchor
set and a case-exact existence check (check-keys.py, check-evidence.py), and
the one citation parser, parse_citations (check-rows.py, check-evidence.py,
compare-runs.py). The scripts import this module instead of keeping their
own copy, so the pseudo-anchor list and the citation grammar cannot drift.

Each script's own directory is already on sys.path when it runs by path
(python's default for a script argument), so `from repo_paths import ...`
resolves whether check-keys.py or check-evidence.py is the one running.
"""
import os
import re

PSEUDO_ANCHORS = {
    "LICENSE", "README.md", "CHANGELOG.md", ".github/workflows",
    "releases", "issues", "contributors", "commits", "root",
}


def exists_case_exact(root, anchor):
    """Whether anchor (repo-relative) exists under root with every segment's
    case matching exactly. os.path.exists is case-insensitive on some
    filesystems (APFS default, most of Windows), which would let
    'readme.md:readme-typo' validate locally and fail in CI or vice versa.
    Walk the anchor's segments and require each to appear byte-for-byte in
    os.listdir() of its parent."""
    current = root
    for seg in anchor.split("/"):
        try:
            entries = os.listdir(current)
        except OSError:
            return False
        if seg not in entries:
            return False
        current = os.path.join(current, seg)
    return True


# ---- citations ------------------------------------------------------------
#
# One grammar for check-rows.py, check-evidence.py and compare-runs.py. A
# citation is a path, a colon and a line list:
#   path:N   path:N-M   path:N–M (en dash)   path:N,M   (and comma lists of
#   those, spaces allowed around ',' and the dash).
# Several groups may sit in one cell, separated by ';', whitespace or prose.
# The path may be wrapped in backticks or */** emphasis (`a.sh:3`, `a.sh`:3,
# **a.sh**:3) and may carry a leading ./, which is dropped. A path must
# contain a letter (so 12:30 and 0.0.0.0:5000 are not citations) and may not
# follow a path character or a colon (so http://host:8080 is not one, and
# other/a.sh:1 is never read as a.sh:1). A line list followed by '.<digit>'
# is a version, not a line (ruby:3.1). "a.sh: line 3" and "a.sh line 3" are
# prose, not citations: the digits must be glued to the colon.

_PATH = r"[\w./@+~-]*[A-Za-z][\w./@+~-]*"
_SPEC = r"\d+(?:\s*[-–]\s*\d+)?(?!\d)"
_LIST = _SPEC + r"(?:\s*,\s*" + _SPEC + r")*"
CITATION_RE = re.compile(
    r"(?<![\w./:@+~-])(?:\./)?(" + _PATH + r")[`*]*:[`*]*(" + _LIST + r")(?!\.\d)")
REVIEWED_OK_RE = re.compile(r";\s*reviewed OK\s*:", re.I)
MAX_RANGE_EXPAND = 10000


def _lines(spec):
    out = []
    for piece in spec.split(","):
        nums = [int(x) for x in re.findall(r"\d+", piece)]
        if not nums:
            continue
        lo, hi = min(nums), max(nums)
        if hi - lo > MAX_RANGE_EXPAND:
            out.extend([lo, hi])  # an absurd range: its endpoints only
        else:
            out.extend(range(lo, hi + 1))
    return out


def parse_citations(text):
    """[(path, [lines]), ...], one entry per citation group in text, in
    order. Ranges are expanded (N-M gives every line from N to M; a range
    wider than MAX_RANGE_EXPAND gives its two endpoints); a comma list gives
    each item. Non-string input gives []."""
    if not isinstance(text, str):
        return []
    return [(m.group(1), _lines(m.group(2))) for m in CITATION_RE.finditer(text)]


def split_reviewed_ok(text):
    """(main, reviewed_ok) of a cell: the text before and after a
    '; reviewed OK:' marker ('' when there is none). The reviewed-OK part is
    the PASS portion of the same cell."""
    if not isinstance(text, str):
        return "", ""
    m = REVIEWED_OK_RE.search(text)
    if not m:
        return text, ""
    return text[:m.start()], text[m.end():]
