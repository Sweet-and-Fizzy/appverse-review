"""Shared report-table parsing for the finding checkers: splitting a review
report into its '## App:' sections and reading the Markdown tables inside
them into rows keyed by `check: <id>` marker. check-rows.py, check-rating.py
and compare-runs.py all read the same report shape; this module is the one
implementation, so their section and row parsing cannot drift the way
check-rating's own `app_sections` (which ended a section at the literal
"\\n## ") and check-rows' (the regex `^## `) once did — the regex form is
kept here, the two differing only in whether a body keeps its trailing
newline before the next heading, which no caller's pattern (always run with
re.M/re.S) depends on.

Each script's own directory is already on sys.path when it runs by path
(python's default for a script argument), so `from report_parse import ...`
resolves the same way `from repo_paths import ...` does.
"""
import argparse
import os
import re

# Exit code for "the report lacks a section this checker needs": a malformed
# report the repair can fix, not a tooling failure (exit 2). check-all.py
# reads the code, never the wording of the error line.
MALFORMED = 3

MARKER = re.compile(r"`check:\s*([A-Za-z0-9_.-]+)`")
RESULTS = ("NOT CHECKED", "FAIL", "WARN", "PASS")
RESULT_RE = re.compile(r"[^A-Z]*(" + "|".join(RESULTS).replace(" ", r"\s+") + r")(?![A-Z])")


def split_row(line):
    """Cells of a table row. A '|' escaped as '\\|' or inside a backtick code
    span (`a | b`, closed by the same number of backticks) does not split."""
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|") and not s.endswith("\\|"):
        s = s[:-1]
    cells, cur, i, fence = [], [], 0, 0
    while i < len(s):
        ch = s[i]
        if ch == "\\" and i + 1 < len(s):
            cur.append(s[i:i + 2])
            i += 2
            continue
        if ch == "`":
            j = i
            while j < len(s) and s[j] == "`":
                j += 1
            run = j - i
            if fence == 0:
                if "`" * run in s[j:]:
                    fence = run  # opens only when a closing run follows
            elif run == fence:
                fence = 0
            cur.append(s[i:j])
            i = j
            continue
        if ch == "|" and fence == 0:
            cells.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
        i += 1
    cells.append("".join(cur).strip())
    return cells


def is_separator(line):
    cells = split_row(line)
    return bool(cells) and all(re.fullmatch(r":?-{1,}:?", c) for c in cells)


def header_name(cell):
    return re.sub(r"[*_`]", "", cell).strip().lower()


def normalize_result(cell):
    """FAIL, WARN, PASS or NOT CHECKED from the cell's leading token, else None."""
    m = RESULT_RE.match(re.sub(r"[*_`]", "", cell).upper())
    return re.sub(r"\s+", " ", m.group(1)) if m else None


def rows_by_check(body):
    """{check_id: [{"result", "severity", "evidence", "summary"}, ...]} from
    tables with a Check column. Evidence runs from the Evidence column to the
    end of the row when the row has more cells than the header."""
    rows = {}
    lines = body.splitlines()
    i = 0
    while i < len(lines):
        if lines[i].lstrip().startswith("|") and i + 1 < len(lines) and is_separator(lines[i + 1]):
            head = [header_name(c) for c in split_row(lines[i])]
            i += 2
            if "check" not in head:
                while i < len(lines) and lines[i].lstrip().startswith("|"):
                    i += 1
                continue
            ci = head.index("check")
            ri = head.index("result") if "result" in head else None
            ei = head.index("evidence") if "evidence" in head else None
            si = head.index("severity") if "severity" in head else None
            sui = head.index("summary") if "summary" in head else None
            while i < len(lines) and lines[i].lstrip().startswith("|"):
                cells = split_row(lines[i])
                get = lambda k: cells[k] if k is not None and k < len(cells) else ""
                result = normalize_result(get(ri))
                if result is None:
                    i += 1
                    continue
                evidence = get(ei)
                if ei is not None and len(cells) > len(head):
                    evidence = " | ".join(cells[ei:])
                row = {"result": result, "severity": get(si), "evidence": evidence,
                       "summary": get(sui)}
                for cid in MARKER.findall(get(ci)):
                    rows.setdefault(cid, []).append(row)
                i += 1
            continue
        i += 1
    return rows


def app_sections(text):
    """[(heading, paren_value, body)] for each '## App:' section."""
    parts = re.split(r"^(## App:[^\n]*)$", text, flags=re.M)
    out = []
    for i in range(1, len(parts) - 1, 2):
        body = re.split(r"^## ", parts[i + 1], maxsplit=1, flags=re.M)[0]
        m = re.search(r"\(([^()]*)\)\s*$", parts[i].strip())
        out.append((parts[i].strip(), m.group(1).strip() if m else None, body))
    return out


def section_for(app, sections, single):
    keys = {app["app_id"], (app.get("path") or "").strip().strip("/"),
            _app_prefix(app).rstrip("/")}
    keys.discard("")
    for _, key, body in sections:
        if key is not None and key.strip("/") in keys:
            return body
    if single and len(sections) == 1:
        return sections[0][2]
    return None


def _app_prefix(app):
    p = (app.get("path") or ".").strip().strip("/")
    p = p[2:] if p.startswith("./") else p
    return "" if p in ("", ".") else p + "/"


# The four review outcomes, mildest first. Every checker that reads a decision
# (check-meta, check-decisions, check-sections) normalizes it here, so they
# cannot disagree about whether "request_changes" or "Request  changes" is valid.
def defect_tag(defect_key):
    """The mechanism tag out of a defect_key: the part after the first ':'
    (the anchor), truncated before any further ':' qualifier."""
    key = str(defect_key or "")
    tag = key.split(":", 1)[1] if ":" in key else key
    return tag.split(":", 1)[0]


def is_gate_finding(finding):
    """A Structure gate row: an STR rule, whichever aspect filed it, unless it
    is an `other:` note, which the structure skill adds after the checks for
    anything else worth a look (review-structure SKILL.md) and is not a gate."""
    rule = str(finding.get("rule", "")).strip().upper()
    return rule.startswith("STR") and defect_tag(finding.get("defect_key")) != "other"


DECISIONS = ("accept", "accept with suggestions", "request changes", "reject")
DECISION_NAMES = {"accept": "Accept", "accept with suggestions": "Accept with suggestions",
                  "request changes": "Request changes", "reject": "Reject"}


def normalize_decision(value):
    """The canonical lower-case decision for a string such as "Request changes"
    or "request_changes", or None when it is not one of the four."""
    if not isinstance(value, str):
        return None
    key = re.sub(r"[\s_-]+", " ", value.strip().strip("*_.:").lower())
    return key if key in DECISION_NAMES else None


def decision_rank(value):
    """0 (Accept) to 3 (Reject), or None for anything normalize_decision rejects."""
    key = normalize_decision(value)
    return DECISIONS.index(key) if key else None


def section(text, title, level=2):
    """Body of the '#'*level + ' <title>' heading up to the next heading of the
    same level, or None when the report has no such heading. Case-insensitive;
    the heading may carry more words after the title ("## Overall
    recommendation (pending the duplicate check)")."""
    hashes = "#" * level
    m = re.search(r"^" + hashes + " " + re.escape(title) + r"\b[^\n]*$(.*?)(?=^" + hashes + r" |\Z)",
                  text, re.M | re.S | re.I)
    return m.group(1) if m else None


def positional_args(argv, required, optional=(), description=None):
    """Parse a checker's positional arguments with argparse, so every checker
    takes --help and reports a bad call the same way. Returns argv with the
    given values ([prog, *required, *optional present]), or an exit code:
    0 after --help, 2 for a bad call (argparse prints the usage)."""
    ap = argparse.ArgumentParser(prog=os.path.basename(argv[0]), description=description)
    for name in required:
        ap.add_argument(name)
    for name in optional:
        ap.add_argument(name, nargs="?")
    try:
        ns = ap.parse_args(argv[1:])
    except SystemExit as e:
        return int(e.code or 0)
    values = [getattr(ns, n) for n in list(required) + list(optional)]
    while values and values[-1] is None:
        values.pop()
    return [argv[0]] + values
