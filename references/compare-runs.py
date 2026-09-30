#!/usr/bin/env python3
"""Compare finding sets across review runs of the same commit (R4 item 4).

    python3 references/compare-runs.py <run-dir>... [--json]

Each <run-dir> is searched recursively for one `review-*.findings.json` (a
JSON list of finding records, or `{"findings": [...]}`) and one `pre-review/`
directory (holding `apps.json` and, per app, `<app_id>/{form,template,
security}.json`). A run missing the findings file is skipped with a
warning; at least two runs with a findings file are required.

Two things are reported:

Pairwise Jaccard of fix-item keys. A "fix-item" is a FAIL/WARN finding whose
severity is above info. Its stable key is `(rule, defect_key)`. For every
pair of runs, the Jaccard index of their fix-item key sets is printed
(1.0 when both are empty).

Per-candidate recall. The candidate list is the union, across all runs'
fact files, of `security.json` candidates (`kind`, `file`, `line`, `rule`),
`template.json` list items (`absolute_paths`, `numeric_literals`,
`hex_colors`, `commented_code`, `icons`; `file`, `line`), and `form.json`
`attributes[]` (`name`, `line`; app-relative to the fact file's app_id). A
candidate is recorded by a run when that run has a FAIL/WARN finding whose
evidence's leading `path:line` (or `path:line-line` range) citation covers
the candidate's file and line, or whose defect_key anchor is the
candidate's file and whose rule is one the candidate's kind maps to
(SECURITY_KINDS below), or a PASS finding meeting either of those same
tests. For each candidate the table prints how many of N runs recorded it
and which did. When no run under the given directories has any fact file,
per-candidate recall is not computable (there is no candidate list), so
only the Jaccard section is printed, with a note that per-candidate is
unavailable.

--json prints {"runs": [...], "jaccard": [{"a", "b", "value"}, ...],
"candidates": [{"file", "line", "kind", "n_runs", "recorded_by": n,
"runs": [...]}]} (the same data, "candidates" empty and a "note" key set
when no run has fact files) instead of the Markdown report.

Exit 0 on a normal comparison (Jaccard, with or without per-candidate).
Exit 2 when fewer than two run directories are given, a run directory does
not exist, or fewer than two runs have a readable findings file.
"""
import argparse
import glob
import itertools
import json
import os
import re
import sys

# candidate kind -> the security-finding rules that cover it (security-tools.md).
SECURITY_KINDS = {
    "interpolation": ("OODT-01",),
    "unquoted_expansion": ("OODT-01",),
    "eval_exec": ("OODT-01",),
    "network_call": ("OODT-04", "OODT-05"),
    "file_write_outside_job": ("OODT-07",),
    "permission_change": ("OODT-03",),
    "credential_string": ("OODT-02",),
    "config_flag": ("OODT-08",),
    "binary_in_template": ("OODT-04",),
}
TEMPLATE_KINDS = {
    "absolute_paths": ("QUA-02",),
    "numeric_literals": ("QUA-08",),
    "hex_colors": ("QUA-08",),
    "commented_code": ("QUA-04",),
    "icons": ("QUA-06",),
}
FORM_KIND = ("form_attribute", ("QUA-07", "QUA-10"))
LEADING_CITATION = re.compile(r"^([^\s:]+):(\d+)(?:-(\d+))?")


class InputError(Exception):
    pass


def load_json(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        raise InputError("cannot read {} '{}': {}".format(what, path, e))


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


def find_pre_review(run_dir):
    hits = sorted(glob.glob(os.path.join(run_dir, "**", "pre-review"), recursive=True))
    return hits[0] if hits else None


def fact(pre_review, app_id, name):
    path = os.path.join(pre_review, app_id, name)
    if not os.path.isfile(path):
        return None
    try:
        return load_json(path, name)
    except InputError:
        return None


def load_candidates(pre_review):
    """[(file, line, kind, rules)] deduplicated, from every app's fact files."""
    if pre_review is None:
        return []
    apps_path = os.path.join(pre_review, "apps.json")
    if not os.path.isfile(apps_path):
        return []
    try:
        apps = load_json(apps_path, "apps.json")
    except InputError:
        return []
    if not isinstance(apps, list):
        return []
    found = []
    for app in apps:
        if not isinstance(app, dict) or not app.get("app_id"):
            continue
        app_id = app["app_id"]

        sec = fact(pre_review, app_id, "security.json")
        if isinstance(sec, dict):
            for c in sec.get("candidates") or []:
                if c.get("file") and c.get("line") is not None:
                    found.append((c["file"], c["line"], c.get("kind"),
                                  SECURITY_KINDS.get(c.get("kind"), ())))

        tpl = fact(pre_review, app_id, "template.json")
        if isinstance(tpl, dict):
            for key, rules in TEMPLATE_KINDS.items():
                for c in tpl.get(key) or []:
                    if c.get("file") and c.get("line") is not None:
                        found.append((c["file"], c["line"], key, rules))

        form = fact(pre_review, app_id, "form.json")
        if isinstance(form, dict):
            kind, rules = FORM_KIND
            for a in form.get("attributes") or []:
                if a.get("line") is not None:
                    ffile = form.get("file") or "form.yml"
                    found.append((ffile, a["line"], kind, rules))

    seen, unique = set(), []
    for file_, line, kind, rules in found:
        key = (file_, line, kind)
        if key not in seen:
            seen.add(key)
            unique.append((file_, line, kind, rules))
    unique.sort(key=lambda c: (c[0], c[1], c[2] or ""))
    return unique


def is_fix_item(rec):
    return rec.get("result") in ("FAIL", "WARN") and rec.get("severity") != "info"


def fix_key(rec):
    return (rec.get("rule"), rec.get("defect_key"))


def citation(evidence):
    """(path, low, high) from a leading `path:N` or `path:N-M`, else None."""
    if not isinstance(evidence, str):
        return None
    m = LEADING_CITATION.match(evidence)
    if not m:
        return None
    path, lo, hi = m.group(1), int(m.group(2)), m.group(3)
    return path, lo, int(hi) if hi else lo


def anchor_file(defect_key):
    if not isinstance(defect_key, str) or ":" not in defect_key:
        return None
    return defect_key.split(":", 1)[0]


def records_candidate(records, file_, line, rules):
    """Whether any FAIL/WARN/PASS record in this run recorded the candidate."""
    for rec in records:
        if rec.get("result") not in ("FAIL", "WARN", "PASS"):
            continue
        cite = citation(rec.get("evidence"))
        if cite is not None:
            path, lo, hi = cite
            if path == file_ and lo <= line <= hi:
                return True
        if rules and anchor_file(rec.get("defect_key")) == file_ and rec.get("rule") in rules:
            return True
    return False


def jaccard(a, b):
    if not a and not b:
        return 1.0
    return len(a & b) / len(a | b)


def gather_runs(run_dirs):
    """[(label, findings_records, candidates)]; raises InputError on a bad dir."""
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
        candidates = load_candidates(pre_review)
        runs.append((label, records, candidates))
    return runs


def build_report(runs):
    labels = [r[0] for r in runs]
    fix_sets = {label: set(fix_key(r) for r in records if is_fix_item(r))
                for label, records, _ in runs}
    pairs = []
    for (la, _, _), (lb, _, _) in itertools.combinations(runs, 2):
        pairs.append({"a": la, "b": lb, "value": round(jaccard(fix_sets[la], fix_sets[lb]), 4)})

    all_candidates = {}
    for _, _, cands in runs:
        for file_, line, kind, rules in cands:
            all_candidates[(file_, line, kind)] = rules

    candidate_rows = []
    for (file_, line, kind), rules in sorted(all_candidates.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        recorded_in = [label for label, records, _ in runs if records_candidate(records, file_, line, rules)]
        candidate_rows.append({
            "file": file_, "line": line, "kind": kind,
            "n_runs": len(runs), "recorded_by": len(recorded_in), "runs": recorded_in,
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
    lines.append("## Per-candidate recall")
    lines.append("")
    lines.append("| File:Line | Kind | Recorded by | Runs |")
    lines.append("|---|---|---|---|")
    for c in report["candidates"]:
        lines.append("| {}:{} | {} | {}/{} | {} |".format(
            c["file"], c["line"], c["kind"] or "", c["recorded_by"], c["n_runs"],
            ", ".join(c["runs"]) or "(none)"))
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
    try:
        runs = gather_runs(args.run_dirs)
    except InputError as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    if len(runs) < 2:
        print("error: fewer than two runs had a readable findings file", file=sys.stderr)
        return 2

    has_facts = any(cands for _, _, cands in runs)
    report = build_report(runs)
    if not has_facts:
        report["candidates"] = []
        report["note"] = ("per-candidate recall is unavailable: no run under the given "
                           "directories has pre-review fact files")

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(render_markdown(report))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
