#!/usr/bin/env python3
"""Compare finding sets across review runs of the same commit (R4 item 4).

    python3 references/compare-runs.py <run-dir>... [--json]

Each <run-dir> is searched recursively for one `review-*.findings.json` (a
JSON list of finding records, or `{"findings": [...]}`) and one `pre-review/`
directory (holding `apps.json` and, per app, `<app_id>/{form,template,
security}.json`). A run missing the findings file is skipped with a
warning; at least two runs with a findings file are required. The
denominator for "recorded_by X/N" is N = every run that has a readable
findings file, whether or not that run has fact files: a run's own
candidate list may be empty (no fact files) while it still has an opinion
(findings) on candidates another run's facts named, so it must count in the
denominator to be judged fairly.

Two things are reported:

Pairwise Jaccard of fix-item keys. A "fix-item" is a FAIL/WARN finding whose
severity is above info. Its stable key is `(rule, defect_key)`. For every
pair of runs, the Jaccard index of their fix-item key sets is printed
(1.0 when both are empty).

Per-candidate recall. The candidate list is the union, across all runs'
fact files, of `security.json` candidates (`kind`, `file`, `line`, `rule`
-- each candidate's own `rule`, since one kind such as `config_flag` can
carry different rules per match, e.g. OODT-05 vs OODT-08), `template.json`
list items (`absolute_paths`, `numeric_literals`, `hex_colors`,
`commented_code`, `icons`; `file`, `line`, rule from checks.json by check
id), and `form.json` `attributes[]` (`line`, rule from checks.json).
security.json and template.json paths are already repo-relative (baked in
by pre-review.py at scan time); form.json's `file` is app-relative, so it is
prefixed with the app's `path` from apps.json the way check-rows.py's
app_prefix/paths_for does (only when the path doesn't already carry that
prefix, so a repo-relative path already matching is left alone) -- a
monorepo candidate then matches a finding that cites the repo-relative
path. A candidate is recorded by a run when that run has a
FAIL/WARN or PASS finding whose evidence's leading `path:line` (or
`path:line-line`, or a comma list of those) citation covers the candidate's
exact file and line. This is deliberately the only test: an earlier version
also credited a finding whose defect_key anchor matched the candidate's file
and whose rule matched the candidate's kind, but that fallback over-counts
-- a single FAIL anchored `submit.yml.erb:some-tag` with rule OODT-01 would
then mark every OODT-01 candidate in that file as recorded, whether or not
the finding actually addressed that candidate's line. A finding whose
evidence carries no parseable line (a bare path, or free-text prose) can
never record a candidate, by design: without a line, there is no way to
tell which candidate in a multi-candidate file it addresses. For each
candidate the table prints how many of the runs with a findings file
recorded it and which did. When no run under the given directories has any
fact file, per-candidate recall is not computable (there is no candidate
list), so only the Jaccard section is printed, with a note that
per-candidate is unavailable.

--json prints {"runs": [...], "jaccard": [{"a", "b", "value"}, ...],
"candidates": [{"file", "line", "kind", "rule", "n_runs", "recorded_by": n,
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

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHECKS_JSON = os.path.join(SCRIPT_DIR, "checks.json")

# template.json/form.json list key -> the checks.json check id that covers it.
# (security.json candidates carry their own "rule" field instead -- one kind,
# e.g. config_flag, can carry different rules per match -- so no table is
# needed for those.)
TEMPLATE_CHECK_ID = {
    "absolute_paths": "hardcoded-site-paths",
    "numeric_literals": "magic-numbers",
    "hex_colors": "magic-numbers",
    "commented_code": "dead-code",
    "icons": "icon-matches-target-os",
}
FORM_CHECK_ID = "numeric-field-bounds"  # erb-missing-value shares QUA-* territory but
                                        # numeric-field-bounds is the form.json rule of record here
LEADING_CITATION = re.compile(r"^([^\s:]+):(\d+(?:\s*[-–]\s*\d+)?(?:\s*,\s*\d+(?:\s*[-–]\s*\d+)?)*)")
LINE_SPEC = re.compile(r"(\d+)(?:\s*[-–]\s*(\d+))?")


class InputError(Exception):
    pass


def load_json(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        raise InputError("cannot read {} '{}': {}".format(what, path, e))


def load_rule_table(path=CHECKS_JSON):
    """{check_id: rule} from checks.json, or {} when it cannot be read."""
    try:
        data = load_json(path, "checks manifest")
    except InputError:
        return {}
    checks = data.get("checks") if isinstance(data, dict) else None
    if not isinstance(checks, list):
        return {}
    return {c["id"]: c.get("rule") for c in checks if isinstance(c, dict) and c.get("id")}


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


def app_prefix(app):
    """Repo-relative prefix for an app-relative path, per check-rows.py's app_prefix:
    'root' / '.' / '' -> no prefix; otherwise '<path>/' with any leading './' and
    surrounding slashes stripped."""
    p = (app.get("path") or ".").strip().strip("/")
    p = p[2:] if p.startswith("./") else p
    return "" if p in ("", ".") else p + "/"


def repo_relative(prefix, path):
    """path, prefixed with the app's prefix unless it is already repo-relative
    (security.json/template.json paths are baked in at scan time; only
    form.json's `file` is app-relative) -- check-rows.py's paths_for."""
    if prefix and not path.startswith(prefix):
        return prefix + path
    return path


def load_candidates(pre_review, rule_table):
    """[(file, line, kind, rule)] deduplicated, from every app's fact files."""
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
        prefix = app_prefix(app)

        sec = fact(pre_review, app_id, "security.json")
        if isinstance(sec, dict):
            for c in sec.get("candidates") or []:
                if c.get("file") and c.get("line") is not None:
                    found.append((repo_relative(prefix, c["file"]), c["line"],
                                  c.get("kind"), c.get("rule")))

        tpl = fact(pre_review, app_id, "template.json")
        if isinstance(tpl, dict):
            for key, check_id in TEMPLATE_CHECK_ID.items():
                rule = rule_table.get(check_id)
                for c in tpl.get(key) or []:
                    if c.get("file") and c.get("line") is not None:
                        found.append((repo_relative(prefix, c["file"]), c["line"], key, rule))

        form = fact(pre_review, app_id, "form.json")
        if isinstance(form, dict):
            rule = rule_table.get(FORM_CHECK_ID)
            ffile = form.get("file") or "form.yml"
            for a in form.get("attributes") or []:
                if a.get("line") is not None:
                    found.append((repo_relative(prefix, ffile), a["line"], "form_attribute", rule))

    seen, unique = set(), []
    for file_, line, kind, rule in found:
        key = (file_, line, kind)
        if key not in seen:
            seen.add(key)
            unique.append((file_, line, kind, rule))
    unique.sort(key=lambda c: (c[0], c[1], c[2] or ""))
    return unique


def is_fix_item(rec):
    return rec.get("result") in ("FAIL", "WARN") and rec.get("severity") != "info"


def fix_key(rec):
    return (rec.get("rule"), rec.get("defect_key"))


def citations(evidence):
    """[(path, low, high), ...] from a leading `path:N`, `path:N-M`, or a
    comma list of those; [] when evidence has no parseable line citation."""
    if not isinstance(evidence, str):
        return []
    m = LEADING_CITATION.match(evidence)
    if not m:
        return []
    path, spec = m.group(1), m.group(2)
    out = []
    for piece in spec.split(","):
        lm = LINE_SPEC.search(piece)
        if not lm:
            continue
        lo = int(lm.group(1))
        hi = int(lm.group(2)) if lm.group(2) else lo
        out.append((path, lo, hi))
    return out


def records_candidate(records, file_, line):
    """Whether any FAIL/WARN/PASS record in this run cites the candidate's exact file:line."""
    for rec in records:
        if rec.get("result") not in ("FAIL", "WARN", "PASS"):
            continue
        for path, lo, hi in citations(rec.get("evidence")):
            if path == file_ and lo <= line <= hi:
                return True
    return False


def jaccard(a, b):
    if not a and not b:
        return 1.0
    return len(a & b) / len(a | b)


def gather_runs(run_dirs, rule_table):
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
        candidates = load_candidates(pre_review, rule_table)
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
        for file_, line, kind, rule in cands:
            all_candidates[(file_, line, kind)] = rule

    candidate_rows = []
    for (file_, line, kind), rule in sorted(all_candidates.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        recorded_in = [label for label, records, _ in runs if records_candidate(records, file_, line)]
        candidate_rows.append({
            "file": file_, "line": line, "kind": kind, "rule": rule,
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
    lines.append("| File:Line | Kind | Rule | Recorded by | Runs |")
    lines.append("|---|---|---|---|---|")
    for c in report["candidates"]:
        lines.append("| {}:{} | {} | {} | {}/{} | {} |".format(
            c["file"], c["line"], c["kind"] or "", c["rule"] or "",
            c["recorded_by"], c["n_runs"], ", ".join(c["runs"]) or "(none)"))
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
    rule_table = load_rule_table()
    try:
        runs = gather_runs(args.run_dirs, rule_table)
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
