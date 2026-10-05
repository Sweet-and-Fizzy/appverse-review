#!/usr/bin/env python3
"""Check that the report has one row per manifest check per app, and that
every candidate the pre-review facts listed is answered (R1).

    python3 references/check-rows.py review-<slug>.md review-<slug>.findings.json \
        references/checks.json <pre-review-out-dir>

For each app in <out>/apps.json, and each check in checks.json whose
app_types include the app's app_type (an app_type outside the manifest's
vocabulary, e.g. "unknown", is treated as batch_connect, as pre-review does
for template.json):

  Rows. A row is a Markdown table row, inside the app's "## App: <name>
  (<app_id>)" section, whose Check column (the column headed "Check") holds
  `check: <id>` and whose Result column leads with FAIL, WARN, PASS or NOT
  CHECKED once markdown and emoji are stripped ("**WARN** (low)" is WARN).
  A marker in any other column, or a row with any other Result (or in a
  table with no Result column), does not count. A check may have several
  rows (Security is row-per-candidate). A row is required when the check's
  row_required is "always", or when it is "when_candidates" and its facts
  list at least one candidate. A required check with no row is
      MISSING <app_id> <id>

  A MISSING check that has candidates is followed by one line per
  candidate, so the whole gap shows in one pass:
      MISSING <app_id> <id>
        candidate <file:line>

  Candidates. A FAIL, WARN or PASS row answers exactly the candidates its
  Evidence cites: a FAIL citing one of three sites answers that one only.
  A NOT CHECKED row answers no candidate (it still counts as the check's
  row). When the facts list candidates, every candidate must be cited by
  some FAIL/WARN/PASS row of the check. Each candidate left uncited is
      UNCITED <app_id> <id> <file:line>
  (for a syntax.json or entry_point.json candidate, which has no line, the
  label is the bare path). A check with no candidates is satisfied by any
  row, a plain PASS included.

  Citations. Parsed by repo_paths.parse_citations, the grammar shared with
  check-evidence.py and compare-runs.py: the candidate's repo-relative path
  (or, for form.json candidates, the app-relative path form.json records),
  optionally with a leading ./, backticks or */** emphasis, then a colon and
  a line list: N, N-M or N–M (en dash), or a comma list of those (22,25 or
  22, 25). The list must cover the line. Paths compare whole, and a number
  may not run on into more digits, so script.sh:1 does not match
  script.sh:12 and other/script.sh:1 does not match script.sh:1. Prose is
  not a citation: "script.sh: line 12" and "script.sh line 12" do not cite
  line 12. A '; reviewed OK:' segment is part of the same cell and cites the
  same way. A path-only candidate is cited by the path alone or with any
  line.

  Cells. A '|' inside backticks does not split a cell. When a row still has
  more cells than its header (an unescaped '|' in a Summary), the Evidence
  cell is everything from the Evidence column to the end of the row.

Candidate sets, per check id (fact files are <out>/<app_id>/<name>.json,
syntax.json is <out>/syntax.json; a missing fact file means no candidates):
  str-06-syntax          syntax.json entries with ok false under the app path
  entry-point-parses     entry_point.json when parses is false
  sec-*                  security.json candidates of the kinds in SECURITY_KINDS.
                         sec-tool-finding is one candidate per (tool, code,
                         file) (lines carry every line that tool raised the
                         code at); a row answers it only when its Evidence
                         cites at least one of those lines AND its Summary
                         names the code as a whole token (the code-naming
                         rule) -- citing the line alone, from any check, is
                         not enough. A collapsed candidate (more than 15
                         tool-finding candidates in the app) has no single
                         file; its lines are "file:line" strings instead.
  hardcoded-site-paths   template.json absolute_paths
  magic-numbers          template.json numeric_literals + hex_colors
                         (hex_colors: #rrggbb literals in any template file)
  dead-code              template.json commented_code
  icon-matches-target-os template.json icons
  numeric-field-bounds   form.json attributes that are in the form (in_form)
                         and defined under attributes: (defined; an undefined
                         one is an OOD built-in such as bc_num_hours, bounded
                         by OOD), reach the scheduler, and are unbounded: a
                         number_field without both min and max; a free-text
                         field (any other widget outside CONSTRAINED_WIDGETS,
                         a null widget included) without a pattern and
                         without both min and max. A non-null bound
                         (ERBVALUE included) is a bound.
  erb-missing-value      form.json attributes in the form and defined (as
                         above) that are interpolated in submit.yml.erb,
                         minus any with "guarded": true. form.json does not
                         record guards today, so every interpolated attribute
                         is a candidate. Cited by the form line or any of its
                         submit lines.
Other checks have no candidates: they only need a row.

findings.json is read only to confirm it exists and is JSON, so the command
line matches check-rating.py and check-evidence.py.

The last line is "check-rows: N app(s), R required row(s), P problem(s)".
Exit 0 when every required row exists and is answered, 1 with a MISSING or
UNCITED line per problem, 2 when an input is missing or unreadable, 3
(a malformed report) when the report has no "## App:" section.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_paths import parse_citations  # noqa: E402
from row_candidates import (  # noqa: E402,F401  (re-exported for check-evidence and tests)
    CONSTRAINED_WIDGETS, InputError, SECURITY_KINDS, TEMPLATE_KEYS, TOOL_FINDING_LABEL, app_prefix, candidates, fact, form_candidates, label, load_json, paths_for, site,
)
from report_parse import (  # noqa: E402
    positional_args,
    MALFORMED,
    MARKER, app_sections, header_name, is_separator, normalize_result,
    rows_by_check, section_for, split_row,
)

APP_TYPES = ("batch_connect", "passenger", "companion", "widget")
TOOL_FINDING_CODE_RE = lambda code: re.compile(r"(?<![\w-])" + re.escape(code) + r"(?![\w-])")


# ---- candidates: each is (label, [(path, line or None), ...]) -------------


def cited(evidence, path, line):
    """Whether evidence cites path (and line, when not None)."""
    groups = parse_citations(evidence)
    if line is None:
        if any(p == path for p, _ in groups):
            return True
        pat = r"(?<![\w./-])(?:\./)?" + re.escape(path) + r"(?![\w/-]|\.\w)"
        return re.search(pat, evidence) is not None
    return any(p == path and int(line) in lines for p, lines in groups)


def main(argv):
    argv = positional_args(argv, ["report.md", "findings.json", "checks.json", "pre-review-out-dir"], description=(__doc__ or "").split("\n\n")[0])
    if isinstance(argv, int):
        return argv
    report, findings, manifest, out = argv[1:]
    try:
        try:
            with open(report, encoding="utf-8") as f:
                text = f.read()
        except OSError as e:
            raise InputError("cannot read report '{}': {}".format(report, e))
        load_json(findings, "findings")
        data = load_json(manifest, "manifest")
        checks = data.get("checks") if isinstance(data, dict) else None
        if not isinstance(checks, list) or not all(isinstance(c, dict) and c.get("id") for c in checks):
            raise InputError("manifest '{}' has no checks list".format(manifest))
        apps = load_json(os.path.join(out, "apps.json"), "apps.json")
        if not isinstance(apps, list) or not all(isinstance(a, dict) and a.get("app_id") for a in apps):
            raise InputError("apps.json in '{}' is not a list of apps".format(out))
    except InputError as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    sections = app_sections(text)
    if not sections:
        print("error: no '## App:' section in report", file=sys.stderr)
        return MALFORMED

    problems, required = [], 0
    for app in apps:
        app_type = app.get("app_type")
        app_type = app_type if app_type in APP_TYPES else "batch_connect"
        body = section_for(app, sections, single=len(apps) == 1)
        rows = rows_by_check(body) if body is not None else {}
        for check in checks:
            if app_type not in (check.get("app_types") or []):
                continue
            cands = candidates(check, app, out)
            if check.get("row_required") == "when_candidates" and not cands:
                continue
            required += 1
            cid = check["id"]
            found = rows.get(cid)
            if not found:
                problems.append("MISSING {} {}".format(app["app_id"], cid) +
                                "".join("\n  candidate {}".format(c[0]) for c in cands))
                continue
            answering = [r for r in found if r["result"] != "NOT CHECKED"]
            for lab, cites, _ in cands:
                if cid == "sec-tool-finding":
                    code = lab.rsplit(":", 1)[-1]
                    code_re = TOOL_FINDING_CODE_RE(code)
                    answered = any(cited(r["evidence"], p, n) and code_re.search(r["summary"])
                                   for r in answering for p, n in cites)
                else:
                    answered = any(cited(r["evidence"], p, n) for r in answering for p, n in cites)
                if not answered:
                    problems.append("UNCITED {} {} {}".format(app["app_id"], cid, lab))
    for p in problems:
        print(p)
    plural = lambda n, w: "{} {}{}".format(n, w, "" if n == 1 else "s")
    print("check-rows: {}, {}, {}".format(plural(len(apps), "app"),
                                         plural(required, "required row"),
                                         plural(len(problems), "problem")))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
