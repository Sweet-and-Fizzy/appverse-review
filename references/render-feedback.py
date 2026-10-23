#!/usr/bin/env python3
"""Write the report's Draft feedback section from feedback.json.

    python3 references/render-feedback.py <report.md> <feedback.json>

feedback.json is prepare-feedback.py's output with the model's `opening`
and item `text` filled in. The section is replaced whole: a
`## Draft feedback` heading (with or without "— edit before sending") and
its body, up to the next `## ` heading or the structured-findings ```json
fence. With no such heading, the section is appended at the end.

The section is the opening, then each non-empty level as a bold label and
numbered items, numbered straight through, then a feedback-generated marker
and the feedback-covers checksum of every rendered defect key. An item with
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

HEADING = "## Draft feedback — edit before sending"
HEADING_RE = re.compile(r"^##\s+Draft feedback\b", re.IGNORECASE)
TITLE_RE = re.compile(r"^#\s+Appverse Review:\s*(?:[^/\s]+/)?([^\s(]+)", re.MULTILINE)
JSON_FENCE = re.compile(r"^```json\s*$")
LABELS = (("must", "**Must fix**"), ("should", "**Should fix**"), ("suggestion", "**Suggestions (optional)**"))


def default_opening(app_name, report):
    name = app_name
    if not name:
        m = TITLE_RE.search(report)
        name = m.group(1) if m else "this app"
    return "Thank you for submitting {} to Appverse.".format(name)


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
    lines = [HEADING, "", as_text(doc.get("opening")) or default_opening(as_text(doc.get("app_name")), report), ""]
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
            lines.append("{}. {}".format(n, (prefix + " " + text) if prefix else text))
            keys = item.get("defect_keys") if isinstance(item.get("defect_keys"), list) else []
            covers += [str(k) for k in keys if k]
        lines.append("")
    lines += ["<!-- feedback-generated -->", "<!-- feedback-covers: {} -->".format(", ".join(covers)), ""]
    return "\n".join(lines), missing


def replace_section(report, section):
    lines = report.splitlines()
    start = None
    in_fence = False
    for i, line in enumerate(lines):
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence and HEADING_RE.match(line):
            start = i
            break
    if start is None:
        return report.rstrip("\n") + "\n\n" + section
    end = len(lines)
    in_fence = False
    for i in range(start + 1, len(lines)):
        line = lines[i]
        if not in_fence and (JSON_FENCE.match(line) or line.startswith("## ")):
            end = i
            break
        if line.startswith("```"):
            in_fence = not in_fence
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
