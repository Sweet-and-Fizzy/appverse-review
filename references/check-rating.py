#!/usr/bin/env python3
"""Check that judged levels in the report follow their own evidence.

    python3 references/check-rating.py review-<slug>.md review-<slug>.findings.json

Per "## App:" section:
  1. The Documentation rating may not exceed the highest rung whose
     requirements, and every lower rung's, all have non-"none" evidence lines.
  2. The Signals table's Documentation level must be the one the rating maps to
     (Strong/Exemplary -> Low, Adequate -> Medium, Minimal -> High).
  3. The Signals table's Security level must equal the level derived from the
     app's OODT- findings with result FAIL/WARN (none -> Low; low/info only ->
     Medium; any medium/high/critical -> High).
Exit 0 when consistent, 1 with one MISMATCH line per problem, 2 when the
report or findings cannot be read or a needed section is missing.
"""
import json
import re
import sys

RUNGS = [
    ("Minimal", ["what it launches", "prerequisites"]),
    ("Adequate", ["installation", "configuration", "known limitations"]),
    ("Strong", ["troubleshooting", "screenshots", "environment variables"]),
    ("Exemplary", ["info panel", "architecture"]),
]
RATING_ORDER = [r for r, _ in RUNGS]
DOC_SIGNAL = {"Minimal": "High", "Adequate": "Medium", "Strong": "Low", "Exemplary": "Low"}
NONE_WORDS = {"none", "n/a", "na", "absent", "missing", "not", "no"}
SEV_RANK = {"info": 0, "low": 1, "medium": 2, "high": 3, "critical": 4}


def is_none(value):
    if not re.sub(r"[\W_]", "", value):
        return True  # empty or punctuation only ("—", "-", "")
    first = re.sub(r"[^a-z/]", "", value.strip().lower().split()[0])
    return first in NONE_WORDS


def app_sections(text):
    """Yield (app_heading, body) for each '## App:' section."""
    parts = re.split(r"^(## App:[^\n]*)$", text, flags=re.M)
    for i in range(1, len(parts) - 1, 2):
        body = parts[i + 1].split("\n## ", 1)[0]
        yield parts[i].strip(), body


def app_id_from_heading(heading):
    m = re.search(r"\(([^)]*)\)\s*$", heading)
    sub = (m.group(1).strip() if m else "root")
    return "root" if sub in ("", "root", "repo root") else sub


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


def highest_supported_rung(evidence):
    best = None
    for rung, reqs in RUNGS:
        if all(req in evidence and not is_none(evidence[req]) for req in reqs):
            best = rung
        else:
            break
    return best


def signal(body, dim):
    m = re.search(r"^\|\s*(?:\*\*)?" + dim + r"(?:\*\*)?\s*\|\s*(?:\*\*)?(Low|Medium|High)(?:\*\*)?\s*\|",
                  body, flags=re.M)
    return m.group(1) if m else None


def derived_security(findings, app_id):
    sevs = [str(f.get("severity", "")).lower() for f in findings
            if f.get("app_id", "root") == app_id and str(f.get("rule", "")).startswith("OODT-")
            and str(f.get("result", "")).upper() in ("FAIL", "WARN")]
    if not sevs:
        return "Low", 0, None
    top = max(sevs, key=lambda s: SEV_RANK.get(s, 0))
    return ("High" if SEV_RANK.get(top, 0) >= 2 else "Medium"), len(sevs), top


def main(argv):
    if len(argv) != 3:
        print("usage: check-rating.py <report.md> <findings.json>", file=sys.stderr)
        return 2
    try:
        report = open(argv[1]).read()
        findings = json.load(open(argv[2]))
    except (OSError, ValueError) as e:
        print("error: {}".format(e), file=sys.stderr)
        return 2
    problems = 0
    seen = 0
    for heading, body in app_sections(report):
        seen += 1
        app_id = app_id_from_heading(heading)
        doc = subsection(body, "Documentation")
        if doc is None:
            print("error: {} has no '### Documentation' section".format(heading), file=sys.stderr)
            return 2
        rm = re.search(r"Rating:\s*\**\s*(Minimal|Adequate|Strong|Exemplary)", doc)
        if not rm:
            print("error: {} has no Documentation rating".format(heading), file=sys.stderr)
            return 2
        rating = rm.group(1)
        evidence = parse_evidence(doc)
        supported = highest_supported_rung(evidence)

        signals = subsection(body, "Signals")
        if signals is None:
            print("error: {} has no '### Signals' section".format(heading), file=sys.stderr)
            return 2
        doc_sig = signal(signals, "Documentation")
        if doc_sig is None:
            print("error: {} has no Signals row for Documentation".format(heading), file=sys.stderr)
            return 2
        sec_sig = signal(signals, "Security")
        if sec_sig is None:
            print("error: {} has no Signals row for Security".format(heading), file=sys.stderr)
            return 2

        if supported is None or RATING_ORDER.index(rating) > RATING_ORDER.index(supported):
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
            print("MISMATCH Documentation rating ({} claimed but '{}' evidence is {}; highest supported rung is {})".format(
                rating, blocker, "missing" if blocker not in evidence else "none", supported or "none"))
        if doc_sig != DOC_SIGNAL[rating]:
            problems += 1
            print("MISMATCH Documentation signal (report says {}; rating {} maps to {})".format(doc_sig, rating, DOC_SIGNAL[rating]))
        derived, count, top = derived_security(findings, app_id)
        if sec_sig != derived:
            problems += 1
            detail = "{} OODT finding{}, highest severity {}".format(count, "" if count == 1 else "s", top) if count else "no OODT findings"
            print("MISMATCH Security signal (report says {}; findings derive {}: {})".format(sec_sig, derived, detail))
    if seen == 0:
        print("error: no '## App:' section in report", file=sys.stderr)
        return 2
    print("ratings: consistent" if not problems else "ratings: {} mismatch{}".format(problems, "" if problems == 1 else "es"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
