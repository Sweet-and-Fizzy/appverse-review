#!/usr/bin/env python3
"""Check that every FAIL or WARN row in an app's report section is backed by a
finding record: one of its rule, at its result or worse, whose evidence
carries a line the row cites.

    python3 references/check-row-records.py <report.md> <findings.json> <pre-review-dir>

A row is a Markdown table row, inside an app's "## App: <name> (<app_id>)"
section, in a table whose header has Rule and Result columns, whose Rule
cell is a rule code (STR-04, OODT-01, ...) and whose Result leads with FAIL
or WARN once markdown is stripped ("**WARN** (low)" is WARN). The hub's
criteria and the draft feedback come from findings.json, so a row the
records do not back shows a failure only the report reader sees. A repair
that removes or downgrades a record and leaves its row does this.

A record backs a row when its app_id is the section's app, or root (a
repo-level record, such as the maintainer fields, shows in each app's
section); its rule is the row's; its result is the row's or worse (FAIL >
WARN), since the record merge rule gives a record merging several
candidates the worst result while the rows stay per candidate; and, when
the row cites a path:N, its evidence cites one of the same lines. A line
after "reviewed OK:" is a PASS line and backs nothing. A row that cites no
line is backed by rule and result alone. Paths compare whole; outside a
single-app repo a repo path and an app path match. Each row no record backs
is one of

    MISMATCH <app_id> <rule> <result> row (<check marker>, <first citation>): findings.json has no <rule> record at <result> for this app; its <rule> records are <results>
    MISMATCH <app_id> <rule> <result> row (...): findings.json has no <rule> record at <result> for this app; it has no <rule> record
    MISMATCH <app_id> <rule> <result> row (...): no <rule> record at <result> or worse for this app cites <path:N>
 A `check: portability-rating` row is never judged: the quality
skill has it cite the hardcoded-* records that set it and add no record of
its own. PASS and NOT CHECKED rows, rows whose Rule is not a rule code (a
PASS tool row's "—"), and tables outside the app sections are not judged.
A record without a row is not checked: repo-level and upkeep records are
reported outside the app sections.

The apps come from <pre-review-dir>/apps.json; without it, each section's
own id names its app. The last line is "row-records: N app(s), R FAIL/WARN
row(s), P problem(s)". Exit 0 when every row is backed, 1 with a MISMATCH
line per unbacked row, 2 when the report or findings cannot be read.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_paths import parse_citations, split_reviewed_ok  # noqa: E402
from report_parse import (  # noqa: E402
    MARKER, app_sections, header_name, is_separator, normalize_result, positional_args, section_for, split_row,
)

RULE_RE = re.compile(r"^[A-Z]+-[0-9]+$")
UNJUDGED_CHECKS = {"portability-rating"}
RANK = {"WARN": 1, "FAIL": 2}


def plain(cell):
    return re.sub(r"[*_`]", "", cell or "").strip().upper()


def judged_rows(body):
    """[(rule, result, cells_text, check_ids, evidence)] for the FAIL/WARN rows
    of the section's tables that have Rule and Result columns."""
    out = []
    lines = body.splitlines()
    i = 0
    while i < len(lines):
        if not (lines[i].lstrip().startswith("|") and i + 1 < len(lines) and is_separator(lines[i + 1])):
            i += 1
            continue
        head = [header_name(c) for c in split_row(lines[i])]
        i += 2
        ok = "rule" in head and "result" in head
        while i < len(lines) and lines[i].lstrip().startswith("|"):
            if ok:
                cells = split_row(lines[i])
                get = lambda name: cells[head.index(name)] if name in head and head.index(name) < len(cells) else ""
                rule, result = plain(get("rule")), normalize_result(get("result"))
                if RULE_RE.match(rule) and result in ("FAIL", "WARN"):
                    ei = head.index("evidence") if "evidence" in head else None
                    evidence = " | ".join(cells[ei:]) if ei is not None and len(cells) > len(head) else get("evidence")
                    out.append((rule, result, MARKER.findall(get("check")), evidence, get("summary")))
            i += 1
    return out


def line_cites(evidence):
    """{(path, line)} the evidence cites, before any "reviewed OK:"."""
    main, _ = split_reviewed_ok(evidence)
    return {(path, n) for path, nums in parse_citations(main) for n in nums}


def same_path(a, b, app_id):
    if a == b:
        return True
    return app_id != "root" and (a.endswith("/" + b) or b.endswith("/" + a))


def describe(checks, evidence, summary):
    first = parse_citations(evidence)
    where = None
    if first:
        path, nums = first[0]
        where = "{}:{}".format(path, nums[0]) if nums else path
    parts = ["`check: {}`".format(c) for c in checks] + ([where] if where else [])
    return ", ".join(parts) if parts else (summary or evidence or "")[:60]


def unbacked(app_id, rule, result, evidence, records):
    """None when a record backs the row, else the reason it is not."""
    ranked = [r for r in records if RANK[r[0]] >= RANK[result]]
    if not ranked:
        tail = "its {} records are {}".format(rule, ", ".join(sorted({r[0] for r in records}))) if records \
            else "it has no {} record".format(rule)
        return "findings.json has no {} record at {} for this app; {}".format(rule, result, tail)
    cites = sorted(line_cites(evidence))
    if not cites:
        return None
    for _, rec_cites in ranked:
        if any(n == m and same_path(p, q, app_id) for p, n in cites for q, m in rec_cites):
            return None
    return "no {} record at {} or worse for this app cites {}:{}".format(rule, result, cites[0][0], cites[0][1])


def main(argv):
    argv = positional_args(argv, ["report.md", "findings.json", "pre-review-dir"],
                           description=(__doc__ or "").split("\n\n")[0])
    if isinstance(argv, int):
        return argv
    report, findings_path, pre = argv[1:]
    try:
        with open(report, encoding="utf-8") as f:
            text = f.read()
        with open(findings_path) as f:
            findings = json.load(f)
        if not isinstance(findings, list):
            raise ValueError("not a list of findings")
    except (OSError, ValueError) as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    sections = app_sections(text)
    try:
        with open(os.path.join(pre, "apps.json")) as f:
            apps = json.load(f)
        if not isinstance(apps, list) or not all(
                isinstance(a, dict) and isinstance(a.get("app_id"), str) and isinstance(a.get("path", ""), (str, type(None)))
                for a in apps):
            raise ValueError
        bodies = [(a["app_id"], section_for(a, sections, single=len(apps) == 1)) for a in apps]
    except (OSError, ValueError):
        bodies = [(key or "root", body) for _, key, body in sections]

    have = {}
    for r in findings:
        if not isinstance(r, dict) or not isinstance(r.get("app_id", "root"), (str, type(None))) \
                or not isinstance(r.get("rule"), str):
            continue
        result = normalize_result(str(r.get("result", "")))
        if result in RANK:
            evidence = r.get("evidence") if isinstance(r.get("evidence"), str) else ""
            have.setdefault((r.get("app_id") or "root", plain(r["rule"])), []).append((result, line_cites(evidence)))

    problems, total = [], 0
    for app_id, body in bodies:
        if body is None:
            continue
        for rule, result, checks, evidence, summary in judged_rows(body):
            if UNJUDGED_CHECKS & set(checks):
                continue
            total += 1
            why = unbacked(app_id, rule, result, evidence, have.get((app_id, rule), []) + have.get(("root", rule), []))
            if why:
                problems.append("MISMATCH {} {} {} row ({}): {}".format(
                    app_id, rule, result, describe(checks, evidence, summary), why))
    for p in problems:
        print(p)
    plural = lambda n, w: "{} {}{}".format(n, w, "" if n == 1 else "s")
    print("row-records: {}, {}, {}".format(plural(len(bodies), "app"), plural(total, "FAIL/WARN row"),
                                          plural(len(problems), "problem")))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
