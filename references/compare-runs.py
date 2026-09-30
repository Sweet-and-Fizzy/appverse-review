#!/usr/bin/env python3
"""Compare finding sets across review runs of the same commit (R4 item 4).

    python3 references/compare-runs.py <run-dir>... [--json]

Each <run-dir> is searched recursively for one `review-*.findings.json` (a
JSON list of finding records, or `{"findings": [...]}`), one `review-*.md`
report (optional) and one `pre-review/` directory (apps.json, syntax.json
and the per-app `<app_id>/*.json` fact files). A run missing the findings
file is skipped with a warning; at least two runs with a findings file are
required. N, the denominator, is every run with a readable findings file,
whether or not that run has fact files: a run with no candidate list of its
own still has verdicts on candidates another run's facts named.

Two things are reported:

Pairwise Jaccard of fix-item keys. A "fix-item" is a FAIL/WARN finding whose
severity is above info. Its stable key is `(rule, defect_key)`. For every
pair of runs, the Jaccard index of their fix-item key sets is printed
(1.0 when both are empty).

Per-candidate verdicts. The candidate list is the union, across all runs,
of exactly the candidates check-rows.py requires an answer for: check-rows
is imported and its `candidates()` (security kinds, template keys, the form
rules, syntax.json and entry_point.json) is run for every app in apps.json
and every checks.json check that applies to the app's type. Each candidate
belongs to one check id; its rule is its own fact's rule when it carries one
(a security.json config_flag can be OODT-05 or OODT-08), else the check's.

For each candidate and run, the verdict is read from that run's report: the
FAIL/WARN/PASS rows of the candidate's check (`check: <id>` in the app's
section) whose Evidence cites the candidate, by check-rows' citation test
(repo_paths.parse_citations). A row of another check never counts, so a
QUA-10 row citing submit.yml.erb:17 does not answer the OODT-01 candidate
there. A sec-tool-finding candidate additionally needs its own row's Summary
to name the candidate's code as a whole token (check-rows' code-naming
rule, shared here via check_rows.TOOL_FINDING_CODE_RE): a row that cites the
same line but names a different tool code does not answer it. A NOT CHECKED
row answers nothing. When the run has no report, or the report has no
`check:` rows, the findings records stand in: records of the candidate's
rule whose evidence (and, for sec-tool-finding, summary) cites/names it. In
both, a `; reviewed OK:` segment of the Evidence is PASS for what it cites,
and the rest takes the row's (record's) result. Several answers give the
worst (FAIL > WARN > PASS) and, among those, the highest severity.

The table prints, per run, F, W or P (with the severity for F and W) or -
(no answer), then two columns: recorded, the runs that FAIL or WARN the
candidate, and answered, the runs that give any verdict, each as n/N. When
no run has fact files, per-candidate verdicts are not computable (there is
no candidate list), so only the Jaccard section is printed, with a note.

--json prints {"runs": [...], "jaccard": [{"a", "b", "value"}, ...],
"candidates": [{"app_id", "check", "candidate", "file", "line", "rule",
"n_runs", "recorded_by": n, "answered_by": n, "runs": [recording runs],
"verdicts": {run: {"result": "F"|"W"|"P"|"-", "severity": s}}}]} (the same
data, "candidates" empty and a "note" key set when no run has fact files)
instead of the Markdown report.

Exit 0 on a normal comparison (Jaccard, with or without per-candidate).
Exit 2 when fewer than two run directories are given, a run directory does
not exist, or fewer than two runs have a readable findings file.
"""
import argparse
import glob
import importlib.util
import itertools
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHECKS_JSON = os.path.join(SCRIPT_DIR, "checks.json")
sys.path.insert(0, SCRIPT_DIR)
from repo_paths import split_reviewed_ok  # noqa: E402

_spec = importlib.util.spec_from_file_location("check_rows", os.path.join(SCRIPT_DIR, "check-rows.py"))
check_rows = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check_rows)

RANK = {"PASS": 1, "WARN": 2, "FAIL": 3}
LETTER = {"PASS": "P", "WARN": "W", "FAIL": "F", None: "-"}
SEVERITIES = ("info", "low", "medium", "high", "critical")


class InputError(Exception):
    pass


def load_json(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        raise InputError("cannot read {} '{}': {}".format(what, path, e))


def load_checks(path=CHECKS_JSON):
    """The checks.json check list, or [] when it cannot be read."""
    try:
        data = load_json(path, "checks manifest")
    except InputError:
        return []
    checks = data.get("checks") if isinstance(data, dict) else None
    if not isinstance(checks, list):
        return []
    return [c for c in checks if isinstance(c, dict) and c.get("id")]


def find_one(run_dir, name_glob):
    hits = sorted(glob.glob(os.path.join(run_dir, "**", name_glob), recursive=True))
    return hits[0] if hits else None


def load_findings(run_dir):
    path = find_one(run_dir, "review-*.findings.json")
    if path is None:
        return None, None
    data = load_json(path, "findings")
    records = data.get("findings", data) if isinstance(data, dict) else data
    if not isinstance(records, list):
        raise InputError("findings '{}' is not a list".format(path))
    return path, records


def load_report(run_dir):
    path = find_one(run_dir, "review-*.md")
    if path is None:
        return None
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None


def find_pre_review(run_dir):
    hits = sorted(glob.glob(os.path.join(run_dir, "**", "pre-review"), recursive=True))
    return hits[0] if hits else None


def load_apps(pre_review):
    if pre_review is None:
        return None
    try:
        apps = load_json(os.path.join(pre_review, "apps.json"), "apps.json")
    except InputError:
        return None
    if not isinstance(apps, list):
        return None
    return [a for a in apps if isinstance(a, dict) and a.get("app_id")]


def load_candidates(pre_review, apps, checks):
    """{(app_id, check_id, label): {...}} -- check-rows' candidates, per app
    and applicable check."""
    found = {}
    for app in apps or []:
        app_type = app.get("app_type")
        app_type = app_type if app_type in check_rows.APP_TYPES else "batch_connect"
        for check in checks:
            if app_type not in (check.get("app_types") or []):
                continue
            for lab, cites, rule in check_rows.candidates(check, app, pre_review):
                key = (app["app_id"], check["id"], lab)
                if key not in found:
                    if check["id"] == "sec-tool-finding" and cites:
                        # The label ends in a code (SC2164, B602, a semgrep
                        # check_id), not a line, so the trailing-":digit"
                        # split below would misparse it (the whole label
                        # would land in file_, line None). Take file/line
                        # from the first cited site instead.
                        file_, line = cites[0]
                    else:
                        path, _, tail = lab.rpartition(":")
                        file_, line = (path, int(tail)) if path and tail.isdigit() else (lab, None)
                    found[key] = {"app_id": app["app_id"], "check": check["id"],
                                  "candidate": lab, "file": file_, "line": line,
                                  "rule": rule or check.get("rule"), "cites": cites}
    return found


def norm_severity(cell):
    s = re.sub(r"[^a-z]", "", str(cell or "").lower())
    return s if s in SEVERITIES else ""


def answers_from_report(text, apps):
    """{(app_id, check_id): [(result, severity, evidence, summary)]} from the
    report's FAIL/WARN/PASS rows, or None when the report has no `check:`
    rows. summary is the row's Summary cell (needed for sec-tool-finding's
    code-naming rule; harmless for every other check)."""
    if not text:
        return None
    sections = check_rows.app_sections(text)
    out, any_rows = {}, False
    for app in apps or []:
        body = check_rows.section_for(app, sections, single=len(apps) == 1)
        if body is None:
            continue
        for cid, rows in check_rows.rows_by_check(body).items():
            any_rows = True
            for r in rows:
                if r["result"] in RANK:
                    out.setdefault((app["app_id"], cid), []).append(
                        (r["result"], norm_severity(r["severity"]), r["evidence"], r.get("summary", "")))
    return out if any_rows else None


def tool_finding_code(cand):
    """The code a sec-tool-finding candidate's label ends with, else None."""
    if cand.get("check") != "sec-tool-finding":
        return None
    return cand["candidate"].rsplit(":", 1)[-1]


def cites_candidate(evidence, summary, cand):
    """Whether evidence (and, for sec-tool-finding, summary) answers cand --
    the same citation test check-rows.py uses, plus its code-naming rule: a
    sec-tool-finding candidate is answered only when the row's Summary names
    the code as a whole token, not merely by citing the same line."""
    if not any(check_rows.cited(evidence, p, n) for p, n in cand["cites"]):
        return False
    code = tool_finding_code(cand)
    if code is None:
        return True
    return check_rows.TOOL_FINDING_CODE_RE(code).search(summary or "") is not None


def verdict(answers, cand):
    """(result or None, severity) for the candidate from its answers."""
    best = None
    for result, severity, evidence, summary in answers:
        main, ok = split_reviewed_ok(evidence if isinstance(evidence, str) else "")
        for res, sev, text in ((result, severity, main), ("PASS", "", ok)):
            if not text or not cites_candidate(text, summary, cand):
                continue
            key = (RANK[res], SEVERITIES.index(sev) if sev in SEVERITIES else -1)
            if best is None or key > best[0]:
                best = (key, res, sev)
    return (best[1], best[2]) if best else (None, "")


def run_verdict(run, cand):
    if run["report_answers"] is not None:
        answers = run["report_answers"].get((cand["app_id"], cand["check"]), [])
    else:
        answers = [(r.get("result"), norm_severity(r.get("severity")), r.get("evidence"),
                    r.get("summary", ""))
                   for r in run["records"]
                   if r.get("result") in RANK and r.get("rule") == cand["rule"]]
    return verdict(answers, cand)


def is_fix_item(rec):
    return rec.get("result") in ("FAIL", "WARN") and rec.get("severity") != "info"


def fix_key(rec):
    return (rec.get("rule"), rec.get("defect_key"))


def jaccard(a, b):
    if not a and not b:
        return 1.0
    return len(a & b) / len(a | b)


def gather_runs(run_dirs, checks):
    """[run dict]; raises InputError on a bad dir."""
    runs = []
    for d in run_dirs:
        if not os.path.isdir(d):
            raise InputError("run directory '{}' does not exist".format(d))
        label = os.path.basename(d.rstrip("/")) or d
        path, records = load_findings(d)
        if records is None:
            print("warning: no review-*.findings.json under '{}', skipping".format(d),
                  file=sys.stderr)
            continue
        pre_review = find_pre_review(d)
        apps = load_apps(pre_review)
        runs.append({
            "label": label, "records": records, "has_facts": apps is not None,
            "candidates": load_candidates(pre_review, apps, checks),
            "report_answers": answers_from_report(load_report(d), apps),
        })
    return runs


def build_report(runs):
    labels = [r["label"] for r in runs]
    fix_sets = {r["label"]: set(fix_key(x) for x in r["records"] if is_fix_item(x)) for r in runs}
    pairs = []
    for ra, rb in itertools.combinations(runs, 2):
        pairs.append({"a": ra["label"], "b": rb["label"],
                      "value": round(jaccard(fix_sets[ra["label"]], fix_sets[rb["label"]]), 4)})

    all_candidates = {}
    for r in runs:
        for key, cand in r["candidates"].items():
            all_candidates.setdefault(key, cand)

    candidate_rows = []
    order = lambda kv: (kv[0][0], kv[0][1], kv[1]["file"], kv[1]["line"] or 0)
    for _, cand in sorted(all_candidates.items(), key=order):
        verdicts, recorded, answered = {}, [], 0
        for r in runs:
            result, severity = run_verdict(r, cand)
            verdicts[r["label"]] = {"result": LETTER[result],
                                    "severity": severity if result in ("FAIL", "WARN") else ""}
            if result is not None:
                answered += 1
            if result in ("FAIL", "WARN"):
                recorded.append(r["label"])
        candidate_rows.append({
            "app_id": cand["app_id"], "check": cand["check"], "candidate": cand["candidate"],
            "file": cand["file"], "line": cand["line"], "rule": cand["rule"],
            "n_runs": len(runs), "recorded_by": len(recorded), "answered_by": answered,
            "runs": recorded, "verdicts": verdicts,
        })

    return {"runs": labels, "jaccard": pairs, "candidates": candidate_rows}


def render_markdown(report):
    lines = ["## Pairwise Jaccard (fix-item keys)", ""]
    lines.append("| Run A | Run B | Jaccard |")
    lines.append("|---|---|---|")
    for p in report["jaccard"]:
        lines.append("| {} | {} | {:.2f} |".format(p["a"], p["b"], p["value"]))
    lines.append("")
    if report.get("note"):
        lines.append(report["note"])
        return "\n".join(lines)
    lines.append("## Per-candidate verdicts")
    lines.append("")
    lines.append("F/W/P = FAIL/WARN/PASS (severity for F and W), - = no answer. "
                 "Recorded = FAIL or WARN; answered = any verdict.")
    lines.append("")
    runs = report["runs"]
    lines.append("| Candidate | Check | Rule | " + " | ".join(runs) + " | Recorded | Answered |")
    lines.append("|---|---|---|" + "---|" * len(runs) + "---|---|")
    for c in report["candidates"]:
        cells = []
        for r in runs:
            v = c["verdicts"][r]
            cells.append((v["result"] + " " + v["severity"]).strip())
        lines.append("| {} | {} | {} | {} | {}/{} | {}/{} |".format(
            c["candidate"], c["check"], c["rule"] or "", " | ".join(cells),
            c["recorded_by"], c["n_runs"], c["answered_by"], c["n_runs"]))
    return "\n".join(lines)


def main(argv):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("run_dirs", nargs="*")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv[1:])
    if len(args.run_dirs) < 2:
        print("usage: compare-runs.py <run-dir>... [--json]  (at least two run dirs required)",
              file=sys.stderr)
        return 2
    checks = load_checks()
    try:
        runs = gather_runs(args.run_dirs, checks)
    except InputError as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    if len(runs) < 2:
        print("error: fewer than two runs had a readable findings file", file=sys.stderr)
        return 2

    has_facts = any(r["has_facts"] for r in runs)
    report = build_report(runs)
    if not has_facts:
        report["candidates"] = []
        report["note"] = ("per-candidate verdicts are unavailable: no run under the given "
                           "directories has pre-review fact files")

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(render_markdown(report))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
