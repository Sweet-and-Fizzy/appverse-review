#!/usr/bin/env python3
"""Run every report/findings checker in one pass and summarize the result.

    python3 references/check-all.py <report.md> <findings.json> <checks.json> \
        <pre-review-out-dir> --target <target-dir>

Runs, in order:
  1. check-feedback-floor.py <findings.json> <report.md>
  2. check-keys.py <findings.json> --target <target-dir>
  3. check-rating.py <report.md> <findings.json> <pre-review-out-dir>
  4. check-rows.py <report.md> <findings.json> <checks.json> <pre-review-out-dir>
  5. check-evidence.py <findings.json> --target <target-dir> --report <report.md>

Each checker's problem lines (MISSING, INVALID, MISMATCH, UNCITED, BAD) are
printed as-is, prefixed with the checker's short name in brackets
([floor], [keys], [rating], [rows], [evidence]) so a mixed failure is easy
to scan. Each checker's own summary line follows its block, also prefixed.

Exit code is the worst of the five: 0 if every checker exited 0, 1 if any
exited 1 (a real problem was found) and none exited 2, 2 if any checker
could not run at all (exit 2 — bad input, not a finding).

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
     lambda a: [a.findings, "--target", a.target, "--report", a.report]),
]


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
    args = ap.parse_args(argv[1:])

    worst = 0
    for name, script, build_argv in CHECKERS:
        rc, lines = run_one(name, script, build_argv(args))
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
