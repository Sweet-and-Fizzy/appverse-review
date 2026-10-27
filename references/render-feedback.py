#!/usr/bin/env python3
"""Write the report's Draft feedback section from feedback.json.

    python3 references/render-feedback.py <report.md> <feedback.json>

feedback.json is prepare-feedback.py's output with the model's `opening`
and item `text` filled in. The section is replaced whole: a
`## Draft feedback` heading (with or without "— edit before sending") and
its body, up to the next `## ` heading or the structured-findings ```json
fence. With no such heading, the section is appended at the end.

The section is the greeting and opening on one line, then each non-empty
level as a bold label and numbered items, numbered straight through, then
the reminder paragraph when there is one, a feedback-generated marker and
the feedback-covers checksum of every rendered defect key. When the file has
a `greeting` key (even an empty one: nothing changed since the last send),
the greeting is the thank-you, so a leading thank-you sentence the model
left in `opening` is dropped; a file without the key (an old one) renders
the opening as written, or the default thank-you when it is empty. A
`still_open` item is prefixed "Still open from the last review:". An item with
no text falls back to its findings' summaries, marked feedback-missing, so
the reviewer still gets a complete draft; the warning names those groups
(as a GitHub Actions ::warning:: when GITHUB_ACTIONS is set).

Exit 0 in every degraded case, including an unreadable feedback.json (an
empty list under the default opening); exit 2 only when the report cannot be
read or written.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from feedback_terms import draft_section_bounds  # noqa: E402

HEADING = "## Draft feedback — edit before sending"
TITLE_RE = re.compile(r"^#\s+Appverse Review:\s*(?:[^/\s]+/)?([^\s(]+)", re.MULTILINE)
LABELS = (("must", "**Must fix**"), ("should", "**Should fix**"), ("suggestion", "**Suggestions (optional)**"))


def default_opening(app_name, report):
    name = app_name
    if not name:
        m = TITLE_RE.search(report)
        name = m.group(1) if m else "this app"
    return "Thank you for submitting {} to Appverse.".format(name)


THANKS_RE = re.compile(r"^\s*(?:thank you|thanks)\b.*?[.!?](?:\s+|$)", re.IGNORECASE)


def as_text(value):
    """A string field as one line. A newline the model put in a JSON string
    would end the numbered list, or start a `## ` section of its own that
    carries the covers comment out of the Draft feedback section."""
    return " ".join(value.split()) if isinstance(value, str) else ""


def fallback_text(summaries):
    """The findings' summaries as sentences, each once, for an item the model
    wrote no text for. Several findings in one group often share a summary."""
    out = []
    for s in summaries:
        s = as_text(s)
        if s and s[-1] not in ".!?":
            s += "."
        if s and s not in out:
            out.append(s)
    return " ".join(out)


def render_section(doc, report):
    items = [i for i in doc.get("items", []) if isinstance(i, dict)] if isinstance(doc.get("items"), list) else []
    # The opening is the one line not led by an item number, so a leading
    # '#' would make it a heading and end the section there.
    opening = as_text(doc.get("opening")).lstrip("# ").strip()
    if "greeting" in doc:
        # The greeting is the thank-you, so one the model also wrote into the
        # opening would thank twice (or at all, when nothing changed).
        greeting = as_text(doc.get("greeting")).lstrip("# ").strip()
        opening = THANKS_RE.sub("", opening, count=1).strip()
        first = " ".join(part for part in (greeting, opening) if part)
    else:
        first = opening or default_opening(as_text(doc.get("app_name")), report)
    lines = [HEADING, ""] + ([first, ""] if first else [])
    missing = []
    covers = []
    n = 0
    for level, label in LABELS:
        group = [i for i in items if i.get("level") == level]
        if not group:
            continue
        lines += [label, ""]
        for item in group:
            n += 1
            locations = [str(loc) for loc in item.get("locations", []) if loc] \
                if isinstance(item.get("locations"), list) else []
            prefix = ", ".join("`{}`".format(loc) for loc in locations)
            text = as_text(item.get("text"))
            if not text:
                summaries = item.get("summaries") if isinstance(item.get("summaries"), list) else []
                text = (fallback_text(summaries) + " <!-- feedback-missing -->").strip()
                missing.append(str(item.get("group", "?")))
            if item.get("still_open") is True:
                prefix = (prefix + " " if prefix else "") + "Still open from the last review:"
            lines.append("{}. {}".format(n, (prefix + " " + text) if prefix else text))
            keys = item.get("defect_keys") if isinstance(item.get("defect_keys"), list) else []
            covers += [str(k) for k in keys if k]
        lines.append("")
    reminder = as_text(doc.get("reminder")).lstrip("# ").strip()
    if reminder:
        lines += [reminder, ""]
    lines += ["<!-- feedback-generated -->", "<!-- feedback-covers: {} -->".format(", ".join(covers)), ""]
    return "\n".join(lines), missing


def replace_section(report, section):
    lines = report.splitlines()
    bounds = draft_section_bounds(lines)
    if bounds is None:
        return report.rstrip("\n") + "\n\n" + section
    start, end = bounds
    before = "\n".join(lines[:start])
    after = "\n".join(lines[end:])
    out = (before + "\n" if before else "") + section
    return out + ("\n" + after + "\n" if after else "")


def main(argv):
    if len(argv) != 3:
        print("usage: render-feedback.py <report.md> <feedback.json>", file=sys.stderr)
        return 2
    report_path, feedback_path = argv[1:]
    try:
        with open(report_path, encoding="utf-8") as f:
            report = f.read()
    except OSError as e:
        print("error: cannot read report {} ({})".format(report_path, e), file=sys.stderr)
        return 2
    try:
        with open(feedback_path, encoding="utf-8") as f:
            doc = json.load(f)
    except (OSError, ValueError) as e:
        print("warning: cannot read feedback {} ({}); rendering an empty list".format(feedback_path, e), file=sys.stderr)
        doc = {}
    if not isinstance(doc, dict):
        doc = {}
    section, missing = render_section(doc, report)
    try:
        tmp = report_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(replace_section(report, section))
        os.replace(tmp, report_path)
    except OSError as e:
        print("error: cannot write report {} ({})".format(report_path, e), file=sys.stderr)
        return 2
    if missing:
        print("warning: feedback-missing for {}".format(", ".join(missing)), file=sys.stderr)
        if os.environ.get("GITHUB_ACTIONS"):
            print("::warning::Draft feedback: {} item{} have no sentence ({})".format(
                len(missing), "" if len(missing) == 1 else "s", ", ".join(missing)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
