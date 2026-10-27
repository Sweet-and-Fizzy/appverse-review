#!/usr/bin/env python3
"""Write the report's "Since the last review" section from the baseline.

    python3 references/insert-since.py <report.md> <findings.json> --baseline <path>

Compares the report's findings with the last review the hub sent to the
contributor (see review_baseline.py) and writes three groups: New, Still
open and Not found this time. An existing section is replaced in place;
otherwise the section goes before "## Overall recommendation" (or
"## Draft feedback"), else at the end. With no comparison (no baseline, or
one without findings) any existing section is removed instead, so a stale
section never survives a rerun.

Exit 0 in every case except an unreadable or unwritable report or findings
file (2).
"""
import datetime
import json
import os
import re
import sys

import report_parse
import review_baseline as rb

HEADING_RE = re.compile(r"^## Since the last review\b.*$", re.M)
NEXT_H2_RE = re.compile(r"^## ", re.M)
ANCHORS = ("## Overall recommendation", "## Draft feedback")
NOTE = ("_Not found this time means this run did not record the finding: "
        "it may have been fixed, or the review may have varied._")


def _line(finding, summary=None, dismissed=False):
    rule = finding.get("rule") or "—"
    text = "- {} `{}`".format(rule, finding["defect_key"])
    if summary:
        text += " — " + summary
    if dismissed:
        text += " (dismissed last time)"
    return text


def _group(label, lines):
    return ["**{}** ({})".format(label, len(lines))] + lines


def section(findings, baseline):
    """The section text, trailing newline included."""
    sent = datetime.datetime.fromtimestamp(baseline["sent_at"], datetime.timezone.utc)
    date, commit = sent.strftime("%Y-%m-%d"), baseline["sha"][:7]
    if baseline.get("same_commit"):
        heading = "## Since the last review (same commit {}, sent {})".format(commit, date)
    else:
        heading = "## Since the last review (sent {}, commit {})".format(date, commit)
    status = rb.statuses(findings, baseline)
    seen = set()
    new, still = [], []
    for f in findings:
        i = rb.stable_id(f)
        if i in seen or i not in status:
            continue
        seen.add(i)
        line = _line(f, f.get("summary"), status[i] == "still_open" and rb.dismissed_last_time(f, baseline))
        (new if status[i] == "new" else still).append(line)
    gone = [_line(f) for f in rb.not_found(findings, baseline)]
    parts = _group("New", new) + _group("Still open", still) + _group("Not found this time", gone)
    return "\n".join([heading, ""] + parts + ["", NOTE]) + "\n"


def place(text, new_section):
    """Replace, remove (new_section None) or insert the section in the report."""
    m = HEADING_RE.search(text)
    if m:
        nxt = NEXT_H2_RE.search(text, m.end())
        end = nxt.start() if nxt else len(text)
        tail = text[end:]
        if new_section is None:
            return text[:m.start()] + tail if tail else text[:m.start()].rstrip("\n") + "\n"
        return text[:m.start()] + new_section + ("\n" + tail if tail else "")
    if new_section is None:
        return text
    for anchor in ANCHORS:
        a = re.search(r"^" + re.escape(anchor), text, re.M)
        if a:
            return text[:a.start()] + new_section + "\n" + text[a.start():]
    return text.rstrip("\n") + "\n\n" + new_section


def main(argv):
    parsed = report_parse.positional_args(
        argv, ["report.md", "findings.json"], options=("--baseline",),
        description=(__doc__ or "").split("\n\n")[0])
    if isinstance(parsed, int):
        return parsed
    (_, report, findings_path), opts = parsed
    try:
        with open(report, encoding="utf-8") as f:
            text = f.read()
        with open(findings_path, encoding="utf-8") as f:
            findings = json.load(f)
    except (OSError, ValueError) as e:
        print("error: %s" % e)
        return 2
    baseline = rb.load(opts["--baseline"])
    comparable = bool(baseline and baseline.get("comparable"))
    new = place(text, section(findings, baseline) if comparable else None)
    if new != text:
        try:
            tmp = report + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                f.write(new)
            os.replace(tmp, report)
        except OSError as e:
            print("error: %s" % e)
            return 2
    print("insert-since: %s" % ("Since the last review section written" if comparable
                                else "no comparison; no section written"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
