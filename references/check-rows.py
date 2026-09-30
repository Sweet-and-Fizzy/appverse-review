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
UNCITED line per problem, 2 when an input is missing or unreadable, or the
report has no "## App:" section.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from repo_paths import parse_citations  # noqa: E402

APP_TYPES = ("batch_connect", "passenger", "companion", "widget")
SECURITY_KINDS = {
    "sec-interpolation": ("interpolation", "unquoted_expansion"),
    "sec-eval-exec": ("eval_exec",),
    "sec-credential-string": ("credential_string",),
    "sec-permissive-mode": ("permission_change",),
    "sec-network-call": ("network_call",),
    "sec-file-write-outside-job": ("file_write_outside_job",),
    "sec-config-flag": ("config_flag",),
    "sec-binary-in-template": ("binary_in_template",),
    "sec-tool-finding": ("tool_finding",),
}
TEMPLATE_KEYS = {
    "hardcoded-site-paths": ("absolute_paths",),
    "magic-numbers": ("numeric_literals", "hex_colors"),
    "dead-code": ("commented_code",),
    "icon-matches-target-os": ("icons",),
}
CONSTRAINED_WIDGETS = {"select", "radio_button", "radio", "check_box", "checkbox", "hidden_field"}
MARKER = re.compile(r"`check:\s*([A-Za-z0-9_.-]+)`")
RESULTS = ("NOT CHECKED", "FAIL", "WARN", "PASS")
RESULT_RE = re.compile(r"[^A-Z]*(" + "|".join(RESULTS).replace(" ", r"\s+") + r")(?![A-Z])")
# sec-tool-finding: a candidate's label carries its code after the last ':',
# so a row's Evidence-citing answer can be checked separately for naming the
# code as a whole token in its Summary (the code-naming rule).
TOOL_FINDING_LABEL = "{site}:{code}"
TOOL_FINDING_CODE_RE = lambda code: re.compile(r"(?<![\w-])" + re.escape(code) + r"(?![\w-])")


class InputError(Exception):
    pass


def load_json(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        raise InputError("cannot read {} '{}': {}".format(what, path, e))


def fact(out, app_id, name):
    """A per-app fact file, or None when absent or unreadable."""
    path = os.path.join(out, name) if name == "syntax.json" else os.path.join(out, app_id, name)
    if not os.path.isfile(path):
        return None
    try:
        return load_json(path, name)
    except InputError:
        return None


# ---- candidates: each is (label, [(path, line or None), ...]) -------------

def app_prefix(app):
    p = (app.get("path") or ".").strip().strip("/")
    p = p[2:] if p.startswith("./") else p
    return "" if p in ("", ".") else p + "/"


def paths_for(prefix, path):
    """Repo-relative first, then the path as written when it differs."""
    if prefix and not path.startswith(prefix):
        return [prefix + path, path]
    return [path]


def site(prefix, path, line):
    return [(p, line) for p in paths_for(prefix, path)]


def label(path, line):
    return path if line is None else "{}:{}".format(path, line)


def form_candidates(check_id, form, prefix):
    if not isinstance(form, dict) or form.get("error"):
        return []
    ffile = form.get("file") or "form.yml"
    sfile = form.get("submit_file") or "submit.yml.erb"
    out = []
    for a in form.get("attributes") or []:
        if not a.get("in_form", True) or a.get("defined") is False:
            continue
        cites = site(prefix, ffile, a.get("line"))
        if check_id == "numeric-field-bounds":
            if not a.get("reaches_scheduler"):
                continue
            widget = a.get("widget")
            both = a.get("min") is not None and a.get("max") is not None
            if widget in CONSTRAINED_WIDGETS:
                continue
            if widget == "number_field":
                bounded = both
            else:
                bounded = both or a.get("pattern") is not None
            if bounded:
                continue
            out.append((label(cites[0][0], a.get("line")), cites, None))
        elif check_id == "erb-missing-value":
            if not a.get("interpolated_in_submit") or a.get("guarded") is True:
                continue
            lines = a.get("submit_lines") or []
            for n in lines:
                cites = cites + site(prefix, sfile, n)
            first = site(prefix, sfile, lines[0])[0] if lines else cites[0]
            out.append((label(*first), cites, None))
    return out


def candidates(check, app, out):
    """[(label, cites, rule)]: rule is the candidate's own rule when its fact
    carries one (security.json), else None (the check's rule applies)."""
    cid = check["id"]
    app_id = app["app_id"]
    prefix = app_prefix(app)
    found = []
    if cid == "str-06-syntax":
        for e in fact(out, app_id, "syntax.json") or []:
            p = e.get("path") or ""
            if e.get("ok") is False and p.startswith(prefix):
                found.append((p, [(p, None)], None))
    elif cid == "entry-point-parses":
        ep = fact(out, app_id, "entry_point.json")
        if isinstance(ep, dict) and ep.get("parses") is False and ep.get("file"):
            p = ep["file"]
            found.append((p, [(x, None) for x in paths_for(prefix, p)], None))
    elif cid == "sec-tool-finding":
        sec = fact(out, app_id, "security.json")
        for c in (sec.get("candidates") or []) if isinstance(sec, dict) else []:
            if c.get("kind") != "tool_finding":
                continue
            code = c.get("code")
            if c.get("file"):
                cites = [(p, n) for p, _ in site(prefix, c["file"], None) for n in (c.get("lines") or [])]
                site_label = label(paths_for(prefix, c["file"])[0], None)
            else:
                cites, sites_seen = [], []
                for entry in c.get("lines") or []:
                    path, _, tail = str(entry).rpartition(":")
                    if path and tail.isdigit():
                        cites.extend(site(prefix, path, int(tail)))
                        sites_seen.append(path)
                site_label = ",".join(sites_seen) or "?"
            found.append((TOOL_FINDING_LABEL.format(site=site_label, code=code), cites, None))
    elif cid in SECURITY_KINDS:
        sec = fact(out, app_id, "security.json")
        for c in (sec.get("candidates") or []) if isinstance(sec, dict) else []:
            if c.get("kind") in SECURITY_KINDS[cid] and c.get("file"):
                cites = site(prefix, c["file"], c.get("line"))
                found.append((label(cites[0][0], c.get("line")), cites, c.get("rule")))
    elif cid in TEMPLATE_KEYS:
        tpl = fact(out, app_id, "template.json")
        if isinstance(tpl, dict):
            for key in TEMPLATE_KEYS[cid]:
                for c in tpl.get(key) or []:
                    if c.get("file"):
                        cites = site(prefix, c["file"], c.get("line"))
                        found.append((label(cites[0][0], c.get("line")), cites, None))
    elif cid in ("numeric-field-bounds", "erb-missing-value"):
        found = form_candidates(cid, fact(out, app_id, "form.json"), prefix)
    seen, unique = set(), []
    for lab, cites, rule in found:
        if lab not in seen:
            seen.add(lab)
            unique.append((lab, cites, rule))
    return unique


def cited(evidence, path, line):
    """Whether evidence cites path (and line, when not None)."""
    groups = parse_citations(evidence)
    if line is None:
        if any(p == path for p, _ in groups):
            return True
        pat = r"(?<![\w./-])(?:\./)?" + re.escape(path) + r"(?![\w/-]|\.\w)"
        return re.search(pat, evidence) is not None
    return any(p == path and int(line) in lines for p, lines in groups)


def normalize_result(cell):
    """FAIL, WARN, PASS or NOT CHECKED from the cell's leading token, else None."""
    m = RESULT_RE.match(re.sub(r"[*_`]", "", cell).upper())
    return re.sub(r"\s+", " ", m.group(1)) if m else None


# ---- report parsing -------------------------------------------------------

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
    keys = {app["app_id"], (app.get("path") or "").strip().strip("/"), app_prefix(app).rstrip("/")}
    keys.discard("")
    for _, key, body in sections:
        if key is not None and key.strip("/") in keys:
            return body
    if single and len(sections) == 1:
        return sections[0][2]
    return None


def main(argv):
    if len(argv) != 5:
        print("usage: check-rows.py <report.md> <findings.json> <checks.json> <pre-review-out-dir>",
              file=sys.stderr)
        return 2
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
        return 2

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
