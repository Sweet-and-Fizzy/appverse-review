#!/usr/bin/env python3
"""Run every report/findings checker in one pass and summarize the result.

    python3 references/check-all.py <report.md> <findings.json> <checks.json> \
        <pre-review-out-dir> --target <target-dir> [--meta <meta.json>]

--meta names the review metadata; without it, <report minus .md>.meta.json
beside the report (the name the review writes). The corpus keeps it as
meta.json, so tests/run-corpus.sh passes it.

Runs, in order:
  1. check-feedback-floor.py <findings.json> <report.md>
  2. check-keys.py <findings.json> --target <target-dir>
  3. check-rating.py <report.md> <findings.json> <pre-review-out-dir>
  4. check-rows.py <report.md> <findings.json> <checks.json> <pre-review-out-dir>
  5. check-evidence.py <findings.json> --target <target-dir> --report <report.md>
         --pre-review <pre-review-out-dir>   (only when that directory exists)
  6. check-catalog.py <report.md> <pre-review-out-dir>
  7. check-meta.py <report minus .md>.meta.json   (only when that file exists;
         the workflow reports a missing one itself)
  8. check-decisions.py <report minus .md>.meta.json <findings.json>
         (only when that file exists)
  9. check-sections.py <report.md> [<report minus .md>.meta.json]
         (the meta.json only when that file exists)

Each checker's problem lines (MISSING, INVALID, MISMATCH, UNCITED, BAD) are
printed as-is, prefixed with the checker's short name in brackets
([floor], [keys], [rating], [rows], [evidence], [catalog], [meta],
[decisions], [sections]) so a mixed failure is easy
to scan. Each checker's own summary line follows its block, also prefixed.

Exit code is the worst of them: 0 if every checker exited 0, 1 if any
exited 1 (a real problem was found) and none exited 2, 2 if any checker
could not run at all (exit 2 — bad input, not a finding). Two results are
reclassified so the code stays an honest split between "the report is
wrong" and "the tooling could not run":
  - A checker that exits 3 (report_parse.MALFORMED) found the report lacks
    a section it needs. That is a malformed report the repair can fix, not
    a tooling failure: its lines are printed as `[<name>] MISSING section:
    <error>` and count as exit 1. check-all reads the exit code, never the
    wording of the error.
  - A checker that crashes (a Python traceback in its output, or an exit
    code other than 0, 1, 2 or 3) could not run: its block is printed as
    `[<name>] crashed: <last output line>` after the traceback and counts
    as exit 2, never as a finding.

--target is required: check-keys.py and check-evidence.py both need it to
validate real paths; without it they still run (in format-only mode) but
that is never what a corpus/CI run wants, so check-all.py requires the flag
itself rather than silently downgrading both checks.
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# (short name, script, argv-builder). argv-builder takes the parsed args and
# returns the argv list (script path excluded; main() prepends it).
CHECKERS = [
    ("floor", "check-feedback-floor.py",
     lambda a: [a.findings, a.report]),
    ("keys", "check-keys.py",
     lambda a: [a.findings, "--target", a.target]),
    ("rating", "check-rating.py",
     lambda a: [a.report, a.findings, a.pre_review_dir]),
    ("rows", "check-rows.py",
     lambda a: [a.report, a.findings, a.checks, a.pre_review_dir]),
    ("evidence", "check-evidence.py",
     lambda a: [a.findings, "--target", a.target, "--report", a.report]
     + (["--pre-review", a.pre_review_dir] if os.path.isdir(a.pre_review_dir) else [])),
    ("catalog", "check-catalog.py",
     lambda a: [a.report, a.pre_review_dir]),
    ("meta", "check-meta.py",
     lambda a: [a.meta]),
    ("decisions", "check-decisions.py",
     lambda a: [a.meta, a.findings]),
    ("sections", "check-sections.py",
     lambda a: [a.report] + [m for m in [a.meta] if os.path.exists(m)]),
]
# A checker named here is skipped, as "not checked", when the file the
# function returns does not exist. The workflow reports a missing meta.json
# itself.
NEEDS = {
    "meta": lambda a: a.meta,
    "decisions": lambda a: a.meta,
}
TRACEBACK = "Traceback (most recent call last):"
MALFORMED = 3  # report_parse.MALFORMED: the report lacks a section a checker needs


def run_one(name, script, argv):
    """Run one checker as a subprocess; return (exit_code, stdout_lines)."""
    path = os.path.join(HERE, script)
    proc = subprocess.run(
        [sys.executable, path] + argv,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    lines = proc.stdout.splitlines()
    return proc.returncode, lines


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("findings")
    ap.add_argument("checks")
    ap.add_argument("pre_review_dir")
    ap.add_argument("--target", required=True,
                     help="reviewed repo checkout, passed to check-keys.py and check-evidence.py")
    ap.add_argument("--meta", help="review metadata (default: <report minus .md>.meta.json)")
    args = ap.parse_args(argv[1:])
    if not args.meta:
        args.meta = os.path.splitext(args.report)[0] + ".meta.json"

    worst = 0
    for name, script, build_argv in CHECKERS:
        argv_ = build_argv(args)
        need = NEEDS.get(name)
        if need and not os.path.exists(need(args)):
            print("[{0}] {0}: not checked (no meta.json beside the report)".format(name))
            continue
        rc, lines = run_one(name, script, argv_)
        if any(line.startswith(TRACEBACK) for line in lines) or rc not in (0, 1, 2, MALFORMED):
            for line in lines:
                print("[{}] {}".format(name, line))
            print("[{}] crashed: {}".format(name, lines[-1] if lines else "exit {}".format(rc)))
            worst = max(worst, 2)
            continue
        if rc == MALFORMED:
            for line in lines:
                print("[{}] MISSING section: {}".format(
                    name, line[len("error: "):] if line.startswith("error: ") else line))
            worst = max(worst, 1)
            continue
        if not lines:
            problem_lines, summary_line = [], None
        else:
            # Every checker prints zero or more problem lines followed by
            # exactly one summary line last (error output on rc==2 has no
            # fixed summary line — print it all as problem lines).
            problem_lines, summary_line = lines[:-1], lines[-1]
        for line in problem_lines:
            print("[{}] {}".format(name, line))
        if summary_line is not None:
            print("[{}] {}".format(name, summary_line))
        worst = max(worst, rc)

    return worst


if __name__ == "__main__":
    sys.exit(main(sys.argv))
