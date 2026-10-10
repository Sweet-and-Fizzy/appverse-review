#!/usr/bin/env python3
"""Check that judged levels in the report follow their own evidence.

    python3 references/check-rating.py review-<slug>.md review-<slug>.findings.json [<pre-review-dir>]

Per "## App:" section:
  1. The Documentation rating may not exceed the highest rung whose
     requirements, and every lower rung's, all have non-"none" evidence lines.
     This is a ceiling, not an equality: a rating below the highest
     supported rung is not flagged here, since the evidence lines support
     at least that much; rule 6 judges a rating below the facts' baseline.
     Evidence of the form `content: README.md:N` (a rung met by a cited
     content line rather than a matching heading) is non-"none" like any
     other citation; check-evidence.py verifies that line N is a content
     line. One content line may not meet two requirements: a `content:
     <path>:N` cited for two of them is `MISMATCH <app> documentation:
     content line <path>:N cited for two rungs (<a>, <b>)`.
  2. The Signals table's Documentation level must be the one the rating maps to
     (Strong/Exemplary -> Low, Adequate -> Medium, Minimal and Below minimal
     -> High).
Only Documentation is checked among ratings/signals: there is no Security
signal (R4); only the Documentation rating and signal are checked.

Below minimal. The rating `Below minimal` (no rung supports Minimal and the
README is not a stub) claims no rung, so rule 1 cannot fail it; it is
accepted when the findings JSON has a QUA-01 `docs-minimal` record for that
app whose result is WARN or FAIL, and is a MISMATCH without one. With a
pre-review directory whose readme.json says `stub: true`, it is a MISMATCH
either way: a stub README takes the stub line below, not Below minimal.

A stub README. The rating line `Minimal — not supported (stub README; see
QUA-01)` is accepted in place of rule 1 when the findings JSON has a QUA-01
FAIL record for that app (its app_id is the section heading's parenthesised
id) whose defect_key tag is `docs-stub`, and the README is a stub by the
facts. With a pre-review directory, the facts are
<pre-review-dir>/<app_id>/readme.json's `stub` (app_id "root" when the
heading has none, or has "."): false is a MISMATCH naming readme.json. When
that file or its `stub` key is absent (no directory given, or facts written
before the key existed), the findings JSON decides instead: a STR-01 FAIL
record whose tag is `readme-not-substantive`, for the app or the repo
(app_id "root" or none), and a MISMATCH without one. The Markdown gate
table is never read for this. Without the docs-stub record the line is
read as a Minimal claim and fails rule 1 as any unsupported rating does.
Rule 2 still applies (Minimal maps to High).

  3. A suggestion-class check, or a maintenance good-practice signal
     (MNT-02 to MNT-06), recorded as FAIL is a mismatch — the rubric holds
     both are never a failure. A check counts as suggestion-class when
     checks.json (loaded from beside this script) marks it `"weight":
     "suggestion"`. A record matches a check when its rule equals the
     check's rule and its tag (the part of defect_key after the first ':',
     truncated before any further ':' qualifier) is one of the check's
     `tags`, the list of every vocabulary tag a suggestion check owns (so
     choosing another tag the same check owns does not escape the rule),
     or equals its single `tag` when it has no `tags`. A tag of the same
     rule that the check does not own (QUA-06 `duplicate-yaml-key`, a
     correctness defect, beside the icon check's `icon-os-mismatch`) does
     not match. A maintenance record matches when
     its rule is one of MNT-02 through MNT-06 (MNT-01, activity, is a real
     failure and is untouched). A suggestion-class record whose result is
     FAIL or WARN and whose severity is above info (low, medium, high,
     critical) is also a mismatch, `MISMATCH <app> <rule> <defect_key>:
     suggestion (check <id>) rated <severity>; suggestions are info`:
     suggestion checks carry `default_severity: info` in checks.json, and
     a suggestion at Low or above would be a fix-item the contributor is
     told to fix. A suggestion FAIL rated low gets both lines. When checks.json cannot be read, is not
     JSON or has no checks list, the script exits 2 with `error: cannot
     load references/checks.json (<reason>)` rather than skip the rule.
     This rule is general — it is not keyed to any particular app or run.
  4. Within each app's "### Security" section (up to the next "### "),
     count table rows whose Result cell normalises to FAIL or WARN
     (normalize_result, imported from report_parse.py), whatever rule code
     the first cell holds: a tool-finding row records under a QUA-xx rule,
     and emphasis or backticks in the cell do not hide an OODT-xx code. The
     Result cell is the table's Result column when its header has one, else
     the cell after the Check cell, else the second cell. The section can
     hold more than one table (Findings, then Additional observations
     (review)); each table's header (a '|' row immediately followed by a
     separator row, report_parse.is_separator, itself required to start
     with '|' so a bare '---' prose divider is never read as one) is read on
     its own, so one table's columns never carry over into the next. When
     that count is nonzero, "No tool-detectable issues in the checked
     tiers." must not appear — the report would be claiming its own rows
     are clean. The sentence is matched with emphasis dropped, whitespace
     (a line wrap) collapsed and with or without its final period. A
     missing sentence when the count is 0 is not flagged: this rule fails a
     claim the rows contradict, it never requires prose that isn't there.
     This rule is general — it is not keyed to any particular app or run.
  5. When a pre-review directory is given and its root/readme.json has a
     `stub` key, the report's "## Repo-level gate criteria" table's STR-01
     row that names the README (the third cell contains "README",
     case-insensitively — a LICENSE STR-01 row is not this row and is
     ignored) must be FAIL iff `stub` is true. A mismatch is `MISMATCH
     <app> STR-01 README gate: <result> but readme.json says stub:
     <true|false>`, <app> always "root" (the table is repo-level, never
     per app). Without a pre-review directory, or with one whose
     root/readme.json has no `stub` key, this rule does nothing — it does
     not fall back to a findings-JSON record the way the stub-README rating
     exception (above) does. This rule is general — it is not keyed to any
     particular app or run.

  6. With a pre-review directory whose <app_id>/readme.json has `rungs`
     and is not a stub, the rating starts from the facts' baseline
     (readme_lines.baseline_rating, the highest rung whose requirements and
     every lower rung's the facts meet; the pre-review writes it as
     readme.json `baseline_rating`). The checker computes it from `rungs`,
     `screenshots` and `env_vars`, so facts written before that key are
     read the same way.
     - A rating below the baseline (Below minimal counts as lowest) must
       carry `(lowered from <baseline>: <reason>)` on its rating line, the
       reason non-empty: without it `MISMATCH <app> documentation: rated
       <r> below the readme.json baseline <b> with no reason ...`; naming a
       rung other than the baseline is `... lowered from <x> but the
       readme.json baseline is <b>`.
     - A lowering clause on a rating at or above the baseline is a
       mismatch (`... rated <r> with a lowering clause ...`).
     - A rating above the baseline is a mismatch unless every requirement
       between the baseline and the claimed rung that the facts do not meet
       is cited as `content: <path>:N` (check-evidence.py verifies that
       line): `... rated <r> above the readme.json baseline <b>; '<req>' is
       not met in readme.json and its evidence is not a content: line`.
     Rule 6 runs only when rule 1 passed for the app (one rating line per
     app) and never for the stub line. Without a pre-review directory, or
     with a readme.json that has no `rungs`, it does nothing.

Every MISMATCH line that names an app uses its pre-review directory name
(fact_app_id: "root" for a single app with no id or "."), so the same app
reads the same in every line.

The findings argument is read: for the Below minimal and stub-README
exceptions above, and for rule 3, which scans every record regardless of
app section.

Exit 0 when consistent, 1 with one MISMATCH line per problem, 2 when the
report, findings or checks.json cannot be read or a readme.json the stub
check reads is not valid JSON, 3 (a malformed report) when a needed section
or row is missing.
"""
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CHECKS_JSON = os.path.join(SCRIPT_DIR, "checks.json")
sys.path.insert(0, SCRIPT_DIR)
from report_parse import (  # noqa: E402
    positional_args,
    MALFORMED,
    app_sections as _app_sections, header_name, is_separator, normalize_result, split_row,
)
from readme_lines import BELOW_MINIMAL, DOC_LADDER, baseline_rating, facts_meet  # noqa: E402

GOOD_PRACTICE_RULES = {"MNT-02", "MNT-03", "MNT-04", "MNT-05", "MNT-06"}
# Severities above info: a suggestion-class record rated one of these is a
# fix-item (check-feedback-floor.py), which a suggestion must never be.
ABOVE_INFO = {"critical", "high", "medium", "low"}

SECURITY_CLAIM_SENTENCE = "No tool-detectable issues in the checked tiers."

RUNGS = DOC_LADDER
RATING_ORDER = [r for r, _ in RUNGS]
DOC_SIGNAL = {BELOW_MINIMAL: "High", "Minimal": "High", "Adequate": "Medium", "Strong": "Low",
              "Exemplary": "Low"}
# The lowering clause on the rating line: `(lowered from <baseline>: <reason>)`.
LOWERED_RE = re.compile(r"\(\s*lowered from\s+((?i:below\s+minimal)|Minimal|Adequate|Strong|Exemplary)"
                        r"\s*:\s*([^)]*?)\s*\)", re.I)
RATING_RE = re.compile(r"Rating:\s*\**\s*((?i:below\s+minimal)|Minimal|Adequate|Strong|Exemplary)")
STUB_NOT_STUB = "stub rating but readme.json says the README is not a stub"
STUB_NO_RECORD = "stub rating but no STR-01 readme-not-substantive FAIL record and no readme.json stub fact"
BELOW_NO_RECORD = "Below minimal rating but no QUA-01 docs-minimal FAIL record"
BELOW_BUT_STUB = "Below minimal rating but readme.json says the README is a stub (the stub line applies)"
CONTENT_CITE_RE = re.compile(r"(?<![\w-])content:\s*[`*]*([^\s`*:]+):(\d+)")
NONE_WORDS = {"none", "n/a", "na", "absent", "missing", "not", "no"}
STUB_LINE = "Minimal \u2014 not supported (stub README; see QUA-01)"  # the form the docs write
STUB_RATING = re.compile(r"Rating:\s*\**\s*Minimal\s*(?:\u2014|\u2013|--?)\s*not supported\s*"
                         r"\(stub README; see QUA-01\)")


def is_none(value):
    if not re.sub(r"[\W_]", "", value):
        return True  # empty or punctuation only ("—", "-", "")
    first = re.sub(r"[^a-z/]", "", value.strip().lower().split()[0])
    return first in NONE_WORDS


def app_sections(text):
    """Yield (app_heading, body) for each '## App:' section. Thin wrapper
    around report_parse.app_sections (the shared parser check-rows.py and
    compare-runs.py also use), dropping the paren-value key this module
    does not need."""
    for heading, _key, body in _app_sections(text):
        yield heading, body


def subsection(body, name):
    m = re.search(r"^### " + re.escape(name) + r"\s*$(.*?)(?=^### |\Z)", body, flags=re.M | re.S)
    return m.group(1) if m else None


def parse_evidence(doc):
    """Map rung requirement -> value, from bullet lines or semicolon-joined lines."""
    m = re.search(r"Evidence per rung[^\n]*\n(.*?)(?=\n\s*\n|\n<!--|\Z)", doc, flags=re.S)
    if not m:
        return {}
    block = m.group(1)
    items = []
    for line in block.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped[:2] in ("- ", "* ", "+ "):
            items.append(stripped[2:])           # bullet form: one requirement per line
        else:
            items.extend(p for p in stripped.split(";") if p.strip())  # template form
    out = {}
    for item in items:
        k, _, v = item.partition(":")
        # "**what it launches:** README.md:27" splits into "**what it launches"
        # and "** README.md:27"; drop the emphasis markers from both.
        out[re.sub(r"[*_`]", "", k).strip().lower()] = v.strip().strip("*_`").strip()
    return out


def reused_content_lines(app_id, evidence):
    """MISMATCH lines for a `content: <path>:N` line cited for two rung
    requirements: one line of prose does not meet two requirements. Named
    by the first two requirements (in RUNGS order) that cite it."""
    order = [req for _, reqs in RUNGS for req in reqs]
    first = {}
    lines = []
    for req in sorted(evidence, key=lambda k: order.index(k) if k in order else len(order)):
        for path, n in CONTENT_CITE_RE.findall(evidence[req]):
            cite = "{}:{}".format(path, n)
            if cite in first and first[cite] != req:
                lines.append("MISMATCH {} documentation: content line {} cited for two rungs ({}, {})"
                             .format(app_id, cite, first[cite], req))
            first.setdefault(cite, req)
    return lines


def highest_supported_rung(evidence):
    best = None
    for rung, reqs in RUNGS:
        if all(req in evidence and not is_none(evidence[req]) for req in reqs):
            best = rung
        else:
            break
    return best


def app_id_of(heading):
    m = re.search(r"\(([^()]*)\)\s*$", heading)
    return m.group(1).strip().strip("/") if m else None


def has_record(findings, rule, tag, results, app_ids, single):
    """Whether findings hold a `rule` record with one of `results` whose
    defect_key tag is `tag` (or `tag:<qualifier>`), for an app_id in
    app_ids (or, in a single-app report, a record with no app_id)."""
    for r in findings:
        if r.get("rule") != rule or r.get("result") not in results:
            continue
        key_tag = str(r.get("defect_key") or "").split(":", 1)[-1]
        if key_tag != tag and not key_tag.startswith(tag + ":"):
            continue
        rid = str(r.get("app_id") or "").strip().strip("/")
        if rid in app_ids or (single and not rid):
            return True
    return False


def has_stub_record(findings, app_id, single):
    """Whether findings hold a QUA-01 FAIL docs-stub record for app_id (or,
    in a single-app report, a record with no app_id)."""
    return has_record(findings, "QUA-01", "docs-stub", ("FAIL",), {app_id or ""}, single)


def fact_app_id(app_id):
    """The pre-review directory name for a heading's app id: "root" for a
    single app written with no id or as "."."""
    return "root" if app_id in (None, "", ".") else app_id


def readme_facts(pre_review_dir, app_id):
    """The app's readme.json as a dict, or None when there is no directory
    or no readme.json. Raises ValueError when the file exists but is not a
    JSON object."""
    if not pre_review_dir:
        return None
    path = os.path.join(pre_review_dir, fact_app_id(app_id), "readme.json")
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        raise ValueError("{}: {}".format(path, e))
    if not isinstance(data, dict):
        raise ValueError("{}: not a JSON object".format(path))
    return data


def readme_stub_fact(pre_review_dir, app_id):
    """readme.json's `stub` for the app: True/False, or None when there is
    no directory, no readme.json, or no `stub` key. Raises ValueError when
    the file exists but is not a JSON object."""
    data = readme_facts(pre_review_dir, app_id)
    if data is None:
        return None
    stub = data.get("stub")
    return stub if isinstance(stub, bool) else None


def stub_problem(findings, app_id, single, pre_review_dir):
    """None when the stub rating line is backed by the facts (readme.json
    stub true) or, with no stub fact, by a STR-01 readme-not-substantive
    FAIL record for the app or the repo; else the MISMATCH reason."""
    fact = readme_stub_fact(pre_review_dir, app_id)
    if fact is True:
        return None
    if fact is False:
        return STUB_NOT_STUB
    ids = {app_id or "", fact_app_id(app_id), "root"}
    if has_record(findings, "STR-01", "readme-not-substantive", ("FAIL",), ids, True):
        return None
    return STUB_NO_RECORD


def rating_rank(rating):
    """Position on the ladder, Below minimal lowest."""
    return -1 if rating == BELOW_MINIMAL else RATING_ORDER.index(rating)


def canonical_rating(text):
    low = " ".join(text.lower().split())
    return BELOW_MINIMAL if low == "below minimal" else low.capitalize()


def baseline_mismatch(app, rating, rating_line, evidence, facts):
    """The MISMATCH line (or None) for rule 6, the rating against the
    facts' baseline (readme_lines.baseline_rating). A rating below the
    baseline needs `(lowered from <baseline>: <reason>)` on its rating
    line, naming the baseline and giving a reason; a lowering clause on a
    rating that is not below the baseline is a mismatch too. A rating
    above the baseline is a mismatch unless every requirement up to it
    that the facts do not meet is cited as a `content: <path>:N` line (a
    line the README delivers the rung on outside its own heading)."""
    baseline = baseline_rating(facts)
    if baseline is None:
        return None
    m = LOWERED_RE.search(rating_line)
    named = canonical_rating(m.group(1)) if m else None
    reason = m.group(2).strip() if m else ""
    if rating_rank(rating) < rating_rank(baseline):
        if not m or not re.search(r"[A-Za-z]", reason):
            return ("MISMATCH {} documentation: rated {} below the readme.json baseline {} with no reason "
                    "(write '(lowered from {}: <reason>)' on the rating line)".format(app, rating, baseline, baseline))
        if named != baseline:
            return ("MISMATCH {} documentation: lowered from {} but the readme.json baseline is {}"
                    .format(app, named, baseline))
        return None
    if m:
        return ("MISMATCH {} documentation: rated {} with a lowering clause but the readme.json baseline is {}"
                .format(app, rating, baseline))
    if rating_rank(rating) > rating_rank(baseline):
        for rung, reqs in RUNGS:
            if rating_rank(rung) <= rating_rank(baseline):
                continue
            for req in reqs:
                if facts_meet(facts, req) or CONTENT_CITE_RE.search(evidence.get(req, "")):
                    continue
                return ("MISMATCH {} documentation: rated {} above the readme.json baseline {}; '{}' is not "
                        "met in readme.json and its evidence is not a content: line"
                        .format(app, rating, baseline, req))
            if rung == rating:
                break
    return None


def defect_tag(defect_key):
    """The mechanism tag out of a defect_key: the part after the first ':'
    (the anchor), truncated before any further ':' qualifier."""
    key = str(defect_key or "")
    tag = key.split(":", 1)[1] if ":" in key else key
    return tag.split(":", 1)[0]


class ChecksUnreadable(Exception):
    pass


def load_checks(path=CHECKS_JSON):
    """checks.json's checks list. Raises ChecksUnreadable (with the reason)
    when the file cannot be read, is not JSON, or has no checks list: rule
    3 cannot tell a suggestion from a target without it, and a silent pass
    would hide that."""
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except OSError as e:
        raise ChecksUnreadable(e.strerror or str(e))
    except ValueError as e:
        raise ChecksUnreadable(str(e))
    checks = data.get("checks") if isinstance(data, dict) else None
    if not isinstance(checks, list):
        raise ChecksUnreadable("no checks list")
    return [c for c in checks if isinstance(c, dict) and c.get("id")]


def matching_check(record, checks):
    """The checks.json entry a record belongs to: the first whose rule equals
    the record's and whose `tags` (every vocabulary tag the check owns;
    the single `tag` when `tags` is absent) holds the record's tag, read
    before any qualifier. None when nothing matches."""
    rule = record.get("rule")
    tag = defect_tag(record.get("defect_key"))
    for c in checks:
        owned = c.get("tags") if isinstance(c.get("tags"), list) else [c.get("tag")]
        if c.get("rule") == rule and tag in owned:
            return c
    return None


def never_fail_mismatches(findings, checks):
    """MISMATCH lines for suggestion-class checks and MNT-02..MNT-06
    good-practice signals recorded as FAIL — the rubric holds neither is
    ever a failure — and for a suggestion-class FAIL or WARN rated above
    info, its default_severity, so it never becomes a fix-item. One line
    per problem: a suggestion FAIL rated low gets both lines."""
    lines = []
    for r in findings:
        result = r.get("result")
        if result not in ("FAIL", "WARN"):
            continue
        rule = r.get("rule")
        app_id = fact_app_id(str(r.get("app_id") or "").strip().strip("/"))
        check = matching_check(r, checks)
        suggestion = check is not None and check.get("weight") == "suggestion"
        severity = str(r.get("severity") or "").strip().lower()
        if suggestion and severity in ABOVE_INFO:
            lines.append(
                "MISMATCH {} {} {}: suggestion (check {}) rated {}; suggestions are info".format(
                    app_id, rule, r.get("defect_key"), check["id"], severity))
        if result != "FAIL":
            continue
        if suggestion:
            lines.append(
                "MISMATCH {} {} {}: suggestion (check {}) recorded as FAIL".format(
                    app_id, rule, r.get("defect_key"), check["id"]))
        elif rule in GOOD_PRACTICE_RULES:
            lines.append(
                "MISMATCH {} {} {}: good-practice signal recorded as FAIL".format(
                    app_id, rule, r.get("defect_key")))
    return lines


def count_flagged_security_rows(security):
    """Count table rows in a '### Security' body whose Result cell
    normalises to FAIL or WARN, whatever the rule code in the first cell (a
    tool-finding row records under a QUA-xx rule; `**OODT-01**` is read as
    OODT-01). The Result cell is the table's own Result column when its
    header has one, else the cell after Check, else the second cell. The
    body can hold more than one table (Findings, then Additional
    observations (review)), and each table's header is read independently —
    a column layout in one table must not leak into the next."""
    count = 0
    lines = security.splitlines()
    result_index = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.startswith("|"):
            result_index = None
            continue
        # A header row is a '|' row immediately followed by a '|---' style
        # separator row: that pair starts a new table.
        next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""
        if next_line.startswith("|") and is_separator(next_line):
            header = [header_name(c) for c in split_row(line)]
            if "result" in header:
                result_index = header.index("result")
            else:
                result_index = header.index("check") + 1 if "check" in header else 1
            continue
        if result_index is None or is_separator(stripped):
            continue
        cells = split_row(line)
        if not re.sub(r"[*`_\s]", "", cells[0] if cells else ""):
            continue
        if result_index < len(cells) and normalize_result(cells[result_index]) in ("FAIL", "WARN"):
            count += 1
    return count


def gate_section(report):
    """The body of the report's '## Repo-level gate criteria' section (up
    to the next '## '), or None when there is no such section."""
    m = re.search(r"^## Repo-level gate criteria\s*$(.*?)(?=^## |\Z)", report, flags=re.M | re.S)
    return m.group(1) if m else None


def readme_gate_results(gate):
    """Results (normalize_result) of every STR-01 row in a gate-table body
    whose third cell names the README (contains "README", case-insensitive;
    a LICENSE row is not this row and is skipped). Table headers are read
    the same way count_flagged_security_rows reads them, so a Rule/Result
    column reorder is still found."""
    results = []
    lines = gate.splitlines()
    rule_index = result_index = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.startswith("|"):
            rule_index = result_index = None
            continue
        next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""
        if next_line.startswith("|") and is_separator(next_line):
            header = [header_name(c) for c in split_row(line)]
            rule_index = header.index("rule") if "rule" in header else 0
            result_index = header.index("result") if "result" in header else 1
            continue
        if result_index is None or is_separator(stripped):
            continue
        cells = split_row(line)
        if not re.sub(r"[*`_\s]", "", cells[0] if cells else ""):
            continue
        rule_cell = re.sub(r"[*`_]", "", cells[rule_index]).strip() if rule_index < len(cells) else ""
        if rule_cell != "STR-01":
            continue
        third = cells[2] if len(cells) > 2 else ""
        if "readme" not in third.lower():
            continue
        if result_index < len(cells):
            results.append(normalize_result(cells[result_index]))
    return results


def readme_gate_mismatches(report, pre_review_dir):
    """MISMATCH lines for rule 5: each STR-01 README row in the repo-level
    gate table whose Result disagrees with root/readme.json's `stub` fact.
    [] when there is no pre-review directory, no gate section, or the fact
    is absent (no readme.json, or no `stub` key)."""
    stub = readme_stub_fact(pre_review_dir, None)
    if stub is None:
        return []
    gate = gate_section(report)
    if gate is None:
        return []
    lines = []
    for result in readme_gate_results(gate):
        is_fail = result == "FAIL"
        if is_fail != stub:
            lines.append("MISMATCH root STR-01 README gate: {} but readme.json says stub: {}".format(
                result, "true" if stub else "false"))
    return lines


def normalize_prose(text):
    """text with emphasis markers dropped, U+2011 (non-breaking hyphen)
    mapped to a plain '-', whitespace runs collapsed, casefolded and a
    trailing period removed, for matching a sentence however it is
    emphasised, wrapped, cased, hyphenated or ended."""
    return re.sub(r"\s+", " ", re.sub(r"[*_`]", "", text.replace("\u2011", "-"))).strip().rstrip(".").casefold()


def security_claim_mismatch(app_id, security):
    """MISMATCH line for a '### Security' body that claims "No tool-detectable
    issues in the checked tiers." (with or without emphasis, a line wrap or
    the final period) while its own rows contradict that claim (a FAIL or
    WARN row present). None when the claim holds, and also None when the
    sentence is simply absent — a checker fails a claim the report makes
    against its own rows; it never requires prose that isn't there."""
    count = count_flagged_security_rows(security)
    prose = normalize_prose("\n".join(l for l in security.splitlines() if not l.lstrip().startswith("|")))
    if count > 0 and normalize_prose(SECURITY_CLAIM_SENTENCE) in prose:
        return ('MISMATCH {} security: "{}" with {} FAIL/WARN row{} above it'
                .format(app_id, SECURITY_CLAIM_SENTENCE, count, "" if count == 1 else "s"))
    return None


def signal(body, dim):
    m = re.search(r"^\|\s*(?:\*\*)?" + dim + r"(?:\*\*)?\s*\|\s*(?:\*\*)?(Low|Medium|High)(?:\*\*)?\s*\|",
                  body, flags=re.M)
    return m.group(1) if m else None


def main(argv):
    argv = positional_args(argv, ["report.md", "findings.json"], ["pre-review-dir"], description=(__doc__ or "").split("\n\n")[0])
    if isinstance(argv, int):
        return argv
    pre_review_dir = argv[3] if len(argv) == 4 else None
    try:
        report = open(argv[1]).read()
        with open(argv[2], encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    findings = data.get("findings", data) if isinstance(data, dict) else data
    if not isinstance(findings, list):
        print("error: findings '{}' is not a list".format(argv[2]), file=sys.stderr)
        return 2
    findings = [r for r in findings if isinstance(r, dict)]
    try:
        checks = load_checks()
    except ChecksUnreadable as e:
        print("error: cannot load references/checks.json ({})".format(e), file=sys.stderr)
        return 2
    problems = 0
    seen = 0
    sections = list(app_sections(report))
    for heading, body in sections:
        seen += 1
        doc = subsection(body, "Documentation")
        if doc is None:
            print("error: {} has no '### Documentation' section".format(heading), file=sys.stderr)
            return MALFORMED
        rm = RATING_RE.search(doc)
        if not rm:
            print("error: {} has no Documentation rating".format(heading), file=sys.stderr)
            return MALFORMED
        rating = rm.group(1)
        if rating.lower().split() == ["below", "minimal"]:
            rating = BELOW_MINIMAL
        evidence = parse_evidence(doc)
        supported = highest_supported_rung(evidence)

        signals = subsection(body, "Signals")
        if signals is None:
            print("error: {} has no '### Signals' section".format(heading), file=sys.stderr)
            return MALFORMED
        doc_sig = signal(signals, "Documentation")
        if doc_sig is None:
            print("error: {} has no Signals row for Documentation".format(heading), file=sys.stderr)
            return MALFORMED

        app_id = app_id_of(heading)
        single = len(sections) == 1
        stub_ok = (STUB_RATING.search(doc) is not None and
                   has_stub_record(findings, app_id, single))
        rating_line = doc[rm.start():].split("\n", 1)[0]
        try:
            facts = readme_facts(pre_review_dir, app_id)
        except ValueError as e:
            print("error: {}".format(e), file=sys.stderr)
            return 2
        ceiling_ok = True
        if stub_ok:
            try:
                reason = stub_problem(findings, app_id, single, pre_review_dir)
            except ValueError as e:
                print("error: {}".format(e), file=sys.stderr)
                return 2
            if reason:
                problems += 1
                print("MISMATCH {} documentation: {}".format(fact_app_id(app_id), reason))
        elif rating == BELOW_MINIMAL:
            if not has_record(findings, "QUA-01", "docs-minimal", ("FAIL",), {app_id or ""}, single):
                problems += 1
                print("MISMATCH {} documentation: {}".format(fact_app_id(app_id), BELOW_NO_RECORD))
            try:
                stub_fact = readme_stub_fact(pre_review_dir, app_id)
            except ValueError as e:
                print("error: {}".format(e), file=sys.stderr)
                return 2
            if stub_fact is True:
                problems += 1
                print("MISMATCH {} documentation: {}".format(fact_app_id(app_id), BELOW_BUT_STUB))
        elif supported is None or RATING_ORDER.index(rating) > RATING_ORDER.index(supported):
            # name the first requirement that blocks the claimed rung
            blocker = None
            for rung, reqs in RUNGS:
                for req in reqs:
                    if req not in evidence or is_none(evidence[req]):
                        blocker = req
                        break
                if blocker or rung == rating:
                    break
            problems += 1
            ceiling_ok = False
            print("MISMATCH Documentation rating ({} claimed but '{}' evidence is {}; highest supported rung is {})".format(
                rating, blocker, "missing" if blocker not in evidence else "none", supported or "none"))
        if not stub_ok and ceiling_ok and facts is not None and facts.get("stub") is not True:
            line = baseline_mismatch(fact_app_id(app_id), rating, rating_line, evidence, facts)
            if line:
                problems += 1
                print(line)
        for line in reused_content_lines(fact_app_id(app_id), evidence):
            problems += 1
            print(line)
        if doc_sig != DOC_SIGNAL[rating]:
            problems += 1
            print("MISMATCH Documentation signal (report says {}; rating {} maps to {})".format(doc_sig, rating, DOC_SIGNAL[rating]))

        security = subsection(body, "Security")
        if security is not None:
            claim_problem = security_claim_mismatch(fact_app_id(app_id), security)
            if claim_problem:
                problems += 1
                print(claim_problem)
    if seen == 0:
        print("error: no '## App:' section in report", file=sys.stderr)
        return MALFORMED

    for line in never_fail_mismatches(findings, checks):
        problems += 1
        print(line)

    try:
        gate_lines = readme_gate_mismatches(report, pre_review_dir)
    except ValueError as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    for line in gate_lines:
        problems += 1
        print(line)

    print("ratings: consistent" if not problems else "ratings: {} mismatch{}".format(problems, "" if problems == 1 else "es"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
