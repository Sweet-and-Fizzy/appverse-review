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
  `check: <id>`. A marker in any other column does not count. A check may
  have several rows (Security is row-per-candidate). A row is required when
  the check's row_required is "always", or when it is "when_candidates" and
  its facts list at least one candidate. A required check with no row is
      MISSING <app_id> <id>

  Candidates. When the facts list candidates, the check is answered when any
  of its rows has Result FAIL or WARN; otherwise (PASS, NOT CHECKED, or
  anything else) every candidate must be cited in the Evidence column of one
  of the check's rows. Each candidate left uncited is
      UNCITED <app_id> <id> <file:line>
  (for a syntax.json or entry_point.json candidate, which has no line, the
  label is the bare path). A citation is the candidate's repo-relative path
  (or, for form.json candidates, the app-relative path form.json records)
  followed by :N or :N-M covering the line, not preceded by another path
  character and not followed by a digit, so script.sh:1 does not match
  script.sh:12 and other/script.sh:1 does not match script.sh:1. A
  path-only candidate is cited by the path alone or with any line.

Candidate sets, per check id (fact files are <out>/<app_id>/<name>.json,
syntax.json is <out>/syntax.json; a missing fact file means no candidates):
  str-06-syntax          syntax.json entries with ok false under the app path
  entry-point-parses     entry_point.json when parses is false
  sec-*                  security.json candidates of the kinds in SECURITY_KINDS
  hardcoded-site-paths   template.json absolute_paths
  magic-numbers          template.json numeric_literals + hex_colors
  dead-code              template.json commented_code
  icon-matches-target-os template.json icons
  numeric-field-bounds   form.json attributes in the form that reach the
                         scheduler and are unbounded: number_field without
                         both min and max; a free-text field (any other widget
                         outside CONSTRAINED_WIDGETS, including an undefined
                         one) without a pattern and without both min and max.
                         A non-null bound (ERBVALUE included) is a bound.
  erb-missing-value      form.json attributes in the form that are interpolated
                         in submit.yml.erb, minus any with "guarded": true.
                         form.json does not record guards today, so every
                         interpolated attribute is a candidate. Cited by the
                         form line or any of its submit lines.
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
}
TEMPLATE_KEYS = {
    "hardcoded-site-paths": ("absolute_paths",),
    "magic-numbers": ("numeric_literals", "hex_colors"),
    "dead-code": ("commented_code",),
    "icon-matches-target-os": ("icons",),
}
CONSTRAINED_WIDGETS = {"select", "radio_button", "radio", "check_box", "checkbox", "hidden_field"}
MARKER = re.compile(r"`check:\s*([A-Za-z0-9_.-]+)`")
ANSWERING = {"FAIL", "WARN"}


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
        if not a.get("in_form", True):
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
            out.append((label(cites[0][0], a.get("line")), cites))
        elif check_id == "erb-missing-value":
            if not a.get("interpolated_in_submit") or a.get("guarded") is True:
                continue
            lines = a.get("submit_lines") or []
            for n in lines:
                cites = cites + site(prefix, sfile, n)
            first = site(prefix, sfile, lines[0])[0] if lines else cites[0]
            out.append((label(*first), cites))
    return out


def candidates(check, app, out):
    cid = check["id"]
    app_id = app["app_id"]
    prefix = app_prefix(app)
    found = []
    if cid == "str-06-syntax":
        for e in fact(out, app_id, "syntax.json") or []:
            p = e.get("path") or ""
            if e.get("ok") is False and p.startswith(prefix):
                found.append((p, [(p, None)]))
    elif cid == "entry-point-parses":
        ep = fact(out, app_id, "entry_point.json")
        if isinstance(ep, dict) and ep.get("parses") is False and ep.get("file"):
            p = ep["file"]
            found.append((p, [(x, None) for x in paths_for(prefix, p)]))
    elif cid in SECURITY_KINDS:
        sec = fact(out, app_id, "security.json")
        for c in (sec.get("candidates") or []) if isinstance(sec, dict) else []:
            if c.get("kind") in SECURITY_KINDS[cid] and c.get("file"):
                cites = site(prefix, c["file"], c.get("line"))
                found.append((label(cites[0][0], c.get("line")), cites))
    elif cid in TEMPLATE_KEYS:
        tpl = fact(out, app_id, "template.json")
        if isinstance(tpl, dict):
            for key in TEMPLATE_KEYS[cid]:
                for c in tpl.get(key) or []:
                    if c.get("file"):
                        cites = site(prefix, c["file"], c.get("line"))
                        found.append((label(cites[0][0], c.get("line")), cites))
    elif cid in ("numeric-field-bounds", "erb-missing-value"):
        found = form_candidates(cid, fact(out, app_id, "form.json"), prefix)
    seen, unique = set(), []
    for lab, cites in found:
        if lab not in seen:
            seen.add(lab)
            unique.append((lab, cites))
    return unique


def cited(evidence, path, line):
    pat = r"(?<![\w./-])" + re.escape(path)
    if line is None:
        return re.search(pat + r"(?![\w./-])", evidence) is not None or \
            re.search(pat + r":\d", evidence) is not None
    for m in re.finditer(pat + r":(\d+)(?:-(\d+))?(?!\d)", evidence):
        lo = int(m.group(1))
        hi = int(m.group(2)) if m.group(2) else lo
        if lo <= int(line) <= hi:
            return True
    return False


# ---- report parsing -------------------------------------------------------

def split_row(line):
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|") and not s.endswith("\\|"):
        s = s[:-1]
    return [c.strip() for c in re.split(r"(?<!\\)\|", s)]


def is_separator(line):
    cells = split_row(line)
    return bool(cells) and all(re.fullmatch(r":?-{1,}:?", c) for c in cells)


def header_name(cell):
    return re.sub(r"[*_`]", "", cell).strip().lower()


def rows_by_check(body):
    """{check_id: [(result, evidence), ...]} from tables with a Check column."""
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
            while i < len(lines) and lines[i].lstrip().startswith("|"):
                cells = split_row(lines[i])
                get = lambda k: cells[k] if k is not None and k < len(cells) else ""
                result = re.sub(r"[*_`]", "", get(ri)).strip().upper()
                for cid in MARKER.findall(get(ci)):
                    rows.setdefault(cid, []).append((result, get(ei)))
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
                problems.append("MISSING {} {}".format(app["app_id"], cid))
                continue
            if any(r in ANSWERING for r, _ in found):
                continue
            for lab, cites in cands:
                if not any(cited(ev, p, n) for _, ev in found for p, n in cites):
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
