#!/usr/bin/env python3
"""Check that the report has the sections a reader and the portal rely on,
and that its decisions agree with meta.json.

    python3 references/check-sections.py <report.md> [<meta.json>]

Other checkers already fail a report without the '## App:' sections, their
Signals and Documentation, the gate table, the feedback section or the
Catalog checks. This covers the rest of the template (review-app SKILL.md
section 3):

  1. '## Upkeep', '## Review scope' and '## Overall recommendation' are
     present (a heading may carry more words after its title), and the
     Overall recommendation states a decision (Accept, Accept with
     suggestions, Request changes or Reject) outside HTML comments: the one
     it opens with (the template opens it in bold), one after "decision is"
     or "Decision:", the first in bold, or the only one it names.
  2. In a report with more than one '## App:' section, every one has a
     'Per-app decision' line naming a decision.
  3. With a meta.json, the report and the metadata agree: the Overall
     recommendation's decision is recommendation.decision, each Per-app
     decision is that app's apps[].decision (matched by the app id in the
     section heading's parentheses), and a single-app repo's apps[].decision
     is the recommendation. Fields meta.json lacks are check-meta.py's to
     report, so they are skipped here.

Output: one MISSING or MISMATCH line per problem, then a summary line.
Exit 0 when complete, 1 when a section is missing or a decision disagrees,
2 when an input cannot be read.
"""
import json
import re
import sys

from report_parse import (DECISION_NAMES as NAMES, app_sections, normalize_decision as norm,
                          section, section_for)

REQUIRED = ("Upkeep", "Review scope", "Overall recommendation")
DEC = r"(accept[\s-]+with[\s-]+suggestions|request[\s-]+changes|reject|accept)"
DECISION_RE = re.compile(r"\b" + DEC + r"\b", re.I)
LEADING_RE = re.compile(r"^[\s*_>#.-]*" + DEC + r"\b", re.I)
STATED_RE = re.compile(r"(?:recommend(?:ed|ation)?(?:\s+decision)?|decision)\s*\**\s*(?:is|:)\s*\**\s*" + DEC, re.I)
BOLD_RE = re.compile(r"\*\*\s*" + DEC + r"\b[^*]*\*\*", re.I)
PER_APP_RE = re.compile(r"per[\s-]+app\s+decision\W*(.*)", re.I)


def stated_decision(text):
    """The decision a paragraph states, in order of how explicitly it says so:
    the decision it opens with ("**Request changes.**", "Request changes."),
    one after "decision is" or "Decision:", the first in bold, or the only one
    it names at all. None when it names several without stating which, so
    prose that mentions a milder outcome "once the gates are fixed" is not
    read as that outcome."""
    for para in [p for p in re.split(r"\n\s*\n", text) if p.strip()][:1]:
        m = LEADING_RE.match(para)
        if m:
            return norm(m.group(1))
    for rx in (STATED_RE, BOLD_RE):
        m = rx.search(text)
        if m:
            return norm(m.group(1))
    named = {norm(m.group(1)) for m in DECISION_RE.finditer(text)}
    return named.pop() if len(named) == 1 else None


def per_app_decision(body):
    """(found_line, decision) for an app section's Per-app decision line."""
    for line in body.splitlines():
        m = PER_APP_RE.search(line)
        if m:
            return True, stated_decision(m.group(1))
    return False, None


def main(argv):
    if len(argv) not in (2, 3):
        print("usage: check-sections.py <report.md> [<meta.json>]", file=sys.stderr)
        return 2
    try:
        with open(argv[1], encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        print("error: cannot read report %s (%s)" % (argv[1], e))
        return 2
    meta = None
    if len(argv) == 3:
        try:
            with open(argv[2], encoding="utf-8") as f:
                meta = json.load(f)
        except (OSError, ValueError) as e:
            print("error: cannot read meta.json %s (%s)" % (argv[2], e))
            return 2
        if not isinstance(meta, dict):
            print("error: meta.json is not a JSON object")
            return 2
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)  # the template's comments name every decision

    problems = []
    for title in REQUIRED:
        if section(text, title) is None:
            problems.append("MISSING section: ## %s" % title)
    rec_body = section(text, "Overall recommendation")
    report_rec = stated_decision(rec_body) if rec_body is not None else None
    if rec_body is not None and report_rec is None:
        problems.append("MISSING decision: ## Overall recommendation does not state its decision; open it "
                        "with the decision in bold, e.g. **Request changes.**")

    apps = app_sections(text)
    if len(apps) > 1:
        for heading, _, body in apps:
            found, d = per_app_decision(body)
            if not found or d is None:
                problems.append("MISSING decision: %s has no Per-app decision line naming a decision" % heading)

    if meta is not None:
        rec = meta.get("recommendation") if isinstance(meta.get("recommendation"), dict) else {}
        meta_rec = norm(rec.get("decision"))
        if report_rec and meta_rec and report_rec != meta_rec:
            problems.append("MISMATCH decision recommendation: the report says %s, meta.json says %s"
                            % (NAMES[report_rec], NAMES[meta_rec]))
        meta_apps = [a for a in meta.get("apps") or [] if isinstance(a, dict) and a.get("app_id")]
        for a in meta_apps:
            want = norm(a.get("decision"))
            if want is None:
                continue
            if len(apps) > 1:
                # The same id matching check-rows uses (a trailing "/" or the
                # app's path both name it), so the two cannot disagree.
                body = section_for(a, apps, single=False)
                have = per_app_decision(body)[1] if body is not None else None
                where = "its Per-app decision line"
            else:
                have, where = report_rec, "the Overall recommendation"
            if have and have != want:
                problems.append("MISMATCH decision %s: %s says %s, meta.json says %s"
                                % (a["app_id"], where, NAMES[have], NAMES[want]))

    for p in problems:
        print(p)
    print("sections: %s" % ("complete" if not problems else "%d problem%s" % (len(problems), "" if len(problems) == 1 else "s")))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
